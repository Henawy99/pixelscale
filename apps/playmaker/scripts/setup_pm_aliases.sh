#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# SETUP PM ALIASES
# ═══════════════════════════════════════════════════════════════════════════════
# This script adds convenient aliases to your shell so you can use:
#   pm run       - Interactive menu to run apps
#   pm build     - Interactive menu to build apps
#   pm build-all - Build all apps
# 
# From ANYWHERE in your terminal!
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PM_SCRIPT="$SCRIPT_DIR/pm"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  📦 Setting up Playmaker Quick Commands${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Determine which shell profile to use
SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_PROFILE="$HOME/.bash_profile"
fi

if [ -z "$SHELL_PROFILE" ]; then
    echo -e "${YELLOW}Could not find shell profile. Creating ~/.zshrc${NC}"
    SHELL_PROFILE="$HOME/.zshrc"
    touch "$SHELL_PROFILE"
fi

echo -e "Using shell profile: ${YELLOW}$SHELL_PROFILE${NC}"

# Check if aliases already exist
if grep -q "# Playmaker Quick Commands" "$SHELL_PROFILE" 2>/dev/null; then
    echo -e "${YELLOW}Aliases already exist. Updating...${NC}"
    # Remove old aliases
    sed -i '' '/# Playmaker Quick Commands/,/# End Playmaker/d' "$SHELL_PROFILE" 2>/dev/null
fi

# Add aliases
cat >> "$SHELL_PROFILE" << EOF

# Playmaker Quick Commands
alias pm='$PM_SCRIPT'
alias pmrun='$PM_SCRIPT run'
alias pmbuild='$PM_SCRIPT build'
alias pmbuildall='$PM_SCRIPT build-all'
# End Playmaker

EOF

echo ""
echo -e "${GREEN}✅ Aliases added to $SHELL_PROFILE${NC}"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✨ Setup Complete!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Available commands (after restarting terminal or running ${YELLOW}source $SHELL_PROFILE${NC}):"
echo ""
echo -e "  ${GREEN}pm${NC}           - Main menu (run/build/build-all)"
echo -e "  ${GREEN}pm run${NC}       - Interactive menu to run apps"
echo -e "  ${GREEN}pm build${NC}     - Interactive menu to build apps"
echo -e "  ${GREEN}pm build-all${NC} - Build all apps (iOS + Android)"
echo -e "  ${GREEN}pm ios${NC}       - Build all iOS apps"
echo -e "  ${GREEN}pm android${NC}   - Build all Android apps"
echo -e "  ${GREEN}pm help${NC}      - Show help"
echo ""
echo -e "${CYAN}Short aliases:${NC}"
echo -e "  ${GREEN}pmrun${NC}        - Same as 'pm run'"
echo -e "  ${GREEN}pmbuild${NC}      - Same as 'pm build'"
echo -e "  ${GREEN}pmbuildall${NC}   - Same as 'pm build-all'"
echo ""
echo -e "${YELLOW}To activate now, run:${NC}"
echo -e "  ${GREEN}source $SHELL_PROFILE${NC}"
echo ""
