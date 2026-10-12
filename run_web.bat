@echo off
title Go-On Web Application (Port 3000)
cd /d "%~dp0"
echo ============================================================
echo   Go-On Flutter Web Server (Port 3000)
echo   URL: http://localhost:3000 and http://127.0.0.1:3000
echo ============================================================
if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" scripts\serve_web.py
) else (
    py -3.10 scripts\serve_web.py
)
pause
