# Existing Pester 3.x Throw without a message is unreliable in this installation.
# Execute positive checks directly and verify exceptions with an explicit detector.
# No database connection.
$runner=Join-Path $PSScriptRoot 'run-editable-trip-concurrency.ps1'
$tokens=$null; $parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($runner,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw 'Runner PowerShell parse errors.' }
# Load only function definitions, never the ExecuteStaging script body.
foreach ($statement in $ast.EndBlock.Statements) {
  if ($statement -is [Management.Automation.Language.FunctionDefinitionAst]) {
    . ([scriptblock]::Create($statement.Extent.Text))
  }
}
$fixturePath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../test/fixtures/editable_trip_v2_vectors.json'))
Describe 'P32 isolated staging harness controls' {
  It 'accepts only the exact staging project and direct host' {
    $null=Assert-Target 'bkocylxbuyvdgxccpixx' 'db.bkocylxbuyvdgxccpixx.supabase.co'
  }
  It 'rejects primary' {
    Assert-Rejected { Assert-Target 'oavbymauorhmrjcustzw' 'db.oavbymauorhmrjcustzw.supabase.co' } 'expected rejection'
  }
  It 'rejects localhost and pooler/lookalike hosts' {
    foreach ($hostName in @('localhost','127.0.0.1','db.bkocylxbuyvdgxccpixx.supabase.co.evil','aws-0-ap-southeast-1.pooler.supabase.com')) {
      Assert-Rejected { Assert-Target 'bkocylxbuyvdgxccpixx' $hostName } 'expected rejection'
    }
  }
  It 'rejects ref and host case variants' {
    Assert-Rejected { Assert-Target 'BKOCYLXBUYVDGXCCPIXX' 'db.bkocylxbuyvdgxccpixx.supabase.co' } 'expected rejection'
    Assert-Rejected { Assert-Target 'bkocylxbuyvdgxccpixx' 'DB.bkocylxbuyvdgxccpixx.supabase.co' } 'expected rejection'
  }
  It 'rejects missing source without opening a connection' {
    Assert-Rejected { Assert-Sources @($fixturePath+'.missing') } 'expected rejection'
  }
  It 'rejects timeout even when an exit code looks successful' {
    Assert-Rejected { Assert-Exit $false 0 'timeout' } 'expected rejection'
  }
  It 'rejects nonzero native exit and accepts successful completion' {
    Assert-Rejected { Assert-Exit $true 7 'failure' } 'expected rejection'
    $null=Assert-Exit $true 0 'success'
  }
  It 'drains native child output and rejects real native timeout/nonzero exits' {
    (Invoke-NativeControl 'success') | Should Be 'native-control'
    Assert-Rejected { Invoke-NativeControl 'nonzero' } 'expected rejection'
    Assert-Rejected { Invoke-NativeControl 'timeout' } 'expected rejection'
  }
  It 'distinguishes a SQL null from an empty text literal' {
    (Sql-Literal $null) | Should Be 'NULL'
    ((Sql-Literal '') -ceq 'NULL') | Should Be $false
  }
  It 'refuses cleanup when the email or owner does not match this run' {
    $run=[guid]::NewGuid().ToString('N'); $owner=[guid]::NewGuid().ToString()
    $email=$run+'-'+$owner+'@p32-concurrency.invalid'
    $null=Get-CleanupSql $owner $email $run
    Assert-Rejected { Get-CleanupSql $owner 'wrong@p32-concurrency.invalid' $run } 'expected rejection'
    Assert-Rejected { Get-CleanupSql ([guid]::NewGuid().ToString()) $email $run } 'expected rejection'
  }
  It 'keeps every T1 rawText literal intact, including duplicate keys' {
    $sql=Get-VectorSql $fixturePath
    foreach ($v in @(Get-Content -LiteralPath $fixturePath -Raw -Encoding utf8 | ConvertFrom-Json)) {
      $sql.Contains($v.rawText) | Should Be $true
    }
  }
  It 'detects deliberately broken assertions and missing expected errors' {
    Assert-Rejected { Assert-True $false 'broken' } 'expected rejection'
    Assert-Rejected { Assert-Rejected { $null=1 } 'missing failure' } 'expected rejection'
  }
  It 'builds digest-bound create/update requests and preserves a command array' {
    $doc=@(Get-Content -LiteralPath $fixturePath -Raw -Encoding utf8 | ConvertFrom-Json)[0].rawText | ConvertFrom-Json
    $create=New-Body $doc | ConvertFrom-Json
    ($null -eq $create.sourceBinding) | Should Be $true
    $create.contentDigest | Should Be (Get-Sha256 $create.payloadText)
    $update=New-Note $doc 'Updated' | ConvertFrom-Json
    $update.commands.Count | Should Be 1
    $update.commands[0].op | Should Be 'setDayNotes'
    $update.contentDigest | Should Be (Get-Sha256 $update.payloadText)
  }
  It 'passes the built-in self-test without database credentials' {
    $null=Invoke-RunnerSelfTest $fixturePath
  }
}
