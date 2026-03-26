#!/bin/bash
# ============================================
# PixelScale Project Manager (pm)
# Interactive CLI to run, build, and manage apps
# ============================================
# Apps: animight · playmaker · restaurantadmin · tennisacademyapp
# Usage:
#   ./pm                # Interactive menu
#   ./pm run            # Select & run an app in dev mode
#   ./pm build          # Select & build for iOS / Android
#   ./pm build-all      # Build all apps (both platforms)
#   ./pm ios            # Build all iOS apps → TestFlight
#   ./pm android        # Build all Android apps → Play Console
#   ./pm list           # List all apps
#   ./pm help           # Show help
# ============================================

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ────────────────────────────────────────────────────────────
# App discovery
# ────────────────────────────────────────────────────────────
get_apps() {
  local apps=()
  for dir in "$APPS_DIR"/*/; do
    local name=$(basename "$dir")
    [[ "$name" == _* ]] && continue
    [[ -f "$dir/pubspec.yaml" || -f "$dir/package.json" ]] && apps+=("$name")
  done
  echo "${apps[@]}"
}

get_app_type() {
  local app_dir="$APPS_DIR/$1"
  # pubspec.yaml takes priority — Flutter projects may also have package.json
  if [[ -f "$app_dir/pubspec.yaml" ]]; then
    echo "flutter"
  elif [[ -f "$app_dir/package.json" ]]; then
    echo "expo"
  else
    echo "unknown"
  fi
}

# ────────────────────────────────────────────────────────────
# Version helpers
# ────────────────────────────────────────────────────────────

# Read current version string (X.Y.Z+N) from pubspec.yaml
get_version() {
  local app_dir="$APPS_DIR/$1"
  local pubspec="$app_dir/pubspec.yaml"
  [[ ! -f "$pubspec" ]] && echo "?.?.?+?" && return
  grep -E '^version:' "$pubspec" | head -1 | sed 's/version: *//;s/ *#.*//' | tr -d '[:space:]'
}

# Parse X.Y.Z part
get_version_name() { echo "$1" | cut -d'+' -f1; }

# Parse the build number (N)
get_build_number() { echo "$1" | cut -d'+' -f2; }

# Bump build number in pubspec.yaml and show a visual version-bump box
bump_build_number() {
  local app_dir="$APPS_DIR/$1"
  local pubspec="$app_dir/pubspec.yaml"
  [[ ! -f "$pubspec" ]] && echo -e "${RED}No pubspec.yaml in $app_dir${NC}" && return 1

  local current_version; current_version=$(get_version "$1")
  local version_name;    version_name=$(get_version_name "$current_version")
  local old_build;       old_build=$(get_build_number "$current_version")
  local new_build=$(( old_build + 1 ))
  local new_version="${version_name}+${new_build}"

  # Write new version
  sed -i '' "s/^version: .*/version: ${new_version}/" "$pubspec"

  echo -e ""
  echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}${BOLD}│        ⬆  Version Bump                  │${NC}"
  echo -e "${CYAN}${BOLD}├─────────────────────────────────────────┤${NC}"
  echo -e "${CYAN}│${NC}  App:        ${BOLD}$1${NC}"
  echo -e "${CYAN}│${NC}  Old build:  ${YELLOW}${version_name}+${old_build}${NC}"
  echo -e "${CYAN}│${NC}  New build:  ${GREEN}${BOLD}${new_version}${NC}  ← will be shipped"
  echo -e "${CYAN}${BOLD}└─────────────────────────────────────────┘${NC}"
  echo ""
}

# ────────────────────────────────────────────────────────────
# UI Helpers
# ────────────────────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║      PixelScale Project Manager 🎮        ║${NC}"
  echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════╝${NC}"
  echo ""
}

select_app() {
  local prompt="$1"
  local show_version_flag="${2:-false}"   # pass 'true' to show version
  local apps=($(get_apps))

  if [[ ${#apps[@]} -eq 0 ]]; then
    echo -e "${RED}No apps found in $APPS_DIR${NC}" >&2
    exit 1
  fi

  # Print menu to /dev/tty so it shows even inside $()
  echo -e "${CYAN}${BOLD}${prompt}${NC}" >/dev/tty
  echo "" >/dev/tty
  for i in "${!apps[@]}"; do
    local type=$(get_app_type "${apps[$i]}")
    local badge=""
    [[ "$type" == "expo" ]]    && badge="${BLUE}[Expo]${NC}"
    [[ "$type" == "flutter" ]] && badge="${CYAN}[Flutter]${NC}"
    local ver_info=""
    if [[ "$show_version_flag" == "true" ]]; then
      local cv
      cv=$(get_version "${apps[$i]}")
      local vname; vname=$(get_version_name "$cv")
      local bnum;  bnum=$(get_build_number "$cv")
      local nbnum=$((bnum + 1))
      ver_info="  ${YELLOW}${vname}+${bnum}${NC} → ${GREEN}${vname}+${nbnum}${NC}"
    fi
    echo -e "  ${BOLD}$((i+1)))${NC} ${apps[$i]}  $badge$ver_info" >/dev/tty
  done
  echo "" >/dev/tty

  local choice
  read -p "  Select (1-${#apps[@]}): " choice </dev/tty

  if [[ "$choice" -ge 1 && "$choice" -le ${#apps[@]} ]]; then
    echo "${apps[$((choice-1))]}"   # only this goes to stdout (captured by $())
  else
    echo -e "${RED}Invalid selection${NC}" >/dev/tty
    exit 1
  fi
}

# ────────────────────────────────────────────────────────────
# Commands
# ────────────────────────────────────────────────────────────
cmd_run() {
  local app=$(select_app "Which app do you want to run?")
  echo ""
  echo -e "${GREEN}Starting ${BOLD}$app${NC}${GREEN}...${NC}"
  echo ""
  local app_dir="$APPS_DIR/$app"

  if [[ -f "$app_dir/run.sh" ]]; then
    cd "$app_dir" && bash run.sh
  elif [[ -f "$app_dir/pm" ]]; then
    cd "$app_dir" && bash pm run
  else
    local type=$(get_app_type "$app")
    if [[ "$type" == "expo" ]]; then
      cd "$app_dir" && npx expo start
    elif [[ "$type" == "flutter" ]]; then
      cd "$app_dir" && flutter run
    fi
  fi
}

cmd_build() {
  local app
  # select_app prints the list to terminal, then echoes the chosen name — capture only the echo
  app=$(select_app "Which app to build?  (current build → new build)" "true")
  # Bump build number in pubspec.yaml and display the version box
  bump_build_number "$app"
  echo -e "${YELLOW}${BOLD}Select platform:${NC}"
  echo ""
  echo -e "  ${BOLD}1)${NC} 🍎 iOS  → TestFlight"
  echo -e "  ${BOLD}2)${NC} 🤖 Android → Play Console"
  echo -e "  ${BOLD}3)${NC} 🚀 Both"
  echo ""
  read -p "  Select (1-3): " platform

  local app_dir="$APPS_DIR/$app"

  case $platform in
    1)
      echo -e "${GREEN}Building ${BOLD}$app${NC}${GREEN} for iOS (TestFlight)...${NC}"
      if [[ -f "$app_dir/build_ios.sh" ]]; then
        cd "$app_dir" && bash build_ios.sh
      elif [[ -f "$app_dir/build_ios_release.sh" ]]; then
        cd "$app_dir" && bash build_ios_release.sh --upload
      else
        echo -e "${RED}No iOS build script found for $app${NC}"
        echo -e "${YELLOW}Tip: run 'cd apps/$app/fastlane && bundle exec fastlane ios upload'${NC}"
      fi
      ;;
    2)
      echo -e "${GREEN}Building ${BOLD}$app${NC}${GREEN} for Android (Play Console)...${NC}"
      if [[ -f "$app_dir/build_android.sh" ]]; then
        cd "$app_dir" && bash build_android.sh
      elif [[ -f "$app_dir/build_android_release.sh" ]]; then
        cd "$app_dir" && bash build_android_release.sh --upload
      else
        echo -e "${RED}No Android build script found for $app${NC}"
        echo -e "${YELLOW}Tip: run 'cd apps/$app/android && bundle exec fastlane upload'${NC}"
      fi
      ;;
    3)
      echo -e "${GREEN}Building ${BOLD}$app${NC}${GREEN} for iOS + Android...${NC}"
      if [[ -f "$app_dir/build_ios.sh" ]]; then
        (cd "$app_dir" && bash build_ios.sh)
      elif [[ -f "$app_dir/build_ios_release.sh" ]]; then
        (cd "$app_dir" && bash build_ios_release.sh --upload)
      fi
      if [[ -f "$app_dir/build_android.sh" ]]; then
        (cd "$app_dir" && bash build_android.sh)
      elif [[ -f "$app_dir/build_android_release.sh" ]]; then
        (cd "$app_dir" && bash build_android_release.sh --upload)
      fi
      ;;
    *)
      echo -e "${RED}Invalid selection${NC}"
      exit 1
      ;;
  esac
}

cmd_build_all() {
  echo -e "${YELLOW}${BOLD}Building ALL apps for iOS + Android...${NC}"
  echo ""
  for app in $(get_apps); do
    local app_dir="$APPS_DIR/$app"
    echo -e "${GREEN}${BOLD}=== $app ===${NC}"

    # iOS
    if [[ -f "$app_dir/build_ios.sh" ]]; then
      echo -e "${CYAN}  🍎 iOS...${NC}"
      (cd "$app_dir" && bash build_ios.sh) || echo -e "${RED}  ⚠️  iOS build failed for $app${NC}"
    elif [[ -f "$app_dir/build_ios_release.sh" ]]; then
      echo -e "${CYAN}  🍎 iOS...${NC}"
      (cd "$app_dir" && bash build_ios_release.sh --upload) || echo -e "${RED}  ⚠️  iOS build failed for $app${NC}"
    fi

    # Android
    if [[ -f "$app_dir/build_android.sh" ]]; then
      echo -e "${CYAN}  🤖 Android...${NC}"
      (cd "$app_dir" && bash build_android.sh) || echo -e "${RED}  ⚠️  Android build failed for $app${NC}"
    elif [[ -f "$app_dir/build_android_release.sh" ]]; then
      echo -e "${CYAN}  🤖 Android...${NC}"
      (cd "$app_dir" && bash build_android_release.sh --upload) || echo -e "${RED}  ⚠️  Android build failed for $app${NC}"
    fi

    echo ""
  done
  echo -e "${GREEN}${BOLD}All builds complete! 🎉${NC}"
}

cmd_ios_all() {
  echo -e "${YELLOW}${BOLD}Building all iOS apps → TestFlight...${NC}"
  echo ""
  for app in $(get_apps); do
    local app_dir="$APPS_DIR/$app"
    echo -e "${GREEN}  🍎 $app${NC}"
    if [[ -f "$app_dir/build_ios.sh" ]]; then
      (cd "$app_dir" && bash build_ios.sh) || echo -e "${RED}  ⚠️  Failed for $app${NC}"
    elif [[ -f "$app_dir/build_ios_release.sh" ]]; then
      (cd "$app_dir" && bash build_ios_release.sh --upload) || echo -e "${RED}  ⚠️  Failed for $app${NC}"
    else
      echo -e "${YELLOW}  No iOS script for $app — skipping${NC}"
    fi
  done
  echo -e "${GREEN}${BOLD}Done! ✅${NC}"
}

cmd_android_all() {
  echo -e "${YELLOW}${BOLD}Building all Android apps → Play Console...${NC}"
  echo ""
  for app in $(get_apps); do
    local app_dir="$APPS_DIR/$app"
    echo -e "${GREEN}  🤖 $app${NC}"
    if [[ -f "$app_dir/build_android.sh" ]]; then
      (cd "$app_dir" && bash build_android.sh) || echo -e "${RED}  ⚠️  Failed for $app${NC}"
    elif [[ -f "$app_dir/build_android_release.sh" ]]; then
      (cd "$app_dir" && bash build_android_release.sh --upload) || echo -e "${RED}  ⚠️  Failed for $app${NC}"
    else
      echo -e "${YELLOW}  No Android script for $app — skipping${NC}"
    fi
  done
  echo -e "${GREEN}${BOLD}Done! ✅${NC}"
}

cmd_list() {
  echo ""
  echo -e "${CYAN}${BOLD}Registered Apps:${NC}"
  echo ""
  printf "  ${BOLD}%-25s %-12s %-10s %-30s${NC}\n" "APP" "TYPE" "IOS" "ANDROID"
  echo "  ──────────────────────────────────────────────────────────────────────────"
  for app in $(get_apps); do
    local type=$(get_app_type "$app")
    local app_dir="$APPS_DIR/$app"
    local ios="❌"; local android="❌"
    [[ -f "$app_dir/build_ios.sh" || -f "$app_dir/build_ios_release.sh" ]] && ios="✅"
    [[ -f "$app_dir/build_android.sh" || -f "$app_dir/build_android_release.sh" ]] && android="✅"
    printf "  %-25s %-12s %-10s %-30s\n" "$app" "[$type]" "$ios" "$android"
  done
  echo ""
}

cmd_create() {
  if [[ -f "$SCRIPT_DIR/scripts/create-app.sh" ]]; then
    bash "$SCRIPT_DIR/scripts/create-app.sh" "$@"
  else
    echo -e "${RED}create-app.sh not found${NC}"
  fi
}

cmd_help() {
  echo ""
  echo -e "${BOLD}Usage:${NC} ./pm [command]"
  echo ""
  echo -e "${BOLD}Commands:${NC}"
  printf "  %-15s %s\n" "(none)"      "Interactive main menu"
  printf "  %-15s %s\n" "run"         "Select & run an app in dev mode"
  printf "  %-15s %s\n" "build"       "Select & build for iOS or Android"
  printf "  %-15s %s\n" "build-all"   "Build ALL apps for both platforms"
  printf "  %-15s %s\n" "ios"         "Build ALL apps → TestFlight"
  printf "  %-15s %s\n" "android"     "Build ALL apps → Play Console"
  printf "  %-15s %s\n" "list"        "List all apps with pipeline status"
  printf "  %-15s %s\n" "create"      "Create a new app from template"
  printf "  %-15s %s\n" "help"        "Show this help"
  echo ""
  echo -e "${BOLD}Apps:${NC}"
  for app in $(get_apps); do
    echo "  • $app"
  done
  echo ""
}

# ────────────────────────────────────────────────────────────
# Main dispatch
# ────────────────────────────────────────────────────────────
case "${1:-}" in
  run)        cmd_run ;;
  build)      cmd_build ;;
  build-all)  cmd_build_all ;;
  ios)        print_header; cmd_ios_all ;;
  android)    print_header; cmd_android_all ;;
  list)       cmd_list ;;
  create)     shift; cmd_create "$@" ;;
  help|-h|--help) print_header; cmd_help ;;
  "")
    print_header
    echo -e "  ${BOLD}1)${NC} 🚀 Run an app       ${CYAN}dev mode${NC}"
    echo -e "  ${BOLD}2)${NC} 📦 Build an app      ${CYAN}release → stores${NC}"
    echo -e "  ${BOLD}3)${NC} 🏗️  Build ALL apps    ${CYAN}iOS + Android${NC}"
    echo -e "  ${BOLD}4)${NC} 🍎 iOS only          ${CYAN}→ TestFlight${NC}"
    echo -e "  ${BOLD}5)${NC} 🤖 Android only      ${CYAN}→ Play Console${NC}"
    echo -e "  ${BOLD}6)${NC} 📋 List apps"
    echo -e "  ${BOLD}7)${NC} ➕ Create new app"
    echo -e "  ${BOLD}8)${NC} ❓ Help"
    echo -e "  ${BOLD}q)${NC} Quit"
    echo ""
    read -p "  Select: " main_choice
    echo ""
    case $main_choice in
      1) cmd_run ;;
      2) cmd_build ;;
      3) cmd_build_all ;;
      4) cmd_ios_all ;;
      5) cmd_android_all ;;
      6) cmd_list ;;
      7) cmd_create ;;
      8) cmd_help ;;
      q|Q) exit 0 ;;
      *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    ;;
  *)
    echo -e "${RED}Unknown command: $1${NC}"
    cmd_help
    exit 1
    ;;
esac
