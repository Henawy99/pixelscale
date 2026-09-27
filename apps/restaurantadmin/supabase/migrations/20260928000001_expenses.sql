-- =============================================================
-- Expenses: scan a supplier invoice → Gemini reads it → lines are matched to materials →
-- one tap books the quantities into inventory.
--
-- * purchases / purchase_items get the invoice fields and per-line match state.
-- * book_expense() updates stock, average cost and inventory_log in one transaction and
--   learns "supplier product → material + pack size" in purchase_catalog_items, so the next
--   invoice from the same supplier is matched without asking.
-- * unbook_expense() reverses a booking.
-- * assign_expense_supplier() links an expense to a supplier, remembers the name / VAT id the
--   supplier uses on documents and re-applies what was learned for that supplier.
-- =============================================================

-- 1. Categories for goods that did not fit anywhere (oil, cheese, paper towels, ...)
ALTER TYPE material_category_enum ADD VALUE IF NOT EXISTS 'DAIRY';
ALTER TYPE material_category_enum ADD VALUE IF NOT EXISTS 'DRY GOODS';
ALTER TYPE material_category_enum ADD VALUE IF NOT EXISTS 'SUPPLIES';

-- 2. Suppliers: how they identify themselves on documents
ALTER TABLE suppliers
  ADD COLUMN IF NOT EXISTS vat_id TEXT,
  ADD COLUMN IF NOT EXISTS aliases TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS website TEXT;
CREATE INDEX IF NOT EXISTS idx_suppliers_vat_id ON suppliers (upper(vat_id)) WHERE vat_id IS NOT NULL;

-- 3. Expenses (purchases)
ALTER TABLE purchases
  ADD COLUMN IF NOT EXISTS invoice_number TEXT,
  ADD COLUMN IF NOT EXISTS document_paths TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS net_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS vat_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS analysis JSONB,
  ADD COLUMN IF NOT EXISTS analysis_model TEXT,
  ADD COLUMN IF NOT EXISTS error TEXT,
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS booked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS booked_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
-- status: analyzing → needs_review → booked (failed when the document could not be read).
-- Older rows keep 'pending_review' / 'approved'.
CREATE INDEX IF NOT EXISTS idx_purchases_created_at ON purchases (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_purchases_supplier_invoice ON purchases (supplier_id, invoice_number);

ALTER TABLE purchase_items
  ADD COLUMN IF NOT EXISTS position INT,
  ADD COLUMN IF NOT EXISTS vat_rate NUMERIC,
  ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'product',
  ADD COLUMN IF NOT EXISTS content_per_unit NUMERIC,
  ADD COLUMN IF NOT EXISTS content_unit TEXT,
  ADD COLUMN IF NOT EXISTS suggestion JSONB,
  ADD COLUMN IF NOT EXISTS match_source TEXT,
  ADD COLUMN IF NOT EXISTS match_confidence NUMERIC,
  ADD COLUMN IF NOT EXISTS stock BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS base_quantity NUMERIC,
  ADD COLUMN IF NOT EXISTS booked BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON purchase_items (purchase_id, position);

-- 4. Inventory log entries point at the expense they came from
ALTER TABLE inventory_log ADD COLUMN IF NOT EXISTS purchase_id UUID REFERENCES purchases(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_inventory_log_purchase ON inventory_log (purchase_id) WHERE purchase_id IS NOT NULL;
ALTER TABLE inventory_log DROP CONSTRAINT IF EXISTS inventory_log_change_type_check;
ALTER TABLE inventory_log ADD CONSTRAINT inventory_log_change_type_check CHECK (change_type = ANY (ARRAY[
  'ENTRY', 'OUT', 'CORRECTION', 'INITIAL_STOCK', 'MANUAL_RECEIPT', 'STOCK_RETURNED_CANCEL', 'RECEIPT_CANCELLED',
  'PURCHASE', 'PURCHASE_RETURN', 'PURCHASE_UNDO'
]));

-- 5. Faster catalog lookups by supplier + article number / receipt text
CREATE INDEX IF NOT EXISTS idx_catalog_supplier_article
  ON purchase_catalog_items (supplier_id, ltrim(article_number, '0')) WHERE article_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_catalog_supplier_receipt_name
  ON purchase_catalog_items (supplier_id, lower(receipt_name)) WHERE receipt_name IS NOT NULL;

-- 6. Who may work with expenses: staff accounts (not drivers)
CREATE OR REPLACE FUNCTION _caller_is_staff()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'manager', 'worker'));
$$;

-- 7. Re-apply what was learned for the expense's supplier to lines that are not booked yet.
CREATE OR REPLACE FUNCTION _apply_supplier_catalog(p_purchase_id UUID)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_supplier UUID;
  v_count INT;
BEGIN
  SELECT supplier_id INTO v_supplier FROM purchases WHERE id = p_purchase_id;
  IF v_supplier IS NULL THEN
    RETURN 0;
  END IF;

  WITH matches AS (
    SELECT DISTINCT ON (i.id) i.id AS item_id, c.id AS catalog_id, c.material_id, c.conversion_ratio, m.unit_of_measure
      FROM purchase_items i
      JOIN purchase_catalog_items c
        ON c.supplier_id = v_supplier
       AND c.material_id IS NOT NULL
       AND (
         (i.item_number IS NOT NULL AND c.article_number IS NOT NULL
            AND ltrim(c.article_number, '0') = ltrim(i.item_number, '0'))
         OR (c.receipt_name IS NOT NULL AND lower(c.receipt_name) = lower(i.raw_name))
       )
      JOIN material m ON m.id = c.material_id
     WHERE i.purchase_id = p_purchase_id AND NOT i.booked
     ORDER BY i.id, (c.article_number IS NOT NULL) DESC, c.created_at DESC
  )
  UPDATE purchase_items i SET
    material_id = mt.material_id,
    purchase_catalog_item_id = mt.catalog_id,
    conversion_ratio = COALESCE(mt.conversion_ratio, i.conversion_ratio),
    base_unit = mt.unit_of_measure,
    match_source = 'catalog',
    match_confidence = 1,
    stock = (i.kind = 'product' AND COALESCE(mt.conversion_ratio, i.conversion_ratio) > 0)
  FROM matches mt
  WHERE i.id = mt.item_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- 8. Link an expense to a supplier (picked or just created) and learn how it appears on documents.
CREATE OR REPLACE FUNCTION assign_expense_supplier(p_purchase_id UUID, p_supplier_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_purchase purchases%ROWTYPE;
  v_supplier suppliers%ROWTYPE;
  v_seen_name TEXT;
  v_seen_vat TEXT;
  v_matched INT;
BEGIN
  IF NOT _caller_is_staff() THEN
    RAISE EXCEPTION 'Not allowed';
  END IF;
  SELECT * INTO v_purchase FROM purchases WHERE id = p_purchase_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;
  IF v_purchase.status = 'booked' THEN
    RAISE EXCEPTION 'This expense is already in the inventory';
  END IF;
  SELECT * INTO v_supplier FROM suppliers WHERE id = p_supplier_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Supplier not found';
  END IF;

  v_seen_name := NULLIF(trim(v_purchase.analysis->'document'->'supplier'->>'name'), '');
  v_seen_vat := NULLIF(upper(regexp_replace(v_purchase.analysis->'document'->'supplier'->>'vat_id', '\s', '', 'g')), '');

  UPDATE suppliers SET
    aliases = CASE
      WHEN v_seen_name IS NULL OR lower(v_seen_name) = lower(name)
        OR lower(v_seen_name) = ANY (SELECT lower(a) FROM unnest(aliases) a) THEN aliases
      ELSE array_append(aliases, v_seen_name)
    END,
    vat_id = COALESCE(vat_id, v_seen_vat),
    updated_at = NOW()
  WHERE id = p_supplier_id;

  UPDATE purchases SET supplier_id = p_supplier_id, supplier_name = v_supplier.name, updated_at = NOW()
   WHERE id = p_purchase_id;

  v_matched := _apply_supplier_catalog(p_purchase_id);
  RETURN jsonb_build_object('ok', TRUE, 'lines_matched_from_catalog', v_matched);
END;
$$;

-- 9. Book an expense into inventory.
-- p_lines = [{ item_id, material_id, conversion_ratio, stock }] — the reviewed decision per line;
-- conversion_ratio = material units in ONE purchased unit (e.g. 2500 gram per "Packung").
CREATE OR REPLACE FUNCTION book_expense(p_purchase_id UUID, p_lines JSONB)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_purchase purchases%ROWTYPE;
  v_supplier_name TEXT;
  v_source TEXT;
  v_line JSONB;
  v_item purchase_items%ROWTYPE;
  v_material material%ROWTYPE;
  v_material_id UUID;
  v_conv NUMERIC;
  v_stock BOOLEAN;
  v_base NUMERIC;
  v_old NUMERIC;
  v_new NUMERIC;
  v_unit_cost NUMERIC;
  v_catalog_id UUID;
  v_changes JSONB := '[]'::JSONB;
BEGIN
  IF NOT _caller_is_staff() THEN
    RAISE EXCEPTION 'Not allowed';
  END IF;
  SELECT * INTO v_purchase FROM purchases WHERE id = p_purchase_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;
  IF v_purchase.status = 'booked' THEN
    RAISE EXCEPTION 'This expense is already in the inventory';
  END IF;
  IF v_purchase.supplier_id IS NULL THEN
    RAISE EXCEPTION 'Choose or create the supplier first';
  END IF;

  SELECT name INTO v_supplier_name FROM suppliers WHERE id = v_purchase.supplier_id;
  v_source := v_supplier_name || COALESCE(' · ' || v_purchase.invoice_number, '');

  FOR v_line IN SELECT x FROM jsonb_array_elements(COALESCE(p_lines, '[]'::JSONB)) x LOOP
    SELECT * INTO v_item FROM purchase_items
     WHERE id = (v_line->>'item_id')::UUID AND purchase_id = p_purchase_id
     FOR UPDATE;
    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    v_material_id := NULLIF(v_line->>'material_id', '')::UUID;
    v_conv := NULLIF(v_line->>'conversion_ratio', '')::NUMERIC;
    v_stock := COALESCE((v_line->>'stock')::BOOLEAN, FALSE)
               AND v_material_id IS NOT NULL AND COALESCE(v_conv, 0) > 0 AND v_item.quantity IS NOT NULL;
    v_base := CASE WHEN v_stock THEN round(v_item.quantity * v_conv, 3) END;

    IF v_material_id IS NOT NULL THEN
      SELECT * INTO v_material FROM material WHERE id = v_material_id FOR UPDATE;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Material % not found', v_material_id;
      END IF;
    END IF;

    UPDATE purchase_items SET
      material_id = v_material_id,
      conversion_ratio = v_conv,
      base_unit = CASE WHEN v_material_id IS NOT NULL THEN v_material.unit_of_measure END,
      base_quantity = v_base,
      stock = v_stock,
      booked = v_stock AND v_base <> 0,
      match_source = CASE
        WHEN v_material_id IS DISTINCT FROM v_item.material_id OR v_conv IS DISTINCT FROM v_item.conversion_ratio
          THEN 'manual' ELSE match_source END
    WHERE id = v_item.id;

    IF v_stock AND v_base <> 0 THEN
      v_old := COALESCE(v_material.current_quantity, 0);
      v_new := v_old + v_base;
      -- Weighted average net cost per material unit (purchases only; returns keep the average).
      IF v_base > 0 AND COALESCE(v_item.total_item_price, 0) > 0 THEN
        v_unit_cost := v_item.total_item_price / v_base;
        UPDATE material SET average_unit_cost = CASE
            WHEN GREATEST(v_old, 0) = 0 OR COALESCE(average_unit_cost, 0) = 0 THEN v_unit_cost
            ELSE (GREATEST(v_old, 0) * average_unit_cost + v_base * v_unit_cost) / (GREATEST(v_old, 0) + v_base)
          END
         WHERE id = v_material.id;
      END IF;
      UPDATE material SET current_quantity = v_new WHERE id = v_material.id;

      INSERT INTO inventory_log (
        material_id, material_name, change_type, quantity_change, new_quantity_after_change,
        source_details, user_id, unit_price_paid, total_price_paid, purchase_id
      ) VALUES (
        v_material.id, v_material.name, CASE WHEN v_base > 0 THEN 'PURCHASE' ELSE 'PURCHASE_RETURN' END,
        v_base, v_new, v_source, auth.uid(),
        CASE WHEN v_base <> 0 AND v_item.total_item_price IS NOT NULL THEN v_item.total_item_price / v_base END,
        v_item.total_item_price, p_purchase_id
      );

      v_changes := v_changes || jsonb_build_object(
        'material_id', v_material.id, 'material', v_material.name, 'unit', v_material.unit_of_measure,
        'change', v_base, 'new_quantity', v_new
      );
    END IF;

    -- Learn: this supplier's product = this material, this many material units per purchased unit.
    IF v_material_id IS NOT NULL AND COALESCE(v_conv, 0) > 0 THEN
      SELECT id INTO v_catalog_id FROM purchase_catalog_items
       WHERE supplier_id = v_purchase.supplier_id
         AND (
           (v_item.item_number IS NOT NULL AND article_number IS NOT NULL
              AND ltrim(article_number, '0') = ltrim(v_item.item_number, '0'))
           OR (v_item.item_number IS NULL AND lower(receipt_name) = lower(v_item.raw_name))
         )
       ORDER BY (article_number IS NOT NULL) DESC, created_at DESC
       LIMIT 1;

      IF v_catalog_id IS NULL THEN
        INSERT INTO purchase_catalog_items (
          supplier_id, name, receipt_name, article_number, unit, material_id, base_unit,
          conversion_ratio, last_known_price, vat_rate
        ) VALUES (
          v_purchase.supplier_id, v_item.raw_name, v_item.raw_name, v_item.item_number, v_item.unit, v_material_id,
          v_material.unit_of_measure, v_conv, v_item.unit_price, v_item.vat_rate
        ) RETURNING id INTO v_catalog_id;
      ELSE
        UPDATE purchase_catalog_items SET
          material_id = v_material_id,
          base_unit = v_material.unit_of_measure,
          conversion_ratio = v_conv,
          unit = COALESCE(v_item.unit, unit),
          receipt_name = COALESCE(receipt_name, v_item.raw_name),
          last_known_price = COALESCE(v_item.unit_price, last_known_price),
          vat_rate = COALESCE(v_item.vat_rate, vat_rate)
        WHERE id = v_catalog_id;
      END IF;
      UPDATE purchase_items SET purchase_catalog_item_id = v_catalog_id WHERE id = v_item.id;
    END IF;
  END LOOP;

  UPDATE purchases SET status = 'booked', booked_at = NOW(), booked_by = auth.uid(), updated_at = NOW()
   WHERE id = p_purchase_id;

  RETURN jsonb_build_object('ok', TRUE, 'changes', v_changes);
END;
$$;

-- 10. Reverse a booking (net effect of everything this expense did to stock).
CREATE OR REPLACE FUNCTION unbook_expense(p_purchase_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_purchase purchases%ROWTYPE;
  r RECORD;
  v_new NUMERIC;
  v_count INT := 0;
BEGIN
  IF NOT _caller_is_staff() THEN
    RAISE EXCEPTION 'Not allowed';
  END IF;
  SELECT * INTO v_purchase FROM purchases WHERE id = p_purchase_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;
  IF v_purchase.status <> 'booked' THEN
    RAISE EXCEPTION 'This expense is not in the inventory';
  END IF;

  FOR r IN
    SELECT l.material_id, SUM(l.quantity_change) AS net
      FROM inventory_log l
     WHERE l.purchase_id = p_purchase_id
       AND l.change_type IN ('PURCHASE', 'PURCHASE_RETURN', 'PURCHASE_UNDO')
     GROUP BY l.material_id
    HAVING SUM(l.quantity_change) <> 0
  LOOP
    UPDATE material SET current_quantity = COALESCE(current_quantity, 0) - r.net
     WHERE id = r.material_id
     RETURNING current_quantity INTO v_new;
    INSERT INTO inventory_log (material_id, material_name, change_type, quantity_change, new_quantity_after_change,
                               source_details, user_id, purchase_id)
    SELECT r.material_id, m.name, 'PURCHASE_UNDO', -r.net, v_new,
           'Undo: ' || COALESCE(v_purchase.supplier_name, '') || COALESCE(' · ' || v_purchase.invoice_number, ''),
           auth.uid(), p_purchase_id
      FROM material m WHERE m.id = r.material_id;
    v_count := v_count + 1;
  END LOOP;

  UPDATE purchase_items SET booked = FALSE WHERE purchase_id = p_purchase_id;
  UPDATE purchases SET status = 'needs_review', booked_at = NULL, booked_by = NULL, updated_at = NOW()
   WHERE id = p_purchase_id;
  RETURN jsonb_build_object('ok', TRUE, 'materials_reversed', v_count);
END;
$$;

REVOKE ALL ON FUNCTION _caller_is_staff() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION _apply_supplier_catalog(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION assign_expense_supplier(UUID, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION book_expense(UUID, JSONB) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION unbook_expense(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION assign_expense_supplier(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION book_expense(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION unbook_expense(UUID) TO authenticated;

-- 11. Live updates: an expense scanned on the kitchen phone shows up on the PC right away.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'purchases') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.purchases;
  END IF;
END $$;
