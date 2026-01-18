#Requires -Version 5.1
<#
.SYNOPSIS
    Toggle file-size-guard hook on/off
.EXAMPLE
    .\file-size-guard-toggle.ps1 status
    .\file-size-guard-toggle.ps1 enable
    .\file-size-guard-toggle.ps1 disable
    .\file-size-guard-toggle.ps1 repair
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("enable", "disable", "status", "repair")]
    [string]$Action
)

$ErrorActionPreference = "Stop"

$ClaudeDir = "$env:USERPROFILE\.claude"
$CkConfig = if ($env:CK_CONFIG) { $env:CK_CONFIG } else { "$ClaudeDir\.ck.json" }
$SettingsFile = "$ClaudeDir\settings.json"
$HooksDir = "$ClaudeDir\hooks"
$HookCommand = 'node %USERPROFILE%\.claude\hooks\file-size-guard.cjs'

function Ensure-Config {
    if (-not (Test-Path $CkConfig)) {
        $dir = Split-Path $CkConfig -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        '{}' | Out-File -FilePath $CkConfig -Encoding utf8
    }
}

function Test-Registration {
    if (-not (Test-Path $SettingsFile)) { return $false }
    $content = Get-Content $SettingsFile -Raw
    return $content -match "file-size-guard\.cjs"
}

function Register-Hook {
    $nodeScript = @"
const fs = require('fs');
const settingsPath = '$($SettingsFile -replace '\\', '\\\\')';
let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) { settings = {hooks:{}}; }
settings.hooks = settings.hooks || {};
settings.hooks.PreToolUse = settings.hooks.PreToolUse || [];
const cmd = '$($HookCommand -replace '\\', '\\\\')';
const exists = settings.hooks.PreToolUse.some(e => e.hooks?.some(h => h.command === cmd));
if (!exists) {
  let m = settings.hooks.PreToolUse.find(e => e.matcher === 'Edit|Write');
  if (!m) { m = {matcher:'Edit|Write',hooks:[]}; settings.hooks.PreToolUse.push(m); }
  m.hooks.push({type:'command',command:cmd});
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
  console.log('✓ Hook registered in settings.json');
} else { console.log('ℹ Hook already registered'); }
"@
    & node -e $nodeScript
}

switch ($Action) {
    "enable" {
        Ensure-Config
        $nodeScript = @"
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('$($CkConfig -replace '\\', '\\\\')', 'utf-8'));
config.fileSizeGuard = config.fileSizeGuard || {};
config.fileSizeGuard.enabled = true;
fs.writeFileSync('$($CkConfig -replace '\\', '\\\\')', JSON.stringify(config, null, 2));
console.log('✓ file-size-guard ENABLED');
"@
        & node -e $nodeScript
    }

    "disable" {
        Ensure-Config
        $nodeScript = @"
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('$($CkConfig -replace '\\', '\\\\')', 'utf-8'));
config.fileSizeGuard = config.fileSizeGuard || {};
config.fileSizeGuard.enabled = false;
fs.writeFileSync('$($CkConfig -replace '\\', '\\\\')', JSON.stringify(config, null, 2));
console.log('✗ file-size-guard DISABLED');
"@
        & node -e $nodeScript
    }

    "status" {
        Ensure-Config
        Write-Host "=== File Size Guard Status ===" -ForegroundColor Cyan
        Write-Host ""

        # Check files
        if (Test-Path "$HooksDir\file-size-guard.cjs") {
            Write-Host "Hook files:    ✓ Installed" -ForegroundColor Green
        } else {
            Write-Host "Hook files:    ✗ Missing" -ForegroundColor Red
        }

        # Check registration
        if (Test-Registration) {
            Write-Host "Registration:  ✓ Registered" -ForegroundColor Green
        } else {
            Write-Host "Registration:  ✗ Not registered" -ForegroundColor Red
        }

        # Check enabled status
        $nodeScript = @"
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('$($CkConfig -replace '\\', '\\\\')', 'utf-8'));
const enabled = config.fileSizeGuard?.enabled !== false;
console.log('Enabled:       ' + (enabled ? '✓ Yes' : '✗ No'));
console.log('warnThreshold: ' + (config.fileSizeGuard?.warnThreshold || 120));
console.log('blockThreshold:' + (config.fileSizeGuard?.blockThreshold || 200));
"@
        & node -e $nodeScript

        Write-Host ""
        Write-Host "Run 'repair' if registration is missing after Claude Code update."
    }

    "repair" {
        Write-Host "=== Repairing file-size-guard ===" -ForegroundColor Cyan

        if (-not (Test-Path "$HooksDir\file-size-guard.cjs")) {
            Write-Host "✗ Hook files missing. Please reinstall:" -ForegroundColor Red
            Write-Host "   irm https://raw.githubusercontent.com/hangocduong/claude-file-size-guard/main/install.ps1 | iex"
            exit 1
        }

        Register-Hook

        Ensure-Config
        $nodeScript = @"
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('$($CkConfig -replace '\\', '\\\\')', 'utf-8'));
config.fileSizeGuard = config.fileSizeGuard || {};
if (config.fileSizeGuard.enabled === undefined) {
  config.fileSizeGuard.enabled = true;
}
fs.writeFileSync('$($CkConfig -replace '\\', '\\\\')', JSON.stringify(config, null, 2));
"@
        & node -e $nodeScript

        Write-Host "✓ Repair complete. Restart Claude Code to apply." -ForegroundColor Green
    }

    default {
        Write-Host "Usage: .\file-size-guard-toggle.ps1 [enable|disable|status|repair]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  enable   - Enable file size guard"
        Write-Host "  disable  - Disable file size guard (temporary)"
        Write-Host "  status   - Show current status and registration"
        Write-Host "  repair   - Re-register hook after Claude Code/Kit update"
        exit 1
    }
}
