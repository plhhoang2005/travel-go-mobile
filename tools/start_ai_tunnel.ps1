# TravelGO AI Public Tunnel Launcher
$cloudflared = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
if (-not (Test-Path $cloudflared)) {
    Write-Error "cloudflared.exe khong tim thay tai $cloudflared"
    pause
    exit 1
}

# Stop old cloudflared instances
Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     TRAVELGO AI - KHOI DONG DUONG HAM PUBLIC CHO CA NHOM " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Dang ket noi voi Cloudflare Edge (http://127.0.0.1:11434)..."

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $cloudflared
$psi.Arguments = "tunnel --url http://127.0.0.1:11434 --http-host-header localhost:11434"
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
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host " [THANH CONG] DUONG LINK HTTPS CHO CA NHOM:" -ForegroundColor Green
    Write-Host " $tunnelUrl" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "1. Da sao chep duong link vao bo nho tam (Clipboard)."
    Write-Host "2. Ban gui link tren cho cac thanh vien trong nhom."
    Write-Host "3. Tren dien thoai (dung 4G hoac Wifi bat ky):"
    Write-Host "   Vao TravelGO -> Quan tri AI -> Dan link nay vao -> Luu."
    Write-Host "`n[Luu y] De nguyen cua so nay chay ngam khi ca nhom dang test." -ForegroundColor DarkGray
    Set-Clipboard $tunnelUrl -ErrorAction SilentlyContinue
    
    # Wait until process exits
    $proc.WaitForExit()
} else {
    Write-Host "Khong the lay link tu Cloudflare Tunnel. Kiem tra ket noi mang." -ForegroundColor Red
    pause
}
