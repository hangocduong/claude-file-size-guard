# Claude File Size Guard

[![Version](https://img.shields.io/badge/version-1.4.0-blue.svg)](https://github.com/hangocduong/claude-file-size-guard/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Node](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen.svg)](https://nodejs.org)

> Prevent AI coding assistants from creating large files that require refactoring

A Claude Code hook that enforces modular code from the start by warning or blocking file operations exceeding configurable line thresholds.

## Quick Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/install.ps1 | iex
```

**That's it!** Restart Claude Code to activate.

## Why Use This?

### The Problem

AI assistants tend to add code to existing files, creating monolithic files that need refactoring later:

```
150-line file + 80 new lines = 230-line file (needs refactoring!)
```

### The Solution: Micro-Extract Pattern

Extract NEW code to NEW files from the beginning:

```
150-line file + import = 151-line file + 80-line new module
```

## Features

| Feature | Description |
|---------|-------------|
| **Warning at 120 lines** | Suggests micro-extract pattern |
| **Block at 200 lines** | Requires extraction before continuing |
| **Smart exclusions** | Auto-skips lock files, configs, markdown, tests |
| **Language suggestions** | Tailored advice for JS/TS, Python, Rust |
| **File-level overrides** | `// @file-size-guard: max-lines=500` |
| **Whitelist paths** | Exclude specific files/directories |
| **Easy toggle** | Enable/disable without uninstalling |
| **Fail-open** | Errors don't block your workflow |

## Usage

### Quick Commands (macOS/Linux)

```bash
# Check status
~/.claude/scripts/file-size-guard-toggle.sh status

# Verify installation (check all files exist)
~/.claude/scripts/file-size-guard-toggle.sh verify

# Repair (download missing files + re-register)
~/.claude/scripts/file-size-guard-toggle.sh repair

# Disable temporarily
~/.claude/scripts/file-size-guard-toggle.sh disable

# Re-enable
~/.claude/scripts/file-size-guard-toggle.sh enable

# Update to latest version
curl -fsSL https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/update.sh | bash

# Uninstall
curl -fsSL https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/uninstall.sh | bash
```

### Quick Commands (Windows PowerShell)

```powershell
# Check status
& $env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 status

# Verify installation
& $env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 verify

# Repair (download missing files + re-register)
& $env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 repair

# Disable temporarily
& $env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 disable

# Re-enable
& $env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 enable
```

### File-Level Overrides

Override thresholds for specific files with inline comments:

```javascript
// @file-size-guard: max-lines=500
// This file can have up to 500 lines

// @file-size-guard: disabled
// This file has no size limit
```

```python
# @file-size-guard: max-lines=400
```

## Configuration

Edit `~/.claude/.ck.json`:

```json
{
  "fileSizeGuard": {
    "enabled": true,
    "warnThreshold": 120,
    "blockThreshold": 200,
    "excludePatterns": ["\\.json$", "\\.md$"],
    "whitelistPaths": ["src/generated/", "src/legacy/big-file.ts"]
  }
}
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `true` | Enable/disable the guard |
| `warnThreshold` | `120` | Lines before warning |
| `blockThreshold` | `200` | Lines before blocking |
| `excludePatterns` | [see below] | Regex patterns to skip |
| `whitelistPaths` | `[]` | Specific paths to skip |

### Default Exclusions

Already excluded (no config needed):

- **Lock files**: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`
- **Generated**: `.min.js`, `.d.ts`, `.generated.*`, `.bundle.*`
- **Configs**: `*.config.js`, `tsconfig.json`, `.eslintrc`, `.prettierrc`
- **Data**: `.json`, `.yaml`, `.yml`, `.toml`, `.xml`
- **Docs**: `.md`, `.mdx`, `.rst`, `.txt`
- **Tests**: `.test.ts`, `.spec.js`, `_test.go`, `test_*.py`, `__fixtures__/`, `__snapshots__/`
- **Shell**: `.sh`

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code Session                      │
├─────────────────────────────────────────────────────────────┤
│  1. AI attempts Edit/Write operation                        │
│  2. file-size-guard hook intercepts                         │
│  3. Checks exclusions, whitelist, file overrides            │
│  4. Estimates resulting file size                           │
│  5. Returns: OK (0), WARN (0+msg), or BLOCK (2)             │
└─────────────────────────────────────────────────────────────┘
```

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Operation allowed |
| `0` + message | Warning shown, operation continues |
| `2` | Operation blocked |

## Troubleshooting

### Hook stopped working after Claude Code update?

**macOS/Linux:**

```bash
# Check status
~/.claude/scripts/file-size-guard-toggle.sh status

# Quick repair (re-registers hook)
~/.claude/scripts/file-size-guard-toggle.sh repair

# Full update (downloads latest version)
curl -fsSL https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/update.sh | bash
```

**Windows PowerShell:**

```powershell
# Check status
& $env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 status

# Quick repair (re-registers hook)
& $env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 repair
```

### Auto-repair (Recommended)

**macOS/Linux** - Add to `.bashrc` or `.zshrc`:

```bash
source ~/.claude/scripts/file-size-guard-auto-repair.sh
```

**Windows** - Add to PowerShell profile (`$PROFILE`):

```powershell
. $env:USERPROFILE\.claude\scripts\file-size-guard-auto-repair.ps1
```

This runs silently in background on shell startup and only outputs when repair is needed.

## File Structure

**macOS/Linux:** `~/.claude/` | **Windows:** `%USERPROFILE%\.claude\`

```
.claude/
├── hooks/
│   ├── file-size-guard.cjs              # Main hook entry
│   └── file-size-guard/
│       ├── line-counter.cjs             # Line counting & estimation
│       ├── threshold-checker.cjs        # Threshold & exclusion logic
│       └── suggestion-generator.cjs     # Micro-extract suggestions
├── scripts/
│   ├── file-size-guard-toggle.sh        # (macOS/Linux) Enable/disable/repair
│   ├── file-size-guard-toggle.ps1       # (Windows) Enable/disable/repair
│   ├── file-size-guard-auto-repair.sh   # (macOS/Linux) Self-healing
│   ├── file-size-guard-auto-repair.ps1  # (Windows) Self-healing
│   └── file-size-guard-recovery.sh      # Legacy recovery check
├── settings.json                         # Hook registration
├── .ck.json                              # Configuration
└── backups/                              # Automatic backups
```

## Alternative Installation

### From source (macOS/Linux)

```bash
git clone https://github.com/hangocduong/claude-file-size-guard.git
cd claude-file-size-guard
./install.sh
```

### From source (Windows)

```powershell
git clone https://github.com/hangocduong/claude-file-size-guard.git
cd claude-file-size-guard
.\install.ps1
```

### Manual

1. Copy `src/hooks/` to:
   - macOS/Linux: `~/.claude/hooks/`
   - Windows: `%USERPROFILE%\.claude\hooks\`
2. Copy `src/scripts/` to:
   - macOS/Linux: `~/.claude/scripts/`
   - Windows: `%USERPROFILE%\.claude\scripts\`
3. Register hook in settings.json:

   **macOS/Linux** (`~/.claude/settings.json`):
   ```json
   {
     "hooks": {
       "PreToolUse": [{
         "matcher": "Edit|Write",
         "hooks": [{"type": "command", "command": "node $HOME/.claude/hooks/file-size-guard.cjs"}]
       }]
     }
   }
   ```

   **Windows** (`%USERPROFILE%\.claude\settings.json`):
   ```json
   {
     "hooks": {
       "PreToolUse": [{
         "matcher": "Edit|Write",
         "hooks": [{"type": "command", "command": "node %USERPROFILE%\\.claude\\hooks\\file-size-guard.cjs"}]
       }]
     }
   }
   ```

## Requirements

- **Node.js** >= 18.0.0
- **Claude Code** CLI or VS Code extension

## Changelog

### v1.4.0 (2026-01-19)

- Added Windows support with PowerShell scripts
- install.ps1 for Windows installation
- file-size-guard-toggle.ps1 for enable/disable/repair
- file-size-guard-auto-repair.ps1 for self-healing on Windows
- Updated documentation for cross-platform usage

### v1.3.0 (2026-01-19)

- Added auto-repair system for Claude Code/Kit updates
- Added `repair` command to toggle script
- Self-healing shell integration (background, non-blocking)
- Hook re-registers automatically when missing from settings.json

### v1.2.0 (2026-01-19)

- Fixed `const` reassignment bug for file-level overrides
- Optimized file reading (4KB buffer instead of full file)
- Added symlink/directory protection
- Added regex validation for custom exclude patterns
- Added encoding error handling
- Improved robustness and error handling

### v1.1.0 (2026-01-19)

- Added file-level overrides (`@file-size-guard` directive)
- Added whitelist paths configuration
- Added test file patterns to default exclusions
- Fixed `replace_all` estimation accuracy

### v1.0.0 (2026-01-19)

- Initial release
- Warning/block thresholds
- Smart exclusions
- Language-specific suggestions

## License

MIT

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `npm test`
5. Submit a pull request

---

**Links**: [GitHub](https://github.com/hangocduong/claude-file-size-guard) | [Issues](https://github.com/hangocduong/claude-file-size-guard/issues) | [Releases](https://github.com/hangocduong/claude-file-size-guard/releases)
