#Requires -Version 5.1
<#
.SYNOPSIS
    Claude File Size Guard - Windows Installer
.DESCRIPTION
    Prevents AI from creating large files that require refactoring
.EXAMPLE
    irm https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"

# Config
$Version = "1.4.0"
$RepoUrl = if ($env:REPO_URL) { $env:REPO_URL } else { "https://github.com/hangocduong/claude-file-size-guard" }
$RawUrl = if ($env:RAW_URL) { $env:RAW_URL } else { "https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main" }
$ClaudeDir = "$env:USERPROFILE\.claude"
$HooksDir = "$ClaudeDir\hooks"
$ScriptsDir = "$ClaudeDir\scripts"
$BackupDir = "$ClaudeDir\backups\file-size-guard-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$SettingsFile = "$ClaudeDir\settings.json"
$CkConfig = "$ClaudeDir\.ck.json"

function Write-Banner {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║       Claude File Size Guard Installer v$Version            ║" -ForegroundColor Blue
    Write-Host "║  Prevent large files, enforce modular code from start    ║" -ForegroundColor Blue
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
}

function Test-ClaudeVersion {
    try {
        $version = & claude --version 2>$null | Select-Object -First 1
        Write-Host "✓ Claude Code detected: $version" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Claude Code CLI not found (OK if using IDE extension)" -ForegroundColor Yellow
    }
}

function Test-Node {
    try {
        $version = & node --version 2>$null
        Write-Host "✓ Node.js: $version" -ForegroundColor Green
    } catch {
        Write-Host "✗ Node.js not found. Please install Node.js first." -ForegroundColor Red
        exit 1
    }
}

function New-Backup {
    Write-Host "`nCreating backup..." -ForegroundColor Blue
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

    if (Test-Path $SettingsFile) { Copy-Item $SettingsFile $BackupDir }
    if (Test-Path $CkConfig) { Copy-Item $CkConfig $BackupDir }
    if (Test-Path "$HooksDir\file-size-guard.cjs") { Copy-Item "$HooksDir\file-size-guard.cjs" $BackupDir }

    Write-Host "✓ Backup: $BackupDir" -ForegroundColor Green
}

function Install-Hooks {
    Write-Host "`nInstalling hooks..." -ForegroundColor Blue

    New-Item -ItemType Directory -Force -Path "$HooksDir\file-size-guard" | Out-Null
    New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null

    $ScriptPath = $PSScriptRoot
    if ($ScriptPath -and (Test-Path "$ScriptPath\src")) {
        # Local install
        Copy-Item "$ScriptPath\src\hooks\file-size-guard.cjs" $HooksDir
        Copy-Item "$ScriptPath\src\hooks\file-size-guard\*.cjs" "$HooksDir\file-size-guard\"
        Copy-Item "$ScriptPath\src\scripts\file-size-guard-toggle.ps1" $ScriptsDir
        Copy-Item "$ScriptPath\src\scripts\file-size-guard-auto-repair.ps1" $ScriptsDir
    } else {
        # Download from GitHub
        Write-Host "  Downloading from $RawUrl..."

        $files = @(
            @{ Url = "$RawUrl/src/hooks/file-size-guard.cjs"; Dest = "$HooksDir\file-size-guard.cjs" }
            @{ Url = "$RawUrl/src/hooks/file-size-guard/line-counter.cjs"; Dest = "$HooksDir\file-size-guard\line-counter.cjs" }
            @{ Url = "$RawUrl/src/hooks/file-size-guard/threshold-checker.cjs"; Dest = "$HooksDir\file-size-guard\threshold-checker.cjs" }
            @{ Url = "$RawUrl/src/hooks/file-size-guard/suggestion-generator.cjs"; Dest = "$HooksDir\file-size-guard\suggestion-generator.cjs" }
            @{ Url = "$RawUrl/src/scripts/file-size-guard-toggle.ps1"; Dest = "$ScriptsDir\file-size-guard-toggle.ps1" }
            @{ Url = "$RawUrl/src/scripts/file-size-guard-auto-repair.ps1"; Dest = "$ScriptsDir\file-size-guard-auto-repair.ps1" }
        )

        foreach ($file in $files) {
            Invoke-WebRequest -Uri $file.Url -OutFile $file.Dest -UseBasicParsing
        }
    }

    Write-Host "✓ Hooks installed" -ForegroundColor Green
}

function Register-Hook {
    Write-Host "`nRegistering hook..." -ForegroundColor Blue

    if (-not (Test-Path $SettingsFile)) {
        '{"hooks":{}}' | Out-File -FilePath $SettingsFile -Encoding utf8
    }

    $nodeScript = @"
const fs = require('fs');
const settingsPath = '$($SettingsFile -replace '\\', '\\\\')';
let s = {};
try { s = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) { s = {hooks:{}}; }
s.hooks = s.hooks || {};
s.hooks.PreToolUse = s.hooks.PreToolUse || [];
const cmd = 'node %USERPROFILE%\\.claude\\hooks\\file-size-guard.cjs';
const exists = s.hooks.PreToolUse.some(e => e.hooks?.some(h => h.command === cmd));
if (!exists) {
  let m = s.hooks.PreToolUse.find(e => e.matcher === 'Edit|Write');
  if (!m) { m = {matcher:'Edit|Write',hooks:[]}; s.hooks.PreToolUse.push(m); }
  m.hooks.push({type:'command',command:cmd});
  fs.writeFileSync(settingsPath, JSON.stringify(s, null, 2));
  console.log('Hook registered');
} else { console.log('Hook already exists'); }
"@

    & node -e $nodeScript
    Write-Host "✓ Hook registered" -ForegroundColor Green
}

function Set-CkConfig {
    Write-Host "`nConfiguring defaults..." -ForegroundColor Blue

    $nodeScript = @"
const fs = require('fs');
const ckPath = '$($CkConfig -replace '\\', '\\\\')';
let c = {};
try { c = JSON.parse(fs.readFileSync(ckPath, 'utf-8')); } catch(e) {}
if (!c.fileSizeGuard) {
  c.fileSizeGuard = {
    enabled: true,
    warnThreshold: 120,
    blockThreshold: 200,
    excludePatterns: [
      'package-lock\\.json$','pnpm-lock\\.yaml$','yarn\\.lock$',
      '\\.min\\.(js|css)$','\\.d\\.ts$','\\.json$','\\.yaml$',
      '\\.yml$','\\.md$','\\.sh$','__fixtures__/','__snapshots__/'
    ]
  };
  fs.writeFileSync(ckPath, JSON.stringify(c, null, 2));
  console.log('Config created');
} else { console.log('Config exists'); }
"@

    & node -e $nodeScript
    Write-Host "✓ Configuration done" -ForegroundColor Green
}

function Install-Recovery {
    Write-Host "`nInstalling auto-repair system..." -ForegroundColor Blue
    # Auto-repair script is already installed by Install-Hooks
    Write-Host "✓ Auto-repair system installed" -ForegroundColor Green
}

function Write-Summary {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║            Installation Complete!                         ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Config: warnThreshold=120, blockThreshold=200"
    Write-Host ""
    Write-Host "Commands (PowerShell):"
    Write-Host "  & `$env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 status"
    Write-Host "  & `$env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 disable"
    Write-Host "  & `$env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 enable"
    Write-Host "  & `$env:USERPROFILE\.claude\scripts\file-size-guard-toggle.ps1 repair"
    Write-Host ""
    Write-Host "Optional: Survive Claude Code/Kit updates" -ForegroundColor Yellow
    Write-Host "Add to PowerShell profile (`$PROFILE):"
    Write-Host "  . `$env:USERPROFILE\.claude\scripts\file-size-guard-auto-repair.ps1"
    Write-Host ""
    Write-Host "Start new Claude session to activate." -ForegroundColor Yellow
}

# Main
Write-Banner
Test-ClaudeVersion
Test-Node
New-Backup
Install-Hooks
Register-Hook
Set-CkConfig
Install-Recovery
Write-Summary
