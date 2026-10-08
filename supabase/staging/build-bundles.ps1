<#
.SYNOPSIS
  Generates deterministic, pure-SQL execution bundles for TravelGO Staging & Dashboard.
.DESCRIPTION
  Flattens modular test harnesses and their shared helper dependency into self-contained,
  pure-SQL bundles. Completely eliminates \ir meta-commands while guaranteeing 100%
  source equivalence.
#>
[CmdletBinding()]
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$testsDir = Join-Path $repoRoot "supabase\tests"
$bundlesDir = Join-Path $scriptDir "bundles"

if (!(Test-Path $bundlesDir)) {
  New-Item -ItemType Directory -Path $bundlesDir -Force | Out-Null
}

function Get-NormalizedSha256Content([string]$content) {
  $lf = $content.Replace("`r`n", "`n").Replace("`r", "`n")
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($lf)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  return [System.BitConverter]::ToString($sha256.ComputeHash($bytes)).Replace('-', '').ToUpper()
}

$helperPath = Join-Path $testsDir "profile_privacy_test_helpers.sql"
$helperRaw = [System.IO.File]::ReadAllText($helperPath, [System.Text.Encoding]::UTF8)
$helperHash = Get-NormalizedSha256Content -content $helperRaw

$targets = @(
  @{
    Source = "profile_privacy.sql"
    Bundle = "profile_privacy.bundle.sql"
    Description = "Main test harness execution bundle (12 test cases)"
  },
  @{
    Source = "profile_privacy_negative_controls.sql"
    Bundle = "profile_privacy_negative_controls.bundle.sql"
    Description = "Negative controls execution bundle (5 controls)"
  }
)

foreach ($t in $targets) {
  $srcPath = Join-Path $testsDir $t.Source
  $bundlePath = Join-Path $bundlesDir $t.Bundle
  $srcRaw = [System.IO.File]::ReadAllText($srcPath, [System.Text.Encoding]::UTF8)
  $srcHash = Get-NormalizedSha256Content -content $srcRaw

  $pattern = '(?m)^\\ir\s+profile_privacy_test_helpers\.sql\s*$'
  if ($srcRaw -notmatch $pattern) {
    throw "Target $($t.Source) does not contain expected '\ir profile_privacy_test_helpers.sql' directive."
  }

  $helperBlock = @"
-- >>> START INJECTED DEPENDENCY: profile_privacy_test_helpers.sql (LF-SHA256: $helperHash) <<<
$($helperRaw.Trim())
-- >>> END INJECTED DEPENDENCY: profile_privacy_test_helpers.sql <<<
"@

  $bundledContent = $srcRaw -replace $pattern, $helperBlock
  $bundledContent = $bundledContent.Replace("`r`n", "`n").Replace("`r", "`n").Trim() + "`n"

  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($bundlePath, $bundledContent, $utf8NoBom)

  $bundleHash = Get-NormalizedSha256Content -content $bundledContent
  Write-Host "Generated bundle: $($t.Bundle)" -ForegroundColor Green
  Write-Host "  Source: $($t.Source) (SHA256: $srcHash)"
  Write-Host "  Helper: profile_privacy_test_helpers.sql (SHA256: $helperHash)"
  Write-Host "  Bundle SHA256: $bundleHash"
}
