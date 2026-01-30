#!/bin/bash
#
# file-size-guard-auto-repair.sh - Self-healing auto-repair for Claude Code/Kit updates
#
# This script ensures file-size-guard remains functional after:
# - Claude Code updates (which may reset settings.json)
# - ClaudeKit updates (which may modify hook registrations)
# - Accidental file deletion
#
# Add to .bashrc/.zshrc: source ~/.claude/scripts/file-size-guard-auto-repair.sh
#
# The script runs silently and only outputs when repair is needed.

# Run in background to not slow down shell startup
(
  CLAUDE_DIR="$HOME/.claude"
  HOOKS_DIR="$CLAUDE_DIR/hooks"
  SCRIPTS_DIR="$CLAUDE_DIR/scripts"
  SETTINGS_FILE="$CLAUDE_DIR/settings.json"
  HOOK_COMMAND='node $HOME/.claude/hooks/file-size-guard.cjs'
  RAW_URL="https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main"

  # Check if all hook files exist
  check_files() {
    [ -f "$HOOKS_DIR/file-size-guard.cjs" ] && \
    [ -d "$HOOKS_DIR/file-size-guard" ] && \
    [ -f "$HOOKS_DIR/file-size-guard/line-counter.cjs" ] && \
    [ -f "$HOOKS_DIR/file-size-guard/threshold-checker.cjs" ] && \
    [ -f "$HOOKS_DIR/file-size-guard/suggestion-generator.cjs" ]
  }

  # Check if hook is registered in settings.json
  check_registration() {
    [ -f "$SETTINGS_FILE" ] && grep -q "file-size-guard.cjs" "$SETTINGS_FILE" 2>/dev/null
  }

  # Download and restore missing files
  restore_files() {
    command -v curl >/dev/null 2>&1 || return 1
    mkdir -p "$HOOKS_DIR/file-size-guard" "$SCRIPTS_DIR"

    echo "[file-size-guard] Restoring missing files..."
    curl -fsSL "$RAW_URL/src/hooks/file-size-guard.cjs" -o "$HOOKS_DIR/file-size-guard.cjs" 2>/dev/null && \
    curl -fsSL "$RAW_URL/src/hooks/file-size-guard/line-counter.cjs" -o "$HOOKS_DIR/file-size-guard/line-counter.cjs" 2>/dev/null && \
    curl -fsSL "$RAW_URL/src/hooks/file-size-guard/threshold-checker.cjs" -o "$HOOKS_DIR/file-size-guard/threshold-checker.cjs" 2>/dev/null && \
    curl -fsSL "$RAW_URL/src/hooks/file-size-guard/suggestion-generator.cjs" -o "$HOOKS_DIR/file-size-guard/suggestion-generator.cjs" 2>/dev/null && \
    echo "[file-size-guard] Files restored successfully"
  }

  # Register hook in settings.json
  register_hook() {
    [ ! -f "$SETTINGS_FILE" ] && echo '{"hooks":{}}' > "$SETTINGS_FILE"

    node -e "
const fs = require('fs');
const settingsPath = '$SETTINGS_FILE';
let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) { settings = { hooks: {} }; }
settings.hooks = settings.hooks || {};
settings.hooks.PreToolUse = settings.hooks.PreToolUse || [];
const hookCommand = '$HOOK_COMMAND';
const hookExists = settings.hooks.PreToolUse.some(entry => entry.hooks?.some(h => h.command === hookCommand));
if (!hookExists) {
  let matcher = settings.hooks.PreToolUse.find(e => e.matcher === 'Edit|Write');
  if (!matcher) { matcher = { matcher: 'Edit|Write', hooks: [] }; settings.hooks.PreToolUse.push(matcher); }
  matcher.hooks.push({ type: 'command', command: hookCommand });
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
  console.log('[file-size-guard] Hook re-registered successfully');
}
" 2>/dev/null
  }

  # Main repair logic
  if ! check_files; then
    restore_files
  fi

  if check_files && ! check_registration; then
    register_hook
  fi
) &
