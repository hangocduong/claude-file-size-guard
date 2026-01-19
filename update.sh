#!/bin/bash
#
# Claude File Size Guard - Updater with Auto-Recovery
# Updates to latest version and repairs broken installations
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

VERSION="1.0.0"
REPO_URL="${REPO_URL:-https://github.com/hangocduong/claude-file-size-guard}"
RAW_URL="${RAW_URL:-https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main}"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo -e "${BLUE}Claude File Size Guard - Updater v${VERSION}${NC}\n"

# Check current status
check_status() {
  echo -e "${BLUE}Checking installation status...${NC}"
  local issues=0

  if [ ! -f "$HOOKS_DIR/file-size-guard.cjs" ]; then
    echo -e "${RED}✗${NC} Hook file missing"
    issues=$((issues + 1))
  else
    echo -e "${GREEN}✓${NC} Hook file exists"
  fi

  if [ ! -d "$HOOKS_DIR/file-size-guard" ]; then
    echo -e "${RED}✗${NC} Hook modules missing"
    issues=$((issues + 1))
  else
    echo -e "${GREEN}✓${NC} Hook modules exist"
  fi

  if ! grep -q "file-size-guard.cjs" "$SETTINGS_FILE" 2>/dev/null; then
    echo -e "${RED}✗${NC} Hook not registered in settings.json"
    issues=$((issues + 1))
  else
    echo -e "${GREEN}✓${NC} Hook registered"
  fi

  return $issues
}

# Download latest
download_latest() {
  echo -e "\n${BLUE}Downloading latest version...${NC}"
  mkdir -p "$HOOKS_DIR/file-size-guard" "$SCRIPTS_DIR"

  curl -fsSL "$RAW_URL/src/hooks/file-size-guard.cjs" -o "$HOOKS_DIR/file-size-guard.cjs"
  curl -fsSL "$RAW_URL/src/hooks/file-size-guard/line-counter.cjs" -o "$HOOKS_DIR/file-size-guard/line-counter.cjs"
  curl -fsSL "$RAW_URL/src/hooks/file-size-guard/threshold-checker.cjs" -o "$HOOKS_DIR/file-size-guard/threshold-checker.cjs"
  curl -fsSL "$RAW_URL/src/hooks/file-size-guard/suggestion-generator.cjs" -o "$HOOKS_DIR/file-size-guard/suggestion-generator.cjs"
  curl -fsSL "$RAW_URL/src/scripts/file-size-guard-toggle.sh" -o "$SCRIPTS_DIR/file-size-guard-toggle.sh"

  chmod +x "$SCRIPTS_DIR/file-size-guard-toggle.sh"
  echo -e "${GREEN}✓${NC} Files updated"
}

# Repair registration
repair_registration() {
  echo -e "\n${BLUE}Repairing hook registration...${NC}"
  node -e "
const fs = require('fs');
const settingsPath = '$SETTINGS_FILE';
let s = {};
try { s = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) { s = {hooks:{}}; }
s.hooks = s.hooks || {};
s.hooks.PreToolUse = s.hooks.PreToolUse || [];
const cmd = 'node \$HOME/.claude/hooks/file-size-guard.cjs';
const exists = s.hooks.PreToolUse.some(e => e.hooks?.some(h => h.command === cmd));
if (!exists) {
  let m = s.hooks.PreToolUse.find(e => e.matcher === 'Edit|Write');
  if (!m) { m = {matcher:'Edit|Write',hooks:[]}; s.hooks.PreToolUse.push(m); }
  m.hooks.push({type:'command',command:cmd});
  fs.writeFileSync(settingsPath, JSON.stringify(s, null, 2));
  console.log('Registration repaired');
} else { console.log('Registration OK'); }
"
  echo -e "${GREEN}✓${NC} Registration verified"
}

main() {
  if check_status; then
    echo -e "\n${GREEN}Installation is healthy.${NC}"
    read -p "Update to latest anyway? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
  fi

  download_latest
  repair_registration

  echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗"
  echo "║               Update Complete!                            ║"
  echo -e "╚═══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "Run ${BLUE}~/.claude/scripts/file-size-guard-toggle.sh status${NC} to verify"
}

main "$@"
