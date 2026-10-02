-- =============================================================
-- Supplier price rules
--
-- Some suppliers print no product name: a butcher's scale prints every line as
-- "Grundpreiseingabe" with only weight, price per kg and total. suppliers.price_rule tells the
-- products apart by price per unit, both when a scan is read (scan-expense) and when the supplier
-- is chosen by hand (assign_expense_supplier). It wins over learned catalog entries, which cannot
-- tell two products with the same receipt text apart.
--
--   { "text": "Grundpreiseingabe",  lines whose name contains this (any case); omit = every line
--     "split": 8.0,                  price per unit between the cheaper and the dearer product
--     "low":  "<material id>",       the cheaper product
--     "high": "<material id>",       the dearer product (on a receipt with both: always the dearest)
--     "conversion": 1000 }           material units per purchased unit (1 kg → 1000 g)
-- =============================================================

ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS price_rule JSONB;

CREATE OR REPLACE FUNCTION _apply_supplier_price_rule(p_purchase_id UUID)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rule JSONB;
  v_text TEXT;
  v_count INT;
BEGIN
  SELECT s.price_rule INTO v_rule
    FROM purchases p JOIN suppliers s ON s.id = p.supplier_id
   WHERE p.id = p_purchase_id;
  IF v_rule IS NULL THEN
    RETURN 0;
  END IF;
  v_text := NULLIF(lower(trim(v_rule->>'text')), '');

  WITH priced AS (
    SELECT i.id, round(COALESCE(i.unit_price, i.total_item_price / NULLIF(i.quantity, 0)), 2) AS price
      FROM purchase_items i
     WHERE i.purchase_id = p_purchase_id
       AND NOT i.booked
       AND (v_text IS NULL OR strpos(lower(i.raw_name), v_text) > 0)
  ),
  valid AS (SELECT * FROM priced WHERE price > 0),
  bounds AS (SELECT min(price) AS lo, max(price) AS hi, count(DISTINCT price) AS n FROM valid),
  pick AS (
    SELECT v.id,
           (CASE
              WHEN b.n >= 2 AND v.price = b.lo THEN v_rule->>'low'
              WHEN b.n >= 2 AND v.price = b.hi THEN v_rule->>'high'
              WHEN v.price < (v_rule->>'split')::NUMERIC THEN v_rule->>'low'
              ELSE v_rule->>'high'
            END)::UUID AS material_id
      FROM valid v CROSS JOIN bounds b
  )
  UPDATE purchase_items i SET
    material_id = pk.material_id,
    conversion_ratio = (v_rule->>'conversion')::NUMERIC,
    base_unit = m.unit_of_measure,
    match_source = 'rule',
    match_confidence = 1,
    purchase_catalog_item_id = NULL,
    kind = 'product',
    stock = (v_rule->>'conversion')::NUMERIC > 0
  FROM pick pk
  JOIN material m ON m.id = pk.material_id
  WHERE i.id = pk.id;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION _apply_supplier_price_rule(UUID) FROM PUBLIC, anon, authenticated;

-- Choosing the supplier by hand applies its price rule after the learned catalog.
CREATE OR REPLACE FUNCTION assign_expense_supplier(p_purchase_id UUID, p_supplier_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_purchase purchases%ROWTYPE;
  v_supplier suppliers%ROWTYPE;
  v_seen_name TEXT;
  v_seen_vat TEXT;
  v_matched INT;
  v_ruled INT;
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
  v_ruled := _apply_supplier_price_rule(p_purchase_id);
  RETURN jsonb_build_object('ok', TRUE, 'lines_matched_from_catalog', v_matched, 'lines_matched_by_price', v_ruled);
END;
$$;
REVOKE ALL ON FUNCTION assign_expense_supplier(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION assign_expense_supplier(UUID, UUID) TO authenticated;
