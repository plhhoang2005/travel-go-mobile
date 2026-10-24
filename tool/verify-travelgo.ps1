[CmdletBinding()]
param(
    [ValidateSet('Status', 'Ai', 'Targeted', 'Full')]
    [string]$Mode = 'Status',
    [string[]]$TestPath = @(),
    [string]$FlutterRoot,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Check {
    param([string]$Label, [string]$Executable, [string[]]$CommandArgs)
    if ($DryRun) {
        [pscustomobject]@{ Check = $Label; Executable = $Executable; Arguments = $CommandArgs } |
            ConvertTo-Json -Compress
        return
    }
    $logPath = Join-Path $script:logRoot "$Label.log"
    Write-Host "Running $Label; log: $logPath"
    & $Executable @CommandArgs 2>&1 | Tee-Object -FilePath $logPath
    $checkExit = $LASTEXITCODE
    if ($checkExit -ne 0) {
        throw "$Label failed with exit $checkExit. See $logPath"
    }
    Write-Host "$Label PASS (exit 0)"
}

Push-Location $repoRoot
try {
    if ($Mode -eq 'Status') {
        & git status --short --branch
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read Git status.' }
        & git rev-parse HEAD
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read Git HEAD.' }
        Write-Host 'Current delivery ledger: docs/phase-3/MUST_DELIVERY_PLAN_20261024.md'
        Write-Host 'Inspect its latest checkpoint; historical PASS is not a fresh check.'
        return
    }

    if ($Mode -eq 'Targeted') {
        if ($TestPath.Count -eq 0) { throw 'Targeted mode requires -TestPath.' }
        foreach ($testFile in $TestPath) {
            $resolvedTest = [IO.Path]::GetFullPath((Join-Path $repoRoot $testFile))
            $testRoot = (Join-Path $repoRoot 'test') + [IO.Path]::DirectorySeparatorChar
            if (-not $resolvedTest.StartsWith($testRoot, [StringComparison]::OrdinalIgnoreCase) -or
                -not $resolvedTest.EndsWith('_test.dart') -or
                -not (Test-Path -LiteralPath $resolvedTest -PathType Leaf)) {
                throw "Expected an existing Dart test inside test/: $testFile"
            }
        }
    } elseif ($TestPath.Count -gt 0) {
        throw '-TestPath is only valid with -Mode Targeted.'
    }

    if ($Mode -in @('Targeted', 'Full')) {
        if (-not $FlutterRoot) {
            $flutterCommand = Get-Command flutter -CommandType Application -ErrorAction Stop |
                Select-Object -First 1
            $FlutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
        }
        $dartExecutable = Join-Path $FlutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
        $flutterSnapshot = Join-Path $FlutterRoot 'bin/cache/flutter_tools.snapshot'
        foreach ($requiredPath in @($dartExecutable, $flutterSnapshot)) {
            if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
                throw "Missing cached Flutter runtime: $requiredPath. Run the normal SDK setup first."
            }
        }
    }
    if ($Mode -in @('Ai', 'Full')) {
        $nodeExecutable = (Get-Command node -CommandType Application -ErrorAction Stop |
            Select-Object -First 1).Source
    }
    if (-not $DryRun) {
        $script:logRoot = Join-Path $repoRoot ('.dart_tool/travelgo-verification/' +
            [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + $PID)
        New-Item -ItemType Directory -Path $script:logRoot -ErrorAction Stop | Out-Null
    }

    if ($Mode -eq 'Full') {
        Invoke-Check 'analyze' $dartExecutable @($flutterSnapshot, '--suppress-analytics', 'analyze', '--no-pub')
    }
    if ($Mode -in @('Targeted', 'Full')) {
        $flutterArgs = @($flutterSnapshot, '--suppress-analytics', 'test', '--no-pub',
            '--concurrency=2', '--reporter=expanded')
        if ($Mode -eq 'Targeted') { $flutterArgs += $TestPath }
        Invoke-Check 'flutter-tests' $dartExecutable $flutterArgs
    }
    if ($Mode -in @('Ai', 'Full')) {
        Invoke-Check 'node-contracts' $nodeExecutable @('--test', 'test/ai_gateway_test.mjs',
            'test/itinerary_gateway_test.mjs', 'test/catalogue_readiness_test.mjs')
    }
} finally {
    Pop-Location
}
