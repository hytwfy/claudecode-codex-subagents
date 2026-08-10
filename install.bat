@echo off
setlocal

:: Codex Subagents Plugin - Windows Batch Installer (fallback wrapper)
:: For: CMD / Command Prompt
:: Usage: install.bat [/auto]
:: Note: For a better experience on Windows, use install.ps1 directly.

title Codex Subagents Installer

echo.
echo ==================================================
echo   Codex Subagents Plugin Installer (Batch)
echo   This is a fallback wrapper around install.ps1.
echo ==================================================
echo.

set "AUTO_FLAG="
for %%a in (%*) do (
    if /I "%%a"=="/auto" set "AUTO_FLAG=-Auto"
    if /I "%%a"=="--auto" set "AUTO_FLAG=-Auto"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %AUTO_FLAG%
exit /b %errorlevel%
