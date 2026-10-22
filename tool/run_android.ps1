[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Device,
    [string]$Flutter = 'flutter',
    [string]$Adb = 'adb'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & $Flutter build apk --debug --target lib/main.dart
    if ($LASTEXITCODE -ne 0) {
        throw 'Flutter build failed. The installed application was not changed.'
    }

    $apk = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-debug.apk'
    # Android checks signatures and version compatibility atomically. A failed
    # replacement must stop here; do not use Flutter's uninstall/retry fallback.
    $installOutput = @(& $Adb -s $Device install -r $apk 2>&1)
    $installExit = $LASTEXITCODE
    $installOutput | Write-Output
    if ($installExit -ne 0 -or -not ($installOutput -match '^Success\s*$')) {
        throw 'Update rejected. Existing app and data were kept. Use an APK with the same signing key and a compatible version.'
    }

    & $Adb -s $Device shell am start -W -n 'io.github.aceykn.nwuschedule.debug/io.github.aceykn.nwuschedule.MainActivity'
    if ($LASTEXITCODE -ne 0) {
        throw 'The update succeeded, but the development app could not be started.'
    }
} finally {
    Pop-Location
}
