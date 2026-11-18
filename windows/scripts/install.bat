@echo off
setlocal
cd /d "%~dp0"
echo ==========================================================
echo  PeerLink 1-Click Windows Setup
echo ==========================================================
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0install.ps1"
echo.
pause
