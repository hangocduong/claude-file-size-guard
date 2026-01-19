#!/bin/bash
#
# Claude File Size Guard - Uninstaller
# Cleanly removes file-size-guard and restores settings
#

set -e

# shellcheck disable=SC2034
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
CK_CONFIG="$CLAUDE_DIR/.ck.json"

echo -e "${BLUE}Claude File Size Guard - Uninstaller${NC}\n"

# Remove hook from settings.json
echo -e "${BLUE}Removing hook registration...${NC}"
if [ -f "$SETTINGS_FILE" ]; then
  node -e "
const fs = require('fs');
const settingsPath = '$SETTINGS_FILE';
let s = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
if (s.hooks?.PreToolUse) {
  s.hooks.PreToolUse = s.hooks.PreToolUse.map(entry => {
    if (entry.hooks) {
      entry.hooks = entry.hooks.filter(h => !h.command?.includes('file-size-guard'));
    }
    return entry;
  }).filter(entry => entry.hooks?.length > 0);
  fs.writeFileSync(settingsPath, JSON.stringify(s, null, 2));
  console.log('Hook removed from settings.json');
}
"
fi

# Remove config from .ck.json
echo -e "${BLUE}Removing configuration...${NC}"
if [ -f "$CK_CONFIG" ]; then
  node -e "
const fs = require('fs');
const ckPath = '$CK_CONFIG';
let c = JSON.parse(fs.readFileSync(ckPath, 'utf-8'));
if (c.fileSizeGuard) {
  delete c.fileSizeGuard;
  fs.writeFileSync(ckPath, JSON.stringify(c, null, 2));
  console.log('Config removed from .ck.json');
}
"
fi

# Remove hook files
echo -e "${BLUE}Removing files...${NC}"
rm -f "$HOOKS_DIR/file-size-guard.cjs"
rm -rf "$HOOKS_DIR/file-size-guard"
rm -f "$SCRIPTS_DIR/file-size-guard-toggle.sh"
rm -f "$SCRIPTS_DIR/file-size-guard-recovery.sh"

echo -e "\n${GREEN}✓ Uninstall complete${NC}"
echo -e "${YELLOW}Note: Backups preserved in ~/.claude/backups/${NC}"
