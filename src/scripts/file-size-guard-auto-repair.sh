#!/bin/bash
#
# file-size-guard-auto-repair.sh - Self-healing auto-repair for Claude Code/Kit updates
#
# This script ensures file-size-guard remains functional after:
# - Claude Code updates (which may reset settings.json)
# - ClaudeKit updates (which may modify hook registrations)
#
# Add to .bashrc/.zshrc: source ~/.claude/scripts/file-size-guard-auto-repair.sh
#
# The script runs silently and only outputs when repair is needed.

# Run in background to not slow down shell startup
(
  CLAUDE_DIR="$HOME/.claude"
  HOOKS_DIR="$CLAUDE_DIR/hooks"
  SETTINGS_FILE="$CLAUDE_DIR/settings.json"
  HOOK_COMMAND='node $HOME/.claude/hooks/file-size-guard.cjs'

  # Check if hook files exist
  check_files() {
    if [ ! -f "$HOOKS_DIR/file-size-guard.cjs" ]; then
      return 1
    fi
    if [ ! -d "$HOOKS_DIR/file-size-guard" ]; then
      return 1
    fi
    return 0
  }

  # Check if hook is registered in settings.json
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
    if [ ! -f "$SETTINGS_FILE" ]; then
      echo '{"hooks":{}}' > "$SETTINGS_FILE"
    fi

    node -e "
const fs = require('fs');
const settingsPath = '$SETTINGS_FILE';
let settings = {};

try {
  settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
} catch(e) {
  settings = { hooks: {} };
}

settings.hooks = settings.hooks || {};
settings.hooks.PreToolUse = settings.hooks.PreToolUse || [];

const hookCommand = '$HOOK_COMMAND';
const hookExists = settings.hooks.PreToolUse.some(entry =>
  entry.hooks?.some(h => h.command === hookCommand)
);

if (!hookExists) {
  // Find or create Edit|Write matcher
  let matcher = settings.hooks.PreToolUse.find(e => e.matcher === 'Edit|Write');
  if (!matcher) {
    matcher = { matcher: 'Edit|Write', hooks: [] };
    settings.hooks.PreToolUse.push(matcher);
  }
  matcher.hooks.push({ type: 'command', command: hookCommand });
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
  console.log('[file-size-guard] Hook re-registered successfully');
}
" 2>/dev/null
  }

  # Main check
  if check_files; then
    if ! check_registration; then
      register_hook
    fi
  fi
) &
