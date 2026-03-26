#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

echo "Starting build.sh script (v3 - with manual Flutter install)..."
echo "Initial PATH: $PATH"
echo "FLUTTER_VERSION from env: $FLUTTER_VERSION"
echo "HOME directory: $HOME"
echo "Current user: $(whoami)"

# Function to check if flutter command is available
check_flutter() {
  if command -v flutter &> /dev/null; then
    echo "Flutter command successfully found in PATH."
    return 0 # success
  else
    echo "Flutter command not found in PATH."
    return 1 # failure
  fi
}

# Attempt to source common environment setup scripts (less critical now but good to keep)
if [ -f "$HOME/.nvm/nvm.sh" ]; then . "$HOME/.nvm/nvm.sh"; fi
if [ -f "$HOME/.asdf/asdf.sh" ]; then . "$HOME/.asdf/asdf.sh"; fi

# Initial check for Flutter
if check_flutter; then
  echo "Flutter found on initial check."
else
  echo "Flutter not found initially. Attempting manual installation..."
  if [ -z "$FLUTTER_VERSION" ]; then
    echo "CRITICAL: FLUTTER_VERSION is not set. Cannot download Flutter."
    exit 1
  fi

  FLUTTER_SDK_DIR="$HOME/flutter_sdk_manual"
  FLUTTER_SDK_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  FLUTTER_SDK_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_SDK_ARCHIVE}"

  echo "Target Flutter SDK directory: $FLUTTER_SDK_DIR"
  echo "Flutter SDK archive name: $FLUTTER_SDK_ARCHIVE"
  echo "Flutter SDK download URL: $FLUTTER_SDK_URL"

  # Clean up previous attempt if any
  rm -rf "$FLUTTER_SDK_DIR" "$FLUTTER_SDK_ARCHIVE"
  mkdir -p "$FLUTTER_SDK_DIR"

  echo "Downloading Flutter SDK..."
  if command -v wget &> /dev/null; then
    wget -q "$FLUTTER_SDK_URL"
  elif command -v curl &> /dev/null; then
    curl -sLO "$FLUTTER_SDK_URL"
  else
    echo "CRITICAL: Neither wget nor curl is available to download Flutter."
    exit 1
  fi

  if [ ! -f "$FLUTTER_SDK_ARCHIVE" ]; then
    echo "CRITICAL: Flutter SDK archive failed to download."
    exit 1
  fi

  echo "Extracting Flutter SDK..."
  tar xf "$FLUTTER_SDK_ARCHIVE" -C "$FLUTTER_SDK_DIR" --strip-components=1
  rm "$FLUTTER_SDK_ARCHIVE" # Clean up archive

  echo "Adding manually installed Flutter SDK to PATH: $FLUTTER_SDK_DIR/bin"
  export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
  echo "Updated PATH: $PATH"

  # Final check for Flutter after manual install
  if ! check_flutter; then
    echo "CRITICAL: Flutter command still not found even after manual installation attempt."
    echo "Contents of $FLUTTER_SDK_DIR:"
    ls -la "$FLUTTER_SDK_DIR"
    echo "Contents of $FLUTTER_SDK_DIR/bin:"
    ls -la "$FLUTTER_SDK_DIR/bin" || echo "$FLUTTER_SDK_DIR/bin not found or no permissions."
    exit 1
  fi
fi

echo "Proceeding with Flutter commands..."
echo "Running flutter doctor..."
flutter doctor

echo "Running flutter --version..."
flutter --version

# Ensure .env exists for Flutter asset bundling (pubspec.yaml lists .env under assets)
# In Netlify, we generally don't commit .env to the repo. Create it from environment variables if missing.
if [ ! -f ".env" ]; then
  echo ".env not found. Creating .env from environment variables for the build..."
  {
    echo "SUPABASE_URL=${SUPABASE_URL}"
    echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
    echo "GEMINI_API_KEY=${GEMINI_API_KEY}"
  } > .env
fi

echo "Starting Flutter web build..."
flutter build web \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY"

echo "Flutter web build finished successfully."
