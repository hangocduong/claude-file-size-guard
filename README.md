# Claude File Size Guard

> Prevent AI coding assistants from creating large files that require refactoring

A Claude Code hook that enforces modular code from the start by warning or blocking file operations that would create files exceeding configurable line thresholds.

## Philosophy

**Micro-Extract Pattern**: Instead of adding code to existing files and later refactoring, extract NEW code to NEW files from the beginning.

```
Before: 150-line file + 80 new lines = 230-line file (needs refactoring!)
After:  150-line file + import = 151-line file + 80-line new module
```

## Features

- **Warning at 120 lines** - Suggests micro-extract pattern
- **Block at 200 lines** - Requires extraction before continuing
- **Smart exclusions** - Ignores lock files, configs, markdown, tests
- **Language-specific suggestions** - Tailored advice for JS/TS, Python, Rust
- **Easy toggle** - Enable/disable without uninstalling
- **Auto-recovery** - Repairs broken installations after updates

## Installation

### Quick Install (Remote)

```bash
curl -fsSL https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/install.sh | bash
```

### Manual Install (Local)

```bash
git clone https://github.com/hangocduong/claude-file-size-guard.git
cd claude-file-size-guard
./install.sh
```

## Usage

### Toggle Commands

```bash
# Check status
~/.claude/scripts/file-size-guard-toggle.sh status

# Temporarily disable
~/.claude/scripts/file-size-guard-toggle.sh disable

# Re-enable
~/.claude/scripts/file-size-guard-toggle.sh enable
```

### Update

```bash
~/.claude/scripts/file-size-guard-update.sh
# or
curl -fsSL https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/update.sh | bash
```

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/uninstall.sh | bash
```

## Configuration

Edit `~/.claude/.ck.json`:

```json
{
  "fileSizeGuard": {
    "enabled": true,
    "warnThreshold": 120,
    "blockThreshold": 200,
    "excludePatterns": [
      "\\.json$",
      "\\.md$",
      "\\.test\\.(ts|js)$"
    ]
  }
}
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `true` | Enable/disable the guard |
| `warnThreshold` | `120` | Lines before warning |
| `blockThreshold` | `200` | Lines before blocking |
| `excludePatterns` | (see below) | Regex patterns to skip |

### Default Exclusions

- Lock files: `package-lock.json`, `yarn.lock`, etc.
- Generated: `.min.js`, `.d.ts`, `.generated.*`
- Configs: `*.config.js`, `tsconfig.json`, etc.
- Data: `.json`, `.yaml`, `.yml`
- Docs: `.md`, `.mdx`, `.txt`
- Tests: `__fixtures__/`, `__snapshots__/`, `.snap`
- Shell: `.sh`

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code Session                       │
├─────────────────────────────────────────────────────────────┤
│  1. AI attempts Edit/Write operation                        │
│  2. file-size-guard hook intercepts                         │
│  3. Estimates resulting file size                           │
│  4. Checks against thresholds                               │
│  5. Returns: OK (0), WARN (0+msg), or BLOCK (2)            │
└─────────────────────────────────────────────────────────────┘
```

### Exit Codes

- `0` - Operation allowed
- `0` + message - Warning, operation continues
- `2` - Operation blocked

## After Claude Code Updates

If the hook stops working after a Claude Code update:

```bash
# Check status
~/.claude/scripts/file-size-guard-toggle.sh status

# Run update/repair
~/.claude/scripts/file-size-guard-update.sh
```

### Auto-Recovery (Optional)

Add to your shell profile (`.bashrc`, `.zshrc`):

```bash
source ~/.claude/scripts/file-size-guard-recovery.sh
```

## File Structure

```
~/.claude/
├── hooks/
│   ├── file-size-guard.cjs           # Main hook
│   └── file-size-guard/
│       ├── line-counter.cjs          # Line counting logic
│       ├── threshold-checker.cjs     # Threshold checking
│       └── suggestion-generator.cjs  # Micro-extract suggestions
├── scripts/
│   ├── file-size-guard-toggle.sh     # Enable/disable
│   └── file-size-guard-recovery.sh   # Auto-recovery
├── settings.json                      # Hook registration
├── .ck.json                          # Configuration
└── backups/
    └── file-size-guard-YYYYMMDD-HHMMSS/  # Backups
```

## License

MIT

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with Claude Code
5. Submit a pull request
