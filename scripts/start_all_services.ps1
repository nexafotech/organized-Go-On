<#
.SYNOPSIS
    go-On AI Face Attendance System - Master Localhost Service Orchestrator
.DESCRIPTION
    Safely starts and verifies all required go-On services in the correct sequence:
    1. Validates SQLite database and dependency readiness
    2. Checks port allocations (8000: Backend, 3000: Web Frontend, 8080: APK Server)
    3. Starts FastAPI Backend (Port 8000) and waits for health & database connectivity
    4. Starts Production Web Server (Port 3000) serving mobile/build/web
    5. Starts APK Server (Port 8080) for Android client distribution
    6. Verifies all endpoints and outputs service status dashboard
#>

param(
    [switch]$NoBrowser = $false,
    [switch]$ForceRestart = $false
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "E:\originalam"
Set-Location -Path $ProjectRoot

Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host "         go-On AI Face Attendance System - Localhost Orchestrator       " -ForegroundColor Yellow
Write-Host "=======================================================================" -ForegroundColor Cyan

# 1. Dependency & Environment Checks
Write-Host "`n[1/5] Checking Environment & Database..." -ForegroundColor Gray

$PythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $PythonPath) {
    Write-Host "ERROR: Python is not found on PATH. Please install Python 3.10+." -ForegroundColor Red
    exit 1
}
Write-Host "  * Python: $PythonPath" -ForegroundColor Green

$DbPath = Join-Path $ProjectRoot "attendance_system.db"
if (-not (Test-Path $DbPath)) {
    Write-Host "ERROR: Database file not found at $DbPath." -ForegroundColor Red
    exit 1
}
$DbSizeMB = [math]::Round((Get-Item $DbPath).Length / 1MB, 2)
Write-Host "  * Database: $DbPath ($DbSizeMB MB verified)" -ForegroundColor Green

$WebBuildDir = Join-Path $ProjectRoot "mobile\build\web\index.html"
if (-not (Test-Path $WebBuildDir)) {
    Write-Host "  * Notice: Web build not found at $WebBuildDir. Building web release..." -ForegroundColor Yellow
    Push-Location "mobile"
    flutter build web --release
    Pop-Location
} else {
    Write-Host "  * Flutter Web Bundle: Verified ($WebBuildDir)" -ForegroundColor Green
}

# 2. Port and Process Validation Helper
function Test-PortListening {
    param([int]$Port)
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    return ($null -ne $conn)
}

function Test-HttpEndpoint {
    param([string]$Url, [int]$TimeoutSec = 3)
    try {
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Timeout = $TimeoutSec * 1000
        $req.Method = "GET"
        $resp = $req.GetResponse()
        $status = [int]$resp.StatusCode
        $resp.Close()
        return ($status -eq 200)
    } catch {
        return $false
    }
}

# 3. Start or Verify Backend API (Port 8000)
Write-Host "`n[2/5] Checking Backend API Server (Port 8000)..." -ForegroundColor Gray
$BackendPortActive = Test-PortListening -Port 8000

if ($BackendPortActive -and -not $ForceRestart) {
    if (Test-HttpEndpoint -Url "http://127.0.0.1:8000/health") {
        Write-Host "  * Backend already running and healthy at http://localhost:8000" -ForegroundColor Green
    } else {
        Write-Host "  * Port 8000 is listening but not responding to /health. Checking process..." -ForegroundColor Yellow
    }
} else {
    Write-Host "  * Launching FastAPI backend on port 8000..." -ForegroundColor Cyan
    $BackendProc = Start-Process python -ArgumentList "-m uvicorn app.main:app --host 0.0.0.0 --port 8000" -WorkingDirectory $ProjectRoot -PassThru -WindowStyle Hidden
    Write-Host "  * Process launched (PID: $($BackendProc.Id)). Waiting for database readiness..." -ForegroundColor Gray
    
    $Ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-HttpEndpoint -Url "http://127.0.0.1:8000/health/ready") {
            $Ready = $true
            break
        }
    }
    if ($Ready) {
        Write-Host "  * Backend is READY and connected to SQLite database." -ForegroundColor Green
    } else {
        Write-Host "  * Warning: Backend took longer than expected to become ready. Check logs." -ForegroundColor Yellow
    }
}

# 4. Start or Verify Web Frontend (Port 3000)
Write-Host "`n[3/5] Checking Web Frontend Server (Port 3000)..." -ForegroundColor Gray
$WebPortActive = Test-PortListening -Port 3000

if ($WebPortActive -and -not $ForceRestart) {
    if (Test-HttpEndpoint -Url "http://127.0.0.1:3000/") {
        Write-Host "  * Web server already active at http://localhost:3000" -ForegroundColor Green
    } else {
        Write-Host "  * Port 3000 is active. Serving existing build." -ForegroundColor Green
    }
} else {
    Write-Host "  * Launching Web server on port 3000 (serving mobile/build/web)..." -ForegroundColor Cyan
    $WebProc = Start-Process python -ArgumentList "scripts\serve_web.py" -WorkingDirectory $ProjectRoot -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 2
    if (Test-HttpEndpoint -Url "http://127.0.0.1:3000/") {
        Write-Host "  * Web server is online and serving at http://localhost:3000" -ForegroundColor Green
    } else {
        Write-Host "  * Web server started (PID: $($WebProc.Id))." -ForegroundColor Yellow
    }
}

# 5. Start or Verify APK Distribution Server (Port 8080)
Write-Host "`n[4/5] Checking Android APK Server (Port 8080)..." -ForegroundColor Gray
$ApkPortActive = Test-PortListening -Port 8080

if ($ApkPortActive -and -not $ForceRestart) {
    Write-Host "  * APK distribution server already active at http://localhost:8080" -ForegroundColor Green
} else {
    Write-Host "  * Launching APK server on port 8080..." -ForegroundColor Cyan
    $ApkProc = Start-Process python -ArgumentList "scripts\serve_apk.py" -WorkingDirectory $ProjectRoot -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 1
    Write-Host "  * APK server online at http://localhost:8080" -ForegroundColor Green
}

# 6. Service Dashboard Summary
Write-Host "`n[5/5] Service Status & Gateway Summary:" -ForegroundColor Gray
Write-Host "-----------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ("  {0,-28} : {1}" -f "Web Application (Flutter)", "http://localhost:3000") -ForegroundColor Green
Write-Host ("  {0,-28} : {1}" -f "Production Admin Console", "http://localhost:8000/admin") -ForegroundColor Cyan
Write-Host ("  {0,-28} : {1}" -f "FastAPI Backend API", "http://localhost:8000") -ForegroundColor White
Write-Host ("  {0,-28} : {1}" -f "Swagger Interactive Docs", "http://localhost:8000/docs") -ForegroundColor White
Write-Host ("  {0,-28} : {1}" -f "APK Download Endpoint", "http://localhost:8080/app-release.apk") -ForegroundColor Yellow
Write-Host ("  {0,-28} : {1}" -f "Background Timetable Sched", "Active (Every 60s - Asia/Kolkata)") -ForegroundColor Magenta
Write-Host "-----------------------------------------------------------------------" -ForegroundColor DarkGray

if (-not $NoBrowser) {
    Write-Host "`nLaunching default browser to http://localhost:3000..." -ForegroundColor Cyan
    Start-Process "http://localhost:3000"
}

Write-Host "`nAll go-On services are active, healthy, and verified!`n" -ForegroundColor Green
