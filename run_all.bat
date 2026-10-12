@echo off
title Go-On Full Stack Launcher
cd /d "%~dp0"
echo ============================================================
echo   Launching Go-On Local Hosting
echo   1. Backend API Server -> http://localhost:8000
echo   2. Go-On Web App      -> http://localhost:3000
echo ============================================================
start "Go-On Backend (Port 8000)" run_backend.bat
timeout /t 3 /nobreak >nul
start "Go-On Web (Port 3000)" run_web.bat
start "" "http://localhost:3000"
echo Done. Both services running and browser opened!
