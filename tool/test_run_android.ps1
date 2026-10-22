$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run_android.ps1'
$global:nwuDeployTestCalls = [System.Collections.Generic.List[string]]::new()
$global:nwuDeployTestBuildExit = 0
$global:nwuDeployTestInstallExit = 0
$global:nwuDeployTestInstallMessage = 'Success'

function Test-Flutter {
    $global:LASTEXITCODE = $global:nwuDeployTestBuildExit
}

function Test-Adb {
    $global:nwuDeployTestCalls.Add(($args -join ' '))
    if ($args -contains 'install') { Write-Output $global:nwuDeployTestInstallMessage }
    $global:LASTEXITCODE = if ($args -contains 'install') { $global:nwuDeployTestInstallExit } else { 0 }
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-Case([int]$BuildResult, [int]$InstallResult, [bool]$ShouldFail, [string]$InstallMessage = 'Success') {
    $global:nwuDeployTestCalls.Clear()
    $global:nwuDeployTestBuildExit = $BuildResult
    $global:nwuDeployTestInstallExit = $InstallResult
    $global:nwuDeployTestInstallMessage = $InstallMessage
    $failed = $false
    try {
        & $runner -Device 'test-device' -Flutter 'Test-Flutter' -Adb 'Test-Adb'
    } catch {
        $failed = $true
    }
    Assert-True ($failed -eq $ShouldFail) 'Unexpected deployment outcome.'
    Assert-True (-not ($global:nwuDeployTestCalls -match '\buninstall\b|\bclear\b')) 'Deployment must never remove user data.'
}

Invoke-Case -BuildResult 1 -InstallResult 0 -ShouldFail $true
Assert-True ($global:nwuDeployTestCalls.Count -eq 0) 'A failed build must not change the device.'

Invoke-Case -BuildResult 0 -InstallResult 1 -ShouldFail $true
Assert-True ($global:nwuDeployTestCalls.Count -eq 1) 'A rejected update must stop without retrying or launching.'
Assert-True ($global:nwuDeployTestCalls[0] -match 'install -r ') 'Updates must preserve the existing installation.'

Invoke-Case -BuildResult 0 -InstallResult 0 -ShouldFail $true -InstallMessage 'Failure [INSTALL_FAILED_INSUFFICIENT_STORAGE]'
Assert-True ($global:nwuDeployTestCalls.Count -eq 1) 'A failure reported with exit code zero must still stop without uninstalling.'

Invoke-Case -BuildResult 0 -InstallResult 0 -ShouldFail $false
Assert-True ($global:nwuDeployTestCalls.Count -eq 2) 'A successful update should launch once.'
Assert-True ($global:nwuDeployTestCalls[1] -match 'nwuschedule\.debug/io\.github\.aceykn\.nwuschedule\.MainActivity') 'Launch the development package.'

$global:LASTEXITCODE = 0
Write-Output 'Android deployment regression checks passed (4 scenarios).'
