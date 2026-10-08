<#
.SYNOPSIS
  Guarded SQL Runner for TravelGO Staging Database
.DESCRIPTION
  Safely executes SQL files against the verified TravelGO staging project.
  Strictly allows ONLY the verified staging project 'bkocylxbuyvdgxccpixx' and
  validated connection parameters.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$false)]
  [string]$ProjectRef,

  [Parameter(Mandatory=$false)]
  [string]$ConnectionHost,

  [Parameter(Mandatory=$false)]
  [string]$SqlFile,

  [Parameter(Mandatory=$false)]
  [string]$ExpectedBaselineHash,

  [Parameter(Mandatory=$false)]
  [string]$ExpectedSqlHash,

  [Parameter(Mandatory=$false)]
  [string]$ExpectedHelperHash,

  [Parameter(Mandatory=$false)]
  [switch]$Bootstrap,

  [Parameter(Mandatory=$false)]
  [switch]$DryRun,

  [Parameter(Mandatory=$false)]
  [scriptblock]$ExecutorMock
)

$ErrorActionPreference = 'Stop'

# Verified Staging Project and Forbidden Primary References
$VERIFIED_STAGING_REF = "bkocylxbuyvdgxccpixx"
$VERIFIED_DIRECT_ENDPOINT = "db.bkocylxbuyvdgxccpixx.supabase.co"
$FORBIDDEN_PRIMARY_REF = "oavbymauorhmrjcustzw"

function Get-NormalizedSha256([string]$filePath) {
  $rawContent = [System.IO.File]::ReadAllText((Resolve-Path $filePath).Path, [System.Text.Encoding]::UTF8)
  $lfContent = $rawContent.Replace("`r`n", "`n").Replace("`r", "`n")
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($lfContent)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  return [System.BitConverter]::ToString($sha256.ComputeHash($bytes)).Replace('-', '').ToUpper()
}

# 1. Validate ProjectRef presence
if ([string]::IsNullOrWhiteSpace($ProjectRef)) {
  throw "ProjectRef cannot be empty. Please provide the verified staging project reference."
}

# 2. Strict Target Guard: Block primary project reference
if ($ProjectRef.Trim().ToLower() -eq $FORBIDDEN_PRIMARY_REF.ToLower()) {
  throw "SECURITY VIOLATION: Target project reference is the primary production project '$FORBIDDEN_PRIMARY_REF'! Writes are strictly forbidden."
}

# 3. Strict Allowlist Guard: Accept ONLY the verified staging reference
if ($ProjectRef.Trim().ToLower() -ne $VERIFIED_STAGING_REF.ToLower()) {
  throw "TARGET REJECTED: ProjectRef '$ProjectRef' is not the verified staging project ('$VERIFIED_STAGING_REF'). Arbitrary or unverified projects are rejected."
}

# 4. Validate ConnectionHost presence
if ([string]::IsNullOrWhiteSpace($ConnectionHost)) {
  throw "ConnectionHost cannot be empty. Target connection parameters must be explicitly provided."
}

# 5. Strict Target Guard: Block primary project host
if ($ConnectionHost.ToLower() -match $FORBIDDEN_PRIMARY_REF.ToLower()) {
  throw "SECURITY VIOLATION: Target connection host '$ConnectionHost' points to the primary host ($FORBIDDEN_PRIMARY_REF)! Execution aborted."
}

# 6. Strict Target Guard: Reject localhost / loopback
if ($ConnectionHost.Trim().ToLower() -match '^(localhost|127\.0\.0\.1|0\.0\.0\.0)$') {
  throw "SECURITY VIOLATION: Localhost is not the verified cloud staging host! Target rejected."
}

# 7. Strict Target Guard: Exact match on verified staging endpoint (No substring matching)
$normalizedHost = $ConnectionHost.Trim().ToLower()
if ($normalizedHost -ne $VERIFIED_DIRECT_ENDPOINT.ToLower()) {
  throw "TARGET MISMATCH: Connection host '$ConnectionHost' does not match verified staging endpoint '$VERIFIED_DIRECT_ENDPOINT'. Arbitrary, prefixed, or lookalike hosts are strictly rejected."
}

# 8. Validate SQL File exists
if ([string]::IsNullOrWhiteSpace($SqlFile) -or !(Test-Path -Path $SqlFile)) {
  throw "SqlFile does not exist: '$SqlFile'"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$canonicalBaselinePath = (Resolve-Path (Join-Path $scriptDir "baseline.sql")).Path
$resolvedSqlPath = (Resolve-Path $SqlFile).Path

# 9. Bootstrap vs Corrective Mode & Baseline Integrity Enforcement
if ($Bootstrap) {
  # Strict canonical path binding: Must match the runner's canonical baseline artifact exactly
  if ($resolvedSqlPath -ne $canonicalBaselinePath) {
    throw "BOOTSTRAP REJECTED: Bootstrap mode is strictly restricted to the canonical baseline artifact at '$canonicalBaselinePath'. Unrelated file '$resolvedSqlPath' (even if named baseline.sql) is strictly rejected."
  }

  # Reviewed baseline integrity is MANDATORY in Bootstrap mode
  if ([string]::IsNullOrWhiteSpace($ExpectedBaselineHash)) {
    throw "BOOTSTRAP REJECTED: Bootstrap mode requires reviewed -ExpectedBaselineHash to verify canonical baseline integrity before execution."
  }

  $computedBaselineHex = Get-NormalizedSha256 -filePath $canonicalBaselinePath
  if ($computedBaselineHex -ne $ExpectedBaselineHash.Trim().ToUpper()) {
    throw "Bootstrap baseline hash mismatch! Expected: '$ExpectedBaselineHash', Actual: '$computedBaselineHex' on '$canonicalBaselinePath'."
  }
} else {
  # Corrective writes, migrations, and harnesses REQUIRE reviewed -ExpectedBaselineHash
  if ([string]::IsNullOrWhiteSpace($ExpectedBaselineHash)) {
    throw "CORRECTIVE RUN REJECTED: Corrective writes and harness runs require -ExpectedBaselineHash to verify against reviewed baseline artifact."
  }

  if (Test-Path $canonicalBaselinePath) {
    $computedBaselineHex = Get-NormalizedSha256 -filePath $canonicalBaselinePath
    if ($computedBaselineHex -ne $ExpectedBaselineHash.Trim().ToUpper()) {
      throw "Baseline hash mismatch! Expected: '$ExpectedBaselineHash', Actual: '$computedBaselineHex' on '$canonicalBaselinePath'."
    }
  } else {
    throw "Baseline file not found at '$canonicalBaselinePath' to verify -ExpectedBaselineHash."
  }
}

# 10. Consistent Input SQL File Integrity Check (LF-normalized SHA-256)
if (!$Bootstrap) {
  if ([string]::IsNullOrWhiteSpace($ExpectedSqlHash)) {
    throw "CORRECTIVE RUN REJECTED: Corrective mode requires -ExpectedSqlHash to verify input artifact integrity before execution."
  }
}

if (![string]::IsNullOrWhiteSpace($ExpectedSqlHash)) {
  $computedHex = Get-NormalizedSha256 -filePath $resolvedSqlPath
  if ($computedHex -ne $ExpectedSqlHash.Trim().ToUpper()) {
    throw "Input SQL file hash mismatch! Expected: '$ExpectedSqlHash', Actual: '$computedHex' on '$SqlFile'."
  }
}

# 11. Modular Dependency & Manifest Protection Guard
$rawSqlContent = [System.IO.File]::ReadAllText($resolvedSqlPath, [System.Text.Encoding]::UTF8)
$isModularHarness = ($rawSqlContent -match '(?m)^\s*\\ir\s+.*profile_privacy_test_helpers\.sql')
if ($isModularHarness) {
  $repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
  $candidatePaths = @(
    (Join-Path (Split-Path -Parent $resolvedSqlPath) "profile_privacy_test_helpers.sql"),
    (Join-Path $repoRoot "supabase\tests\profile_privacy_test_helpers.sql")
  )
  $helperPath = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

  if (!$helperPath -or !(Test-Path $helperPath)) {
    throw "DEPENDENCY INTEGRITY FAILURE: Modular harness '$SqlFile' depends on 'profile_privacy_test_helpers.sql', but the helper file does not exist on disk. Target rejected before connection."
  }

  if ([string]::IsNullOrWhiteSpace($ExpectedHelperHash)) {
    throw "DEPENDENCY INTEGRITY FAILURE: Modular harness '$SqlFile' depends on 'profile_privacy_test_helpers.sql'. -ExpectedHelperHash is mandatory to verify dependency integrity before execution."
  }

  $computedHelperHex = Get-NormalizedSha256 -filePath $helperPath
  if ($computedHelperHex -ne $ExpectedHelperHash.Trim().ToUpper()) {
    throw "DEPENDENCY HASH MISMATCH: Dependency 'profile_privacy_test_helpers.sql' hash mismatch! Expected: '$ExpectedHelperHash', Actual: '$computedHelperHex'. Target rejected before connection."
  }
}

Write-Host "Target Guard Check Passed: Target '$ProjectRef' on '$ConnectionHost' is verified staging." -ForegroundColor Green

if ($DryRun) {
  Write-Host "[DryRun] Validation complete. No SQL executed." -ForegroundColor Cyan
  exit 0
}

# 11. Mock Executor Support (for Unit Testing)
if ($ExecutorMock) {
  Write-Host "Invoking ExecutorMock..." -ForegroundColor Cyan
  & $ExecutorMock -TargetHost $ConnectionHost -TargetFile $SqlFile
  exit 0
}

# 12. Database Execution via host psql
$psqlExe = "psql"
$psqlCmd = Get-Command psql -ErrorAction SilentlyContinue
if (!$psqlCmd) {
  $hostPsql = Get-ChildItem -Path "C:\Program Files\PostgreSQL\*\bin\psql.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
  if ($hostPsql) {
    $psqlExe = $hostPsql.FullName
    $psqlCmd = $true
  }
}
if (!$psqlCmd) {
  throw "EXECUTION BLOCKER: 'psql' is not installed or not available on PATH. Direct SQL execution requires psql on host machine or Supabase Dashboard SQL Editor."
}

Write-Host "Executing SQL file: $SqlFile against $ConnectionHost..." -ForegroundColor Cyan
& $psqlExe -X -v ON_ERROR_STOP=1 -h $ConnectionHost -U postgres -d postgres -f $SqlFile
if ($LASTEXITCODE -ne 0) {
  throw "psql execution failed with exit code $LASTEXITCODE on file $SqlFile"
}

Write-Host "Execution finished successfully." -ForegroundColor Green
exit 0
