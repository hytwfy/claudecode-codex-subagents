#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Codex Subagents Plugin - Windows PowerShell Installer

.DESCRIPTION
    Installs the codex-subagents plugin for Claude Code on Windows.
    Supports both interactive and agent/non-interactive execution.

.PARAMETER Auto
    Run in agent mode: do not prompt, install missing dependencies automatically,
    and output a machine-readable summary at the end.

.PARAMETER SkipDependencyInstall
    Skip automatic installation of missing dependencies.

.EXAMPLE
    .\install.ps1

.EXAMPLE
    .\install.ps1 -Auto

.EXAMPLE
    .\install.ps1 -Auto -SkipDependencyInstall
#>

[CmdletBinding()]
param(
    [switch]$Auto,
    [switch]$SkipDependencyInstall
)

$ErrorActionPreference = "Stop"

# ── Paths ──
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$PluginsDir = Join-Path $ClaudeDir "plugins"
$CommandsDir = Join-Path $ClaudeDir "commands"
$McpJsonPath = Join-Path $ScriptDir ".mcp.json"

# ── Result tracking ──
$Result = [ordered]@{
    success = $true
    os = "windows"
    mode = if ($Auto) { "auto" } else { "interactive" }
    dependencies = [ordered]@{
        python3 = $false
        uvx = $false
        codex = $false
    }
    actions = [ordered]@{
        directories_created = $false
        plugin_installed = $false
        commands_installed = $false
        mcp_configured = $false
    }
    requires_user_action = @()
    errors = @()
}

# ── Helpers ──
function Test-CommandAvailable {
    param([string]$Name)
    return ($null -ne (Get-Command $Name -ErrorAction SilentlyContinue))
}

function Get-CommandVersionSafe {
    param([string]$Name, [string]$Arg = "--version")
    try {
        return (& $Name $Arg 2>&1 | Select-Object -First 1)
    } catch {
        return "unknown"
    }
}

function Write-Info { param([string]$Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-WarningMsg { param([string]$Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-ErrorMsg { param([string]$Message) Write-Host "✗ $Message" -ForegroundColor Red }

function Read-YesNoAuto {
    param([string]$Prompt)
    if ($Auto) { return $true }
    $response = Read-Host "$Prompt (y/n)"
    return ($response -eq "y" -or $response -eq "Y")
}

function Add-UserAction {
    param([string]$Action)
    if ($Result.requires_user_action -notcontains $Action) {
        $Result.requires_user_action += $Action
    }
}

function Add-Error {
    param([string]$Message)
    $Result.success = $false
    $Result.errors += $Message
    Write-ErrorMsg $Message
}

# ── Header ──
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Codex Subagents Plugin Installer (PowerShell)" -ForegroundColor Cyan
if ($Auto) {
    Write-Host "  Mode: automatic (agent)" -ForegroundColor Cyan
}
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Dependency checks ──
Write-Host "[1/5] Checking dependencies..." -ForegroundColor Yellow

if (Test-CommandAvailable "python3") {
    $Result.dependencies.python3 = $true
    Write-Success "python3: $(Get-CommandVersionSafe python3)"
} elseif (Test-CommandAvailable "python") {
    Write-WarningMsg "python3 not found, but python is available: $(Get-CommandVersionSafe python)"
    Write-Info "Consider adding python3 to your PATH"
} else {
    Add-Error "python3 is not installed"
}

if (Test-CommandAvailable "uvx") {
    $Result.dependencies.uvx = $true
    Write-Success "uvx: $(Get-CommandVersionSafe uvx)"
} else {
    Add-Error "uvx is not installed"
}

if (Test-CommandAvailable "codex") {
    $Result.dependencies.codex = $true
    Write-Success "codex: $(Get-CommandVersionSafe codex)"
} else {
    Add-Error "codex CLI is not installed"
}

Write-Host ""

# ── 2. Install missing dependencies ──
if ($Result.dependencies.Values -contains $false) {
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host "  Missing dependencies" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host ""

    if (-not $Result.dependencies.python3) {
        Write-WarningMsg "Python 3"
        Write-Host "  Install from: https://www.python.org/downloads/"
        Write-Host "  Or with winget: winget install Python.Python.3"
        Add-UserAction "Install Python 3 (https://www.python.org/downloads/)"
    }

    if (-not $Result.dependencies.uvx) {
        if ($SkipDependencyInstall) {
            Write-WarningMsg "uvx missing, but -SkipDependencyInstall is set"
            Add-UserAction "Install uv: powershell -ExecutionPolicy ByPass -c 'irm https://astral.sh/uv/install.ps1 | iex'"
        } else {
            if ($Auto -or (Read-YesNoAuto "Install uv now?")) {
                Write-Host "[uv] Installing..." -ForegroundColor Yellow
                try {
                    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
                    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
                    if (Test-CommandAvailable "uvx") {
                        $Result.dependencies.uvx = $true
                        Write-Success "uv installed: $(Get-CommandVersionSafe uvx)"
                    } else {
                        Add-Error "uv installed but uvx not in PATH; restart terminal and re-run"
                        Add-UserAction "Restart terminal to load uvx in PATH"
                    }
                } catch {
                    Add-Error "uv installation failed: $_"
                    Add-UserAction "Install uv manually: powershell -ExecutionPolicy ByPass -c 'irm https://astral.sh/uv/install.ps1 | iex'"
                }
            } else {
                Add-UserAction "Install uv: powershell -ExecutionPolicy ByPass -c 'irm https://astral.sh/uv/install.ps1 | iex'"
            }
        }
    }

    if (-not $Result.dependencies.codex) {
        if ($SkipDependencyInstall) {
            Write-WarningMsg "codex missing, but -SkipDependencyInstall is set"
            Add-UserAction 'Install Codex CLI: powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"; then run: codex login'
        } else {
            if ($Auto -or (Read-YesNoAuto "Install Codex CLI now?")) {
                Write-Host "[Codex CLI] Installing..." -ForegroundColor Yellow
                try {
                    powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
                    if (Test-CommandAvailable "codex") {
                        $Result.dependencies.codex = $true
                        Write-Success "Codex CLI installed: $(Get-CommandVersionSafe codex)"
                        Add-UserAction "Run 'codex login' to authenticate"
                    } else {
                        Add-Error "Codex CLI installed but not in PATH"
                        Add-UserAction "Restart terminal, then run: codex login"
                    }
                } catch {
                    Add-Error "Codex CLI installation failed: $_"
                    Add-UserAction 'Install Codex CLI manually: powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"; then run: codex login'
                }
            } else {
                Add-UserAction 'Install Codex CLI: powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"; then run: codex login'
            }
        }
    }

    Write-Host ""
}

# ── 3. Create directories ──
Write-Host "[2/5] Creating directories..." -ForegroundColor Yellow
try {
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    New-Item -ItemType Directory -Force -Path $PluginsDir | Out-Null
    New-Item -ItemType Directory -Force -Path $CommandsDir | Out-Null
    $Result.actions.directories_created = $true
    Write-Success "Directories created"
} catch {
    Add-Error "Failed to create directories: $_"
}
Write-Host ""

# ── 4. Install plugin ──
Write-Host "[3/5] Installing plugin..." -ForegroundColor Yellow

$pluginTarget = Join-Path $PluginsDir "codex-subagents"
if (Test-Path $pluginTarget) {
    Write-WarningMsg "Existing plugin found, backing up..."
    $backupName = "codex-subagents.bak.{0:yyyyMMddHHmmss}" -f (Get-Date)
    try {
        Move-Item -Path $pluginTarget -Destination (Join-Path $PluginsDir $backupName) -Force
    } catch {
        Add-Error "Failed to backup existing plugin: $_"
    }
}

try {
    New-Item -ItemType Junction -Path $pluginTarget -Target $ScriptDir -Force | Out-Null
    $Result.actions.plugin_installed = $true
    Write-Success "Plugin linked to: $pluginTarget"
} catch {
    Write-WarningMsg "Could not create junction, copying files instead..."
    try {
        Copy-Item -Path $ScriptDir -Destination $pluginTarget -Recurse -Force
        $Result.actions.plugin_installed = $true
        Write-Success "Plugin copied to: $pluginTarget"
    } catch {
        Add-Error "Failed to install plugin: $_"
    }
}

$commandSrc = Join-Path $ScriptDir "commands"
try {
    if (Test-Path (Join-Path $commandSrc "codex-subagents.md")) {
        Copy-Item -Path (Join-Path $commandSrc "codex-subagents.md") -Destination $CommandsDir -Force
        Write-Success "Installed: codex-subagents.md"
    }
    if (Test-Path (Join-Path $commandSrc "codex-subagents-en.md")) {
        Copy-Item -Path (Join-Path $commandSrc "codex-subagents-en.md") -Destination $CommandsDir -Force
        Write-Success "Installed: codex-subagents-en.md"
    }
    $Result.actions.commands_installed = $true
} catch {
    Add-Error "Failed to install commands: $_"
}
Write-Host ""

# ── 5. Configure MCP server ──
Write-Host "[4/5] Configuring MCP server..." -ForegroundColor Yellow

$mcpServerArgs = @("--with", "fastmcp", "codex-as-mcp@latest")
$registered = $false

# Register with Claude Code first so the MCP server is user-scoped and active after restart.
if (Test-CommandAvailable "claude") {
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        # Remove stale entries from every scope before adding the user-scoped server.
        $null = & claude mcp remove codex-subagent -s local 2>&1
        $null = & claude mcp remove codex-subagent -s project 2>&1
        $null = & claude mcp remove codex-subagent -s user 2>&1
        $addOutput = & claude mcp add --scope user codex-subagent -- uvx @mcpServerArgs 2>&1
        $addExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference

        if ($addExitCode -eq 0) {
            $registered = $true
            $Result.actions.mcp_configured = $true
            Write-Success "MCP server registered with Claude Code"
        } else {
            Write-WarningMsg "claude mcp add returned an error; will use .mcp.json fallback"
            if ($addOutput) { Write-WarningMsg ($addOutput -join "`n") }
        }
    } catch {
        $ErrorActionPreference = $previousErrorActionPreference
        Write-WarningMsg "Could not run 'claude mcp add'; will use .mcp.json fallback"
        Write-WarningMsg "Detail: $_"
    }
} else {
    Write-WarningMsg "claude CLI not found in PATH; will use .mcp.json fallback"
}

if ($registered) {
    if (Test-Path $McpJsonPath) {
        try {
            Remove-Item -Path $McpJsonPath -Force
            Write-Info "Removed project-scoped .mcp.json to avoid duplicate server name"
        } catch {
            Write-WarningMsg "Could not remove .mcp.json: $_"
        }
    }
} else {
    $mcpJsonConfig = @{
        mcpServers = @{
            "codex-subagent" = @{
                command = "uvx"
                args = $mcpServerArgs
            }
        }
    }
    try {
        $mcpJsonConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $McpJsonPath -Encoding UTF8
        $Result.actions.mcp_configured = $true
        Write-Success "Plugin .mcp.json written to: $McpJsonPath"
    } catch {
        Add-Error "Could not write .mcp.json: $_"
    }
    Write-Info "Please restart Claude Code and approve the 'codex-subagent' MCP server from .mcp.json"
}
Write-Host ""

# ── 6. Verification ──
Write-Host "[5/5] Verifying installation..." -ForegroundColor Yellow

$pluginJson = Join-Path $pluginTarget ".claude-plugin\plugin.json"
if (Test-Path $pluginJson) {
    Write-Success "Plugin structure is correct"
} else {
    Add-Error "Plugin structure is incorrect"
}

if (Test-Path $McpJsonPath) {
    $mcpContent = Get-Content $McpJsonPath -Raw
    if ($mcpContent -match "codex-subagent") {
        Write-Success "MCP server is configured in .mcp.json"
    } else {
        Add-Error "MCP configuration is missing in .mcp.json"
    }
} elseif ($registered) {
    Write-Success "MCP server is configured via Claude Code user config"
} else {
    Add-Error "MCP .mcp.json file not found"
}

if ($registered) {
    Write-Success "MCP server registered with Claude Code (active after restart)"
}

Write-Host ""

# ── Final report ──
if ($Result.success -and $Result.actions.mcp_configured -and ($Result.requires_user_action.Count -eq 0)) {
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "  Installation complete!" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
} else {
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host "  Installation finished with notes" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Installation locations:" -ForegroundColor Cyan
Write-Host "  Plugin:   $pluginTarget"
Write-Host "  Commands: $CommandsDir"
Write-Host "  MCP:      $McpJsonPath"
Write-Host ""

if ($Result.requires_user_action.Count -gt 0) {
    Write-Host "Required user actions:" -ForegroundColor Yellow
    foreach ($action in $Result.requires_user_action) {
        Write-Host "  - $action"
    }
    Write-Host ""
}

Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  /codex-subagents <task>     (Chinese)"
Write-Host "  /codex-subagents-en <task>  (English)"
Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Yellow
Write-Host "  1. Restart Claude Code completely."
Write-Host "  2. Verify with: /mcp"
Write-Host ""

# ── Machine-readable summary ──
if ($Auto) {
    $summaryPath = Join-Path $ScriptDir ".codex-subagents-install-summary.json"
    $Result | ConvertTo-Json -Depth 10 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "Agent summary written to: $summaryPath" -ForegroundColor Cyan
    Write-Host ""
}

# Exit codes:
# 0 = fully successful (MCP configured)
# 1 = installation failed
# 2 = installed but user action required (e.g., codex login)
if (-not $Result.success) {
    exit 1
}
if ($Result.requires_user_action.Count -gt 0) {
    exit 2
}
exit 0
