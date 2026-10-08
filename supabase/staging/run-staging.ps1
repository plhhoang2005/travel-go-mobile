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
  [switch]$Bootstrap,

  [Parameter(Mandatory=$false)]
  [switch]$DryRun,

  [Parameter(Mandatory=$false)]
  [scriptblock]$ExecutorMock
)

$ErrorActionPreference = 'Stop'

# Verified Staging Project and Forbidden Primary References
$VERIFIED_STAGING_REF = "bkocylxbuyvdgxccpixx"
$FORBIDDEN_PRIMARY_REF = "oavbymauorhmrjcustzw"

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

# 7. Strict Target Guard: Host must match the verified staging project ref
$normalizedHost = $ConnectionHost.Trim().ToLower()
$hostHasRef = $normalizedHost -match [regex]::Escape($VERIFIED_STAGING_REF.ToLower())
if (!$hostHasRef) {
  throw "TARGET MISMATCH: Connection host '$ConnectionHost' does not match verified staging project ref '$VERIFIED_STAGING_REF'."
}

# 8. Validate SQL File exists
if ([string]::IsNullOrWhiteSpace($SqlFile) -or !(Test-Path -Path $SqlFile)) {
  throw "SqlFile does not exist: '$SqlFile'"
}

# 9. Optional Input SQL File Integrity Check
if (![string]::IsNullOrWhiteSpace($ExpectedSqlHash)) {
  $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $SqlFile).Path)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  $computedHex = [System.BitConverter]::ToString($sha256.ComputeHash($fileBytes)).Replace('-', '').ToUpper()

  if ($computedHex -ne $ExpectedSqlHash.Trim().ToUpper()) {
    throw "Input SQL file hash mismatch! Expected: '$ExpectedSqlHash', Actual: '$computedHex' on '$SqlFile'."
  }
}

# 10. Baseline Hash Validation: Corrective writes require audited baseline hash
if (!$Bootstrap) {
  if ([string]::IsNullOrWhiteSpace($ExpectedBaselineHash)) {
    throw "CORRECTIVE RUN REJECTED: Corrective writes and harness runs require -ExpectedBaselineHash to verify against reviewed baseline artifact."
  }

  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $baselineFile = Join-Path $scriptDir "baseline.sql"
  if (!(Test-Path $baselineFile)) {
    $baselineFile = Join-Path (Split-Path -Parent (Resolve-Path $SqlFile).Path) "baseline.sql"
  }

  if (Test-Path $baselineFile) {
    $rawContent = [System.IO.File]::ReadAllText((Resolve-Path $baselineFile).Path, [System.Text.Encoding]::UTF8)
    $lfContent = $rawContent.Replace("`r`n", "`n")
    $bBytes = [System.Text.Encoding]::UTF8.GetBytes($lfContent)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $computedBaselineHex = [System.BitConverter]::ToString($sha256.ComputeHash($bBytes)).Replace('-', '').ToUpper()

    if ($computedBaselineHex -ne $ExpectedBaselineHash.Trim().ToUpper()) {
      throw "Baseline hash mismatch! Expected: '$ExpectedBaselineHash', Actual: '$computedBaselineHex' on '$baselineFile'."
    }
  } else {
    throw "Baseline file not found at '$baselineFile' to verify -ExpectedBaselineHash."
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
  & $ExecutorMock -Host $ConnectionHost -File $SqlFile
  exit 0
}

# 12. Database Execution via psql
$psqlCmd = Get-Command psql -ErrorAction SilentlyContinue
if (!$psqlCmd) {
  throw "EXECUTION BLOCKER: 'psql' is not installed or not available on PATH. Direct SQL execution requires psql or authorized runner connection."
}

Write-Host "Executing SQL file: $SqlFile against $ConnectionHost..." -ForegroundColor Cyan
& psql -X -v ON_ERROR_STOP=1 -h $ConnectionHost -U postgres -d postgres -f $SqlFile
if ($LASTEXITCODE -ne 0) {
  throw "psql execution failed with exit code $LASTEXITCODE on file $SqlFile"
}

Write-Host "Execution finished successfully." -ForegroundColor Green
exit 0
