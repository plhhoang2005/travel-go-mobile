# ==============================================================================
# Offline Unit Tests for run-staging.ps1 Target Guard
# ==============================================================================
param(
  [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RunnerScript = Join-Path $ScriptDir "run-staging.ps1"
$DummySql = Join-Path $ScriptDir "test-dummy.sql"

Set-Content -Path $DummySql -Value "SELECT 1;"

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
  & $RunnerScript -ProjectRef "travelgo-staging-ref" -ConnectionHost "db.oavbymauorhmrjcustzw.supabase.co" -SqlFile $DummySql -DryRun
} "SECURITY VIOLATION.*primary host"

# Test 3: Reject empty project reference
Assert-Throws "Reject empty project reference" {
  & $RunnerScript -ProjectRef "" -ConnectionHost "db.staging.supabase.co" -SqlFile $DummySql -DryRun
} "ProjectRef cannot be empty"

# Test 4: Reject missing SQL file
Assert-Throws "Reject missing SQL file" {
  & $RunnerScript -ProjectRef "valid-staging-ref" -ConnectionHost "db.valid-staging-ref.supabase.co" -SqlFile "non_existent_file.sql" -DryRun
} "SqlFile does not exist"

# Test 5: Reject mismatched baseline hash
Assert-Throws "Reject mismatched baseline hash" {
  & $RunnerScript -ProjectRef "valid-staging-ref" -ConnectionHost "db.valid-staging-ref.supabase.co" -SqlFile $DummySql -ExpectedBaselineHash "0000000000000000000000000000000000000000000000000000000000000000" -DryRun
} "Baseline hash mismatch"

# Test 6: Permit valid staging parameters in DryRun mode
Assert-Succeeds "Permit valid staging parameters in DryRun mode" {
  & $RunnerScript -ProjectRef "valid-staging-ref" -ConnectionHost "db.valid-staging-ref.supabase.co" -SqlFile $DummySql -DryRun
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
