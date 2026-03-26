# Metro items import (Excel → purchase catalog)

Fastest way to add 200+ Metro items to the **Metro** supplier in the app.

## 1. Prerequisites

- **Excel file** with columns (names matched case-insensitively):
  - **Name** (or "Article name", "Product name") – required
  - **Price** (or "Price (€)") – required
  - **Article number** (or "Art. number") – optional
  - **EAN** (or "EAN number") – optional (used later for images)

- **Supabase keys** (from [Supabase Dashboard](https://app.supabase.com) → Project → Settings → API):
  - `SUPABASE_URL` (you likely have this in `.env` already)
  - **`SUPABASE_SERVICE_ROLE_KEY`** – use the **service_role** key (secret), not the anon key. The script needs it to bypass RLS. Add it to your project `.env` so you don’t have to export it each time.

**If you get 401 "Invalid API key":** You must use the **service_role** key. In Supabase Dashboard → Settings → API, copy the `service_role` key (under "Project API keys") and add to `.env`:  
`SUPABASE_SERVICE_ROLE_KEY=eyJ...your_key...`  
The script loads `.env` automatically.

## 2. One-time setup (macOS / Homebrew Python)

On macOS, system Python is “externally managed,” so use a **virtual environment** (or the helper script below):

```bash
cd /path/to/restaurantadmin
python3 -m venv .venv
source .venv/bin/activate
pip install openpyxl supabase
```

Or use the **helper script** (creates `.venv` and installs deps automatically). The script reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from your project **`.env`** if set there (no need to export each time):

```bash
chmod +x scripts/run_metro_import.sh

# Ensure .env has SUPABASE_SERVICE_ROLE_KEY=your_service_role_key (from Dashboard → API)

# Dry run
./scripts/run_metro_import.sh /Users/youssefelhenawy/metro_project/metro_items_cleaned.xlsx --dry-run

# Real import
./scripts/run_metro_import.sh /Users/youssefelhenawy/metro_project/metro_items_cleaned.xlsx

# Update prices only (for items already inserted)
./scripts/run_metro_import.sh /Users/youssefelhenawy/metro_project/metro_items_cleaned.xlsx --update-prices
```

## 3. Run the import (without helper script)

If you already have `openpyxl` and `supabase` installed (e.g. inside an activated venv):

```bash
export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"

# Dry run (no DB writes, just show parsed rows)
python3 scripts/import_metro_items.py /Users/youssefelhenawy/metro_project/metro_items_cleaned.xlsx --dry-run

# Real import
python3 scripts/import_metro_items.py /Users/youssefelhenawy/metro_project/metro_items_cleaned.xlsx
```

- **Unit** and **Default qty** are left empty; you can fill them later in the app.
- Rows with the same **article number** for Metro are skipped (no duplicate inserts).

## 4. Attach images (named by EAN)

Images must be named by EAN (e.g. `4337182011682.jpg`, `9001414081013.jpg`). They are uploaded to the **purchase_items** bucket and `image_url` is set on each matching `purchase_catalog_items` row.

**Option A – Import Excel then upload images in one run:**

```bash
python3 scripts/import_metro_items.py /Users/youssefelhenawy/metro_project/metro_items_cleaned.xlsx \
  --images /Users/youssefelhenawy/metro_project/metro_images
```

**Option B – Only upload images (items already in DB):**

```bash
python3 scripts/import_metro_items.py --images-only --images /Users/youssefelhenawy/metro_project/metro_images
```

- Supported extensions: `.jpg`, `.jpeg`, `.png`, `.webp`
- Only files whose stem (filename without extension) matches an EAN of an existing Metro purchase item are uploaded; `image_url` is updated for that row.
- Re-running with the same images overwrites existing files (upsert).

## 5. Alternative: different supplier name

If the supplier is not exactly "Metro":

```bash
python3 scripts/import_metro_items.py /path/to/file.xlsx --supplier-name "Metro Cash"
```

## Column mapping

The script looks for these column names (any match is used):

| Data        | Possible headers |
|------------|-------------------|
| Name       | name, article name, product name, item name |
| Price      | price, price (€), last_known_price |
| Article no | article number, art number, art. number, article_number |
| EAN        | ean, ean number |

If your Excel uses different headers, you can export the sheet to CSV and we can add a CSV variant, or you can rename the first row in the Excel to one of the names above.
