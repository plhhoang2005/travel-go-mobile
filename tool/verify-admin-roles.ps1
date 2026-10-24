param([string]$PostgresBin='C:/Program Files/PostgreSQL/18/bin')
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$runRoot=Join-Path $repoRoot ('.dart_tool/admin-r1-postgres/'+[guid]::NewGuid().ToString('N'))
$dataRoot=Join-Path $runRoot 'data'
$logPath=Join-Path $runRoot 'verification.log'
$migration=Join-Path $repoRoot 'supabase/migrations/20261020145005_two_role_foundation.sql'
$bootstrap=Join-Path $repoRoot 'supabase/staging/bootstrap_first_admin.sql'
$psql=Join-Path $PostgresBin 'psql.exe'
$pgCtl=Join-Path $PostgresBin 'pg_ctl.exe'
$started=$false
New-Item -ItemType Directory -Path $runRoot | Out-Null
# Bind to an available loopback port; never connect to an installed/shared server.
$listener=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,0)
$listener.Start()
$port=$listener.LocalEndpoint.Port
$listener.Stop()
$connection=@('-X','-h','127.0.0.1','-p',"$port",'-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1')
function Invoke-Sql([string]$Label,[string]$Sql,[string]$File,[string]$ExpectedError) {
  $arguments=$connection
  if ($File) { $arguments+=@('-f',$File) }
  else { $arguments+=@('-c',$Sql) }
  $output=& $psql @arguments 2>&1
  $code=$LASTEXITCODE
  $output | Out-File -LiteralPath $logPath -Append -Encoding utf8
  if ($ExpectedError) {
    if ($code -eq 0 -or ($output -join "`n") -notmatch [regex]::Escape($ExpectedError)) {
      throw "Expected denial failed: $Label. See $logPath"
    }
  } elseif ($code -ne 0) { throw "SQL failed: $Label. See $logPath" }
  Write-Output "PASS: $Label"
}
try {
  & (Join-Path $PostgresBin 'initdb.exe') -D $dataRoot -U postgres -A trust --encoding=UTF8 --locale=C *> (Join-Path $runRoot 'initdb.log')
  if ($LASTEXITCODE -ne 0) { throw 'Isolated initdb failed' }
  # PowerShell waits for a native console program's descendants on Windows.
  # Start pg_ctl without attaching PostgreSQL to that console wait, then wait
  # only for the pg_ctl process handle (not the long-lived database process).
  $startArguments="-D `"$dataRoot`" -l `"$(Join-Path $runRoot 'server.log')`" -o `"-p $port -h 127.0.0.1`" -w -t 15 start"
  $launcher=Start-Process -FilePath $pgCtl -ArgumentList $startArguments -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $runRoot 'start.log') -RedirectStandardError (Join-Path $runRoot 'start-error.log')
  if (-not $launcher.WaitForExit(20000) -or $launcher.ExitCode -ne 0) { throw 'Isolated PostgreSQL start failed' }
  $started=$true
  Invoke-Sql 'synthetic Supabase auth substrate (not hosted Auth)' @'
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,phone text,raw_user_meta_data jsonb,
  email_confirmed_at timestamptz,created_at timestamptz,updated_at timestamptz);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
GRANT USAGE ON SCHEMA public,auth TO anon,authenticated,service_role;
SELECT version();
'@
  Invoke-Sql 'existing reconstructed baseline' -File (Join-Path $repoRoot 'supabase/staging/baseline.sql')
  Invoke-Sql 'existing privacy migration' -File (Join-Path $repoRoot 'supabase/migrations/202610080001_profile_privacy.sql')
  Invoke-Sql 'existing preferences migration' -File (Join-Path $repoRoot 'supabase/migrations/202610190001_profile_preferences.sql')
  Invoke-Sql 'legacy fixtures and protected ownership snapshot' @'
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('11111119-1111-4111-8111-111111111111','legacy-a@example.invalid','{}'),
 ('22222229-2222-4222-8222-222222222222','legacy-b@example.invalid','{}'),
 ('33333339-3333-4333-8333-333333333333','legacy-c@example.invalid','{}'),
 ('44444449-4444-4444-8444-444444444444','legacy-d@example.invalid','{}');
UPDATE public.profiles SET role='partner' WHERE id='22222229-2222-4222-8222-222222222222';
UPDATE public.profiles SET role=NULL WHERE id='33333339-3333-4333-8333-333333333333';
UPDATE public.profiles SET role='admin' WHERE id='44444449-4444-4444-8444-444444444444';
INSERT INTO public.trips(user_id,title,destination_name) VALUES('11111119-1111-4111-8111-111111111111','R1 preserved trip','Synthetic');
CREATE TABLE r1_ownership_snapshot AS SELECT jsonb_agg(to_jsonb(t)) AS trips FROM public.trips t;
CREATE TABLE r1_policy_snapshot AS SELECT jsonb_agg(to_jsonb(p) ORDER BY tablename,policyname) AS policies
  FROM pg_policies p WHERE schemaname='public';
GRANT UPDATE(role) ON public.profiles TO authenticated;
'@
  Invoke-Sql 'migration rejects unsafe role grant' -File $migration -ExpectedError 'two_role_requires_protected_profiles'
  Invoke-Sql 'restore intended column privileges' 'REVOKE UPDATE(role) ON public.profiles FROM authenticated;'
  Invoke-Sql 'apply R1 on isolated database' -File $migration
  Invoke-Sql 'migration preserves roles, rows, trips and policies' @'
DO $$ BEGIN
 IF (SELECT count(*) FROM public.profiles)<>4 OR
    (SELECT count(*) FROM public.profiles WHERE role='customer')<>3 OR
    (SELECT role FROM public.profiles WHERE id='44444449-4444-4444-8444-444444444444')<>'admin'
 THEN RAISE EXCEPTION 'legacy_role_normalization_failed'; END IF;
 IF (SELECT trips FROM r1_ownership_snapshot) IS DISTINCT FROM
    (SELECT jsonb_agg(to_jsonb(t)) FROM public.trips t)
 THEN RAISE EXCEPTION 'trip_ownership_changed'; END IF;
 IF (SELECT policies FROM r1_policy_snapshot) IS DISTINCT FROM
    (SELECT jsonb_agg(to_jsonb(p) ORDER BY tablename,policyname) FROM pg_policies p WHERE schemaname='public')
 THEN RAISE EXCEPTION 'existing_policies_changed'; END IF;
 IF to_regclass('public.partner_profiles') IS NULL OR to_regclass('public.services') IS NULL
 THEN RAISE EXCEPTION 'legacy_tables_removed'; END IF;
END $$;
'@
  Invoke-Sql 'migration replay fails closed' -File $migration -ExpectedError 'two_role_baseline_drift'
  Invoke-Sql 'grant, constraint, signup and RLS suite (rollback)' -File (Join-Path $repoRoot 'supabase/tests/profile_two_roles.sql')
  Invoke-Sql 'existing preferences regression (rollback)' -File (Join-Path $repoRoot 'supabase/tests/profile_preferences.sql')
  Invoke-Sql 'bootstrap rejects existing administrator' -File $bootstrap -ExpectedError 'bootstrap_already_initialized'
  Invoke-Sql 'remove isolated legacy fixtures' @'
DELETE FROM auth.users WHERE id IN ('11111119-1111-4111-8111-111111111111',
 '22222229-2222-4222-8222-222222222222','33333339-3333-4333-8333-333333333333',
 '44444449-4444-4444-8444-444444444444');
'@
  Invoke-Sql 'bootstrap rejects missing subject' -File $bootstrap -ExpectedError 'bootstrap_subject_missing_or_unconfirmed'
  Invoke-Sql 'synthetic bootstrap target and two customers' @'
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('6346607e-40e0-4182-b887-2cf9d33321f9','bootstrap-r1@example.invalid','{}'),
 ('11111119-1111-4111-8111-111111111111','bootstrap-other-a@example.invalid','{}'),
 ('22222229-2222-4222-8222-222222222222','bootstrap-other-b@example.invalid','{}');
'@
  Invoke-Sql 'bootstrap rejects unconfirmed subject' -File $bootstrap -ExpectedError 'bootstrap_subject_missing_or_unconfirmed'
  Invoke-Sql 'force late audit failure for atomicity test' @'
UPDATE auth.users SET email_confirmed_at=now() WHERE id='6346607e-40e0-4182-b887-2cf9d33321f9';
ALTER TABLE private_admin.role_bootstrap_audit ADD CONSTRAINT r1_reject_test CHECK(false);
'@
  Invoke-Sql 'audit failure aborts promotion' -File $bootstrap -ExpectedError 'r1_reject_test'
  Invoke-Sql 'failed promotion rolled back fully' @'
DO $$ BEGIN
 IF (SELECT role FROM public.profiles WHERE id='6346607e-40e0-4182-b887-2cf9d33321f9')<>'customer'
 OR EXISTS(SELECT 1 FROM private_admin.role_bootstrap_audit)
 THEN RAISE EXCEPTION 'bootstrap_partial_commit'; END IF;
END $$;
ALTER TABLE private_admin.role_bootstrap_audit DROP CONSTRAINT r1_reject_test;
'@
  Invoke-Sql 'bootstrap exact subject with atomic audit' -File $bootstrap
  Invoke-Sql 'bootstrap repeat denied' -File $bootstrap -ExpectedError 'bootstrap_already_initialized'
  Invoke-Sql 'one admin, two unchanged customers, one honest audit' @'
DO $$ BEGIN
 IF (SELECT count(*) FROM public.profiles WHERE role='admin')<>1
 OR (SELECT role FROM public.profiles WHERE id='6346607e-40e0-4182-b887-2cf9d33321f9')<>'admin'
 OR (SELECT count(*) FROM public.profiles WHERE role='customer')<>2
 OR (SELECT count(*) FROM private_admin.role_bootstrap_audit WHERE
   subject_id='6346607e-40e0-4182-b887-2cf9d33321f9' AND old_role='customer'
   AND new_role='admin' AND actor_db_role=session_user)<>1
 THEN RAISE EXCEPTION 'bootstrap_readback_mismatch'; END IF;
END $$;
'@
  Write-Output "LOCAL SQL VERIFICATION PASSED. Evidence: $runRoot"
} finally {
  if ($started) {
    & $pgCtl -D $dataRoot -m fast -w -t 15 stop *> (Join-Path $runRoot 'stop.log')
    if ($LASTEXITCODE -ne 0) { Write-Warning "Isolated PostgreSQL stop failed: $dataRoot" }
  }
}
