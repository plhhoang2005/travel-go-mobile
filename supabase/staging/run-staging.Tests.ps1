# ==============================================================================
# Comprehensive Offline Unit Tests for run-staging.ps1 Target Guard
# ==============================================================================
param(
  [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RunnerScript = Join-Path $ScriptDir "run-staging.ps1"
$DummySql = Join-Path $ScriptDir "test-dummy.sql"
$BaselineSql = Join-Path $ScriptDir "baseline.sql"
$MarkerFile = Join-Path $ScriptDir "mock-marker.tmp"

Set-Content -Path $DummySql -Value "SELECT 1;"

# Compute LF-normalized hash of baseline.sql for test expectations
$baselineContent = [System.IO.File]::ReadAllText((Resolve-Path $BaselineSql).Path, [System.Text.Encoding]::UTF8)
$lfBaselineContent = $baselineContent.Replace("`r`n", "`n")
$bBytes = [System.Text.Encoding]::UTF8.GetBytes($lfBaselineContent)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$VALID_BASELINE_HASH = [System.BitConverter]::ToString($sha256.ComputeHash($bBytes)).Replace('-', '').ToUpper()

$VERIFIED_REF = "bkocylxbuyvdgxccpixx"
$VALID_HOST = "db.bkocylxbuyvdgxccpixx.supabase.co"

$testsPassed = 0
$testsFailed = 0

function Assert-Throws {
  param(
    [string]$TestName,
    [scriptblock]$Block,
    [string]$ExpectedPattern
  )
  try {
    & $Block
    Write-Host "[FAIL] $($TestName): Expected exception matching '$ExpectedPattern', but no exception was thrown." -ForegroundColor Red
    $script:testsFailed++
  } catch {
    $msg = $_.Exception.Message
    if ($msg -match $ExpectedPattern) {
      Write-Host "[PASS] $($TestName)" -ForegroundColor Green
      $script:testsPassed++
    } else {
      Write-Host "[FAIL] $($TestName): Exception message '$msg' did not match expected '$ExpectedPattern'." -ForegroundColor Red
      $script:testsFailed++
    }
  }
}

function Assert-Succeeds {
  param(
    [string]$TestName,
    [scriptblock]$Block
  )
  try {
    & $Block
    Write-Host "[PASS] $($TestName)" -ForegroundColor Green
    $script:testsPassed++
  } catch {
    Write-Host "[FAIL] $($TestName): Unexpected exception '$($_.Exception.Message)'" -ForegroundColor Red
    $script:testsFailed++
  }
}

Write-Host "Running run-staging.ps1 Target Guard Unit Tests..." -ForegroundColor Cyan

# Test 1: Reject primary project reference
Assert-Throws "Reject primary project reference" {
  & $RunnerScript -ProjectRef "oavbymauorhmrjcustzw" -ConnectionHost "db.oavbymauorhmrjcustzw.supabase.co" -SqlFile $DummySql -DryRun
} "SECURITY VIOLATION.*oavbymauorhmrjcustzw"

# Test 2: Reject connection host referencing primary project
Assert-Throws "Reject connection host referencing primary project" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost "db.oavbymauorhmrjcustzw.supabase.co" -SqlFile $DummySql -DryRun
} "SECURITY VIOLATION.*primary host"

# Test 3: Reject empty project reference
Assert-Throws "Reject empty project reference" {
  & $RunnerScript -ProjectRef "" -ConnectionHost $VALID_HOST -SqlFile $DummySql -DryRun
} "ProjectRef cannot be empty"

# Test 4: Reject unverified arbitrary project reference
Assert-Throws "Reject unverified arbitrary project reference" {
  & $RunnerScript -ProjectRef "unverified-project" -ConnectionHost "db.unverified-project.supabase.co" -SqlFile $DummySql -DryRun
} "TARGET REJECTED.*not the verified staging project"

# Test 5: Reject staging ref paired with unrelated host
Assert-Throws "Reject staging ref paired with unrelated host" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost "db.unrelated.supabase.co" -SqlFile $DummySql -DryRun
} "TARGET MISMATCH.*does not match verified staging project ref"

# Test 6: Reject absent connection host
Assert-Throws "Reject absent connection host" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost "" -SqlFile $DummySql -DryRun
} "ConnectionHost cannot be empty"

# Test 7: Reject localhost connection host
Assert-Throws "Reject localhost connection host" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost "localhost" -SqlFile $DummySql -DryRun
} "SECURITY VIOLATION: Localhost is not the verified cloud staging host"

# Test 8: Reject missing SQL file
Assert-Throws "Reject missing SQL file" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile "non_existent_file.sql" -DryRun
} "SqlFile does not exist"

# Test 9: Reject corrective run without ExpectedBaselineHash
Assert-Throws "Reject corrective run without ExpectedBaselineHash" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $DummySql -DryRun
} "CORRECTIVE RUN REJECTED.*require -ExpectedBaselineHash"

# Test 10: Reject corrective run with mismatched ExpectedBaselineHash
Assert-Throws "Reject corrective run with mismatched ExpectedBaselineHash" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $DummySql -ExpectedBaselineHash "0000000000000000000000000000000000000000000000000000000000000000" -DryRun
} "Baseline hash mismatch"

# Test 11: Permit bootstrap mode with -Bootstrap in DryRun mode
Assert-Succeeds "Permit bootstrap mode with -Bootstrap in DryRun mode" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $DummySql -Bootstrap -DryRun
}

# Test 12: Permit valid corrective staging parameters in DryRun mode
Assert-Succeeds "Permit valid corrective staging parameters in DryRun mode" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $DummySql -ExpectedBaselineHash $VALID_BASELINE_HASH -DryRun
}

# Test 13: Assert executor mock is NOT called when guard rejects
if (Test-Path $MarkerFile) { Remove-Item $MarkerFile -Force }
$rejectedMock = [scriptblock]::Create("Set-Content -Path '$MarkerFile' -Value 'CALLED'")
try {
  & $RunnerScript -ProjectRef "oavbymauorhmrjcustzw" -ConnectionHost "db.oavbymauorhmrjcustzw.supabase.co" -SqlFile $DummySql -ExecutorMock $rejectedMock
} catch {}
if (!(Test-Path $MarkerFile)) {
  Write-Host "[PASS] Assert executor mock is NOT called on rejected target" -ForegroundColor Green
  $script:testsPassed++
} else {
  Write-Host "[FAIL] Assert executor mock was unexpectedly called on rejected target" -ForegroundColor Red
  $script:testsFailed++
  Remove-Item $MarkerFile -Force
}

# Test 14: Assert executor mock IS called exactly ONCE when guard permits
if (Test-Path $MarkerFile) { Remove-Item $MarkerFile -Force }
$permittedMock = [scriptblock]::Create("Set-Content -Path '$MarkerFile' -Value 'CALLED'")
try {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $DummySql -Bootstrap -ExecutorMock $permittedMock
} catch {}
if (Test-Path $MarkerFile) {
  Write-Host "[PASS] Assert executor mock is called on permitted target" -ForegroundColor Green
  $script:testsPassed++
  Remove-Item $MarkerFile -Force
} else {
  Write-Host "[FAIL] Assert executor mock was NOT called on permitted target" -ForegroundColor Red
  $script:testsFailed++
}

# Cleanup dummy file
if (Test-Path $DummySql) {
  Remove-Item $DummySql -Force
}

Write-Host "`nTest Summary: $testsPassed Passed, $testsFailed Failed" -ForegroundColor Cyan
if ($testsFailed -gt 0) {
  exit 1
}
exit 0
