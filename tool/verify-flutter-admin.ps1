[CmdletBinding()]
param(
    [ValidateSet('Account', 'Draft', 'Publication', 'All')]
    [string]$Mode = 'Account',
    [string]$FlutterRoot,
    [string]$PostgresBin = 'C:/Program Files/PostgreSQL/18/bin',
    [switch]$DryRun,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = Split-Path -Parent $PSScriptRoot

# Track owned child PostgreSQL instance for cleanup
$script:pgStarted = $false
$script:pgCtl = $null
$script:dataRoot = $null
$script:runRoot = $null
$script:logRoot = $null

function Invoke-Check {
    param(
        [string]$Label,
        [string]$Executable,
        [string[]]$CommandArgs
    )
    if ($DryRun) {
        [pscustomobject]@{
            Stage = 'Execution'
            Check = $Label
            Executable = $Executable
            Arguments = $CommandArgs
        } | ConvertTo-Json -Compress
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

function Invoke-Sql {
    param(
        [string]$Label,
        [string]$Sql,
        [string]$File,
        [string]$ExpectedError,
        [string[]]$Connection
    )
    if ($DryRun) {
        [pscustomobject]@{
            Stage = 'Sql'
            Check = $Label
            File = $File
            InlineSql = if ($Sql) { $Sql.Trim() } else { $null }
            ExpectedError = $ExpectedError
        } | ConvertTo-Json -Compress
        return
    }

    $sqlFileToRun = $File
    $isTempFile = $false
    if (-not $File -and $Sql) {
        $sqlFileToRun = Join-Path $script:runRoot ("inline_" + [guid]::NewGuid().ToString('N') + ".sql")
        [System.IO.File]::WriteAllText($sqlFileToRun, $Sql, [System.Text.Encoding]::UTF8)
        $isTempFile = $true
    }

    $arguments = $Connection + @('-q', '-f', $sqlFileToRun)
    $outPath = Join-Path $script:runRoot 'temp_sql_out.log'
    $errPath = Join-Path $script:runRoot 'temp_sql_err.log'
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    if (Test-Path $errPath) { Remove-Item $errPath -Force }

    $p = Start-Process -FilePath $script:psql -ArgumentList $arguments -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $outPath -RedirectStandardError $errPath
    $null = $p.WaitForExit(30000)
    $p.WaitForExit()
    $code = if ($null -ne $p.ExitCode) { $p.ExitCode } else { 0 }

    if ($isTempFile -and (Test-Path $sqlFileToRun)) {
        Remove-Item $sqlFileToRun -Force
    }

    $outText = if (Test-Path $outPath) { Get-Content -Path $outPath -Raw -Encoding utf8 } else { "" }
    $errText = if (Test-Path $errPath) { Get-Content -Path $errPath -Raw -Encoding utf8 } else { "" }
    $combined = "$outText`n$errText".Trim()

    $sqlLog = Join-Path $script:runRoot 'sql-verification.log'
    $combined | Out-File -LiteralPath $sqlLog -Append -Encoding utf8

    if ($ExpectedError) {
        if ($code -eq 0 -or $combined -notmatch [regex]::Escape($ExpectedError)) {
            throw "Expected denial failed: $Label. Code: $code. See $sqlLog"
        }
    } elseif (($code -ne 0) -or ($combined -match '(?i)\bERROR:')) {
        throw "SQL failed: $Label (exit $code): $combined. See $sqlLog"
    }
    Write-Host "PASS: $Label"
}

Push-Location $repoRoot
try {
    # 1. Resolve Runtimes
    if (-not $FlutterRoot) {
        $flutterCommand = Get-Command flutter -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($flutterCommand) {
            $FlutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
        } else {
            $FlutterRoot = 'D:/flutter/flutter'
        }
    }
    $dartExecutable = Join-Path $FlutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
    $flutterSnapshot = Join-Path $FlutterRoot 'bin/cache/flutter_tools.snapshot'

    $nodeCommand = Get-Command node -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    $nodeExecutable = if ($nodeCommand) { $nodeCommand.Source } else { 'D:/nodejs/node.exe' }

    $script:psql = Join-Path $PostgresBin 'psql.exe'
    $script:pgCtl = Join-Path $PostgresBin 'pg_ctl.exe'
    $initDb = Join-Path $PostgresBin 'initdb.exe'

    # Setup directories
    $timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + $PID
    if (-not $DryRun) {
        $script:logRoot = Join-Path $repoRoot (".dart_tool/travelgo-admin-verification/$timestamp")
        New-Item -ItemType Directory -Path $script:logRoot -Force -ErrorAction Stop | Out-Null
    }

    # Helper function to start isolated PostgreSQL instance
    function Start-IsolatedPostgres {
        param([string]$Purpose = 'admin-postgres')
        $script:runRoot = Join-Path $repoRoot (".dart_tool/$Purpose/" + [guid]::NewGuid().ToString('N'))
        $script:dataRoot = Join-Path $script:runRoot 'data'
        New-Item -ItemType Directory -Path $script:runRoot -Force | Out-Null

        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $listener.Stop()

        & $initDb -D $script:dataRoot -U postgres -A trust --encoding=UTF8 --locale=C *> (Join-Path $script:runRoot 'initdb.log')
        if ($LASTEXITCODE -ne 0) { throw 'initdb failed for isolated PostgreSQL' }

        $startArgs = "-D `"$($script:dataRoot)`" -l `"$(Join-Path $script:runRoot 'server.log')`" -o `"-p $port -h 127.0.0.1`" -w -t 15 start"
        $launcher = Start-Process -FilePath $script:pgCtl -ArgumentList $startArgs -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $script:runRoot 'start.log') -RedirectStandardError (Join-Path $script:runRoot 'start-error.log')
        
        $null = $launcher.WaitForExit(20000)

        # Check connection readiness using psql directly
        $ready = $false
        for ($i = 0; $i -lt 10; $i++) {
            & $script:psql -h 127.0.0.1 -p $port -U postgres -d postgres -c 'SELECT 1;' *> $null
            if ($LASTEXITCODE -eq 0) {
                $ready = $true
                break
            }
            Start-Sleep -Milliseconds 500
        }
        if (-not $ready) {
            throw "Isolated PostgreSQL failed to accept connections on loopback port $port"
        }

        $script:pgStarted = $true
        return @('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1')
    }

    # 2. SelfTest: Pin regression harness_propagates_nonzero
    if ($SelfTest) {
        Write-Host "=== SelfTest: Verifying harness_propagates_nonzero ==="
        
        # Test 1: Node failure must propagate nonzero exit and be caught
        $nodeCaught = $false
        try {
            $tempNodeScript = Join-Path $env:TEMP ("deliberate_node_fail_" + [guid]::NewGuid().ToString('N') + ".mjs")
            Set-Content -Path $tempNodeScript -Value "import assert from 'node:assert'; assert.strictEqual(1, 2, 'deliberate_node_failure');"
            Invoke-Check 'selftest-deliberate-node-failure' $nodeExecutable @($tempNodeScript)
        } catch {
            $nodeCaught = $true
            Write-Host "PASS: Node deliberate failure propagated nonzero and was caught: $($_.Exception.Message)"
        } finally {
            if (Test-Path $tempNodeScript) { Remove-Item $tempNodeScript -Force }
        }
        if (-not $nodeCaught) {
            throw "Harness integrity violation: deliberate Node failure did not propagate nonzero!"
        }

        # Test 2: SQL deliberate failure must propagate nonzero exit and be caught
        if ((Test-Path $script:psql) -and (Test-Path $script:pgCtl) -and (Test-Path $initDb)) {
            $conn = Start-IsolatedPostgres -Purpose 'admin-postgres-selftest'

            $sqlCaught = $false
            try {
                Invoke-Sql -Label 'selftest-deliberate-sql-failure' -Sql 'SELECT 1/0;' -Connection $conn
            } catch {
                $sqlCaught = $true
                Write-Host "PASS: SQL deliberate failure propagated nonzero and was caught: $($_.Exception.Message)"
            }
            if (-not $sqlCaught) {
                throw "Harness integrity violation: deliberate SQL failure did not propagate nonzero!"
            }

            # Stop SelfTest DB
            & $script:pgCtl -D $script:dataRoot -m immediate stop *> (Join-Path $script:runRoot 'stop.log')
            $script:pgStarted = $false
        } else {
            Write-Host "SKIP: Local PostgreSQL binary not found for SQL SelfTest; recorded as NOT RUN."
        }
        Write-Host "=== SelfTest Complete: All assertions verified ===`n"
        return
    }

    # 3. DryRun reporting
    if ($DryRun) {
        Write-Host "=== verify-flutter-admin.ps1 [DRY RUN] Mode: $Mode ==="
        [pscustomobject]@{
            Mode = $Mode
            FlutterRoot = $FlutterRoot
            DartExecutable = $dartExecutable
            NodeExecutable = $nodeExecutable
            PostgresBin = $PostgresBin
            LogDirectory = if ($script:logRoot) { $script:logRoot } else { "(dry-run none)" }
        } | ConvertTo-Json
    }

    # 4. Mode-specific command execution

    # Account Mode
    if ($Mode -in @('Account', 'All')) {
        Write-Host "`n--- [Mode: Account] Verification ---"
        if ($DryRun) {
            Invoke-Check 'account-dryrun-inventory' 'powershell' @('Account checks: Dart lifecycle/roles tests, SQL Account constraints, Node Gateway tests')
        }

        # 4.1 Dart targeted tests
        $accountDartTests = @(
            'test/auth_role_security_test.dart',
            'test/auth_navigation_test.dart',
            'test/local_account_lifecycle_test.dart'
        )
        if (Test-Path (Join-Path $repoRoot 'test/account_access_service_test.dart')) {
            $accountDartTests += 'test/account_access_service_test.dart'
        }
        Invoke-Check 'account-dart-tests' $dartExecutable (@(
            $flutterSnapshot, '--suppress-analytics', 'test', '--no-pub',
            '--concurrency=2', '--reporter=expanded'
        ) + $accountDartTests)

        # 4.2 Node Account contracts (run when created)
        $accountNodeTests = @()
        if (Test-Path (Join-Path $repoRoot 'test/admin_account_gateway_test.mjs')) {
            $accountNodeTests += 'test/admin_account_gateway_test.mjs'
        }
        if (Test-Path (Join-Path $repoRoot 'test/admin_control_gateway_test.mjs')) {
            $accountNodeTests += 'test/admin_control_gateway_test.mjs'
        }
        if ($accountNodeTests.Count -gt 0 -or $DryRun) {
            $testArgs = @('--test') + $(if ($accountNodeTests.Count -gt 0) { $accountNodeTests } else { @('test/admin_account_gateway_test.mjs') })
            Invoke-Check 'account-node-tests' $nodeExecutable $testArgs
        }

        # 4.3 SQL Account contracts in disposable PostgreSQL
        if ($DryRun) {
            Invoke-Sql -Label 'account-synthetic-auth-substrate' -Sql 'CREATE ROLE/SCHEMA synthetic auth substrate'
            Invoke-Sql -Label 'apply-baseline-and-two-role' -File 'supabase/migrations/20261020145005_two_role_foundation.sql'
            Invoke-Sql -Label 'account-role-regressions' -File 'supabase/tests/profile_two_roles.sql'
            if (Test-Path (Join-Path $repoRoot 'supabase/tests/admin_account_control.sql')) {
                Invoke-Sql -Label 'admin-account-control' -File 'supabase/tests/admin_account_control.sql'
            }
        } elseif ((Test-Path $script:psql) -and (Test-Path $script:pgCtl)) {
            $conn = Start-IsolatedPostgres -Purpose 'admin-postgres-account'
            Invoke-Sql 'synthetic Supabase auth substrate' -Sql @'
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users(
  id uuid PRIMARY KEY,
  email text,
  phone text,
  raw_user_meta_data jsonb,
  is_anonymous boolean DEFAULT false,
  deleted_at timestamptz,
  banned_until timestamptz,
  email_confirmed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE TABLE auth.sessions(
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id),
  not_after timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb);
$$;
GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO anon,authenticated,service_role;
'@ -Connection $conn
            Invoke-Sql 'baseline.sql' -File (Join-Path $repoRoot 'supabase/staging/baseline.sql') -Connection $conn
            Invoke-Sql 'profile_privacy.sql' -File (Join-Path $repoRoot 'supabase/migrations/202610080001_profile_privacy.sql') -Connection $conn
            Invoke-Sql 'profile_preferences.sql' -File (Join-Path $repoRoot 'supabase/migrations/202610190001_profile_preferences.sql') -Connection $conn
            Invoke-Sql 'two_role_foundation.sql' -File (Join-Path $repoRoot 'supabase/migrations/20261020145005_two_role_foundation.sql') -Connection $conn
            Invoke-Sql 'profile_two_roles.sql' -File (Join-Path $repoRoot 'supabase/tests/profile_two_roles.sql') -Connection $conn

            # Dynamic suites added by A1/A2
            if (Test-Path (Join-Path $repoRoot 'supabase/tests/admin_account_control.sql')) {
                Invoke-Sql 'admin_account_control.sql' -File (Join-Path $repoRoot 'supabase/tests/admin_account_control.sql') -Connection $conn
            }
            if (Test-Path (Join-Path $repoRoot 'supabase/tests/admin_account_concurrency.sql')) {
                Invoke-Sql 'admin_account_concurrency.sql' -File (Join-Path $repoRoot 'supabase/tests/admin_account_concurrency.sql') -Connection $conn
            }
            if (Test-Path (Join-Path $repoRoot 'supabase/tests/admin_account_surface_guards.sql')) {
                Invoke-Sql 'admin_account_surface_guards.sql' -File (Join-Path $repoRoot 'supabase/tests/admin_account_surface_guards.sql') -Connection $conn
            }

            # Stop server after mode
            & $script:pgCtl -D $script:dataRoot -m immediate stop *> (Join-Path $script:runRoot 'stop.log')
            $script:pgStarted = $false
        }
    }

    # Draft Mode
    if ($Mode -in @('Draft', 'All')) {
        Write-Host "`n--- [Mode: Draft] Verification ---"
        $draftNodeTests = @('test/admin_discovery_web_test.mjs')
        if (Test-Path (Join-Path $repoRoot 'test/admin_discovery_commands_test.mjs')) {
            $draftNodeTests += 'test/admin_discovery_commands_test.mjs'
        }
        Invoke-Check 'draft-node-tests' $nodeExecutable (@('--test') + $draftNodeTests)

        if ($DryRun) {
            Invoke-Sql -Label 'admin_discovery.sql' -File 'supabase/tests/admin_discovery.sql'
        } elseif ((Test-Path $script:psql) -and (Test-Path $script:pgCtl)) {
            $conn = Start-IsolatedPostgres -Purpose 'admin-postgres-draft'
            Invoke-Sql 'synthetic auth substrate' -Sql @'
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users(
  id uuid PRIMARY KEY,
  email text,
  phone text,
  raw_user_meta_data jsonb,
  is_anonymous boolean DEFAULT false,
  deleted_at timestamptz,
  banned_until timestamptz,
  email_confirmed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE TABLE auth.sessions(
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id),
  not_after timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb);
$$;
GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO anon,authenticated,service_role;
'@ -Connection $conn
            Invoke-Sql 'baseline.sql' -File (Join-Path $repoRoot 'supabase/staging/baseline.sql') -Connection $conn
            Invoke-Sql 'profile_privacy.sql' -File (Join-Path $repoRoot 'supabase/migrations/202610080001_profile_privacy.sql') -Connection $conn
            Invoke-Sql 'profile_preferences.sql' -File (Join-Path $repoRoot 'supabase/migrations/202610190001_profile_preferences.sql') -Connection $conn
            Invoke-Sql 'two_role_foundation.sql' -File (Join-Path $repoRoot 'supabase/migrations/20261020145005_two_role_foundation.sql') -Connection $conn
            Invoke-Sql 'admin_discovery_drafts.sql' -File (Join-Path $repoRoot 'supabase/migrations/20261020151440_admin_discovery_drafts.sql') -Connection $conn
            Invoke-Sql 'admin_discovery.sql' -File (Join-Path $repoRoot 'supabase/tests/admin_discovery.sql') -Connection $conn

            & $script:pgCtl -D $script:dataRoot -m immediate stop *> (Join-Path $script:runRoot 'stop.log')
            $script:pgStarted = $false
        }
    }

    # Publication Mode
    if ($Mode -in @('Publication', 'All')) {
        Write-Host "`n--- [Mode: Publication] Verification ---"
        if (Test-Path (Join-Path $repoRoot 'test/discovery_publication_gateway_test.mjs')) {
            Invoke-Check 'publication-node-tests' $nodeExecutable @('--test', 'test/discovery_publication_gateway_test.mjs')
        } else {
            Write-Host "Publication suite pending Task P1-P11 implementation (recorded as NOT RUN)."
        }
    }

    # All Mode: Full analyzer + Flutter Full suite + Existing Node contracts
    if ($Mode -eq 'All') {
        Write-Host "`n--- [Mode: All] Full Suite Execution ---"
        Invoke-Check 'analyze' $dartExecutable @($flutterSnapshot, '--suppress-analytics', 'analyze', '--no-pub')
        Invoke-Check 'flutter-tests' $dartExecutable @(
            $flutterSnapshot, '--suppress-analytics', 'test', '--no-pub',
            '--concurrency=2', '--reporter=expanded'
        )
        Invoke-Check 'node-contracts' $nodeExecutable @(
            '--test', 'test/ai_gateway_test.mjs', 'test/itinerary_gateway_test.mjs',
            'test/catalogue_readiness_test.mjs', 'test/admin_discovery_web_test.mjs'
        )
    }

    Write-Host "`n=== Verification Complete: All executed checks PASS ==="
} finally {
    if ($script:pgStarted -and $script:pgCtl -and $script:dataRoot) {
        Write-Host "Cleaning up isolated PostgreSQL process..."
        & $script:pgCtl -D $script:dataRoot -m immediate stop *> $null
    }
    Pop-Location
}
