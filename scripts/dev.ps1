param([ValidateSet('check','test','apk','devices','run')][string]$Task='check')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$originalLocation=Get-Location
$mappedDrive=$null
$taskExitCode=0
try {
    $devRoot=$projectRoot
    if ($projectRoot -match '[^\x00-\x7F]') {
        foreach ($letter in @('N','O','P','Q','R','S','T','U','V','W','X','Y','Z')) {
            if (-not (Test-Path ($letter+':\'))) {
                & subst.exe ($letter+':') $projectRoot
                if ($LASTEXITCODE -ne 0) { throw 'Cannot create an ASCII drive mapping.' }
                $mappedDrive=$letter+':'
                $devRoot=$mappedDrive+'\'
                break
            }
        }
        if (-not $mappedDrive) { throw 'No free drive letter. Use an ASCII project path.' }
    }
    Set-Location -LiteralPath $devRoot
    $flutterExecutable=Join-Path $devRoot '.tooling/flutter/bin/flutter.bat'
    if (-not (Test-Path $flutterExecutable)) { $flutterExecutable=(Get-Command flutter -ErrorAction Stop).Source }
    $localJava=Get-ChildItem (Join-Path $devRoot '.tooling/java') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($localJava) { $env:JAVA_HOME=$localJava.FullName }
    $localAndroid=Join-Path $devRoot '.tooling/android-sdk'
    if (Test-Path $localAndroid) { $env:ANDROID_HOME=$localAndroid }
    $localGradle=Join-Path $devRoot '.tooling/gradle-9.3.1/bin/gradle.bat'
    $packageConfig=Join-Path $devRoot '.dart_tool/package_config.json'
    $needsPackages=-not (Test-Path -LiteralPath $packageConfig)
    if (-not $needsPackages) {
        $config=Get-Content -LiteralPath $packageConfig -Raw | ConvertFrom-Json
        $configUri=[Uri]::new($packageConfig)
        foreach ($package in $config.packages) {
            $rootUri=[Uri]::new($configUri, [string]$package.rootUri)
            if (-not (Test-Path -LiteralPath $rootUri.LocalPath)) { $needsPackages=$true; break }
        }
    }
    if ($needsPackages) {
        & $flutterExecutable pub get
        if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    }
    switch ($Task) {
        'check' {
            & $flutterExecutable analyze --no-pub
            if ($LASTEXITCODE -eq 0) { & $flutterExecutable test --no-pub }
        }
        'test' { & $flutterExecutable test --no-pub }
        'apk' {
            if ((Test-Path $localGradle) -and (Test-Path $localAndroid)) {
                $env:GRADLE_USER_HOME=Join-Path $devRoot '.tooling/gradle-cache'
                $flutterSdk=Split-Path -Parent (Split-Path -Parent $flutterExecutable)
                $packageVersion=[regex]::Match((Get-Content pubspec.yaml -Raw),'(?m)^version:\s*([^+\s]+)\+(\d+)\s*$')
                if (-not $packageVersion.Success) { throw 'Expected versionName+versionCode in pubspec.yaml.' }
                Set-Content android/local.properties @(
                    ('sdk.dir='+$localAndroid.Replace('\','\\')),
                    ('flutter.sdk='+$flutterSdk.Replace('\','\\')),
                    'flutter.buildMode=debug',('flutter.versionName='+$packageVersion.Groups[1].Value),('flutter.versionCode='+$packageVersion.Groups[2].Value)
                )
                & $localGradle -p android assembleDebug -Ptarget-platform=android-arm64 --console=plain
            } else { & $flutterExecutable build apk --debug --target-platform=android-arm64 }
        }
        'devices' { & $flutterExecutable devices }
        'run' { & $flutterExecutable run }
    }
    $taskExitCode=$LASTEXITCODE
} finally {
    Set-Location -LiteralPath $originalLocation.Path
    if ($mappedDrive) { & subst.exe $mappedDrive /D }
}
exit $taskExitCode
