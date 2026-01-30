#!/bin/bash
# Toggle file-size-guard hook on/off
# Usage: ./file-size-guard-toggle.sh [enable|disable|status|repair|verify]

set -e

CLAUDE_DIR="$HOME/.claude"
CK_CONFIG="${CK_CONFIG:-$CLAUDE_DIR/.ck.json}"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
HOOK_COMMAND='node $HOME/.claude/hooks/file-size-guard.cjs'
RAW_URL="https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main"

# Ensure config file exists
ensure_config() {
  if [ ! -f "$CK_CONFIG" ]; then
    mkdir -p "$(dirname "$CK_CONFIG")"
    echo '{}' > "$CK_CONFIG"
  fi
}

# Check if hook is registered
check_registration() {
  if [ ! -f "$SETTINGS_FILE" ]; then
    return 1
  fi
  if ! grep -q "file-size-guard.cjs" "$SETTINGS_FILE" 2>/dev/null; then
    return 1
  fi
  return 0
}

# Register hook in settings.json
register_hook() {
  node -e "
const fs = require('fs');
const settingsPath = '$SETTINGS_FILE';
let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) { settings = {hooks:{}}; }
settings.hooks = settings.hooks || {};
settings.hooks.PreToolUse = settings.hooks.PreToolUse || [];
const cmd = '$HOOK_COMMAND';
const exists = settings.hooks.PreToolUse.some(e => e.hooks?.some(h => h.command === cmd));
if (!exists) {
  let m = settings.hooks.PreToolUse.find(e => e.matcher === 'Edit|Write');
  if (!m) { m = {matcher:'Edit|Write',hooks:[]}; settings.hooks.PreToolUse.push(m); }
  m.hooks.push({type:'command',command:cmd});
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
  console.log('✅ Hook registered in settings.json');
} else { console.log('ℹ️  Hook already registered'); }
"
}

case "$1" in
  enable)
    ensure_config
    node -e "
      const fs = require('fs');
      const config = JSON.parse(fs.readFileSync('$CK_CONFIG', 'utf-8'));
      config.fileSizeGuard = config.fileSizeGuard || {};
      config.fileSizeGuard.enabled = true;
      fs.writeFileSync('$CK_CONFIG', JSON.stringify(config, null, 2));
      console.log('✅ file-size-guard ENABLED');
    "
    ;;
  disable)
    ensure_config
    node -e "
      const fs = require('fs');
      const config = JSON.parse(fs.readFileSync('$CK_CONFIG', 'utf-8'));
      config.fileSizeGuard = config.fileSizeGuard || {};
      config.fileSizeGuard.enabled = false;
      fs.writeFileSync('$CK_CONFIG', JSON.stringify(config, null, 2));
      console.log('❌ file-size-guard DISABLED');
    "
    ;;
  status)
    ensure_config
    echo "=== File Size Guard Status ==="
    echo ""
    # Check files
    if [ -f "$HOOKS_DIR/file-size-guard.cjs" ]; then
      echo "Hook files:    ✅ Installed"
    else
      echo "Hook files:    ❌ Missing"
    fi
    # Check registration
    if check_registration; then
      echo "Registration:  ✅ Registered"
    else
      echo "Registration:  ❌ Not registered"
    fi
    # Check enabled status
    node -e "
      const fs = require('fs');
      const config = JSON.parse(fs.readFileSync('$CK_CONFIG', 'utf-8'));
      const enabled = config.fileSizeGuard?.enabled !== false;
      console.log('Enabled:       ' + (enabled ? '✅ Yes' : '❌ No'));
      console.log('warnThreshold: ' + (config.fileSizeGuard?.warnThreshold || 120));
      console.log('blockThreshold:' + (config.fileSizeGuard?.blockThreshold || 200));
    "
    echo ""
    echo "Run 'repair' if registration is missing after Claude Code update."
    ;;
  repair)
    echo "=== Repairing file-size-guard ==="
    # Check and restore files if missing
    if [ ! -f "$HOOKS_DIR/file-size-guard.cjs" ] || [ ! -d "$HOOKS_DIR/file-size-guard" ]; then
      echo "📥 Downloading missing files..."
      mkdir -p "$HOOKS_DIR/file-size-guard" "$SCRIPTS_DIR"
      curl -fsSL "$RAW_URL/src/hooks/file-size-guard.cjs" -o "$HOOKS_DIR/file-size-guard.cjs"
      curl -fsSL "$RAW_URL/src/hooks/file-size-guard/line-counter.cjs" -o "$HOOKS_DIR/file-size-guard/line-counter.cjs"
      curl -fsSL "$RAW_URL/src/hooks/file-size-guard/threshold-checker.cjs" -o "$HOOKS_DIR/file-size-guard/threshold-checker.cjs"
      curl -fsSL "$RAW_URL/src/hooks/file-size-guard/suggestion-generator.cjs" -o "$HOOKS_DIR/file-size-guard/suggestion-generator.cjs"
      echo "✅ Files restored"
    fi
    # Register hook
    register_hook
    # Enable in config
    ensure_config
    node -e "
      const fs = require('fs');
      const config = JSON.parse(fs.readFileSync('$CK_CONFIG', 'utf-8'));
      config.fileSizeGuard = config.fileSizeGuard || {};
      if (config.fileSizeGuard.enabled === undefined) {
        config.fileSizeGuard.enabled = true;
      }
      fs.writeFileSync('$CK_CONFIG', JSON.stringify(config, null, 2));
    "
    echo "✅ Repair complete. Restart Claude Code to apply."
    ;;
  verify)
    echo "=== Verifying file-size-guard installation ==="
    errors=0
    # Check main hook
    if [ -f "$HOOKS_DIR/file-size-guard.cjs" ]; then
      echo "✅ file-size-guard.cjs"
    else
      echo "❌ file-size-guard.cjs MISSING"
      errors=$((errors + 1))
    fi
    # Check modules
    for module in line-counter threshold-checker suggestion-generator; do
      if [ -f "$HOOKS_DIR/file-size-guard/${module}.cjs" ]; then
        echo "✅ file-size-guard/${module}.cjs"
      else
        echo "❌ file-size-guard/${module}.cjs MISSING"
        errors=$((errors + 1))
      fi
    done
    # Check toggle script
    if [ -f "$SCRIPTS_DIR/file-size-guard-toggle.sh" ]; then
      echo "✅ file-size-guard-toggle.sh"
    else
      echo "❌ file-size-guard-toggle.sh MISSING"
      errors=$((errors + 1))
    fi
    # Check registration
    if check_registration; then
      echo "✅ Registered in settings.json"
    else
      echo "❌ NOT registered in settings.json"
      errors=$((errors + 1))
    fi
    echo ""
    if [ $errors -eq 0 ]; then
      echo "✅ Installation verified - all files present"
    else
      echo "❌ $errors error(s) found. Run 'repair' to fix."
    fi
    ;;
  *)
    echo "Usage: $0 [enable|disable|status|repair|verify]"
    echo ""
    echo "Commands:"
    echo "  enable   - Enable file size guard"
    echo "  disable  - Disable file size guard (temporary)"
    echo "  status   - Show current status and thresholds"
    echo "  repair   - Fix missing files and re-register hook"
    echo "  verify   - Check all files exist and are registered"
    exit 1
    ;;
esac
