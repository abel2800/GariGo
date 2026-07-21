@echo off
title GariGo launcher
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0start-all.ps1"
pause
