param(
  [string]$ProjectRef,
  [string]$ConnectionHost,
  [string]$PsqlPath = 'C:\Program Files\PostgreSQL\18\bin\psql.exe',
  [switch]$ExecuteStaging,
  [switch]$SelfTest
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Assert-Target([string]$Ref,[string]$HostName) {
  if ($Ref -cne 'bkocylxbuyvdgxccpixx' -or $HostName -cne 'db.bkocylxbuyvdgxccpixx.supabase.co') {
    throw 'P32 target rejected; exact isolated staging ref and direct host required.'
  }
}
function Assert-Sources([string[]]$Paths) {
  foreach ($path in $Paths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'P32 required source missing.' }
  }
}
function Assert-True([bool]$Ok,[string]$Label) {
  if (-not $Ok) { throw ('P32 assertion failed: '+$Label) }
}
function Assert-Rejected([scriptblock]$Action,[string]$Label) {
  $caught=$false
  try { $null=& $Action } catch { $caught=$true }
  Assert-True $caught $Label
}
function Get-Sha256([string]$Text) {
  $sha=[Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
}
function Sql-Literal([AllowNull()]$Value) {
  if ($null -eq $Value) { return 'NULL' }
  do { $tag='$p32_'+[guid]::NewGuid().ToString('N')+'$' } while ($Value.Contains($tag))
  return $tag+$Value+$tag
}
function Get-Optional($Object,[string]$Name) {
  $property=$Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}
function Get-VectorSql([string]$Path) {
  Assert-Sources @($Path)
  $utf8=[Text.UTF8Encoding]::new($false,$true)
  $vectors=@([IO.File]::ReadAllText($Path,$utf8) | ConvertFrom-Json)
  Assert-True ($vectors.Count -eq 5 -and @($vectors.id | Select-Object -Unique).Count -eq 5) 'complete unique T1 corpus'
  $sql='CREATE TEMP TABLE p32_vectors(name text PRIMARY KEY,raw_text text NOT NULL,canonical_text text,expected_digest text,expected_error text);'
  foreach ($v in $vectors) {
    $canonical=Get-Optional $v 'canonicalText'
    $digest=Get-Optional $v 'expectedDigest'
    $errorCode=Get-Optional $v 'expectedError'
    if ($null -eq $errorCode) { Assert-True ((Get-Sha256 $v.rawText) -ceq $digest) 'T1 exact submitted digest' }
    # rawText is passed verbatim; never decode/re-encode the JSON inside it.
    $values=@($v.id,$v.rawText,$canonical,$digest,$errorCode) | ForEach-Object { Sql-Literal $_ }
    $sql+='INSERT INTO p32_vectors VALUES('+($values -join ',')+');'
  }
  return $sql
}
function Assert-Fixture([string]$Owner,[string]$Email,[string]$RunId) {
  $id=[guid]::Empty
  if (-not [guid]::TryParseExact($Owner,'D',[ref]$id) -or $id -eq [guid]::Empty -or $id.ToString() -cne $Owner -or
      $RunId -cnotmatch '^[0-9a-f]{32}$' -or $Email -cne ($RunId+'-'+$Owner+'@p32-concurrency.invalid')) {
    throw 'P32 cleanup refused: synthetic owner/email/run identity mismatch.'
  }
}
function Get-CleanupSql([string]$Owner,[string]$Email,[string]$RunId) {
  Assert-Fixture $Owner $Email $RunId
  $id=Sql-Literal $Owner; $mail=Sql-Literal $Email
  return ('DO $clean$ BEGIN IF EXISTS(SELECT 1 FROM auth.users WHERE id='+$id+'::uuid AND email IS DISTINCT FROM '+$mail+
    ') THEN RAISE EXCEPTION ''fixture_identity_mismatch''; END IF; DELETE FROM auth.users WHERE id='+$id+'::uuid AND email='+$mail+
    '; END $clean$; SELECT NOT EXISTS(SELECT 1 FROM auth.users WHERE id='+$id+'::uuid)'+
    ' AND NOT EXISTS(SELECT 1 FROM public.trips WHERE user_id='+$id+'::uuid)'+
    ' AND NOT EXISTS(SELECT 1 FROM private.editable_trip_documents WHERE owner_id='+$id+'::uuid)'+
    ' AND NOT EXISTS(SELECT 1 FROM private.editable_trip_mutations WHERE owner_id='+$id+'::uuid)'+
    ' AND NOT EXISTS(SELECT 1 FROM private.guest_import_receipts WHERE owner_id='+$id+'::uuid);')
}
function Assert-Exit([bool]$Exited,[int]$ExitCode,[string]$Name) {
  if (-not $Exited) { throw ('P32 owned process timeout: '+$Name) }
  if ($ExitCode -ne 0) { throw ('P32 SQL failed: '+$Name+'; private stdout/stderr withheld.') }
}
function Stop-OwnedProcess($Process) {
  if (-not $Process.HasExited) { $Process.Kill($true); $null=$Process.WaitForExit(5000) }
}
function Finish-Session($Session,[int]$DeadlineMs=45000) {
  $Session.Process.StandardInput.Close()
  $exited=$Session.Process.WaitForExit($DeadlineMs)
  if (-not $exited) { Stop-OwnedProcess $Session.Process; Assert-Exit $false 0 $Session.Name }
  $output=$Session.Output.GetAwaiter().GetResult(); $null=$Session.Error.GetAwaiter().GetResult()
  Assert-Exit $true $Session.Process.ExitCode $Session.Name
  return $output.Trim()
}
function Invoke-NativeControl([ValidateSet('success','nonzero','timeout')][string]$Mode) {
  # Local disposable pwsh children exercise the SAME finish/kill/drain path as
  # psql, without a database connection or credential arguments.
  $program=switch ($Mode) {
    'success' { '[Console]::Out.Write(''native-control''); [Console]::Error.Write(''synthetic stderr''); exit 0' }
    'nonzero' { '[Console]::Error.Write(''synthetic stderr''); exit 7' }
    'timeout' { 'Start-Sleep -Seconds 10' }
  }
  $info=[Diagnostics.ProcessStartInfo]::new()
  $info.FileName=Join-Path $PSHOME 'pwsh.exe'
  $info.Arguments='-NoProfile -NonInteractive -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($program))
  $info.UseShellExecute=$false; $info.CreateNoWindow=$true
  $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
  $process=[Diagnostics.Process]::new(); $process.StartInfo=$info
  try {
    if (-not $process.Start()) { throw 'Native control start failed.' }
    $session=@{Process=$process;Output=$process.StandardOutput.ReadToEndAsync();Error=$process.StandardError.ReadToEndAsync();Name='native-'+$Mode}
    $deadline=if ($Mode -ceq 'timeout') { 100 } else { 5000 }
    return Finish-Session $session $deadline
  } finally { Stop-OwnedProcess $process; $process.Dispose() }
}
function Invoke-RunnerSelfTest([string]$VectorPath) {
  Assert-Target 'bkocylxbuyvdgxccpixx' 'db.bkocylxbuyvdgxccpixx.supabase.co'
  foreach ($pair in @(
    @('oavbymauorhmrjcustzw','db.oavbymauorhmrjcustzw.supabase.co'),
    @('bkocylxbuyvdgxccpixx','localhost'),@('bkocylxbuyvdgxccpixx','db.bkocylxbuyvdgxccpixx.supabase.co.evil'),
    @('BKOCYLXBUYVDGXCCPIXX','db.bkocylxbuyvdgxccpixx.supabase.co'),
    @('bkocylxbuyvdgxccpixx','DB.bkocylxbuyvdgxccpixx.supabase.co'),@('',''))) {
    Assert-Rejected { Assert-Target $pair[0] $pair[1] } 'target negative control'
  }
  Assert-Rejected { Assert-Sources @($VectorPath+'.missing') } 'missing source'
  Assert-Rejected { Assert-Exit $false 0 'unit-timeout' } 'timeout control'
  Assert-Rejected { Assert-Exit $true 1 'unit-exit' } 'nonzero control'
  Assert-Exit $true 0 'unit-success'
  Assert-True ((Invoke-NativeControl 'success') -ceq 'native-control') 'native process output/drain'
  Assert-Rejected { Invoke-NativeControl 'nonzero' } 'native nonzero process'
  Assert-Rejected { Invoke-NativeControl 'timeout' } 'native timeout/kill'
  $run=[guid]::NewGuid().ToString('N'); $owner=[guid]::NewGuid().ToString(); $email=$run+'-'+$owner+'@p32-concurrency.invalid'
  Assert-Fixture $owner $email $run
  Assert-Rejected { Get-CleanupSql $owner 'other@p32-concurrency.invalid' $run } 'cleanup mismatched email'
  Assert-Rejected { Get-CleanupSql ([guid]::NewGuid().ToString()) $email $run } 'cleanup mismatched owner'
  Assert-Rejected { Get-CleanupSql $owner $email ($run+'x') } 'cleanup mismatched run'
  $literal=Sql-Literal "quote' ; \\ \n `$p32`$ tiếng Việt 😀"
  $tag=[regex]::Match($literal,'^\$p32_[0-9a-f]{32}\$').Value
  Assert-True ($tag.Length -gt 0 -and $literal.EndsWith($tag) -and ($literal.Split(@($tag),[StringSplitOptions]::None)).Length -eq 3) 'safe dollar delimiter'
  $sql=Get-VectorSql $VectorPath
  $vectors=@(Get-Content -LiteralPath $VectorPath -Raw -Encoding utf8 | ConvertFrom-Json)
  foreach ($v in $vectors) { Assert-True ($sql.Contains($v.rawText)) 'raw vector byte preservation' }
  Assert-True ((Sql-Literal $null) -ceq 'NULL' -and (Sql-Literal '') -cne 'NULL') 'SQL null distinct from empty text'
  Assert-True ((Get-CleanupSql $owner $email $run).Contains('email IS DISTINCT FROM')) 'cleanup database identity guard'
  # Detector must reject a deliberately false assertion and an unobserved error.
  Assert-Rejected { Assert-True $false 'deliberately broken' } 'assertion detector'
  Assert-Rejected { Assert-Rejected { $null=1 } 'missing error' } 'negative detector'
  Write-Output 'P32 SelfTest PASS; target/source/vector/exit/cleanup controls; no connection made.'
}

$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$vectorPath=Join-Path $repoRoot 'test/fixtures/editable_trip_v2_vectors.json'
$sourcePaths=@(
  (Join-Path $PSScriptRoot 'editable_trip_v2.sql'),(Join-Path $PSScriptRoot 'editable_trip_v2_negative_controls.sql'),
  (Join-Path $repoRoot 'supabase/migrations/20261016034905_editable_trip_v2.sql'),$vectorPath,
  (Join-Path $PSScriptRoot 'guest_import.sql'),(Join-Path $PSScriptRoot 'guest_import_negative_controls.sql'))
Assert-Sources $sourcePaths
if ($SelfTest) {
  if ($ExecuteStaging) { throw 'SelfTest cannot be combined with ExecuteStaging.' }
  Invoke-RunnerSelfTest $vectorPath
  return
}
Assert-Target $ProjectRef $ConnectionHost
$vectorSql=Get-VectorSql $vectorPath
if (-not $ExecuteStaging) {
  Write-Output 'P32 dry run PASS: exact staging target, SQL sources and T1 vectors; no connection or SQL execution.'
  return
}
# Owner must separately approve the exact migration and this write/test/cleanup run.
# This runner NEVER applies DDL. Migration must already have been applied separately.
Assert-Sources @($PsqlPath)
if ($PSVersionTable.PSVersion.Major -lt 7 -or $env:PGUSER -cne 'postgres' -or $env:PGDATABASE -cne 'postgres' -or
    [string]::IsNullOrWhiteSpace($env:PGPASSFILE) -or -not (Test-Path -LiteralPath $env:PGPASSFILE -PathType Leaf)) {
  throw 'Use PowerShell 7, native psql, PGUSER/PGDATABASE=postgres and existing PGPASSFILE; no credential arguments.'
}
$script:RunId=[guid]::NewGuid().ToString('N')
$script:Stage='initial-suites'
$script:Processes=[Collections.Generic.List[Diagnostics.Process]]::new()
$script:Fixtures=[Collections.Generic.List[hashtable]]::new()
function Start-Session([string]$Name) {
  $info=[Diagnostics.ProcessStartInfo]::new()
  $info.FileName=$PsqlPath; $info.Arguments='-X -q -A -t -w -v ON_ERROR_STOP=1'
  $info.WorkingDirectory=$PSScriptRoot; $info.UseShellExecute=$false; $info.CreateNoWindow=$true
  $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
  $info.StandardInputEncoding=[Text.UTF8Encoding]::new($false)
  $info.StandardOutputEncoding=[Text.UTF8Encoding]::new($false)
  $info.StandardErrorEncoding=[Text.UTF8Encoding]::new($false)
  foreach ($nameToRemove in @('PGSERVICE','PGSERVICEFILE','PGOPTIONS','PGHOSTADDR','PGPASSWORD')) { $info.Environment.Remove($nameToRemove) | Out-Null }
  $info.Environment['PGHOST']=$ConnectionHost; $info.Environment['PGPORT']='5432'
  $info.Environment['PGSSLMODE']='verify-full'; $info.Environment['PGCONNECT_TIMEOUT']='10'
  $info.Environment['PGCLIENTENCODING']='UTF8'; $info.Environment['PGAPPNAME']=$script:RunId+'-'+$Name
  $process=[Diagnostics.Process]::new(); $process.StartInfo=$info
  if (-not $process.Start()) { throw 'P32 could not start owned native process.' }
  $script:Processes.Add($process)
  $session=@{Process=$process;Output=$process.StandardOutput.ReadToEndAsync();Error=$process.StandardError.ReadToEndAsync();Name=$Name}
  Send-Sql $session "SET statement_timeout='35s'; SET lock_timeout='25s'; SET idle_in_transaction_session_timeout='40s';"
  return $session
}
function Send-Sql($Session,[string]$Sql) {
  $Session.Process.StandardInput.WriteLine($Sql); $Session.Process.StandardInput.Flush()
}
function Query([string]$Sql,[string]$Name='probe') {
  $session=Start-Session $Name; Send-Sql $session $Sql; return Finish-Session $session
}
function Wait-State([string]$Name,[string]$BlockedBy='') {
  $timer=[Diagnostics.Stopwatch]::StartNew()
  $waiter=Sql-Literal ($script:RunId+'-'+$Name)
  if ($BlockedBy.Length -eq 0) {
    $condition="a.state='idle in transaction'"
  } else {
    $blocker=Sql-Literal ($script:RunId+'-'+$BlockedBy)
    $condition="a.wait_event_type='Lock' AND EXISTS(SELECT 1 FROM pg_stat_activity b WHERE b.application_name="+$blocker+' AND b.pid=ANY(pg_blocking_pids(a.pid)))'
  }
  do {
    if ((Query ('SELECT EXISTS(SELECT 1 FROM pg_stat_activity a WHERE a.application_name='+$waiter+' AND '+$condition+');') 'barrier') -ceq 't') { return }
    # Backoff only. The observed blocker PID/transaction state defines ordering.
    Start-Sleep -Milliseconds 50
  } while ($timer.ElapsedMilliseconds -lt 15000)
  throw ('P32 observed database barrier missing: '+$Name)
}
function As-Owner([string]$Sql,[string]$Account=$script:Owner) {
  $id=[guid]::ParseExact($Account,'D').ToString()
  $claims='{"sub":"'+$id+'","role":"authenticated"}'
  return 'SET ROLE authenticated; SET request.jwt.claims='+ (Sql-Literal $claims)+'; SET request.jwt.claim.sub='+(Sql-Literal $id)+'; '+$Sql
}
function Envelope([string]$Output) {
  $lines=@($Output -split '\r?\n' | Where-Object { $_.StartsWith('{') })
  Assert-True ($lines.Count -eq 1) 'one JSON envelope'
  return $lines[0] | ConvertFrom-Json
}
function Assert-Receipt($Left,$Right) {
  Assert-True (($Left.receipt | ConvertTo-Json -Depth 30 -Compress) -ceq ($Right.receipt | ConvertTo-Json -Depth 30 -Compress)) 'immutable receipt'
}
function Expected-Error([string]$Sql,[string]$Code) {
  if ($Code -cnotmatch '^[a-z_]+$') { throw 'Invalid internal expected error label.' }
  return ('DO $expected$ DECLARE seen boolean:=false; BEGIN BEGIN EXECUTE '+(Sql-Literal $Sql)+
    '; EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'+(Sql-Literal $Code)+
    ' THEN RAISE; END IF; seen:=true; END; IF NOT seen THEN RAISE EXCEPTION ''missing_expected_error''; END IF; END $expected$; SELECT ''EXPECTED_ERROR_PASS'';')
}
function New-Body($Doc,$Commands=$null) {
  $raw=ConvertTo-Json -InputObject $Doc -Depth 50 -Compress
  $body=[ordered]@{payloadText=$raw;contentDigest=(Get-Sha256 $raw)}
  if ($null -eq $Commands) { $body.sourceBinding=$null } else { $body.commands=@($Commands) }
  return ConvertTo-Json -InputObject $body -Depth 50 -Compress
}
function New-Note($Doc,[string]$Notes) {
  $next=ConvertTo-Json -InputObject $Doc -Depth 50 -Compress | ConvertFrom-Json
  $next.days[0].notes=$Notes
  return New-Body $next @([ordered]@{op='setDayNotes';dayId=$next.days[0].id;notes=$Notes})
}
function Create-Sql([string]$Request,[string]$Body) {
  return 'SELECT public.create_editable_trip_v2('+(Sql-Literal ([guid]::Parse($Request).ToString()))+','+(Sql-Literal $Body)+','+(Sql-Literal (Get-Sha256 $Body))+');'
}
function Update-Sql([string]$Trip,[long]$Version,[string]$Request,[string]$Body) {
  Assert-True ($Version -ge 1 -and $Version -le 9007199254740990) 'internal expected version'
  return 'SELECT public.update_editable_trip_v2('+(Sql-Literal ([guid]::Parse($Trip).ToString()))+','+$Version+','+
    (Sql-Literal ([guid]::Parse($Request).ToString()))+','+(Sql-Literal $Body)+','+(Sql-Literal (Get-Sha256 $Body))+');'
}
function Read-Sql([string]$Trip) { return 'SELECT public.get_editable_trip_v2('+(Sql-Literal ([guid]::Parse($Trip).ToString()))+');' }
function Delete-Sql([string]$Trip,[long]$Version,[string]$Request) {
  return 'SELECT public.delete_editable_trip_v2('+(Sql-Literal ([guid]::Parse($Trip).ToString()))+','+$Version+','+(Sql-Literal ([guid]::Parse($Request).ToString()))+');'
}
function New-Fixture {
  $owner=[guid]::NewGuid().ToString(); $email=$script:RunId+'-'+$owner+'@p32-concurrency.invalid'
  Assert-Fixture $owner $email $script:RunId
  # Register BEFORE sending: lost response after commit must still trigger cleanup.
  $script:Fixtures.Add(@{Owner=$owner;Email=$email})
  $null=Query ('INSERT INTO auth.users(id,aud,role,email,raw_user_meta_data,created_at,updated_at) VALUES('+
    (Sql-Literal $owner)+', ''authenticated'',''authenticated'','+(Sql-Literal $email)+',''{}'',now(),now());') 'seed'
  return $owner
}
function New-Trip {
  $script:Stage='create-fixture-trip'
  $r=Envelope (Query (As-Owner (Create-Sql ([guid]::NewGuid().ToString()) $script:BaseBody)) 'fresh-trip')
  Assert-True ($r.status -ceq 'committed' -and $r.head.version -eq 1) 'fresh V2 trip'
  return [guid]::Parse($r.receipt.tripId).ToString()
}
function Invoke-Schedule([string]$Name,[string]$FirstSql,[string]$SecondSql,[switch]$FirstAdmin,[switch]$SecondAdmin) {
  $script:Stage=$Name
  $firstName=$Name+'-first'; $secondName=$Name+'-second'
  $first=Start-Session $firstName; $second=$null
  try {
    $firstCommand='BEGIN; '+$FirstSql
    if (-not $FirstAdmin) { $firstCommand=As-Owner $firstCommand }
    Send-Sql $first $firstCommand; Wait-State $firstName
    $second=Start-Session $secondName
    if (-not $SecondAdmin) { $SecondSql=As-Owner $SecondSql }
    Send-Sql $second $SecondSql
    Wait-State $secondName $firstName
    Send-Sql $first 'COMMIT;'
    return @{First=(Finish-Session $first);Second=(Finish-Session $second)}
  } catch {
    Stop-OwnedProcess $first.Process
    if ($null -ne $second) { Stop-OwnedProcess $second.Process }
    throw
  }
}

$failed=$false; $cleanupFailed=$false; $failureStage=''
try {
  # All suites use fresh transactions and only synthetic data; closing psql on
  # an error rolls back uncommitted fixture writes. No migration apply commands.
  foreach ($suite in @('editable_trip_v2.sql','editable_trip_v2_negative_controls.sql','guest_import.sql','guest_import_negative_controls.sql')) {
    $script:Stage='suite-'+$suite
    $prefix=if ($suite.StartsWith('editable_')) { $vectorSql+[Environment]::NewLine } else { '' }
    $result=Query ($prefix+'\i '+$suite) ('suite-'+$suite.Replace('.sql',''))
    if ($suite -ceq 'editable_trip_v2.sql') { Assert-True ($result.Contains('P32_POSITIVE_PASS')) 'positive suite completed' }
    if ($suite -ceq 'editable_trip_v2_negative_controls.sql') { Assert-True ($result.Contains('P32_NEGATIVE_PASS')) 'negative suite completed' }
  }
  $script:Owner=New-Fixture
  $base=(@(Get-Content -LiteralPath $vectorPath -Raw -Encoding utf8 | ConvertFrom-Json) | Where-Object id -CEQ 'money_unknown_unicode').rawText | ConvertFrom-Json
  $base.input.startDate='2026-10-15'; $base.input.endDate='2026-10-15'; $base.days[0].date='2026-10-15'
  $script:BaseBody=New-Body $base
  $noteA=New-Note $base 'Concurrent edit A'; $noteB=New-Note $base 'Concurrent edit B'
  $request=[guid]::NewGuid().ToString(); $create=Create-Sql $request $script:BaseBody
  $pair=Invoke-Schedule 'same-create' $create $create
  $one=Envelope $pair.First; $two=Envelope $pair.Second; Assert-Receipt $one $two
  Assert-True ($one.head.version -eq 1 -and $two.head.version -eq 1 -and $one.receipt.tripId -ceq $two.receipt.tripId) 'one concurrent create'
  $id=Sql-Literal $script:Owner
  Assert-True ((Query ('SELECT (SELECT count(*) FROM public.trips WHERE user_id='+$id+'::uuid)=1 AND (SELECT count(*) FROM private.editable_trip_mutations WHERE owner_id='+$id+'::uuid)=1;') 'one-receipt') -ceq 't') 'one row and one receipt'
  $null=Query (As-Owner $create) 'discard-response'
  $lookup='SELECT public.get_editable_mutation_v2('+(Sql-Literal $request)+');'
  Assert-Receipt $one (Envelope (Query (As-Owner $lookup) 'recover-fresh-session'))
  $trip=$one.receipt.tripId
  $winner=Update-Sql $trip 1 ([guid]::NewGuid().ToString()) $noteA
  $loser=Update-Sql $trip 1 ([guid]::NewGuid().ToString()) $noteB
  $pair=Invoke-Schedule 'same-base' $winner (Expected-Error $loser 'version_conflict')
  Assert-True ((Envelope $pair.First).head.version -eq 2 -and $pair.Second -ceq 'EXPECTED_ERROR_PASS') 'same base exactly one commit'
  Assert-True ((Query ('SELECT count(*)=1 FROM private.editable_trip_mutations WHERE owner_id='+$id+'::uuid AND trip_id='+(Sql-Literal $trip)+'::uuid AND operation=''update'';') 'one-update-receipt') -ceq 't') 'one successful update receipt'
  $recovered=Envelope (Query (As-Owner $lookup) 'old-receipt-new-head')
  Assert-Receipt $one $recovered
  Assert-True ($recovered.head.version -eq 2 -and $recovered.receipt.resultVersion -eq 1) 'old receipt with newer head'
  $trip=New-Trip; $update=Update-Sql $trip 1 ([guid]::NewGuid().ToString()) $noteA
  $pair=Invoke-Schedule 'same-update-key' $update $update
  Assert-Receipt (Envelope $pair.First) (Envelope $pair.Second)
  Assert-True ((Envelope $pair.Second).head.version -eq 2) 'same update key does not increment twice'
  $trip=New-Trip; $update=Update-Sql $trip 1 ([guid]::NewGuid().ToString()) $noteA
  $pair=Invoke-Schedule 'update-read' $update (Read-Sql $trip)
  Assert-True ((Envelope $pair.Second).head.version -eq 2) 'read after update sees new head'
  $trip=New-Trip; $update=Update-Sql $trip 1 ([guid]::NewGuid().ToString()) $noteA
  $pair=Invoke-Schedule 'read-update' (Read-Sql $trip) $update
  Assert-True ((Envelope $pair.First).head.version -eq 1 -and (Envelope $pair.Second).head.version -eq 2) 'read before update consistent'
  $trip=New-Trip; $delete=Delete-Sql $trip 1 ([guid]::NewGuid().ToString())
  $pair=Invoke-Schedule 'read-delete' (Read-Sql $trip) $delete
  Assert-True ((Envelope $pair.First).status -ceq 'ready' -and (Envelope $pair.Second).status -ceq 'deleted') 'read before delete'
  $trip=New-Trip; $delete=Delete-Sql $trip 1 ([guid]::NewGuid().ToString())
  $pair=Invoke-Schedule 'delete-read' $delete (Read-Sql $trip)
  Assert-True ((Envelope $pair.Second).status -ceq 'unavailable') 'read after delete unavailable'
  $trip=New-Trip; $delete=Delete-Sql $trip 1 ([guid]::NewGuid().ToString())
  $pair=Invoke-Schedule 'update-delete' (Update-Sql $trip 1 ([guid]::NewGuid().ToString()) $noteA) (Expected-Error $delete 'version_conflict')
  Assert-True ((Envelope $pair.First).head.version -eq 2 -and $pair.Second -ceq 'EXPECTED_ERROR_PASS') 'stale delete cannot remove updated trip'
  $trip=New-Trip; $delete=Delete-Sql $trip 1 ([guid]::NewGuid().ToString())
  $pair=Invoke-Schedule 'delete-update' $delete (Expected-Error (Update-Sql $trip 1 ([guid]::NewGuid().ToString()) $noteA) 'trip_unavailable')
  Assert-True ((Envelope $pair.First).status -ceq 'deleted' -and $pair.Second -ceq 'EXPECTED_ERROR_PASS') 'update cannot resurrect deleted trip'
  $trip=New-Trip; $delete=Delete-Sql $trip 1 ([guid]::NewGuid().ToString())
  $pair=Invoke-Schedule 'same-delete-key' $delete $delete
  Assert-Receipt (Envelope $pair.First) (Envelope $pair.Second)
  Assert-True ((Envelope $pair.Second).status -ceq 'deleted') 'one terminal delete receipt'
  # Mutator first: FK KEY SHARE must make account deletion wait, then cascade.
  $trip=New-Trip; $fixture=$script:Fixtures[0]
  $cascade='DELETE FROM auth.users WHERE id='+(Sql-Literal $fixture.Owner)+'::uuid AND email='+(Sql-Literal $fixture.Email)+';'
  $pair=Invoke-Schedule 'update-account-cascade' (Update-Sql $trip 1 ([guid]::NewGuid().ToString()) $noteA) $cascade -SecondAdmin
  Assert-True ((Envelope $pair.First).head.version -eq 2) 'mutation before account cascade commits'
  Assert-True ((Query (Get-CleanupSql $fixture.Owner $fixture.Email $script:RunId) 'cascade-check') -ceq 't') 'cascade removed owner aggregates/receipts'
  # Cascade first: blocked authenticated mutator must become unauthorized.
  $script:Owner=New-Fixture; $trip=New-Trip; $fixture=$script:Fixtures[1]
  $cascade='DELETE FROM auth.users WHERE id='+(Sql-Literal $fixture.Owner)+'::uuid AND email='+(Sql-Literal $fixture.Email)+';'
  $pair=Invoke-Schedule 'account-cascade-update' $cascade (Expected-Error (Update-Sql $trip 1 ([guid]::NewGuid().ToString()) $noteA) 'unauthorized') -FirstAdmin
  Assert-True ($pair.Second -ceq 'EXPECTED_ERROR_PASS') 'deleted account cannot recreate receipt/trip'
  Write-Output 'P32 SQL suites and 12 observed-lock schedules PASS; cleanup still required.'
} catch {
  $failed=$true; $failureStage=$script:Stage
} finally {
  foreach ($process in $script:Processes.ToArray()) {
    try { Stop-OwnedProcess $process } catch { $cleanupFailed=$true }
  }
  foreach ($fixture in $script:Fixtures) {
    try { Assert-True ((Query (Get-CleanupSql $fixture.Owner $fixture.Email $script:RunId) 'cleanup') -ceq 't') 'exact fixture cleanup' }
    catch { $cleanupFailed=$true }
  }
  foreach ($process in $script:Processes.ToArray()) {
    try { Stop-OwnedProcess $process; $process.Dispose() } catch { $cleanupFailed=$true }
  }
}
if ($cleanupFailed) { throw ('P32 cleanup failed; inspect only synthetic fixture run '+$script:RunId+'; private diagnostics withheld.') }
if ($failed) { throw ('P32 staging harness failed at '+$failureStage+'; run '+$script:RunId+'; private SQL/stdout/stderr withheld.') }
Write-Output 'P32 staging SQL, observed-lock races and exact synthetic cleanup PASS.'
