<#
.SYNOPSIS
  Guarded SQL Runner for TravelGO Staging Database
.DESCRIPTION
  Safely executes SQL files against the verified TravelGO staging project.
  Strictly guards against accidental execution against the primary project 'oavbymauorhmrjcustzw'.
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
  [switch]$Bootstrap,

  [Parameter(Mandatory=$false)]
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Known Primary Project Reference (NEVER ALLOW MUTATIONS OR RUNS AGAINST THIS TARGET)
$FORBIDDEN_PRIMARY_REF = "oavbymauorhmrjcustzw"

# 1. Validate ProjectRef presence
if ([string]::IsNullOrWhiteSpace($ProjectRef)) {
  throw "ProjectRef cannot be empty. Please provide the verified staging project reference."
}

# 2. Strict Target Guard: Block primary project reference
if ($ProjectRef.Trim().ToLower() -eq $FORBIDDEN_PRIMARY_REF.ToLower()) {
  throw "SECURITY VIOLATION: Target project reference is the primary production project 'oavbymauorhmrjcustzw'! Writes are strictly forbidden."
}

# 3. Strict Target Guard: Block primary project host
if (![string]::IsNullOrWhiteSpace($ConnectionHost) -and $ConnectionHost.ToLower() -match $FORBIDDEN_PRIMARY_REF.ToLower()) {
  throw "SECURITY VIOLATION: Target connection host '$ConnectionHost' points to the primary host ($FORBIDDEN_PRIMARY_REF)! Execution aborted."
}

# 4. Validate SQL File exists
if ([string]::IsNullOrWhiteSpace($SqlFile) -or !(Test-Path -Path $SqlFile)) {
  throw "SqlFile does not exist: '$SqlFile'"
}

# 5. Baseline Hash Validation (if provided)
if (![string]::IsNullOrWhiteSpace($ExpectedBaselineHash)) {
  $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $SqlFile).Path)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  $computedBytes = $sha256.ComputeHash($fileBytes)
  $computedHex = [System.BitConverter]::ToString($computedBytes).Replace('-', '').ToUpper()

  if ($computedHex -ne $ExpectedBaselineHash.Trim().ToUpper()) {
    throw "Baseline hash mismatch! Expected: '$ExpectedBaselineHash', Actual: '$computedHex' on '$SqlFile'."
  }
}

Write-Host "Target Guard Check Passed: Target ProjectRef '$ProjectRef' is isolated from primary." -ForegroundColor Green

if ($DryRun) {
  Write-Host "[DryRun] Validation complete. No SQL executed." -ForegroundColor Cyan
  exit 0
}

# 6. Database Execution via psql if available
$psqlCmd = Get-Command psql -ErrorAction SilentlyContinue
if (!$psqlCmd) {
  throw "EXECUTION BLOCKER: 'psql' is not installed or not available on PATH. Direct SQL execution requires psql or authorized runner connection."
}

Write-Host "Executing SQL file: $SqlFile against $ConnectionHost..." -ForegroundColor Cyan
# Execute psql with fail-closed parameters
& psql -X -v ON_ERROR_STOP=1 -h $ConnectionHost -U postgres -d postgres -f $SqlFile
if ($LASTEXITCODE -ne 0) {
  throw "psql execution failed with exit code $LASTEXITCODE on file $SqlFile"
}

Write-Host "Execution finished successfully." -ForegroundColor Green
exit 0
