param([string] $PgBin = 'C:\Program Files\PostgreSQL\18\bin')
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
$ownedName = 'travelgo_c1_pg_' + [Guid]::NewGuid().ToString('N')
$ownedPath = Join-Path $tempRoot $ownedName
$dataPath = Join-Path $ownedPath 'data'
$platformIsWindows = [Environment]::OSVersion.Platform -eq 'Win32NT'
$suffix = if ($platformIsWindows) { '.exe' } else { '' }
$psqlPath = Join-Path $PgBin "psql$suffix"
$pgCtlPath = Join-Path $PgBin "pg_ctl$suffix"
$initPath = Join-Path $PgBin "initdb$suffix"
foreach ($binary in @($psqlPath, $pgCtlPath, $initPath)) {
    if (-not (Test-Path -LiteralPath $binary)) { throw 'Native PostgreSQL test runtime missing.' }
}
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$started = $false
$processes = @()
New-Item -ItemType Directory -Path $ownedPath | Out-Null
try {
    & $initPath -D $dataPath -A trust -U c1_fixture_admin --encoding=UTF8 --locale=C > (Join-Path $ownedPath 'init.log') 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Owned local initdb failed.' }
    & $pgCtlPath -D $dataPath -l (Join-Path $ownedPath 'server.log') -w start -o "-h 127.0.0.1 -p $port"
    if ($LASTEXITCODE -ne 0) { throw 'Owned local PostgreSQL start failed.' }
    $started = $true
    $connection = @('-h','127.0.0.1','-p',"$port",'-U','c1_fixture_admin','-d','postgres','-v','ON_ERROR_STOP=1','-X','-q')
    $rolesPath = Join-Path $ownedPath 'roles.sql'
    'CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;' | Set-Content -LiteralPath $rolesPath
    foreach ($sqlPath in @($rolesPath, (Join-Path $repoPath 'supabase/migrations/202610130001_ai_quota.sql'), (Join-Path $repoPath 'supabase/tests/ai_quota.sql'))) {
        & $psqlPath @connection -f $sqlPath
        if ($LASTEXITCODE -ne 0) { throw "Local SQL failed: $([IO.Path]::GetFileName($sqlPath))" }
    }
    # Four real PostgreSQL sessions compete for three slots under service_role.
    for ($index = 0; $index -lt 4; $index++) {
        $id = [Guid]::NewGuid().ToString()
        $sqlPath = Join-Path $ownedPath "race_$index.sql"
        "SET ROLE service_role; SELECT public.reserve_ai_request_v1('cccccccc-cccc-4ccc-8ccc-cccccccccccc', true, '$id', repeat('a',64));" | Set-Content -LiteralPath $sqlPath
        $arguments = @{};
        if ($platformIsWindows) { $arguments.WindowStyle = 'Hidden' }
        $processes += Start-Process -FilePath $psqlPath -ArgumentList ($connection + @('-A','-t','-f',$sqlPath)) -RedirectStandardOutput (Join-Path $ownedPath "race_$index.out") -RedirectStandardError (Join-Path $ownedPath "race_$index.err") -PassThru @arguments
    }
    foreach ($process in $processes) {
        if (-not $process.WaitForExit(15000)) { throw 'Local quota race timed out.' }
        if ($process.ExitCode -ne 0) { throw 'Local quota race process failed.' }
    }
    $results = 0..3 | ForEach-Object { (Get-Content -LiteralPath (Join-Path $ownedPath "race_$_.out") -Raw | ConvertFrom-Json).status }
    if (@($results | Where-Object { $_ -eq 'reserved' }).Count -ne 3 -or @($results | Where-Object { $_ -eq 'quota_exhausted' }).Count -ne 1) { throw 'Four-session quota limit violated.' }
    $rowCount = & $psqlPath @connection -A -t -c "SELECT count(*) FROM private_ai.requests;"
    if ($LASTEXITCODE -ne 0 -or $rowCount.Trim() -ne '3') { throw 'Unexpected race request count.' }
    Write-Output 'AI_QUOTA_NATIVE_FOUR_SESSION_RACE_PASS'
    $processes = @()
    $sameId = [Guid]::NewGuid().ToString()
    for ($index = 0; $index -lt 2; $index++) {
        $sqlPath = Join-Path $ownedPath "duplicate_$index.sql"
        "SET ROLE service_role; SELECT public.reserve_ai_request_v1('dddddddd-dddd-4ddd-8ddd-dddddddddddd', true, '$sameId', repeat('b',64));" | Set-Content -LiteralPath $sqlPath
        $arguments = @{}
        if ($platformIsWindows) { $arguments.WindowStyle = 'Hidden' }
        $processes += Start-Process -FilePath $psqlPath -ArgumentList ($connection + @('-A','-t','-f',$sqlPath)) -RedirectStandardOutput (Join-Path $ownedPath "duplicate_$index.out") -RedirectStandardError (Join-Path $ownedPath "duplicate_$index.err") -PassThru @arguments
    }
    foreach ($process in $processes) {
        if (-not $process.WaitForExit(15000) -or $process.ExitCode -ne 0) { throw 'Duplicate request race failed.' }
    }
    $duplicates = @(0..1 | ForEach-Object { Get-Content -LiteralPath (Join-Path $ownedPath "duplicate_$_.out") -Raw | ConvertFrom-Json })
    if (@($duplicates | Where-Object { $_.dispatch -eq $true }).Count -ne 1 -or $duplicates[0].workerToken -ne $duplicates[1].workerToken) { throw 'Duplicate request dispatched more than once.' }
    $count = & $psqlPath @connection -A -t -c "SELECT count(*) FROM private_ai.requests WHERE subject = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';"
    if ($LASTEXITCODE -ne 0 -or $count.Trim() -ne '1') { throw 'Duplicate identity ledger contains extra rows.' }
    Write-Output 'AI_QUOTA_NATIVE_DUPLICATE_RACE_PASS'
} finally {
    foreach ($process in $processes) { if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() } }
    if ($started) {
        & $pgCtlPath -D $dataPath -m immediate -w stop
        if ($LASTEXITCODE -ne 0) { throw 'Local server stop failed; owned fixture retained.' }
    }
    $resolved = (Resolve-Path -LiteralPath $ownedPath).Path
    $expected = [IO.Path]::GetFullPath((Join-Path $tempRoot $ownedName))
    if ($resolved -ne $expected -or -not $ownedName.StartsWith('travelgo_c1_pg_') -or [IO.Path]::GetDirectoryName($resolved) -ne $tempRoot) { throw 'Unsafe cleanup target; deletion refused.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
Write-Output 'AI_QUOTA_OWNED_LOCAL_CLEANUP_PASS'
