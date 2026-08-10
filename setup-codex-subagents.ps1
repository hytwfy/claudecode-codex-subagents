#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    在 Windows 上配置 codex-subagents 所需的 MCP server。

.DESCRIPTION
    该脚本会：
    1. 检查 python3、uvx、codex 是否已安装
    2. 可选自动安装 uv（提供 uvx）
    3. 优先通过 claude mcp add 注册 MCP server
    4. 注册失败时创建插件目录下的 .mcp.json
    5. 提示你如何安装 Codex CLI 并重启 Claude Code

.NOTES
    请以普通用户权限运行，不需要管理员权限。
    安装完成后，必须完全退出并重新启动 Claude Code。
#>

$ErrorActionPreference = "Stop"

# ── 路径配置 ──
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$McpJsonPath = Join-Path $ScriptDir ".mcp.json"

# ── 辅助函数 ──
function Test-CommandAvailable {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    return ($null -ne $cmd)
}

function Get-CommandVersion {
    param([string]$Name, [string]$Arg = "--version")
    try {
        $output = & $Name $Arg 2>&1 | Select-Object -First 1
        return $output
    } catch {
        return "unknown"
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Codex Subagents MCP 配置脚本 (Windows)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# ── 1. 检查 Python 3 ──
Write-Host "[1/4] 检查 Python 3..." -ForegroundColor Yellow
if (Test-CommandAvailable "python3") {
    Write-Host "  ✓ python3 已安装: $(Get-CommandVersion python3)" -ForegroundColor Green
} elseif (Test-CommandAvailable "python") {
    Write-Host "  ✓ python 已安装: $(Get-CommandVersion python)" -ForegroundColor Green
    Write-Host "  ⚠ 建议使用 python3 命令，或确保 python 已加入 PATH" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ 未找到 python3/python" -ForegroundColor Red
    Write-Host "  📦 请从 Microsoft Store 或 https://www.python.org 安装 Python 3" -ForegroundColor Yellow
}
Write-Host ""

# ── 2. 检查 uv / uvx ──
Write-Host "[2/4] 检查 uvx (MCP server 运行器)..." -ForegroundColor Yellow
if (Test-CommandAvailable "uvx") {
    Write-Host "  ✓ uvx 已安装: $(Get-CommandVersion uvx)" -ForegroundColor Green
} else {
    Write-Host "  ✗ uvx 未安装" -ForegroundColor Red
    Write-Host "  📦 uvx 是运行 codex-as-mcp 所必需的" -ForegroundColor Yellow

    $installUv = Read-Host "  是否自动安装 uv? (y/n)"
    if ($installUv -eq "y" -or $installUv -eq "Y") {
        Write-Host "  正在安装 uv..." -ForegroundColor Cyan
        try {
            powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
            Write-Host "  ✓ uv 安装命令已执行" -ForegroundColor Green
            Write-Host "  ⚠ 请关闭并重新打开终端，然后再次运行本脚本以验证 uvx" -ForegroundColor Yellow
        } catch {
            Write-Host "  ✗ uv 安装失败: $_" -ForegroundColor Red
            Write-Host "  请手动访问 https://docs.astral.sh/uv/getting-started/installation/ 安装" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  跳过 uv 安装。你可以稍后手动安装：" -ForegroundColor Yellow
        Write-Host '    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"' -ForegroundColor DarkGray
    }
}
Write-Host ""

# ── 3. 检查 Codex CLI ──
Write-Host "[3/4] 检查 Codex CLI..." -ForegroundColor Yellow
if (Test-CommandAvailable "codex") {
    Write-Host "  ✓ codex 已安装: $(Get-CommandVersion codex)" -ForegroundColor Green
    Write-Host "  💡 如果尚未登录，请运行: codex login" -ForegroundColor Cyan
} else {
    Write-Host "  ✗ codex 未安装" -ForegroundColor Red
    Write-Host "  📦 请手动安装 Codex CLI:" -ForegroundColor Yellow
    Write-Host '    powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"' -ForegroundColor DarkGray
    Write-Host "  🔑 安装后登录:" -ForegroundColor Yellow
    Write-Host "    codex login" -ForegroundColor DarkGray
}
Write-Host ""

# ── 4. 注册到 Claude Code 或创建 .mcp.json fallback ──
Write-Host "[4/4] 配置 MCP server..." -ForegroundColor Yellow

$mcpServerArgs = @("--with", "fastmcp", "codex-as-mcp@latest")
$registered = $false
if (Test-CommandAvailable "claude") {
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $null = & claude mcp remove codex-subagent -s local 2>&1
        $null = & claude mcp remove codex-subagent -s project 2>&1
        $null = & claude mcp remove codex-subagent -s user 2>&1
        $addOutput = & claude mcp add --scope user codex-subagent -- uvx @mcpServerArgs 2>&1
        $addExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference

        if ($addExitCode -eq 0) {
            $registered = $true
            Write-Host "  ✓ 已通过 claude mcp add 注册" -ForegroundColor Green
            if (Test-Path $McpJsonPath) {
                Remove-Item -Path $McpJsonPath -Force
                Write-Host "  ℹ 已删除项目级 .mcp.json，避免同名 server 冲突" -ForegroundColor Cyan
            }
        } else {
            Write-Host "  ⚠ claude mcp add 返回错误，将使用 .mcp.json fallback" -ForegroundColor Yellow
            if ($addOutput) { Write-Host "    $addOutput" -ForegroundColor DarkGray }
        }
    } catch {
        $ErrorActionPreference = $previousErrorActionPreference
        Write-Host "  ⚠ 无法运行 claude mcp add，将使用 .mcp.json fallback" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠ 未找到 claude CLI，将使用 .mcp.json fallback" -ForegroundColor Yellow
}

if (-not $registered) {
    $mcpConfig = @{
        mcpServers = @{
            "codex-subagent" = @{
                command = "uvx"
                args = $mcpServerArgs
            }
        }
    }
    try {
        $mcpConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $McpJsonPath -Encoding UTF8
        Write-Host "  ✓ 已写入: $McpJsonPath" -ForegroundColor Green
        Write-Host "  💡 重启 Claude Code 后需要手动批准 codex-subagent MCP server" -ForegroundColor Cyan
    } catch {
        Write-Host "  ✗ 写入 .mcp.json 失败: $_" -ForegroundColor Red
    }
}
Write-Host ""

# ── 显示最终配置 ──
if (Test-Path $McpJsonPath) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  当前 .mcp.json 配置:" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Get-Content $McpJsonPath | Write-Host
    Write-Host ""
}

# ── 后续步骤 ──
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  后续步骤" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. 确保 uvx 已安装（如果刚才安装了 uv，请重启终端后再验证）" -ForegroundColor White
Write-Host "   验证命令: uvx --version" -ForegroundColor DarkGray
Write-Host ""
Write-Host "2. 安装并登录 Codex CLI:" -ForegroundColor White
Write-Host '   powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"' -ForegroundColor DarkGray
Write-Host "   codex login" -ForegroundColor DarkGray
Write-Host ""
Write-Host "3. 完全退出当前 Claude Code 会话，然后重新启动" -ForegroundColor White
Write-Host ""
Write-Host "4. 重启后验证 MCP server:" -ForegroundColor White
Write-Host "   /mcp" -ForegroundColor DarkGray
Write-Host "   确认列表中有 codex-subagent" -ForegroundColor DarkGray
Write-Host ""
Write-Host "5. 测试 codex-subagents:" -ForegroundColor White
Write-Host "   /codex-subagents-en 请创建一个简单的 Hello World 组件" -ForegroundColor DarkGray
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
