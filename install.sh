#!/bin/bash
#
# Claude File Size Guard - Installer
# Prevents AI from creating large files that require refactoring
#
# Usage: curl -fsSL https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/install.sh | bash
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
VERSION="1.0.0"
REPO_URL="${REPO_URL:-https://github.com/hangocduong/claude-file-size-guard}"
RAW_URL="${RAW_URL:-https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main}"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
BACKUP_DIR="$CLAUDE_DIR/backups/file-size-guard-$(date +%Y%m%d-%H%M%S)"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
CK_CONFIG="$CLAUDE_DIR/.ck.json"

print_banner() {
  echo -e "${BLUE}"
  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║       Claude File Size Guard Installer v${VERSION}            ║"
  echo "║  Prevent large files, enforce modular code from start    ║"
  echo "╚═══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

detect_claude_version() {
  if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    echo -e "${GREEN}✓${NC} Claude Code detected: $CLAUDE_VERSION"
  else
    echo -e "${YELLOW}⚠${NC} Claude Code CLI not found (OK if using IDE extension)"
  fi
}

check_node() {
  if ! command -v node &> /dev/null; then
    echo -e "${RED}✗${NC} Node.js not found. Please install Node.js first."
    exit 1
  fi
  echo -e "${GREEN}✓${NC} Node.js: $(node --version)"
}

create_backup() {
  echo -e "\n${BLUE}Creating backup...${NC}"
  mkdir -p "$BACKUP_DIR"
  [ -f "$SETTINGS_FILE" ] && cp "$SETTINGS_FILE" "$BACKUP_DIR/"
  [ -f "$CK_CONFIG" ] && cp "$CK_CONFIG" "$BACKUP_DIR/"
  [ -f "$HOOKS_DIR/file-size-guard.cjs" ] && cp "$HOOKS_DIR/file-size-guard.cjs" "$BACKUP_DIR/"
  echo -e "${GREEN}✓${NC} Backup: $BACKUP_DIR"
}

install_hooks() {
  echo -e "\n${BLUE}Installing hooks...${NC}"
  mkdir -p "$HOOKS_DIR/file-size-guard" "$SCRIPTS_DIR"

  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [ -d "$SCRIPT_DIR/src" ]; then
    cp "$SCRIPT_DIR/src/hooks/file-size-guard.cjs" "$HOOKS_DIR/"
    cp "$SCRIPT_DIR/src/hooks/file-size-guard/"*.cjs "$HOOKS_DIR/file-size-guard/"
    cp "$SCRIPT_DIR/src/scripts/file-size-guard-toggle.sh" "$SCRIPTS_DIR/"
  else
    echo "  Downloading from $RAW_URL..."
    curl -fsSL "$RAW_URL/src/hooks/file-size-guard.cjs" -o "$HOOKS_DIR/file-size-guard.cjs"
    curl -fsSL "$RAW_URL/src/hooks/file-size-guard/line-counter.cjs" -o "$HOOKS_DIR/file-size-guard/line-counter.cjs"
    curl -fsSL "$RAW_URL/src/hooks/file-size-guard/threshold-checker.cjs" -o "$HOOKS_DIR/file-size-guard/threshold-checker.cjs"
    curl -fsSL "$RAW_URL/src/hooks/file-size-guard/suggestion-generator.cjs" -o "$HOOKS_DIR/file-size-guard/suggestion-generator.cjs"
    curl -fsSL "$RAW_URL/src/scripts/file-size-guard-toggle.sh" -o "$SCRIPTS_DIR/file-size-guard-toggle.sh"
  fi
  chmod +x "$SCRIPTS_DIR/file-size-guard-toggle.sh"
  echo -e "${GREEN}✓${NC} Hooks installed"
}

register_hook() {
  echo -e "\n${BLUE}Registering hook...${NC}"
  [ ! -f "$SETTINGS_FILE" ] && echo '{"hooks":{}}' > "$SETTINGS_FILE"

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
  console.log('Hook registered');
} else { console.log('Hook already exists'); }
"
  echo -e "${GREEN}✓${NC} Hook registered"
}

configure_ck() {
  echo -e "\n${BLUE}Configuring defaults...${NC}"
  node -e "
const fs = require('fs');
const ckPath = '$CK_CONFIG';
let c = {};
try { c = JSON.parse(fs.readFileSync(ckPath, 'utf-8')); } catch(e) {}
if (!c.fileSizeGuard) {
  c.fileSizeGuard = {
    enabled: true,
    warnThreshold: 120,
    blockThreshold: 200,
    excludePatterns: [
      'package-lock\\\\.json\$','pnpm-lock\\\\.yaml\$','yarn\\\\.lock\$',
      '\\\\.min\\\\.(js|css)\$','\\\\.d\\\\.ts\$','\\\\.json\$','\\\\.yaml\$',
      '\\\\.yml\$','\\\\.md\$','\\\\.sh\$','__fixtures__/','__snapshots__/'
    ]
  };
  fs.writeFileSync(ckPath, JSON.stringify(c, null, 2));
  console.log('Config created');
} else { console.log('Config exists'); }
"
  echo -e "${GREEN}✓${NC} Configuration done"
}

install_recovery() {
  echo -e "\n${BLUE}Installing recovery script...${NC}"
  cat > "$SCRIPTS_DIR/file-size-guard-recovery.sh" << 'EOF'
#!/bin/bash
# Auto-recovery check for file-size-guard
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
[ ! -f "$HOOKS_DIR/file-size-guard.cjs" ] && echo "[file-size-guard] Hook missing - reinstall needed"
grep -q "file-size-guard.cjs" "$SETTINGS_FILE" 2>/dev/null || echo "[file-size-guard] Not registered"
EOF
  chmod +x "$SCRIPTS_DIR/file-size-guard-recovery.sh"
  echo -e "${GREEN}✓${NC} Recovery script installed"
}

print_summary() {
  echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗"
  echo "║            Installation Complete!                         ║"
  echo -e "╚═══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Config: warnThreshold=120, blockThreshold=200"
  echo ""
  echo "Commands:"
  echo "  ~/.claude/scripts/file-size-guard-toggle.sh status"
  echo "  ~/.claude/scripts/file-size-guard-toggle.sh disable"
  echo "  ~/.claude/scripts/file-size-guard-toggle.sh enable"
  echo ""
  echo -e "${YELLOW}Start new Claude session to activate.${NC}"
}

main() {
  print_banner
  detect_claude_version
  check_node
  create_backup
  install_hooks
  register_hook
  configure_ck
  install_recovery
  print_summary
}

main "$@"
