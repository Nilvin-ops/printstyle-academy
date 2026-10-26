@echo off
setlocal
cd /d "%~dp0"
set "PORT=8765"
start "PrintStyle Academy Server" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1" -Port %PORT%
timeout /t 2 /nobreak >nul
start "" "http://127.0.0.1:%PORT%/#/courses"
exit /b 0
