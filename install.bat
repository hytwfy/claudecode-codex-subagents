@echo off
setlocal EnableDelayedExpansion

:: Codex Subagents Plugin - Windows Batch Installer
:: For: CMD / Command Prompt
:: Usage: install.bat [/auto]
:: Note: For a better experience on Windows, use install.ps1

title Codex Subagents Installer

:: ── Parse arguments ──
set "AUTO_MODE=false"
for %%a in (%*) do (
    if /I "%%a"=="/auto" set "AUTO_MODE=true"
    if /I "%%a"=="--auto" set "AUTO_MODE=true"
)

echo.
echo ==================================================
echo   Codex Subagents Plugin Installer (Batch)
if "%AUTO_MODE%"=="true" (
    echo   Mode: automatic (agent)
)
echo ==================================================
echo.

:: ── Paths ──
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CLAUDE_DIR=%USERPROFILE%\.claude"
set "PLUGINS_DIR=%CLAUDE_DIR%\plugins"
set "COMMANDS_DIR=%CLAUDE_DIR%\commands"
set "MCP_SETTINGS=%CLAUDE_DIR%\mcp_settings.json"
set "SUMMARY_FILE=%SCRIPT_DIR%\.codex-subagents-install-summary.json"

:: ── Result tracking ──
set "RESULT_SUCCESS=true"
set "RESULT_OS=windows"
set "RESULT_MODE=interactive"
if "%AUTO_MODE%"=="true" set "RESULT_MODE=auto"
set "DEP_PYTHON3=false"
set "DEP_UVX=false"
set "DEP_CODEX=false"
set "ACT_DIRS=false"
set "ACT_PLUGIN=false"
set "ACT_COMMANDS=false"
set "ACT_MCP=false"
set "USER_ACTIONS="
set "ERRORS="

:: ── Helper: add user action ──
:add_user_action
set "USER_ACTIONS=%USER_ACTIONS%%~1|"
goto :eof

:: ── Helper: add error ──
:add_error
set "RESULT_SUCCESS=false"
set "ERRORS=%ERRORS%%~1|"
echo   [ERROR] %~1
goto :eof

:: ── 1. Dependency checks ──
echo [1/5] Checking dependencies...

python3 --version > nul 2>&1
if %errorlevel% == 0 (
    set "DEP_PYTHON3=true"
    for /f "tokens=*" %%a in ('python3 --version 2^>^&1') do echo   [OK] python3: %%a
) else (
    python --version > nul 2>&1
    if %errorlevel% == 0 (
        for /f "tokens=*" %%a in ('python --version 2^>^&1') do echo   [WARN] python3 not found, but python: %%a
    ) else (
        echo   [MISSING] python3
        call :add_error "python3 is not installed"
    )
)

uvx --version > nul 2>&1
if %errorlevel% == 0 (
    set "DEP_UVX=true"
    for /f "tokens=*" %%a in ('uvx --version 2^>^&1') do echo   [OK] uvx: %%a
) else (
    echo   [MISSING] uvx
    call :add_error "uvx is not installed"
)

codex --version > nul 2>&1
if %errorlevel% == 0 (
    set "DEP_CODEX=true"
    for /f "tokens=*" %%a in ('codex --version 2^>^&1') do echo   [OK] codex: %%a
) else (
    echo   [MISSING] codex
    call :add_error "codex CLI is not installed"
)

echo.

:: ── 2. Install missing dependencies ──
if "%DEP_PYTHON3%"=="false" (
    echo [python3] Please install Python 3 from:
    echo   https://www.python.org/downloads/
    echo   Or: winget install Python.Python.3
    call :add_user_action "Install Python 3 (https://www.python.org/downloads/)"
    echo.
)

if "%DEP_UVX%"=="false" (
    if "%AUTO_MODE%"=="true" (
        echo [uvx] Auto-installing uv...
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        if %errorlevel% == 0 (
            set "PATH=%USERPROFILE%\.local\bin;%PATH%"
            uvx --version > nul 2>&1
            if %errorlevel% == 0 (
                set "DEP_UVX=true"
                for /f "tokens=*" %%a in ('uvx --version 2^>^&1') do echo   [OK] uvx installed: %%a
            ) else (
                call :add_error "uv installed but uvx not in PATH"
                call :add_user_action "Restart terminal to load uvx in PATH"
            )
        ) else (
            call :add_error "uv installation failed"
            call :add_user_action "Install uv manually: powershell -ExecutionPolicy ByPass -c 'irm https://astral.sh/uv/install.ps1 | iex'"
        )
    ) else (
        echo [uvx] Install with:
        echo   powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        call :add_user_action "Install uv: powershell -ExecutionPolicy ByPass -c 'irm https://astral.sh/uv/install.ps1 | iex'"
    )
    echo.
)

if "%DEP_CODEX%"=="false" (
    if "%AUTO_MODE%"=="true" (
        echo [codex] Auto-installing Codex CLI...
        powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
        if %errorlevel% == 0 (
            codex --version > nul 2>&1
            if %errorlevel% == 0 (
                set "DEP_CODEX=true"
                for /f "tokens=*" %%a in ('codex --version 2^>^&1') do echo   [OK] codex installed: %%a
                call :add_user_action "Run 'codex login' to authenticate"
            ) else (
                call :add_error "Codex CLI installed but not in PATH"
                call :add_user_action "Restart terminal, then run: codex login"
            )
        ) else (
            call :add_error "Codex CLI installation failed"
            call :add_user_action "Install Codex CLI manually: powershell -ExecutionPolicy ByPass -c 'irm https://chatgpt.com/codex/install.ps1 | iex'; then run: codex login"
        )
    ) else (
        echo [codex] Install with:
        echo   powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 ^| iex"
        echo   Then login: codex login
        call :add_user_action "Install Codex CLI: powershell -ExecutionPolicy ByPass -c 'irm https://chatgpt.com/codex/install.ps1 | iex'; then run: codex login"
    )
    echo.
)

:: ── 3. Create directories ──
echo [2/5] Creating directories...
if not exist "%CLAUDE_DIR%" mkdir "%CLAUDE_DIR%"
if not exist "%PLUGINS_DIR%" mkdir "%PLUGINS_DIR%"
if not exist "%COMMANDS_DIR%" mkdir "%COMMANDS_DIR%"
set "ACT_DIRS=true"
echo   [OK] Directories created.
echo.

:: ── 4. Install plugin ──
echo [3/5] Installing plugin...
if exist "%PLUGINS_DIR%\codex-subagents" (
    echo   [INFO] Existing plugin found, backing up...
    move "%PLUGINS_DIR%\codex-subagents" "%PLUGINS_DIR%\codex-subagents.bak.%date:~-4,4%%date:~-10,2%%date:~-7,2%%time:~0,2%%time:~3,2%%time:~6,2%" > nul 2>&1
)

mklink /J "%PLUGINS_DIR%\codex-subagents" "%SCRIPT_DIR%" > nul 2>&1
if %errorlevel% == 0 (
    set "ACT_PLUGIN=true"
    echo   [OK] Plugin linked to: %PLUGINS_DIR%\codex-subagents
) else (
    echo   [INFO] Junction failed, copying files instead...
    xcopy /E /I /Y "%SCRIPT_DIR%" "%PLUGINS_DIR%\codex-subagents" > nul
    if %errorlevel% == 0 (
        set "ACT_PLUGIN=true"
        echo   [OK] Plugin copied to: %PLUGINS_DIR%\codex-subagents
    ) else (
        call :add_error "Failed to install plugin"
    )
)

if exist "%SCRIPT_DIR%\commands\codex-subagents.md" (
    copy /Y "%SCRIPT_DIR%\commands\codex-subagents.md" "%COMMANDS_DIR%\" > nul
    echo   [OK] Installed: codex-subagents.md
)
if exist "%SCRIPT_DIR%\commands\codex-subagents-en.md" (
    copy /Y "%SCRIPT_DIR%\commands\codex-subagents-en.md" "%COMMANDS_DIR%\" > nul
    echo   [OK] Installed: codex-subagents-en.md
)
set "ACT_COMMANDS=true"
echo.

:: ── 5. Configure MCP server using PowerShell ──
echo [4/5] Configuring MCP server...
if exist "%MCP_SETTINGS%" (
    powershell -NoProfile -Command "$path='%MCP_SETTINGS%'; $json=Get-Content $path -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue; if (-not $json) { $json=@{} }; if (-not $json.mcpServers) { $json | Add-Member -NotePropertyName mcpServers -NotePropertyValue @{} -Force }; $json.mcpServers | Add-Member -NotePropertyName codex-subagent -NotePropertyValue @{command='uvx'; args=@('codex-as-mcp@latest'); transport='stdio'} -Force; $json | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8; exit 0"
) else (
    powershell -NoProfile -Command "$path='%MCP_SETTINGS%'; @{mcpServers=@{codex-subagent=@{command='uvx'; args=@('codex-as-mcp@latest'); transport='stdio'}}} | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8; exit 0"
)
if %errorlevel% == 0 (
    set "ACT_MCP=true"
    echo   [OK] MCP settings written to: %MCP_SETTINGS%
) else (
    call :add_error "Failed to write MCP settings"
)
echo.

:: ── 6. Verification ──
echo [5/5] Verifying installation...
if exist "%PLUGINS_DIR%\codex-subagents\.claude-plugin\plugin.json" (
    echo   [OK] Plugin structure is correct
) else (
    call :add_error "Plugin structure is incorrect"
)

if exist "%MCP_SETTINGS%" (
    powershell -NoProfile -Command "$content=Get-Content '%MCP_SETTINGS%' -Raw; if ($content -match 'codex-subagent') { exit 0 } else { exit 1 }"
    if %errorlevel% == 0 (
        echo   [OK] MCP server is configured
    ) else (
        call :add_error "MCP configuration is missing"
    )
) else (
    call :add_error "MCP configuration file not found"
)

echo.

:: ── Determine exit code ──
set "EXIT_CODE=0"
if "%RESULT_SUCCESS%"=="false" (
    set "EXIT_CODE=1"
) else (
    if not "%USER_ACTIONS%"=="" set "EXIT_CODE=2"
)

:: ── Write JSON summary via PowerShell ──
powershell -NoProfile -Command "
$summary = @{
    success = '%RESULT_SUCCESS%' -eq 'true'
    os = 'windows'
    mode = '%RESULT_MODE%'
    exit_code = %EXIT_CODE%
    dependencies = @{
        python3 = '%DEP_PYTHON3%' -eq 'true'
        uvx = '%DEP_UVX%' -eq 'true'
        codex = '%DEP_CODEX%' -eq 'true'
    }
    actions = @{
        directories_created = '%ACT_DIRS%' -eq 'true'
        plugin_installed = '%ACT_PLUGIN%' -eq 'true'
        commands_installed = '%ACT_COMMANDS%' -eq 'true'
        mcp_configured = '%ACT_MCP%' -eq 'true'
    }
    requires_user_action = @('%USER_ACTIONS%' -split '\|' | Where-Object { $_ -ne '' })
    errors = @('%ERRORS%' -split '\|' | Where-Object { $_ -ne '' })
}
$summary | ConvertTo-Json -Depth 10 | Set-Content -Path '%SUMMARY_FILE%' -Encoding UTF8
"

:: ── Final report ──
if "%EXIT_CODE%"=="0" (
    echo ==================================================
    echo   Installation complete!
    echo ==================================================
) else (
    echo ==================================================
    echo   Installation finished with notes
    echo ==================================================
)

echo.
echo Installation locations:
echo   Plugin:   %PLUGINS_DIR%\codex-subagents
echo   Commands: %COMMANDS_DIR%
echo   MCP:      %MCP_SETTINGS%
echo.

if not "%USER_ACTIONS%"=="" (
    echo Required user actions:
    for %%a in ("%USER_ACTIONS:|=" "%") do (
        if not "%%~a"=="" echo   - %%~a
    )
    echo.
)

echo Usage:
echo   /codex-subagents ^<task^>     (Chinese)
echo   /codex-subagents-en ^<task^>  (English)
echo.
echo IMPORTANT:
echo   1. Restart Claude Code completely.
echo   2. Verify with: /mcp
echo.

if "%AUTO_MODE%"=="true" (
    echo Agent summary written to: %SUMMARY_FILE%
    echo.
)

exit /b %EXIT_CODE%
