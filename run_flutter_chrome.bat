@echo off
title Attendance Marker Flutter Chrome
cd /d "%~dp0mobile"
echo ============================================================
echo   Attendance Marker Mobile UI (Flutter Chrome)
echo   Connecting to Backend: http://127.0.0.1:8000
echo ============================================================
"E:\flutter\bin\flutter.bat" run -d chrome --web-port=3000
pause
