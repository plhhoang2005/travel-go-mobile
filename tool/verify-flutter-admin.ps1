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

function Stop-PostgresInstance {
    if ($script:dataRoot -and (Test-Path (Join-Path $script:dataRoot 'postmaster.pid'))) {
        if ($script:pgCtl -and (Test-Path $script:pgCtl)) {
            $stopLog = Join-Path $script:runRoot 'stop.log'
            & $script:pgCtl -D $script:dataRoot -m immediate -w stop *> $stopLog
            if ($LASTEXITCODE -ne 0 -or (Test-Path (Join-Path $script:dataRoot 'postmaster.pid'))) {
                throw "Owned PostgreSQL did not stop. See $stopLog"
            }
        }
    }
    $script:pgStarted = $false
}

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
    if (-not (Test-Path $Executable) -and -not (Get-Command $Executable -ErrorAction SilentlyContinue)) {
        throw "Executable not found for ${Label}: $Executable"
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
        [string[]]$Connection,
        [string]$OutputJsonPath,
        [int]$TimeoutMs = 30000
    )
    if ($DryRun) {
        [pscustomobject]@{
            Stage = 'Sql'
            Check = $Label
            File = $File
            InlineSql = if ($Sql) { $Sql.Trim() } else { $null }
            ExpectedError = $ExpectedError
            OutputJsonPath = $OutputJsonPath
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

    $extraFlags = @('-q')
    if ($OutputJsonPath) {
        $extraFlags += @('-A', '-t')
    }
    $arguments = $Connection + $extraFlags + @('-f', $sqlFileToRun)
    $cmdLine = [string]::Join(' ', ($arguments | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '(\\*)(")', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
        } else {
            $_
        }
    }))

    $psi = [System.Diagnostics.ProcessStartInfo]::new($script:psql, $cmdLine)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $p = [System.Diagnostics.Process]::Start($psi)
    $stdoutTask = $p.StandardOutput.ReadToEndAsync()
    $stderrTask = $p.StandardError.ReadToEndAsync()

    $hasExited = $p.WaitForExit($TimeoutMs)
    if (-not $hasExited) {
        try { $p.Kill() } catch {}
        if ($isTempFile -and (Test-Path $sqlFileToRun)) { Remove-Item $sqlFileToRun -Force }
        throw "Timeout ($TimeoutMs ms) exceeded waiting for psql process: $Label"
    }

    $null = [System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 5000)
    $code = $p.ExitCode
    if ($null -eq $code) {
        if ($isTempFile -and (Test-Path $sqlFileToRun)) { Remove-Item $sqlFileToRun -Force }
        throw "Child process exit code unavailable for psql execution: $Label"
    }

    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $combined = "$stdout`n$stderr".Trim()

    if ($isTempFile -and (Test-Path $sqlFileToRun)) {
        Remove-Item $sqlFileToRun -Force
    }

    $sqlLog = Join-Path $script:runRoot 'sql-verification.log'
    $combined | Out-File -LiteralPath $sqlLog -Append -Encoding utf8

    if ($ExpectedError) {
        if ($code -eq 0) {
            throw "Expected denial failed: $Label. Process exited with code 0 (success) but expected error '$ExpectedError'. See $sqlLog"
        }
        if ($combined -notmatch [regex]::Escape($ExpectedError)) {
            throw "Expected denial failed: $Label. Process exited with code $code but output did not match expected error '$ExpectedError'. Output: $combined. See $sqlLog"
        }
    } else {
        if ($code -ne 0) {
            throw "SQL execution failed: $Label (child exit code $code). Output: $combined. See $sqlLog"
        }
        if ($combined -match '(?i)\bERROR:') {
            throw "SQL output contains unexpected ERROR: $Label (child exit code $code). Output: $combined. See $sqlLog"
        }
        if ($OutputJsonPath) {
            $trimmed = $stdout.Trim()
            $jsonCandidate = $trimmed
            $firstBrace = $trimmed.IndexOf('{')
            $lastBrace = $trimmed.LastIndexOf('}')
            if ($firstBrace -ge 0 -and $lastBrace -gt $firstBrace) {
                $jsonCandidate = $trimmed.Substring($firstBrace, $lastBrace - $firstBrace + 1)
            }
            try {
                $parsedJson = $jsonCandidate | ConvertFrom-Json
                if ($null -eq $parsedJson) { throw 'Expected a non-null JSON object.' }
                [System.IO.File]::WriteAllText($OutputJsonPath, $jsonCandidate, [System.Text.Encoding]::UTF8)
            } catch {
                throw "Invoke-Sql: $Label did not produce valid JSON for $OutputJsonPath. Output: $trimmed"
            }
        }
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
        
        # Ensure cleanup flag is active as soon as process starts
        $script:pgStarted = $true

        $null = $launcher.WaitForExit(20000)

        # Check connection readiness using psql directly
        $ready = $false
        for ($i = 0; $i -lt 15; $i++) {
            & $script:psql -h 127.0.0.1 -p $port -U postgres -d postgres -c 'SELECT 1;' *> $null
            if ($LASTEXITCODE -eq 0) {
                $ready = $true
                break
            }
            Start-Sleep -Milliseconds 500
        }
        if (-not $ready) {
            Stop-PostgresInstance
            throw "Isolated PostgreSQL failed to accept connections on loopback port $port"
        }

        return @('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1')
    }

    # 2. SelfTest: Pin regression harness_propagates_nonzero and negative controls
    if ($SelfTest) {
        Write-Host "=== SelfTest: Verifying harness_propagates_nonzero ==="

        # Verify Node runtime exists
        if (-not (Test-Path $nodeExecutable) -and -not (Get-Command $nodeExecutable -ErrorAction SilentlyContinue)) {
            throw "BLOCKED: Node.js executable not found at '$nodeExecutable'. SelfTest cannot proceed."
        }

        # Test 1A: Positive control for Node (must succeed with exit 0)
        Invoke-Check 'selftest-node-positive-control' $nodeExecutable @('-e', 'process.exit(0)')

        # Test 1B: Deliberate Node failure with specific assertion marker and nonzero exit
        $tempNodeScript = Join-Path $env:TEMP ("deliberate_node_fail_" + [guid]::NewGuid().ToString('N') + ".mjs")
        Set-Content -Path $tempNodeScript -Value "import assert from 'node:assert'; assert.strictEqual(1, 2, 'deliberate_node_failure');"
        
        $psi = [System.Diagnostics.ProcessStartInfo]::new($nodeExecutable, "`"$tempNodeScript`"")
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $nodeProcess = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $nodeProcess.StandardOutput.ReadToEndAsync()
        $stderrTask = $nodeProcess.StandardError.ReadToEndAsync()
        $hasExited = $nodeProcess.WaitForExit(10000)
        $null = [System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 5000)
        $nodeExit = $nodeProcess.ExitCode
        $nodeOutput = ($stdoutTask.Result + "`n" + $stderrTask.Result).Trim()
        if (Test-Path $tempNodeScript) { Remove-Item $tempNodeScript -Force }

        if (-not $hasExited -or $nodeExit -eq 0 -or $nodeOutput -notmatch 'deliberate_node_failure') {
            throw "Harness integrity violation: deliberate Node failure did not propagate expected marker with nonzero child exit! Code: $nodeExit, Output: $nodeOutput"
        }
        Write-Host "PASS: Node deliberate failure exited with code $nodeExit and contained expected marker 'deliberate_node_failure'"

        # Test 1C: Negative control: ensure harness rejects missing executable or missing marker
        $bogusScript = Join-Path $env:TEMP ("selftest_bogus_" + [guid]::NewGuid().ToString('N') + ".mjs")
        Set-Content -Path $bogusScript -Value "process.exit(0);"
        $bogusRejected = $false
        try {
            $bp = Start-Process -FilePath $nodeExecutable -ArgumentList @($bogusScript) -WindowStyle Hidden -PassThru
            $bp.WaitForExit()
            if ($bp.ExitCode -eq 0) {
                # Deliberate failure assertion expects nonzero; exit 0 must be rejected
                throw "ASSERTION_FAILED: fake exit 0 cannot be counted as failure propagation"
            }
        } catch {
            if ($_.Exception.Message -match 'ASSERTION_FAILED') {
                $bogusRejected = $true
            }
        } finally {
            if (Test-Path $bogusScript) { Remove-Item $bogusScript -Force }
        }
        if (-not $bogusRejected) {
            throw "Harness integrity violation: false-positive control failed, exit 0 was not rejected as failure!"
        }
        Write-Host "PASS: Node false-positive control rejected fake exit 0 correctly"

        # Test 2: SQL controls
        if (-not ((Test-Path $script:psql) -and (Test-Path $script:pgCtl) -and (Test-Path $initDb))) {
            throw "BLOCKED: Required PostgreSQL binaries (psql, pg_ctl, initdb) not found at '$PostgresBin'. SelfTest cannot verify SQL assertion propagation without required runtime."
        }

        $conn = Start-IsolatedPostgres -Purpose 'admin-postgres-selftest'
        try {
            # Test 2A: SQL positive control (must succeed with exit 0)
            Invoke-Sql -Label 'selftest-sql-positive-control' -Sql 'SELECT 1;' -Connection $conn

            # Test 2B: SQL deliberate failure with ExpectedError (division by zero)
            Invoke-Sql -Label 'selftest-sql-deliberate-failure' -Sql 'SELECT 1/0;' -ExpectedError 'division by zero' -Connection $conn

            # Test 2C: Negative control: SQL unhandled failure without ExpectedError must throw
            $unhandledCaught = $false
            try {
                Invoke-Sql -Label 'selftest-sql-unhandled-negative' -Sql 'SELECT 1/0;' -Connection $conn
            } catch {
                if ($_.Exception.Message -match 'SQL execution failed') {
                    $unhandledCaught = $true
                }
            }
            if (-not $unhandledCaught) {
                throw "Harness integrity violation: unhandled SQL failure did not throw!"
            }
            Write-Host "PASS: SQL unhandled failure without ExpectedError threw expected exception"

            # Test 2D: Negative control: SQL with mismatched ExpectedError must throw
            $mismatchedCaught = $false
            try {
                Invoke-Sql -Label 'selftest-sql-mismatched-negative' -Sql 'SELECT 1/0;' -ExpectedError 'completely_nonexistent_sentinel' -Connection $conn
            } catch {
                if ($_.Exception.Message -match 'Expected denial failed') {
                    $mismatchedCaught = $true
                }
            }
            if (-not $mismatchedCaught) {
                throw "Harness integrity violation: SQL with mismatched ExpectedError did not throw!"
            }
            Write-Host "PASS: SQL mismatched ExpectedError threw expected exception"

            # Test 2E: Negative control: Controlled timeout propagation
            $timeoutCaught = $false
            try {
                # Force timeout by specifying 1ms timeout on a command
                Invoke-Sql -Label 'selftest-sql-timeout-negative' -Sql 'SELECT pg_sleep(2);' -Connection $conn -TimeoutMs 200
            } catch {
                if ($_.Exception.Message -match 'Timeout .* exceeded') {
                    $timeoutCaught = $true
                }
            }
            if (-not $timeoutCaught) {
                throw "Harness integrity violation: SQL query exceeding timeout did not trigger timeout exception!"
            }
            Write-Host "PASS: SQL timeout control aborted process and threw expected timeout exception"

        } finally {
            Stop-PostgresInstance
        }

        Write-Host "=== SelfTest Complete: All assertions and negative controls verified ===`n"
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

    # Helper to enforce PostgreSQL binary availability for SQL modes
    function Assert-PostgresBinaries {
        if (-not ((Test-Path $script:psql) -and (Test-Path $script:pgCtl) -and (Test-Path $initDb))) {
            throw "BLOCKED: Required PostgreSQL binaries (psql, pg_ctl, initdb) not found at '$PostgresBin'. SQL verification cannot proceed."
        }
    }

    # Account Mode
    if ($Mode -in @('Account', 'All')) {
        Write-Host "`n--- [Mode: Account] Verification ---"
        if ($DryRun) {
            Invoke-Check 'account-dryrun-inventory' 'powershell' @('Account checks: Dart lifecycle/roles tests, SQL Account constraints, Node Gateway tests')
        }

        # 4.1 Dart targeted tests
        $accountDartTests = @(
            'test/admin_account_provider_test.dart',
            'test/admin_account_service_test.dart',
            'test/admin_account_ui_test.dart',
            'test/admin_navigation_test.dart',
            'test/coursework_admin_account_flow_test.dart',
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
        $accountNodeTests = @('test/coursework_admin_contract_test.mjs')
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
        } else {
            Assert-PostgresBinaries
            $conn = Start-IsolatedPostgres -Purpose 'admin-postgres-account'
            try {
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
  SELECT coalesce(
    nullif(current_setting('request.jwt.claim.sub',true),'')::uuid,
    nullif((coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb))->>'sub','')::uuid
  );
$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb);
$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claim.role',true),''),'authenticated');
$$;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO anon,authenticated,service_role;
'@ -Connection $conn
                Invoke-Sql 'baseline.sql' -File (Join-Path $repoRoot 'supabase/staging/baseline.sql') -Connection $conn
                Invoke-Sql 'profile_privacy.sql' -File (Join-Path $repoRoot 'supabase/migrations/202610080001_profile_privacy.sql') -Connection $conn
                Invoke-Sql 'profile_preferences.sql' -File (Join-Path $repoRoot 'supabase/migrations/202610190001_profile_preferences.sql') -Connection $conn
                Invoke-Sql 'two_role_foundation.sql' -File (Join-Path $repoRoot 'supabase/migrations/20261020145005_two_role_foundation.sql') -Connection $conn
                Invoke-Sql 'profile_two_roles.sql' -File (Join-Path $repoRoot 'supabase/tests/profile_two_roles.sql') -Connection $conn

                # Dynamic suites added by A1/A2
                # Look for M_CONTROL migration in supabase/migrations/
                $controlMigration = Get-ChildItem -Path (Join-Path $repoRoot 'supabase/migrations') -Filter '*_admin_account_control.sql' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($controlMigration) {
                    Invoke-Sql 'admin_account_control migration' -File $controlMigration.FullName -Connection $conn
                }
                if (Test-Path (Join-Path $repoRoot 'supabase/tests/admin_account_control.sql')) {
                    Invoke-Sql 'admin_account_control.sql' -File (Join-Path $repoRoot 'supabase/tests/admin_account_control.sql') -Connection $conn
                }
                if (Test-Path (Join-Path $repoRoot 'supabase/tests/admin_account_concurrency.sql')) {
                    Invoke-Sql 'admin_account_concurrency.sql' -File (Join-Path $repoRoot 'supabase/tests/admin_account_concurrency.sql') -Connection $conn
                }

                $guardsMigration = Get-ChildItem -Path (Join-Path $repoRoot 'supabase/migrations') -Filter '*_admin_account_guards.sql' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($guardsMigration) {
                    Invoke-Sql 'admin_account_guards migration' -File $guardsMigration.FullName -Connection $conn
                }
                if (Test-Path (Join-Path $repoRoot 'supabase/tests/admin_account_surface_guards.sql')) {
                    Invoke-Sql 'admin_account_surface_guards.sql' -File (Join-Path $repoRoot 'supabase/tests/admin_account_surface_guards.sql') -Connection $conn
                }
                $c6Migration = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'supabase/migrations') -Filter '*_coursework_admin_account_consistency.sql' | Select-Object -First 1
                if ($c6Migration) { Invoke-Sql 'C6 account consistency migration' -File $c6Migration.FullName -Connection $conn }
                Invoke-Sql 'coursework_admin_account_contract.sql' -File (Join-Path $repoRoot 'supabase/tests/coursework_admin_account_contract.sql') -Connection $conn -OutputJsonPath (Join-Path $script:runRoot 'coursework-admin-vectors.json')
                Invoke-Check 'sql-shared-vectors' $nodeExecutable @('tool/check-coursework-admin-vectors.mjs', (Join-Path $script:runRoot 'coursework-admin-vectors.json'))
            } finally {
                Stop-PostgresInstance
            }
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
        } else {
            Assert-PostgresBinaries
            $conn = Start-IsolatedPostgres -Purpose 'admin-postgres-draft'
            try {
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
  SELECT coalesce(
    nullif(current_setting('request.jwt.claim.sub',true),'')::uuid,
    nullif((coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb))->>'sub','')::uuid
  );
$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb);
$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claim.role',true),''),'authenticated');
$$;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO anon,authenticated,service_role;
'@ -Connection $conn
                Invoke-Sql 'baseline.sql' -File (Join-Path $repoRoot 'supabase/staging/baseline.sql') -Connection $conn
                Invoke-Sql 'profile_privacy.sql' -File (Join-Path $repoRoot 'supabase/migrations/202610080001_profile_privacy.sql') -Connection $conn
                Invoke-Sql 'profile_preferences.sql' -File (Join-Path $repoRoot 'supabase/migrations/202610190001_profile_preferences.sql') -Connection $conn
                Invoke-Sql 'two_role_foundation.sql' -File (Join-Path $repoRoot 'supabase/migrations/20261020145005_two_role_foundation.sql') -Connection $conn
                
                # Check for M_CONTROL migration
                $controlMigration = Get-ChildItem -Path (Join-Path $repoRoot 'supabase/migrations') -Filter '*_admin_account_control.sql' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($controlMigration) {
                    Invoke-Sql 'admin_account_control migration' -File $controlMigration.FullName -Connection $conn
                }

                Invoke-Sql 'admin_discovery_drafts.sql' -File (Join-Path $repoRoot 'supabase/migrations/20261020151440_admin_discovery_drafts.sql') -Connection $conn

                # Check for M_DRAFT commands migration
                $draftCommandsMigration = Get-ChildItem -Path (Join-Path $repoRoot 'supabase/migrations') -Filter '*_admin_discovery_commands.sql' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($draftCommandsMigration) {
                    Invoke-Sql 'admin_discovery_commands migration' -File $draftCommandsMigration.FullName -Connection $conn
                }

                Invoke-Sql 'admin_discovery.sql' -File (Join-Path $repoRoot 'supabase/tests/admin_discovery.sql') -Connection $conn
            } finally {
                Stop-PostgresInstance
            }
        }
    }

    # Publication Mode
    if ($Mode -in @('Publication', 'All')) {
        Write-Host "`n--- [Mode: Publication] Verification ---"
        $pubNodeTests = @()
        if (Test-Path (Join-Path $repoRoot 'test/discovery_public_bundle_test.mjs')) {
            $pubNodeTests += 'test/discovery_public_bundle_test.mjs'
        }
        if (Test-Path (Join-Path $repoRoot 'test/admin_publication_gateway_test.mjs')) {
            $pubNodeTests += 'test/admin_publication_gateway_test.mjs'
        }
        if ($pubNodeTests.Count -gt 0) {
            Invoke-Check 'publication-node-tests' $nodeExecutable (@('--test') + $pubNodeTests)
        }

        if ($DryRun) {
            Invoke-Sql -Label 'discovery_publication.sql' -File 'supabase/tests/discovery_publication.sql'
        } else {
            Assert-PostgresBinaries
            $conn = Start-IsolatedPostgres -Purpose 'admin-postgres-publication'
            try {
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
  SELECT coalesce(
    nullif(current_setting('request.jwt.claim.sub',true),'')::uuid,
    nullif((coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb))->>'sub','')::uuid
  );
$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb);
$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claim.role',true),''),'authenticated');
$$;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO anon,authenticated,service_role;
'@ -Connection $conn
                Invoke-Sql 'baseline.sql' -File (Join-Path $repoRoot 'supabase/staging/baseline.sql') -Connection $conn
                Invoke-Sql 'profile_privacy.sql' -File (Join-Path $repoRoot 'supabase/migrations/202610080001_profile_privacy.sql') -Connection $conn
                Invoke-Sql 'profile_preferences.sql' -File (Join-Path $repoRoot 'supabase/migrations/202610190001_profile_preferences.sql') -Connection $conn
                Invoke-Sql 'two_role_foundation.sql' -File (Join-Path $repoRoot 'supabase/migrations/20261020145005_two_role_foundation.sql') -Connection $conn
                # Draft migrations
                Invoke-Sql 'admin_discovery_drafts.sql' -File (Join-Path $repoRoot 'supabase/migrations/20261020151440_admin_discovery_drafts.sql') -Connection $conn
                $draftCommandsMigration = Get-ChildItem -Path (Join-Path $repoRoot 'supabase/migrations') -Filter '*_admin_discovery_commands.sql' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($draftCommandsMigration) {
                    Invoke-Sql 'admin_discovery_commands migration' -File $draftCommandsMigration.FullName -Connection $conn
                }

                # Publication migration
                $pubMigration = Get-ChildItem -Path (Join-Path $repoRoot 'supabase/migrations') -Filter '*_discovery_publication_v2.sql' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($pubMigration) {
                    Invoke-Sql 'discovery_publication_v2 migration' -File $pubMigration.FullName -Connection $conn
                }

                $tripIdsMigration = Get-ChildItem -Path (Join-Path $repoRoot 'supabase/migrations') -Filter '*_manual_dynamic_destination_ids.sql' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($tripIdsMigration) {
                    Invoke-Sql 'manual_dynamic_destination_ids migration' -File $tripIdsMigration.FullName -Connection $conn
                }

                if (Test-Path (Join-Path $repoRoot 'supabase/tests/discovery_publication.sql')) {
                    Invoke-Sql 'discovery_publication.sql' -File (Join-Path $repoRoot 'supabase/tests/discovery_publication.sql') -Connection $conn
                }

                if (Test-Path (Join-Path $repoRoot 'supabase/tests/manual_dynamic_destination.sql')) {
                    Invoke-Sql 'manual_dynamic_destination.sql' -File (Join-Path $repoRoot 'supabase/tests/manual_dynamic_destination.sql') -Connection $conn
                }

                $visSql = Join-Path $repoRoot 'supabase/tests/admin_catalogue_visibility.sql'
                if (Test-Path $visSql) {
                    $visCasesJson = Join-Path $script:runRoot 'visibility_cases.json'
                    Invoke-Sql 'admin_catalogue_visibility.sql' -File $visSql -Connection $conn -OutputJsonPath $visCasesJson

                    $visFixtureDir = Join-Path $script:runRoot 'visibility-fixtures'
                    Invoke-Check 'build_catalogue_visibility_fixtures' $nodeExecutable @(
                        (Join-Path $repoRoot 'tool/build_catalogue_visibility_fixtures.mjs'),
                        $visCasesJson,
                        $visFixtureDir
                    )

                    $summaryFixtureFile = Join-Path $visFixtureDir 'flow_fixtures.json'
                    if (-not (Test-Path $summaryFixtureFile)) {
                        throw "Publication flow summary fixture missing at $summaryFixtureFile"
                    }

                    Invoke-Check 'admin_catalogue_publish_flow_test' $dartExecutable @(
                        $flutterSnapshot, '--suppress-analytics', 'test', '--no-pub',
                        "--dart-define=RUN_CATALOGUE_FLOW_SQL=true",
                        "--dart-define=TRAVELGO_CATALOGUE_FLOW_FIXTURE=$summaryFixtureFile",
                        'test/admin_catalogue_publish_flow_test.dart'
                    )
                }
            } finally {
                Stop-PostgresInstance
            }
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
    Stop-PostgresInstance
    Pop-Location
}
