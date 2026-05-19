#!/usr/bin/env bash
# Vercel / CI: install Flutter (Linux), then build web with secrets from env.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "ERROR: Set SUPABASE_URL and SUPABASE_ANON_KEY in the Vercel project Environment Variables (Production + Preview)." >&2
  exit 1
fi

# pubspec.yaml lists .env as an asset; local dev uses a real file. CI has no file.
if [[ ! -f .env ]]; then
  echo "INFO: Creating placeholder .env so Flutter can bundle the declared asset (values come from --dart-define)."
  touch .env
fi

FLUTTER_DIR="${FLUTTER_ROOT:-$HOME/flutter_vercel}"
if ! command -v flutter >/dev/null 2>&1; then
  echo "INFO: Installing Flutter stable to $FLUTTER_DIR ..."
  rm -rf "$FLUTTER_DIR"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
  export PATH="$FLUTTER_DIR/bin:$PATH"
  flutter config --no-analytics >/dev/null
  flutter precache --web
else
  export PATH="$(dirname "$(command -v flutter)"):$PATH"
fi

flutter --version
flutter pub get

DEFINE_ARGS=(
  "--dart-define=SUPABASE_URL=${SUPABASE_URL}"
  "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
)
[[ -n "${GEMINI_API_KEY:-}" ]] && DEFINE_ARGS+=("--dart-define=GEMINI_API_KEY=${GEMINI_API_KEY}")
[[ -n "${ENABLE_GLOBAL_ORDER_LISTENER:-}" ]] && DEFINE_ARGS+=("--dart-define=ENABLE_GLOBAL_ORDER_LISTENER=${ENABLE_GLOBAL_ORDER_LISTENER}")
[[ -n "${ENABLE_GLOBAL_PURCHASE_LISTENER:-}" ]] && DEFINE_ARGS+=("--dart-define=ENABLE_GLOBAL_PURCHASE_LISTENER=${ENABLE_GLOBAL_PURCHASE_LISTENER}")

flutter build web --release "${DEFINE_ARGS[@]}"

echo "INFO: Web build output: build/web"
