@echo off
title Attendance Marker FastAPI Server (Port 8000)
cd /d "%~dp0"
echo ============================================================
echo   Attendance Marker Backend Server
echo   Running on: http://localhost:8000 and http://127.0.0.1:8000
echo   Docs:       http://localhost:8000/docs
echo ============================================================
if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
) else (
    py -3.10 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
)
pause
