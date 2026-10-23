param(
  [ValidateSet('Sql')]
  [string]$Mode = 'Sql',
  [switch]$DryRun,
  [switch]$SelfTest,
  [string]$FlutterRoot = 'D:/flutter/flutter',
  [string]$PostgresBin = 'C:/Program Files/PostgreSQL/18/bin'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$runId = [guid]::NewGuid().ToString('N')
$runRoot = Join-Path $repoRoot (".dart_tool/planner-core-verification/$runId")
$dataRoot = Join-Path $runRoot 'data'
$logPath = Join-Path $runRoot 'verification.log'
$fixtureDir = Join-Path $runRoot 'fixtures'

New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null

$psql = Join-Path $PostgresBin 'psql.exe'
$pgCtl = Join-Path $PostgresBin 'pg_ctl.exe'
$initDb = Join-Path $PostgresBin 'initdb.exe'

$flutter = Join-Path $FlutterRoot 'bin/flutter.bat'
if (-not (Test-Path $flutter)) {
  $flutter = 'flutter'
}

if ($DryRun) {
  Write-Output "DryRun: planner-core verification script syntax OK."
  exit 0
}

if ($SelfTest) {
  Write-Output "Running SelfTest for planner-core verification..."
  # Prove that an invalid SQL query causes non-zero exit and properly cleans up
  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
  $listener.Start()
  $testPort = $listener.LocalEndpoint.Port
  $listener.Stop()

  $selfData = Join-Path $runRoot 'selftest_data'
  & $initDb -D $selfData -U postgres -A trust --encoding=UTF8 --locale=C *> (Join-Path $runRoot 'selftest_initdb.log')
  $startArgs = "-D `"$selfData`" -l `"$(Join-Path $runRoot 'selftest_server.log')`" -o `"-p $testPort -h 127.0.0.1`" -w -t 15 start"
  $launcher = Start-Process -FilePath $pgCtl -ArgumentList $startArgs -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $runRoot 'selftest_start.log') -RedirectStandardError (Join-Path $runRoot 'selftest_start_err.log')
  $launcher.WaitForExit(15000)

  try {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $errOut = & $psql -X -h 127.0.0.1 -p $testPort -U postgres -d postgres -v ON_ERROR_STOP=1 -c "SELECT syntax_error_here;" 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -eq 0) {
      throw "SelfTest failed: invalid SQL did not fail."
    }
    Write-Output "SelfTest PASS: syntax error correctly caught and returned non-zero ($code)."
  } finally {
    & $pgCtl -D $selfData -m immediate stop *> $null
    Remove-Item -Recurse -Force -LiteralPath $selfData -ErrorAction SilentlyContinue
  }
  exit 0
}

# 1. Step 1: Export fixtures from Dart test
Write-Output "Exporting SQL fixtures from Dart test..."
$exportArgs = @(
  'test',
  'test/planner_result_persistence_test.dart',
  "--dart-define=PLANNER_EXPORT_SQL_FIXTURES=true",
  "--dart-define=PLANNER_SQL_FIXTURE_DIR=$fixtureDir"
)
& $flutter @exportArgs
if ($LASTEXITCODE -ne 0) {
  throw "Failed to export SQL fixtures from Dart persistence test."
}

$payloadFile = Join-Path $fixtureDir 'payload.json'
$digestFile = Join-Path $fixtureDir 'digest.txt'
if (-not (Test-Path $payloadFile) -or -not (Test-Path $digestFile)) {
  throw "Missing exported fixtures: payload.json or digest.txt not found in $fixtureDir"
}

# 2. Step 2: Spin up isolated PostgreSQL server
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()

$connection = @('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1')

function Invoke-Sql([string]$Label, [string]$Sql, [string]$File, [string]$ExpectedError) {
  $arguments = $connection
  if ($File) { $arguments += @('-f', $File) }
  else { $arguments += @('-c', $Sql) }
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = & $psql @arguments 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  $output | Out-File -LiteralPath $logPath -Append -Encoding utf8
  if ($ExpectedError) {
    if ($code -eq 0 -or ($output -join "`n") -notmatch [regex]::Escape($ExpectedError)) {
      throw "Expected denial failed: $Label. See $logPath"
    }
  } elseif ($code -ne 0) {
    throw "SQL failed: $Label. Output: $($output -join "`n")"
  }
  Write-Output "PASS: $Label"
}

$started = $false
try {
  & $initDb -D $dataRoot -U postgres -A trust --encoding=UTF8 --locale=C *> (Join-Path $runRoot 'initdb.log')
  if ($LASTEXITCODE -ne 0) { throw 'Isolated initdb failed' }

  $startArguments = "-D `"$dataRoot`" -l `"$(Join-Path $runRoot 'server.log')`" -o `"-p $port -h 127.0.0.1`" -w -t 15 start"
  $launcher = Start-Process -FilePath $pgCtl -ArgumentList $startArguments -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $runRoot 'start.log') -RedirectStandardError (Join-Path $runRoot 'start-error.log')
  $launcher.WaitForExit(20000)
  Start-Sleep -Milliseconds 500
  if ($launcher.ExitCode -ne 0) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $testConn = & $psql -X -h 127.0.0.1 -p $port -U postgres -d postgres -c "SELECT 1;" 2>&1
    $ErrorActionPreference = $prev
    if ($LASTEXITCODE -ne 0) {
      throw "Isolated PostgreSQL start failed: exit code $($launcher.ExitCode)"
    }
  }
  $started = $true

  # Setup Auth & extensions
  Invoke-Sql 'synthetic Supabase substrate' @'
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY, aud text, role text, email text, phone text, raw_user_meta_data jsonb,
  email_confirmed_at timestamptz, created_at timestamptz, updated_at timestamptz);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.role',true),'')::text;
$$;
GRANT USAGE ON SCHEMA public, auth, extensions TO anon, authenticated, service_role;
'@

  # Run baseline and prerequisite migrations
  Invoke-Sql 'baseline' -File (Join-Path $repoRoot 'supabase/staging/baseline.sql')
  Invoke-Sql 'privacy' -File (Join-Path $repoRoot 'supabase/migrations/202610080001_profile_privacy.sql')
  Invoke-Sql 'guest_import' -File (Join-Path $repoRoot 'supabase/migrations/202610100001_guest_import.sql')
  Invoke-Sql 'planner_request_context' -File (Join-Path $repoRoot 'supabase/migrations/20261023173436_planner_request_context.sql')

  # Run SQL tests
  Invoke-Sql 'guest_import.sql' -File (Join-Path $repoRoot 'supabase/tests/guest_import.sql')
  Invoke-Sql 'planner_request_context.sql' -File (Join-Path $repoRoot 'supabase/tests/planner_request_context.sql')

  # Validate the exported fixture from Dart inside PostgreSQL
  $rawPayloadText = [System.IO.File]::ReadAllText($payloadFile, [System.Text.Encoding]::UTF8)
  $rawDigest = [System.IO.File]::ReadAllText($digestFile, [System.Text.Encoding]::UTF8).Trim()

  # Write bridge script to validate fixture and write result
  $bridgeSql = Join-Path $runRoot 'validate_bridge.sql'
  $escapedPayload = $rawPayloadText.Replace("'", "''")
  $bridgeScript = "\set ON_ERROR_STOP on`n" +
"DO `$`$`n" +
"DECLARE`n" +
"  p text := '$escapedPayload';`n" +
"  res jsonb;`n" +
"  calc_digest text;`n" +
"BEGIN`n" +
"  res := private.validate_guest_payload_v1(p);`n" +
"  calc_digest := encode(extensions.digest(convert_to(p, 'UTF8'), 'sha256'), 'hex');`n" +
"  IF calc_digest <> '$rawDigest' THEN`n" +
"    RAISE EXCEPTION 'Digest mismatch between Dart and SQL: % vs %', calc_digest, '$rawDigest';`n" +
"  END IF;`n" +
"END `$`$;`n"
  $bridgeScript | Out-File -LiteralPath $bridgeSql -Encoding utf8

  Invoke-Sql 'validate Dart fixture against SQL validator' -File $bridgeSql

  # Record success result for Dart test
  @{
    status = "ok"
    validated = $true
    digest = $rawDigest
  } | ConvertTo-Json | Out-File -LiteralPath (Join-Path $fixtureDir 'result.json') -Encoding utf8

  # Step 3: Run Dart test with PLANNER_SQL_FIXTURES=true to verify bridge
  Write-Output "Running Dart verification against SQL fixture result..."
  $verifyArgs = @(
    'test',
    'test/planner_result_persistence_test.dart',
    "--dart-define=PLANNER_SQL_FIXTURES=true",
    "--dart-define=PLANNER_SQL_FIXTURE_DIR=$fixtureDir"
  )
  & $flutter @verifyArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Dart test failed when asserting SQL fixture results."
  }

  Write-Output "PASS: All planner core SQL and Dart persistence tests passed."
} finally {
  if ($started) {
    & $pgCtl -D $dataRoot -m immediate stop *> $null
  }
  Remove-Item -Recurse -Force -LiteralPath $runRoot -ErrorAction SilentlyContinue
}
