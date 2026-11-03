@echo off
title TravelGO AI Public Tunnel
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "start_ai_tunnel.ps1"
pause
