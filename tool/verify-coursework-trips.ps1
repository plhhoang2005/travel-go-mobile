[CmdletBinding()]
param(
  [string]$PostgresBin = 'C:/Program Files/PostgreSQL/18/bin',
  [string]$FlutterRoot = 'D:/flutter/flutter',
  [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$runRoot = Join-Path $repoRoot ('.dart_tool/coursework-trip-sql/' + [guid]::NewGuid().ToString('N'))
$dataRoot = Join-Path $runRoot 'data'
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$psql = Join-Path $PostgresBin 'psql.exe'
$pgCtl = Join-Path $PostgresBin 'pg_ctl.exe'
$initDb = Join-Path $PostgresBin 'initdb.exe'
foreach ($binary in @($psql,$pgCtl,$initDb)) {
  if (-not (Test-Path -LiteralPath $binary)) { throw "Missing installed PostgreSQL runtime: $binary" }
}
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$connection = @('-X','-h','127.0.0.1','-p',"$port",'-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1')
$started = $false
function Invoke-LocalSql([string]$Label,[string]$File,[string]$Sql) {
  $arguments = $connection
  if ($Label -eq '20261016034905_editable_trip_v2') {
    # PG18 catalogs NOT NULL as contype=n; the archived fingerprint is PG17.
    # Column attnotnull checks remain intact. Only adapt the local test copy.
    $archived = [IO.File]::ReadAllText($File)
    $localCopy = Join-Path $runRoot 'editable-v2-pg18-fixture.sql'
    $adapted = $archived.Replace('FROM pg_constraint WHERE','FROM pg_constraint WHERE contype<>''n'' AND')
    [IO.File]::WriteAllText($localCopy,$adapted,[Text.UTF8Encoding]::new($false))
    $File = $localCopy
  }
  if ($Label -eq '20261023170000_manual_dynamic_destination_ids') {
    # The archived migration omitted the pgcrypto schema. Bootstrap only the
    # intended helpers here; the new forward migration installs these fixes too.
    # Do not claim this adapter proves an unmodified historical migration chain.
    $archived = [IO.File]::ReadAllText($File)
    $localCopy = Join-Path $runRoot 'dynamic-destination-crypto-fixture.sql'
    $adapted = [regex]::Replace($archived,'(?<![\w.])digest\(','extensions.digest(')
    # CREATE OR REPLACE cannot rename the previous p32_utc argument.
    $adapted = $adapted.Replace('private.p32_utc(t timestamptz)','private.p32_utc(v timestamptz)').Replace('to_char(t AT TIME ZONE','to_char(v AT TIME ZONE')
    [IO.File]::WriteAllText($localCopy,$adapted,[Text.UTF8Encoding]::new($false))
    $File = $localCopy
  }
  if ($File) { $arguments += @('-f',$File) } else { $arguments += @('-c',$Sql) }
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = & $psql @arguments 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  $output | Out-File -LiteralPath (Join-Path $runRoot "$Label.log") -Encoding utf8
  if ($code -ne 0) {
    if ($Label -eq '20261016034905_editable_trip_v2') {
      $source = [IO.File]::ReadAllText($File)
      $query = [regex]::Match($source,'SELECT jsonb_build_object\([\s\S]*?\) INTO actual;').Value.Replace(' INTO actual','')
      & $psql @connection -At -c $query *> (Join-Path $runRoot 'baseline-actual.json')
      $expected = [regex]::Match($source,'\$baseline\$([\s\S]*?)\$baseline\$').Groups[1].Value
      [IO.File]::WriteAllText((Join-Path $runRoot 'baseline-expected.json'),$expected)
    }
    throw "SQL $Label failed; evidence: $runRoot/$Label.log"
  }
  Write-Output "$Label PASS"
}
Push-Location $repoRoot
try {
  & $initDb -D $dataRoot -U postgres -A trust --encoding=UTF8 --locale=C *> (Join-Path $runRoot 'initdb.log')
  if ($LASTEXITCODE -ne 0) { throw "initdb failed: $runRoot/initdb.log" }
  $startArgs = "-D `"$dataRoot`" -l `"$(Join-Path $runRoot 'server.log')`" -o `"-p $port -h 127.0.0.1`" -w -t 20 start"
  $process = Start-Process -FilePath $pgCtl -ArgumentList $startArgs -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $runRoot 'start.log') -RedirectStandardError (Join-Path $runRoot 'start-error.log')
  if (-not $process.WaitForExit(30000)) { throw "pg_ctl start timed out: $runRoot" }
  $ready = $false
  for ($i = 0; $i -lt 15; $i++) {
    & $psql @connection -c 'SELECT 1;' *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Milliseconds 500
  }
  if (-not $ready) { throw "Local PostgreSQL start failed: $runRoot/server.log" }
  $started = $true
  if ($SelfTest) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $errOut = & $psql @connection -c 'SELECT coursework_runner_must_fail();' 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    $errOut | Out-File -LiteralPath (Join-Path $runRoot 'expected-error.log') -Encoding utf8
    if ($code -eq 0) { throw 'Runner swallowed a SQL failure.' }
    Write-Output "SelfTest PASS: SQL failure returned nonzero; evidence $runRoot"
    exit 0
  }
  Invoke-LocalSql -Label substrate -Sql @'
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE SCHEMA supabase_migrations;
CREATE TABLE supabase_migrations.schema_migrations(version text PRIMARY KEY,name text,statements text[]);
CREATE TABLE auth.users(id uuid PRIMARY KEY, aud text, role text, email text, phone text,
 raw_user_meta_data jsonb DEFAULT '{}', raw_app_meta_data jsonb DEFAULT '{}',
 email_confirmed_at timestamptz, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now(),
 banned_until timestamptz, deleted_at timestamptz, is_anonymous boolean DEFAULT false);
CREATE TABLE auth.sessions(id uuid PRIMARY KEY,user_id uuid REFERENCES auth.users(id),created_at timestamptz DEFAULT now(),not_after timestamptz);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.role',true),'') $$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
GRANT USAGE ON SCHEMA public,auth,extensions TO anon,authenticated,service_role;
'@
  Invoke-LocalSql -Label baseline -File (Join-Path $repoRoot 'supabase/staging/baseline.sql')
  foreach ($migration in Get-ChildItem (Join-Path $repoRoot 'supabase/migrations') -Filter '*.sql' | Sort-Object Name) {
    Invoke-LocalSql -Label $migration.BaseName -File $migration.FullName
    $version = $migration.BaseName.Split('_')[0]
    $name = $migration.BaseName.Substring($version.Length + 1).Replace("'","''")
    Invoke-LocalSql -Label ($migration.BaseName + '-history') -Sql "INSERT INTO supabase_migrations.schema_migrations VALUES ('$version','$name',ARRAY[]::text[])"
  }
  Invoke-LocalSql -Label ai-request-lookup -File (Join-Path $repoRoot 'supabase/tests/ai_request_lookup.sql')
  $dart = Join-Path $FlutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
  $flutter = Join-Path $FlutterRoot 'bin/cache/flutter_tools.snapshot'
  & $dart $flutter test --no-pub --reporter=expanded test/coursework_trip_roundtrip_test.dart --plain-name 'SQL fixture export' '--dart-define=COURSEWORK_EXPORT_SQL=true' "--dart-define=COURSEWORK_SQL_FIXTURE_DIR=$runRoot" *> (Join-Path $runRoot 'fixture-export.log')
  if ($LASTEXITCODE -ne 0) { throw "Dart fixture export failed: $runRoot/fixture-export.log" }
  $raw = [IO.File]::ReadAllText((Join-Path $runRoot 'document.json'))
  $tag = '$c5_' + [guid]::NewGuid().ToString('N') + '$'
  if ($raw.Contains($tag)) { throw 'SQL fixture delimiter collision.' }
  $prefix = 'CREATE TEMP TABLE c5_fixture(raw_text text); INSERT INTO c5_fixture VALUES (' + $tag + $raw + $tag + ');' + [Environment]::NewLine
  $sql = $prefix + [IO.File]::ReadAllText((Join-Path $repoRoot 'supabase/tests/coursework_trip_roundtrip.sql'))
  $suite = Join-Path $runRoot 'suite.sql'
  [IO.File]::WriteAllText($suite,$sql,[Text.UTF8Encoding]::new($false))
  Invoke-LocalSql -Label coursework-roundtrip -File $suite
  if (Test-Path -LiteralPath (Join-Path $repoRoot 'supabase/tests/trip_evidence_contract.sql')) {
    $evidenceVector = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'test/fixtures/trip_evidence_persistence_vectors.json') | ConvertFrom-Json
    $evidenceTag = '$evidence_' + [guid]::NewGuid().ToString('N') + '$'
    $evidencePrefix = 'CREATE TEMP TABLE e_fixture(raw_text text); INSERT INTO e_fixture VALUES (' + $evidenceTag + $evidenceVector.canonicalText + $evidenceTag + ');' + [Environment]::NewLine
    $evidenceSql = $evidencePrefix + [IO.File]::ReadAllText((Join-Path $repoRoot 'supabase/tests/trip_evidence_contract.sql'))
    $evidenceSuite = Join-Path $runRoot 'evidence-suite.sql'
    [IO.File]::WriteAllText($evidenceSuite,$evidenceSql,[Text.UTF8Encoding]::new($false))
    Invoke-LocalSql -Label trip-evidence-contract -File $evidenceSuite
  }
  Invoke-LocalSql -Label admin-control-final-schema -File (Join-Path $repoRoot 'supabase/tests/admin_account_control.sql')
  Invoke-LocalSql -Label admin-concurrency-final-schema -File (Join-Path $repoRoot 'supabase/tests/admin_account_concurrency.sql')
  Invoke-LocalSql -Label admin-guards-final-schema -File (Join-Path $repoRoot 'supabase/tests/admin_account_surface_guards.sql')
  Invoke-LocalSql -Label coursework-admin-final-schema -File (Join-Path $repoRoot 'supabase/tests/coursework_admin_account_contract.sql')
  & $dart $flutter test --no-pub --reporter=expanded test/ai_evidence_context_test.dart --plain-name 'SQL A3 context export' "--dart-define=A3_CONTEXT_EXPORT_DIR=$runRoot" *> (Join-Path $runRoot 'a3-context-export.log')
  if ($LASTEXITCODE -ne 0) { throw "A3 context export failed: $runRoot/a3-context-export.log" }
  $node = (Get-Command node -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
  & $node tool/a3-catalogue-bridge.mjs $runRoot $psql "$port" *> (Join-Path $runRoot 'a3-gateway-bridge.log')
  if ($LASTEXITCODE -ne 0) { throw "A3 gateway/SQL bridge failed: $runRoot/a3-gateway-bridge.log" }
  $a3Values = @('a3-request.json','a3-receipt.json','a3-envelope.json') | ForEach-Object {
    $raw = [IO.File]::ReadAllText((Join-Path $runRoot $_))
    $tag = '$a3_' + [guid]::NewGuid().ToString('N') + '$'
    if ($raw.Contains($tag)) { throw 'A3 fixture delimiter collision' }
    $tag + $raw + $tag + '::jsonb'
  }
  $a3Prefix = 'CREATE TEMP TABLE a3_fixture(request jsonb,receipt jsonb,envelope jsonb); INSERT INTO a3_fixture VALUES (' + ($a3Values -join ',') + ');' + [Environment]::NewLine
  $a3Suite = Join-Path $runRoot 'a3-receipt-suite.sql'
  [IO.File]::WriteAllText($a3Suite,$a3Prefix+[IO.File]::ReadAllText((Join-Path $repoRoot 'supabase/tests/catalogue_evidence_receipt.sql')),[Text.UTF8Encoding]::new($false))
  Invoke-LocalSql -Label catalogue-evidence-receipt -File $a3Suite
  Write-Output "C5 SQL PASS; local isolated database only; evidence: $runRoot"
} finally {
  if ($started -or (Test-Path -LiteralPath (Join-Path $dataRoot 'postmaster.pid'))) {
    & $pgCtl -D $dataRoot -m immediate -w stop *> (Join-Path $runRoot 'stop.log')
    if ($LASTEXITCODE -ne 0) { throw "Local PostgreSQL stop failed: $runRoot/stop.log" }
  }
  Pop-Location
}
