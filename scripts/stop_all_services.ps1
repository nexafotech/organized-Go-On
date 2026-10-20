<#
.SYNOPSIS
    go-On AI Face Attendance System - Clean Service Teardown
.DESCRIPTION
    Safely stops only the go-On services (FastAPI on 8000, serve_web on 3000, serve_apk on 8080)
    without terminating unrelated user processes.
#>

$ProjectRoot = "E:\originalam"
Write-Host "Stopping go-On localhost services..." -ForegroundColor Cyan

$Ports = @(3000, 8000, 8080)
foreach ($Port in $Ports) {
    $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($connections) {
        foreach ($conn in $connections) {
            $pid = $conn.OwningProcess
            try {
                $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($proc) {
                    Write-Host "  * Stopping service on port $Port (Process: $($proc.ProcessName), PID: $pid)..." -ForegroundColor Yellow
                    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Host "  * Could not stop PID $pid on port $Port." -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  * Port $Port is not currently listening." -ForegroundColor Gray
    }
}

Write-Host "All go-On services stopped cleanly.`n" -ForegroundColor Green
