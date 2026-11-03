# TravelGO Live Web API Playground & Gateway Launcher
$ErrorActionPreference = "Stop"

$cloudflared = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
if (-not (Test-Path $cloudflared)) {
    Write-Error "cloudflared.exe không tìm thấy tại $cloudflared"
    pause
    exit 1
}

# Stop old instances of cloudflared
Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  TRAVELGO LIVE WEB API PLAYGROUND & GATEWAY LAUNCHER     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Start Python API Gateway on Port 8080
Write-Host "[1/2] Khoi dong Python API Gateway tren port 8080..." -ForegroundColor Yellow
$gatewayScript = Join-Path $PSScriptRoot "api_gateway.py"
$pythonProc = Start-Process -FilePath "python" -ArgumentList "`"$gatewayScript`"" -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 1

# 2. Start Cloudflare Tunnel for Port 8080
Write-Host "[2/2] Tao duong ham HTTPS Cloudflare toi cong 8080..." -ForegroundColor Yellow

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $cloudflared
$psi.Arguments = "tunnel --url http://127.0.0.1:8080 --http-host-header localhost:8080"
$psi.UseShellExecute = $false
$psi.RedirectStandardError = $true
$psi.RedirectStandardOutput = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
$proc.Start() | Out-Null

$tunnelUrl = $null
$timeoutSeconds = 30
$sw = [System.Diagnostics.Stopwatch]::StartNew()

while ($sw.Elapsed.TotalSeconds -lt $timeoutSeconds -and -not $tunnelUrl) {
    Start-Sleep -Milliseconds 500
    while (-not $proc.StandardError.EndOfStream) {
        $line = $proc.StandardError.ReadLine()
        if ($line -match 'https://[a-zA-Z0-9-]+\.trycloudflare\.com') {
            $tunnelUrl = $Matches[0]
            break
        }
    }
}

if ($tunnelUrl) {
    # Save URL to current_tunnel_url.txt
    $tunnelFile = Join-Path $PSScriptRoot "current_tunnel_url.txt"
    $tunnelUrl | Out-File -FilePath $tunnelFile -Encoding utf8 -NoNewline

    # Copy to clipboard
    try {
        Set-Clipboard -Value $tunnelUrl
    } catch {}

    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host " [THANH CONG] LINK SONG DEMO WEB API TRUC TIEP CHO THAY CO:" -ForegroundColor Green
    Write-Host " 👉 $tunnelUrl" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "1. Da sao chep duong link tren vao Clipboard." -ForegroundColor White
    Write-Host "2. Thay co co the mo link tren bang trinh duyet bat ky (dien thoai / laptop)." -ForegroundColor White
    Write-Host "3. Giao dien Web API Playground cho phep:" -ForegroundColor White
    Write-Host "   - Test API Tao lich trinh ca nhan hoa (POST /plan-trip)" -ForegroundColor Cyan
    Write-Host "   - Test API Chatbot du lich Local AI (POST /chat)" -ForegroundColor Cyan
    Write-Host "   - Test API Danh muc diem den (GET /destinations)" -ForegroundColor Cyan
    Write-Host "   - Test API Danh gia & Phan hoi cong dong (GET & POST /reviews, /reply)" -ForegroundColor Cyan
    Write-Host "   - Test API Xac thuc & Ho so du lich (POST /auth/login, GET /profile)" -ForegroundColor Cyan
    Write-Host "   - Xem payload JSON, ma nguon cURL va ket qua truc quan." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Nhan Ctrl+C de dung server khi ket thuc buoi bao cao.`n" -ForegroundColor Gray

    # Keep script running
    try {
        while ($true) {
            Start-Sleep -Seconds 2
        }
    } finally {
        $proc.Kill()
        $pythonProc.Kill()
    }
} else {
    Write-Host "`n[LOI] Khong the lay duong ham Cloudflare trong 30 giay." -ForegroundColor Red
    $pythonProc.Kill()
}
