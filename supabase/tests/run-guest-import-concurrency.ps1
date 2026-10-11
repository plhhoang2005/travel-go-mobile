param(
  [string]$ProjectRef,
  [string]$ConnectionHost,
  [string]$PsqlPath = 'C:\Program Files\PostgreSQL\18\bin\psql.exe',
  [switch]$ExecuteStaging,
  [switch]$SelfTest
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert-Target([string]$Ref,[string]$HostName) {
  if ($Ref -cne 'bkocylxbuyvdgxccpixx' -or
      $HostName -cne 'db.bkocylxbuyvdgxccpixx.supabase.co') {
    throw 'B3 target rejected: only the exact isolated staging project/host is allowed.'
  }
}
if ($SelfTest) {
  Assert-Target 'bkocylxbuyvdgxccpixx' 'db.bkocylxbuyvdgxccpixx.supabase.co'
  foreach ($pair in @(
    @('oavbymauorhmrjcustzw','db.oavbymauorhmrjcustzw.supabase.co'),
    @('bkocylxbuyvdgxccpixx','localhost'),
    @('bkocylxbuyvdgxccpixx','db.bkocylxbuyvdgxccpixx.supabase.co.evil'),
    @('bkocylxbuyvdgxccpixx','DB.bkocylxbuyvdgxccpixx.supabase.co'),
    @('',''))) {
    $rejected=$false
    try { Assert-Target $pair[0] $pair[1] } catch { $rejected=$true }
    if (-not $rejected) { throw 'Target negative control failed.' }
  }
  Write-Output 'B3 target guard self-test PASS; no connection made.'
  return
}
Assert-Target $ProjectRef $ConnectionHost
foreach ($file in @('guest_import.sql','guest_import_negative_controls.sql')) {
  if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)) {
    throw 'B3 test source missing.'
  }
}
if (-not $ExecuteStaging) {
  Write-Output 'B3 dry run: target/source validation PASS; no connection or SQL execution.'
  return
}
# This switch requires separate Owner approval. Credentials come only from the environment.
if (-not (Test-Path -LiteralPath $PsqlPath -PathType Leaf) -or
    [string]::IsNullOrWhiteSpace($env:PGUSER) -or
    [string]::IsNullOrWhiteSpace($env:PGDATABASE) -or
    [string]::IsNullOrWhiteSpace($env:PGPASSFILE)) {
  throw 'Configure native psql and PGUSER/PGDATABASE/PGPASSFILE without putting secrets in arguments.'
}
if ($env:PGUSER -cne 'postgres' -or $env:PGDATABASE -cne 'postgres' -or
    -not (Test-Path -LiteralPath $env:PGPASSFILE -PathType Leaf)) {
  throw 'The staging runner requires postgres user/database and an existing local PGPASSFILE.'
}
if ($null -eq ([System.Diagnostics.ProcessStartInfo]::new()).GetType().GetProperty('StandardInputEncoding')) {
  throw 'Run this native UTF-8 harness using PowerShell 7; Windows PowerShell 5 is unsupported.'
}
$script:Processes=[System.Collections.Generic.List[System.Diagnostics.Process]]::new()
$script:RunId=[guid]::NewGuid().ToString('N')
$script:Owner=[guid]::NewGuid().ToString()
$script:Email=$script:RunId+'@b3-concurrency.invalid'
$script:Seeded=$false
$script:PrimaryFailure=$null
function Start-Session([string]$Name) {
  $info=[System.Diagnostics.ProcessStartInfo]::new()
  $info.FileName=$PsqlPath
  $info.Arguments='-X -q -A -t -w -v ON_ERROR_STOP=1'
  $info.WorkingDirectory=$PSScriptRoot
  $info.UseShellExecute=$false
  $info.CreateNoWindow=$true
  $info.RedirectStandardInput=$true
  $info.RedirectStandardOutput=$true
  $info.RedirectStandardError=$true
  $info.StandardInputEncoding=[System.Text.UTF8Encoding]::new($false)
  $info.StandardOutputEncoding=[System.Text.UTF8Encoding]::new($false)
  $info.StandardErrorEncoding=[System.Text.UTF8Encoding]::new($false)
  $info.EnvironmentVariables['PGHOST']=$ConnectionHost
  $info.EnvironmentVariables['PGPORT']='5432'
  $info.EnvironmentVariables['PGSSLMODE']='verify-full'
  $info.EnvironmentVariables['PGCONNECT_TIMEOUT']='10'
  $info.EnvironmentVariables['PGCLIENTENCODING']='UTF8'
  $info.EnvironmentVariables['PGAPPNAME']=$script:RunId+'-'+$Name
  # No inherited command/session options may redirect queries to another host.
  $info.EnvironmentVariables.Remove('PGSERVICE')
  $info.EnvironmentVariables.Remove('PGSERVICEFILE')
  $info.EnvironmentVariables.Remove('PGOPTIONS')
  $info.EnvironmentVariables.Remove('PGHOSTADDR')
  $process=[System.Diagnostics.Process]::new()
  $process.StartInfo=$info
  if (-not $process.Start()) { throw 'Could not start owned psql process.' }
  $script:Processes.Add($process)
  $outTask=$process.StandardOutput.ReadToEndAsync()
  $errTask=$process.StandardError.ReadToEndAsync()
  $process.StandardInput.WriteLine("SET statement_timeout='35s'; SET lock_timeout='30s';")
  $process.StandardInput.Flush()
  return @{ Process=$process; Output=$outTask; Error=$errTask; Name=$Name }
}
function Send-Sql($Session,[string]$Sql) {
  $Session.Process.StandardInput.WriteLine($Sql)
  $Session.Process.StandardInput.Flush()
}
function Finish-Session($Session,[int]$DeadlineMs=45000) {
  $Session.Process.StandardInput.Close()
  if (-not $Session.Process.WaitForExit($DeadlineMs)) {
    $Session.Process.Kill()
    throw ('Owned psql timeout: '+$Session.Name)
  }
  $output=$Session.Output.GetAwaiter().GetResult()
  $null=$Session.Error.GetAwaiter().GetResult()
  if ($Session.Process.ExitCode -ne 0) {
    # Raw PostgreSQL errors can contain payloads; do not log stderr/SQL.
    throw ('Staging SQL failed: '+$Session.Name+'; private stderr withheld.')
  }
  return $output.Trim()
}
function Query([string]$Sql,[string]$Name='probe') {
  $session=Start-Session $Name
  Send-Sql $session $Sql
  return Finish-Session $session
}
function Wait-State([string]$Name,[string]$Condition) {
  $timer=[System.Diagnostics.Stopwatch]::StartNew()
  do {
    $observed=Query ("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='"+
      $script:RunId+'-'+$Name+"' AND "+$Condition+");") 'barrier'
    if ($observed -eq 't') { return }
    # Polling backoff only; observed lock/activity is the correctness barrier.
    Start-Sleep -Milliseconds 50
  } while ($timer.ElapsedMilliseconds -lt 15000)
  throw ('Database barrier not observed: '+$Name)
}
function As-Owner([string]$Sql) {
  return "SET ROLE authenticated; SELECT set_config('request.jwt.claims','{""sub"":"""+
    $script:Owner+""",""role"":""authenticated""}',false) IS NOT NULL; "+$Sql
}
function Envelope([string]$Output) {
  $line=@($Output -split "\r?\n" | Where-Object { $_.StartsWith('{') })
  if ($line.Count -ne 1) { throw 'Expected exactly one receipt envelope.' }
  return $line[0] | ConvertFrom-Json
}
function Assert-Same($Left,$Right) {
  if (($Left.receipt | ConvertTo-Json -Compress) -cne ($Right.receipt | ConvertTo-Json -Compress) -or
      $Left.payloadText -cne $Right.payloadText -or $Left.status -cne $Right.status) {
    throw 'Retry receipt/bytes/status changed.'
  }
}
try {
  # No migration apply here. The separately approved staging migration must already exist.
  $null=Query "\i guest_import.sql" 'positive'
  $null=Query "\i guest_import_negative_controls.sql" 'negative'
  # Mark before sending: connection loss after COMMIT must still attempt owned cleanup.
  $script:Seeded=$true
  $null=Query ("INSERT INTO auth.users(id,aud,role,email,raw_user_meta_data,created_at,updated_at) VALUES('"+
    $script:Owner+"','authenticated','authenticated','"+$script:Email+"','{}',now(),now());") 'seed'
  $payload='{"metadata":{"destinationId":null,"destinationName":"Ha Noi","endDate":null,"startDate":null,"timezone":null,"title":"HN"},"plan":null,"request":{"budgetVnd":2000000,"numDays":2,"numPeople":1,"origin":"SG","preferences":["food"],"priority":"balanced"},"schemaVersion":1}'
  $digest='1a492d03942746d47ab927820b52ca8713b0a7f06d095616768915181fedb45e'
  $rpc="SELECT public.import_guest_draft_v1('b3-race','draft',1,'key', '"+$payload+"','"+$digest+"');"
  $one=Start-Session 'same-one'
  Send-Sql $one (As-Owner ('BEGIN; '+$rpc))
  Wait-State 'same-one' "state='idle in transaction'"
  $two=Start-Session 'same-two'
  Send-Sql $two (As-Owner $rpc)
  $two.Process.StandardInput.Close()
  Wait-State 'same-two' "wait_event_type='Lock'"
  Send-Sql $one 'COMMIT;'
  $first=Envelope (Finish-Session $one)
  $second=Envelope (Finish-Session $two)
  Assert-Same $first $second
  if ($first.status -cne 'committed') { throw 'Initial import did not commit.' }
  $counts=Query ("SELECT (SELECT count(*) FROM public.trips WHERE user_id='"+$script:Owner+
    "')=1 AND (SELECT count(*) FROM private.guest_import_receipts WHERE owner_id='"+$script:Owner+"')=1;") 'counts'
  if ($counts -ne 't') { throw 'Concurrent import created duplicates.' }
  # Conflict waiters must see durable identity/digest bindings after owner-lock release.
  $changedPayload=$payload.Replace('"title":"HN"','"title":"HN changed"')
  $sha=[System.Security.Cryptography.SHA256]::Create()
  try { $changedHash=([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($changedPayload)))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
  $conflicts=@(
    @{ Sql=$rpc.Replace("'draft',1,'key'","'draft',1,'other-key'"); Code='identity_conflict' },
    @{ Sql=$rpc.Replace("'draft',1,'key'","'other-draft',1,'key'"); Code='identity_conflict' },
    @{ Sql=$rpc.Replace($payload,$changedPayload).Replace($digest,$changedHash); Code='payload_conflict' }
  )
  $index=0
  foreach ($case in $conflicts) {
    $index++
    $hold=Start-Session ('hold-'+$index)
    Send-Sql $hold (As-Owner ('BEGIN; '+$rpc))
    Wait-State ('hold-'+$index) "state='idle in transaction'"
    $waiter=Start-Session ('conflict-'+$index)
    $escapedSql=$case.Sql.Replace("'","''")
    $control="DO "+'$b3$'+" DECLARE seen boolean:=false; BEGIN BEGIN EXECUTE '"+$escapedSql+
      "'; EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'"+$case.Code+"' THEN RAISE; END IF; seen:=true; END; "+
      "IF NOT seen THEN RAISE EXCEPTION 'missing_expected_conflict'; END IF; END "+'$b3$'+"; SELECT 'conflict PASS';"
    Send-Sql $waiter (As-Owner $control)
    $waiter.Process.StandardInput.Close()
    Wait-State ('conflict-'+$index) "wait_event_type='Lock'"
    Send-Sql $hold 'COMMIT;'
    $null=Finish-Session $hold
    $conflictResult=Finish-Session $waiter
    if ($conflictResult -notmatch 'conflict PASS') { throw 'Conflict negative control did not complete.' }
  }
  # Deliberately discard a committed response. Fresh connection must recover the stored receipt.
  $null=Query (As-Owner $rpc) 'lost-response'
  Assert-Same $first (Envelope (Query (As-Owner $rpc) 'durable-retry'))
  $tripId=[guid]::Parse($first.receipt.tripId).ToString()
  # Read/retry wins: its shared trip lock must block delete until it commits.
  $reader=Start-Session 'read-first'
  Send-Sql $reader (As-Owner ('BEGIN; SELECT public.get_import_trip_snapshot_v1('+"'"+$tripId+"');"))
  Wait-State 'read-first' "state='idle in transaction'"
  $deleter=Start-Session 'delete-second'
  Send-Sql $deleter (As-Owner ("DELETE FROM public.trips WHERE id='"+$tripId+"';"))
  $deleter.Process.StandardInput.Close()
  Wait-State 'delete-second' "wait_event_type='Lock'"
  Send-Sql $reader 'COMMIT;'
  Assert-Same $first (Envelope (Finish-Session $reader))
  $null=Finish-Session $deleter
  $deleted=Envelope (Query (As-Owner $rpc) 'terminal-retry')
  if ($deleted.status -cne 'deleted' -or $null -ne $deleted.payloadText -or
      ($deleted.receipt | ConvertTo-Json -Compress) -cne ($first.receipt | ConvertTo-Json -Compress)) {
    throw 'Deleted retry recreated content or changed receipt.'
  }
  # Separate source: delete wins while import retry waits on the trip.
  $rpc2=$rpc.Replace("'draft',1,'key'","'draft-2',1,'key-2'")
  $live=Envelope (Query (As-Owner $rpc2) 'second-source')
  $trip2=[guid]::Parse($live.receipt.tripId).ToString()
  $deleteFirst=Start-Session 'delete-first'
  Send-Sql $deleteFirst (As-Owner ("BEGIN; DELETE FROM public.trips WHERE id='"+$trip2+"';"))
  Wait-State 'delete-first' "state='idle in transaction'"
  $retry=Start-Session 'retry-second'
  Send-Sql $retry (As-Owner $rpc2)
  $retry.Process.StandardInput.Close()
  Wait-State 'retry-second' "wait_event_type='Lock'"
  Send-Sql $deleteFirst 'COMMIT;'
  $null=Finish-Session $deleteFirst
  $terminal=Envelope (Finish-Session $retry)
  if ($terminal.status -cne 'deleted' -or $null -ne $terminal.payloadText -or
      ($terminal.receipt | ConvertTo-Json -Compress) -cne ($live.receipt | ConvertTo-Json -Compress)) {
    throw 'Delete-first retry was not terminal.'
  }
  Write-Output 'B3 staging suites/races PASS; cleanup must still complete.'
}
catch {
  $script:PrimaryFailure=$_
  throw
}
finally {
  foreach ($process in $script:Processes) {
    if (-not $process.HasExited) { $process.Kill(); $null=$process.WaitForExit(5000) }
  }
  try {
    if ($script:Seeded) {
      # UUID plus exact random email prove fixture ownership. Never enumerate/delete other users.
      $clean=Query ("DELETE FROM auth.users WHERE id='"+$script:Owner+
        "' AND email='"+$script:Email+"'; SELECT NOT EXISTS(SELECT 1 FROM auth.users WHERE id='"+$script:Owner+"');") 'cleanup'
      if ($clean -ne 't') { throw 'Fixture ownership cleanup assertion failed.' }
      $gone=Query ("SELECT NOT EXISTS(SELECT 1 FROM public.trips WHERE user_id='"+$script:Owner+
        "') AND NOT EXISTS(SELECT 1 FROM private.guest_import_receipts WHERE owner_id='"+$script:Owner+"');") 'cleanup-check'
      if ($gone -ne 't') { throw 'Fixture cascade cleanup failed.' }
    }
  } catch {
    $failureSummary='B3 cleanup failed; inspect only synthetic fixture run '+$script:RunId+'.'
    if ($null -ne $script:PrimaryFailure) {
      $failureSummary+=' Earlier execution failure: '+$script:PrimaryFailure.Exception.Message
    }
    throw $failureSummary
  } finally {
    foreach ($process in $script:Processes) { $process.Dispose() }
  }
}
Write-Output 'B3 staging execution and owned-fixture cleanup PASS.'

# Runtime controls use separate disposable accounts and only their owned process.
# Cooperative cancellation is testable; forced host termination/power loss is not.
foreach ($mode in @('sql-error','timeout','cooperative-cancel')) {
  $probeOwner=[guid]::NewGuid().ToString()
  $probeEmail=[guid]::NewGuid().ToString('N')+'@b3-concurrency.invalid'
  $probeSession=$null
  $observedFailure=$null
  $observedCancellation=$false
  try {
    $null=Query ("INSERT INTO auth.users(id,aud,role,email,raw_user_meta_data,created_at,updated_at) VALUES('"+
      $probeOwner+"','authenticated','authenticated','"+$probeEmail+"','{}',now(),now()); "+
      "INSERT INTO public.trips(user_id,title,destination_name) VALUES('"+$probeOwner+"','B3 fault fixture','B3 fault fixture');") ('fault-seed-'+$mode)
    $null=Query ((As-Owner $rpc).Replace($script:Owner,$probeOwner)) ('fault-import-'+$mode)
    $probeSession=Start-Session ('fault-'+$mode)
    try {
      if ($mode -eq 'sql-error') {
        Send-Sql $probeSession 'SELECT 1/0;'
        $null=Finish-Session $probeSession
      } elseif ($mode -eq 'timeout') {
        Send-Sql $probeSession 'SELECT pg_sleep(10);'
        $null=Finish-Session $probeSession 500
      } else {
        Send-Sql $probeSession 'BEGIN; SELECT 1;'
        Wait-State ('fault-'+$mode) "state='idle in transaction'"
        $cancellation=[System.Threading.CancellationTokenSource]::new()
        try { $cancellation.Cancel(); $cancellation.Token.ThrowIfCancellationRequested() }
        finally { $cancellation.Dispose() }
      }
    } catch {
      $observedFailure=$_.Exception.Message
      $observedCancellation=$_.Exception -is [System.OperationCanceledException] -or
        $_.Exception.InnerException -is [System.OperationCanceledException]
    }
    if ($null -eq $observedFailure -or
        ($mode -eq 'sql-error' -and $observedFailure -notlike 'Staging SQL failed:*') -or
        ($mode -eq 'timeout' -and $observedFailure -notlike 'Owned psql timeout:*') -or
        ($mode -eq 'cooperative-cancel' -and -not $observedCancellation)) {
      throw ('Expected owned fault not observed: '+$mode)
    }
  } finally {
    $stopFailure=$null
    try {
      if ($null -ne $probeSession -and -not $probeSession.Process.HasExited) {
        $probeSession.Process.Kill()
        if (-not $probeSession.Process.WaitForExit(5000)) { throw 'Owned fault process did not stop.' }
      }
    } catch { $stopFailure=$_.Exception.Message }
    # A fresh connection cleans committed fixtures even after the owned child fails.
    try {
      $null=Query ("DELETE FROM auth.users WHERE id='"+$probeOwner+"' AND email='"+$probeEmail+"';") ('fault-clean-'+$mode)
      $probeGone=Query ("SELECT NOT EXISTS(SELECT 1 FROM auth.users WHERE id='"+$probeOwner+
        "') AND NOT EXISTS(SELECT 1 FROM public.trips WHERE user_id='"+$probeOwner+
        "') AND NOT EXISTS(SELECT 1 FROM private.guest_import_receipts WHERE owner_id='"+$probeOwner+"');") ('fault-check-'+$mode)
      if ($probeGone -ne 't') { throw 'Owned fault fixture survived cleanup.' }
    } catch {
      throw ('Fault cleanup failed: '+$mode+'; earlier fault: '+$observedFailure+'; fixture '+$probeOwner)
    } finally {
      if ($null -ne $probeSession) { $probeSession.Process.Dispose() }
    }
    if ($null -ne $stopFailure) { throw ('Owned process stop failed after cleanup: '+$stopFailure) }
  }
  Write-Output ('B3 '+$mode+' and independent owned-fixture cleanup PASS.')
}
Write-Output 'B3 extended acceptance and fault-cleanup controls PASS.'
foreach ($process in $script:Processes) { $process.Dispose() }
