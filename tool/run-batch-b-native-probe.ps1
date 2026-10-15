param(
    [string] $Serial = 'emulator-5554',
    [string] $AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    [string] $FlutterPath = 'D:\flutter\flutter\bin\flutter.bat'
)
$ErrorActionPreference = 'Stop'
if ($Serial -notmatch '^emulator-\d+$') { throw 'Probe accepts an emulator only.' }
$repoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$targetPath = Join-Path $repoPath 'test\native\batch_b_probe.dart'
if (-not (Test-Path -LiteralPath $targetPath)) { throw 'Native probe source missing.' }
$booted = (& $AdbPath -s $Serial shell getprop sys.boot_completed).Trim()
if ($LASTEXITCODE -ne 0 -or $booted -ne '1') { throw 'Emulator is not booted.' }
Push-Location $repoPath
$probeInstalled = $false
try {
    & $FlutterPath build apk --debug --no-pub --target=test/native/batch_b_probe.dart
    if ($LASTEXITCODE -ne 0) { throw 'Native probe build failed.' }
    $apkPath = Join-Path $repoPath 'build\app\outputs\flutter-apk\app-debug.apk'
    & $AdbPath -s $Serial install -r $apkPath
    if ($LASTEXITCODE -ne 0) { throw 'Native probe install failed.' }
    $probeInstalled = $true
    $packageName = 'com.travelgo.travelgo_mobile'
    foreach ($expected in @('B9_NATIVE_STAGE1_PASS', 'B9_NATIVE_STAGE2_PASS', 'B9_NATIVE_STAGE3_AND_OWNED_CLEANUP_PASS')) {
        & $AdbPath -s $Serial shell am force-stop $packageName
        if ($LASTEXITCODE -ne 0) { throw 'Emulator force-stop failed.' }
        & $AdbPath -s $Serial logcat -c
        if ($LASTEXITCODE -ne 0) { throw 'Emulator log reset failed.' }
        & $AdbPath -s $Serial shell am start -n "$packageName/.MainActivity"
        if ($LASTEXITCODE -ne 0) { throw 'Native probe launch failed.' }
        $deadline = [DateTime]::UtcNow.AddSeconds(45)
        $passed = $false
        while ([DateTime]::UtcNow -lt $deadline) {
            $lines = & $AdbPath -s $Serial logcat -d -s flutter
            if ($LASTEXITCODE -ne 0) { throw 'Native probe logs unavailable.' }
            if ($lines -match 'B9_NATIVE_FAIL') { throw 'Native probe reported FAIL; isolated fixture retained for inspection.' }
            if ($lines -match [regex]::Escape($expected)) {
                Write-Output $expected
                $passed = $true
                break
            }
            Start-Sleep -Seconds 1
        }
        if (-not $passed) { throw "Missing native result: $expected" }
    }
    & $AdbPath -s $Serial shell am force-stop $packageName
    Write-Output 'B9_NATIVE_THREE_LAUNCHES_PASS'
} finally {
    try {
        if ($probeInstalled) {
            # Restore the production entry point, including after probe failure.
            & $FlutterPath build apk --debug --no-pub --target=lib/main.dart
            if ($LASTEXITCODE -ne 0) { throw 'Production app restore build failed.' }
            $productionApk = Join-Path $repoPath 'build\app\outputs\flutter-apk\app-debug.apk'
            & $AdbPath -s $Serial install -r $productionApk
            if ($LASTEXITCODE -ne 0) { throw 'Production app restore install failed.' }
            Write-Output 'B9_PRODUCTION_ENTRYPOINT_RESTORED'
        }
    } finally {
        Pop-Location
    }
}
