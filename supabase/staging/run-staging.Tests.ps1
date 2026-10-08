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
$MigrationSql = Join-Path (Join-Path (Split-Path -Parent $ScriptDir) "migrations") "202610080001_profile_privacy.sql"

Set-Content -Path $DummySql -Value "SELECT 1;"

# Compute LF-normalized hash of baseline.sql for test expectations
$baselineContent = [System.IO.File]::ReadAllText((Resolve-Path $BaselineSql).Path, [System.Text.Encoding]::UTF8)
$lfBaselineContent = $baselineContent.Replace("`r`n", "`n")
$bBytes = [System.Text.Encoding]::UTF8.GetBytes($lfBaselineContent)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$VALID_BASELINE_HASH = [System.BitConverter]::ToString($sha256.ComputeHash($bBytes)).Replace('-', '').ToUpper()

$TestsDir = Join-Path (Split-Path -Parent $ScriptDir) "tests"
$MainHarnessSql = Join-Path $TestsDir "profile_privacy.sql"
$HelperSql = Join-Path $TestsDir "profile_privacy_test_helpers.sql"
$BundlesDir = Join-Path $ScriptDir "bundles"
$MainBundleSql = Join-Path $BundlesDir "profile_privacy.bundle.sql"

if (Test-Path $HelperSql) {
  $helperRaw = [System.IO.File]::ReadAllText((Resolve-Path $HelperSql).Path, [System.Text.Encoding]::UTF8)
  $lfHelper = $helperRaw.Replace("`r`n", "`n")
  $hBytes = [System.Text.Encoding]::UTF8.GetBytes($lfHelper)
  $VALID_HELPER_HASH = [System.BitConverter]::ToString($sha256.ComputeHash($hBytes)).Replace('-', '').ToUpper()
}

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
} "TARGET MISMATCH.*does not match verified staging endpoint"

# Test 6: Reject lookalike domain containing verified ref
Assert-Throws "Reject lookalike domain containing verified ref" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost "db.bkocylxbuyvdgxccpixx.supabase.co.example.invalid" -SqlFile $DummySql -DryRun
} "TARGET MISMATCH.*does not match verified staging endpoint"

# Test 7: Reject prefixed host containing verified ref
Assert-Throws "Reject prefixed host containing verified ref" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost "unverified-bkocylxbuyvdgxccpixx.example.invalid" -SqlFile $DummySql -DryRun
} "TARGET MISMATCH.*does not match verified staging endpoint"

# Test 8: Reject absent connection host
Assert-Throws "Reject absent connection host" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost "" -SqlFile $DummySql -DryRun
} "ConnectionHost cannot be empty"

# Test 9: Reject localhost connection host
Assert-Throws "Reject localhost connection host" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost "localhost" -SqlFile $DummySql -DryRun
} "SECURITY VIOLATION: Localhost is not the verified cloud staging host"

# Test 10: Reject missing SQL file
Assert-Throws "Reject missing SQL file" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile "non_existent_file.sql" -DryRun
} "SqlFile does not exist"

# Test 11a: Reject bootstrap mode when file is not canonical baseline.sql
Assert-Throws "Reject bootstrap mode on non-baseline SQL file" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $DummySql -Bootstrap -ExpectedBaselineHash $VALID_BASELINE_HASH -DryRun
} "BOOTSTRAP REJECTED.*strictly restricted to the canonical baseline artifact"

# Test 11b: Reject bootstrap mode when file is an unrelated baseline.sql from external path
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("travelgo_test_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$externalBaseline = Join-Path $tempDir "baseline.sql"
Set-Content -Path $externalBaseline -Value "SELECT 1;"

Assert-Throws "Reject bootstrap mode on unrelated external baseline.sql" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $externalBaseline -Bootstrap -ExpectedBaselineHash $VALID_BASELINE_HASH -DryRun
} "BOOTSTRAP REJECTED.*strictly restricted to the canonical baseline artifact"
Remove-Item -Path $tempDir -Recurse -Force

# Test 11c: Reject bootstrap mode when -ExpectedBaselineHash is missing
Assert-Throws "Reject bootstrap mode without ExpectedBaselineHash" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $BaselineSql -Bootstrap -DryRun
} "BOOTSTRAP REJECTED.*requires reviewed -ExpectedBaselineHash"

# Test 11d: Reject bootstrap mode when -ExpectedBaselineHash is mismatched
Assert-Throws "Reject bootstrap mode with mismatched ExpectedBaselineHash" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $BaselineSql -Bootstrap -ExpectedBaselineHash "0000000000000000000000000000000000000000000000000000000000000000" -DryRun
} "Bootstrap baseline hash mismatch"

# Test 12: Reject bootstrap mode when file is migration file
if (Test-Path $MigrationSql) {
  Assert-Throws "Reject bootstrap mode on migration file" {
    & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $MigrationSql -Bootstrap -ExpectedBaselineHash $VALID_BASELINE_HASH -DryRun
  } "BOOTSTRAP REJECTED.*strictly restricted to the canonical baseline artifact"
}

# Test 13: Reject corrective run without ExpectedBaselineHash
Assert-Throws "Reject corrective run without ExpectedBaselineHash" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $DummySql -DryRun
} "CORRECTIVE RUN REJECTED.*require -ExpectedBaselineHash"

# Test 14: Reject corrective run with mismatched ExpectedBaselineHash
Assert-Throws "Reject corrective run with mismatched ExpectedBaselineHash" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $DummySql -ExpectedBaselineHash "0000000000000000000000000000000000000000000000000000000000000000" -DryRun
} "Baseline hash mismatch"

# Test 15: Permit canonical baseline bootstrap in DryRun mode with valid hash
Assert-Succeeds "Permit canonical baseline bootstrap in DryRun mode" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $BaselineSql -Bootstrap -ExpectedBaselineHash $VALID_BASELINE_HASH -DryRun
}

# Test 16: Permit valid corrective staging parameters in DryRun mode
Assert-Succeeds "Permit valid corrective staging parameters in DryRun mode" {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $DummySql -ExpectedBaselineHash $VALID_BASELINE_HASH -DryRun
}

# Test 17: Assert executor mock is NOT called (call count = 0) when guard rejects
$global:executorCalls = 0
$countingMock = {
  param($TargetHost, $TargetFile)
  $global:executorCalls++
}

$rejectedExceptionCaught = $false
try {
  & $RunnerScript -ProjectRef "oavbymauorhmrjcustzw" -ConnectionHost "db.oavbymauorhmrjcustzw.supabase.co" -SqlFile $DummySql -ExecutorMock $countingMock
} catch {
  $rejectedExceptionCaught = $true
}

if ($rejectedExceptionCaught -and ($global:executorCalls -eq 0)) {
  Write-Host "[PASS] Assert executor mock is NOT called on rejected target (calls = 0)" -ForegroundColor Green
  $script:testsPassed++
} else {
  Write-Host "[FAIL] Assert executor mock: expected exception and calls=0, got exception=$rejectedExceptionCaught, calls=$($global:executorCalls)" -ForegroundColor Red
  $script:testsFailed++
}

# Test 18: Assert executor mock IS called exactly ONCE (call count = 1) when guard permits
$global:executorCalls = 0
$permittedSuccess = $false
try {
  & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $BaselineSql -Bootstrap -ExpectedBaselineHash $VALID_BASELINE_HASH -ExecutorMock $countingMock
  $permittedSuccess = $true
} catch {
  Write-Host "Unexpected exception during permitted call: $_" -ForegroundColor Red
}

if ($permittedSuccess -and ($global:executorCalls -eq 1)) {
  Write-Host "[PASS] Assert executor mock is called exactly once on permitted target (calls = 1)" -ForegroundColor Green
  $script:testsPassed++
} else {
  Write-Host "[FAIL] Assert executor mock: expected success and calls=1, got success=$permittedSuccess, calls=$($global:executorCalls)" -ForegroundColor Red
  $script:testsFailed++
}

# Test 19: Reject test harness when -ExpectedHelperHash is missing
if (Test-Path $MainHarnessSql) {
  Assert-Throws "Reject test harness without ExpectedHelperHash" {
    & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $MainHarnessSql -ExpectedBaselineHash $VALID_BASELINE_HASH -DryRun
  } "DEPENDENCY INTEGRITY FAILURE.*-ExpectedHelperHash is mandatory"
}

# Test 20: Reject test harness when -ExpectedHelperHash mismatches
if (Test-Path $MainHarnessSql) {
  Assert-Throws "Reject test harness with mismatched ExpectedHelperHash" {
    & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $MainHarnessSql -ExpectedBaselineHash $VALID_BASELINE_HASH -ExpectedHelperHash "0000000000000000000000000000000000000000000000000000000000000000" -DryRun
  } "DEPENDENCY HASH MISMATCH"
}

# Test 21: Permit test harness in DryRun mode when -ExpectedHelperHash matches
if (Test-Path $MainHarnessSql) {
  Assert-Succeeds "Permit test harness when ExpectedHelperHash matches" {
    & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $MainHarnessSql -ExpectedBaselineHash $VALID_BASELINE_HASH -ExpectedHelperHash $VALID_HELPER_HASH -DryRun
  }
}

# Test 22: Probe: Modifying helper file while keeping harness parameters unchanged MUST be rejected before connection/executor (calls = 0)
if (Test-Path $MainHarnessSql) {
  $global:executorCalls = 0
  $helperProbeExceptionCaught = $false
  try {
    & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $MainHarnessSql -ExpectedBaselineHash $VALID_BASELINE_HASH -ExpectedHelperHash "MODIFIED00000000000000000000000000000000000000000000000000000000" -ExecutorMock $countingMock
  } catch {
    if ($_.Exception.Message -match "DEPENDENCY HASH MISMATCH") {
      $helperProbeExceptionCaught = $true
    }
  }

  if ($helperProbeExceptionCaught -and ($global:executorCalls -eq 0)) {
    Write-Host "[PASS] Probe: Modified helper rejected before executor call (calls = 0)" -ForegroundColor Green
    $script:testsPassed++
  } else {
    Write-Host "[FAIL] Probe: Modified helper expected rejection and calls=0, got caught=$helperProbeExceptionCaught, calls=$($global:executorCalls)" -ForegroundColor Red
    $script:testsFailed++
  }
}

# Test 23: Permit pure-SQL bundle execution with ExpectedSqlHash
if (Test-Path $MainBundleSql) {
  $bundleRaw = [System.IO.File]::ReadAllText((Resolve-Path $MainBundleSql).Path, [System.Text.Encoding]::UTF8)
  $lfBundle = $bundleRaw.Replace("`r`n", "`n")
  $bundleBytes = [System.Text.Encoding]::UTF8.GetBytes($lfBundle)
  $VALID_BUNDLE_HASH = [System.BitConverter]::ToString($sha256.ComputeHash($bundleBytes)).Replace('-', '').ToUpper()

  Assert-Succeeds "Permit pure-SQL bundle in DryRun mode with verified hash" {
    & $RunnerScript -ProjectRef $VERIFIED_REF -ConnectionHost $VALID_HOST -SqlFile $MainBundleSql -ExpectedBaselineHash $VALID_BASELINE_HASH -ExpectedSqlHash $VALID_BUNDLE_HASH -ExpectedHelperHash $VALID_HELPER_HASH -DryRun
  }
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
