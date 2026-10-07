$ErrorActionPreference = 'Stop'
$taskDateDatabase = Join-Path ([System.IO.Path]::GetTempPath()) ("nwu-timezone-" + [guid]::NewGuid() + '.sqlite')
$taskOriginalTz = $env:TZ
$taskOriginalPhase = $env:NWU_DATE_PHASE
$taskOriginalDatabase = $env:NWU_DATE_DATABASE
$taskOriginalOffset = $env:NWU_DATE_EXPECTED_OFFSET
try {
    $env:NWU_DATE_DATABASE = $taskDateDatabase
    foreach ($taskZone in @(@('CST-8', 'write', '8'), @('PST8', 'read', '-8'), @('JST-9', 'read', '9'))) {
        $env:TZ = $taskZone[0]
        $env:NWU_DATE_PHASE = $taskZone[1]
        $env:NWU_DATE_EXPECTED_OFFSET = $taskZone[2]
        flutter test --no-pub test/regression/teaching_date_timezone_test.dart --reporter expanded
        if ($LASTEXITCODE -ne 0) { throw "Date verification failed in $($taskZone[0])" }
    }
    Write-Output "Verified UTC+8 / UTC-8 / UTC+9; synthetic databases: $taskDateDatabase"
} finally {
    $env:TZ = $taskOriginalTz
    $env:NWU_DATE_PHASE = $taskOriginalPhase
    $env:NWU_DATE_DATABASE = $taskOriginalDatabase
    $env:NWU_DATE_EXPECTED_OFFSET = $taskOriginalOffset
}
