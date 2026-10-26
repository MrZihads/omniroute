@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0OmniRoute.ps1" -Mode Setup
if errorlevel 1 pause
