#!/bin/bash
# Run Metro import using a venv (avoids "externally-managed-environment" on macOS).
# Usage:
#   export SUPABASE_URL="https://xxx.supabase.co"
#   export SUPABASE_SERVICE_ROLE_KEY="your-key"
#   ./scripts/run_metro_import.sh /path/to/metro_items_cleaned.xlsx [--dry-run] [--images /path/to/images]

set -e
cd "$(dirname "$0")/.."
VENV=".venv"

if [[ ! -d "$VENV" ]]; then
  echo "Creating virtual environment..."
  python3 -m venv "$VENV"
fi
echo "Installing dependencies..."
"$VENV/bin/pip" install -q openpyxl supabase

echo "Running import..."
exec "$VENV/bin/python" scripts/import_metro_items.py "$@"
