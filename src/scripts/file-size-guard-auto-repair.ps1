<#
.SYNOPSIS
    file-size-guard-auto-repair.ps1 - Self-healing auto-repair for Claude Code/Kit updates

.DESCRIPTION
    This script ensures file-size-guard remains functional after:
    - Claude Code updates (which may reset settings.json)
    - ClaudeKit updates (which may modify hook registrations)

    Add to PowerShell profile ($PROFILE):
    . $env:USERPROFILE\.claude\scripts\file-size-guard-auto-repair.ps1

    The script runs silently and only outputs when repair is needed.
#>

# Run in background job to not slow down shell startup
Start-Job -ScriptBlock {
    $ClaudeDir = "$env:USERPROFILE\.claude"
    $HooksDir = "$ClaudeDir\hooks"
    $SettingsFile = "$ClaudeDir\settings.json"
    $HookCommand = 'node %USERPROFILE%\.claude\hooks\file-size-guard.cjs'

    function Test-Files {
        if (-not (Test-Path "$HooksDir\file-size-guard.cjs")) { return $false }
        if (-not (Test-Path "$HooksDir\file-size-guard")) { return $false }
        return $true
    }

    function Test-Registration {
        if (-not (Test-Path $SettingsFile)) { return $false }
        $content = Get-Content $SettingsFile -Raw -ErrorAction SilentlyContinue
        return $content -match "file-size-guard\.cjs"
    }

    function Register-Hook {
        if (-not (Test-Path $SettingsFile)) {
            '{"hooks":{}}' | Out-File -FilePath $SettingsFile -Encoding utf8
        }

        $nodeScript = @"
const fs = require('fs');
const settingsPath = '$($SettingsFile -replace '\\', '\\\\')';
let settings = {};

try {
  settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
} catch(e) {
  settings = { hooks: {} };
}

settings.hooks = settings.hooks || {};
settings.hooks.PreToolUse = settings.hooks.PreToolUse || [];

const hookCommand = '$($HookCommand -replace '\\', '\\\\')';
const hookExists = settings.hooks.PreToolUse.some(entry =>
  entry.hooks?.some(h => h.command === hookCommand)
);

if (!hookExists) {
  let matcher = settings.hooks.PreToolUse.find(e => e.matcher === 'Edit|Write');
  if (!matcher) {
    matcher = { matcher: 'Edit|Write', hooks: [] };
    settings.hooks.PreToolUse.push(matcher);
  }
  matcher.hooks.push({ type: 'command', command: hookCommand });
  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
  console.log('[file-size-guard] Hook re-registered successfully');
}
"@
        & node -e $nodeScript 2>$null
    }

    # Main check
    if (Test-Files) {
        if (-not (Test-Registration)) {
            Register-Hook
        }
    }
} | Out-Null
