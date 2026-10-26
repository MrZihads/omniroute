param([ValidateSet('Setup','Start')][string]$Mode = 'Setup')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$project = Join-Path $env:USERPROFILE 'OmniRoute-Chris'
$launcher = Join-Path $env:LOCALAPPDATA 'OmniRouteLauncher'
$portNumber = 20130
$sourceCommit = '515674b6cf7cc29b3db027c9119e9b2ef12e0ba7'
$nodeVersion = '22.23.4'
$env:NODE_ENV = 'production'
$env:HUSKY = '0'
$env:PORT = [string]$portNumber
$env:API_PORT = [string]$portNumber
$env:DASHBOARD_PORT = [string]$portNumber
$env:NEXT_PUBLIC_BASE_URL = "http://localhost:$portNumber"
$env:DATA_DIR = Join-Path $project 'data'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Run-Npm([string[]]$NpmArguments) {
    & $script:npmPath @NpmArguments
    if ($LASTEXITCODE -ne 0) { throw "npm failed (exit $LASTEXITCODE). See the error above." }
}

try {
    Write-Host "OmniRoute - $Mode" -ForegroundColor Cyan
    if (Get-NetTCPConnection -LocalPort $portNumber -State Listen -ErrorAction SilentlyContinue) {
        throw "Port $portNumber is already in use. Stop the OLD OmniRoute window with Ctrl+C, then retry."
    }
    $arch = 'x64'
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { $arch = 'arm64' }
    $runtimeParent = Join-Path $env:USERPROFILE 'Tools'
    $runtime = Join-Path $runtimeParent "node-v$nodeVersion-win-$arch"
    $nodePath = Join-Path $runtime 'node.exe'
    if (!(Test-Path $nodePath)) {
        if ($Mode -eq 'Start') { throw 'Node runtime is missing. Run Setup.cmd first.' }
        Write-Host 'Downloading portable Node.js (no system-wide install)...'
        $tempDir = Join-Path $env:TEMP ('omniroute-node-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $zipName = "node-v$nodeVersion-win-$arch.zip"
            $zipPath = Join-Path $tempDir $zipName
            $baseUrl = "https://nodejs.org/dist/v$nodeVersion"
            Invoke-WebRequest -UseBasicParsing "$baseUrl/$zipName" -OutFile $zipPath
            $sums = (Invoke-WebRequest -UseBasicParsing "$baseUrl/SHASUMS256.txt").Content
            $sumLine = @($sums -split "`n" | Where-Object { $_.Trim().EndsWith("  $zipName") })
            if ($sumLine.Count -ne 1) { throw 'Cannot find the official Node SHA256 checksum.' }
            $expectedHash = ($sumLine[0].Trim() -split '\s+')[0]
            if ((Get-FileHash $zipPath -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Node ZIP checksum mismatch.' }
            New-Item -ItemType Directory -Path $runtimeParent -Force | Out-Null
            Expand-Archive -Path $zipPath -DestinationPath $runtimeParent -Force
        } finally { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $env:Path = "$runtime;$env:Path"
    $script:npmPath = Join-Path $runtime 'npm.cmd'
    Write-Host "Node: $(& $nodePath --version)"

    if (!(Test-Path (Join-Path $project 'package.json'))) {
        if ($Mode -eq 'Start') { throw 'OmniRoute is not installed. Run Setup.cmd first.' }
        if (Test-Path $project) { throw "Existing folder $project has no package.json. Nothing was overwritten." }
        Write-Host 'Downloading ChrisCompton/omniroute source from GitHub...'
        $tempDir = Join-Path $env:TEMP ('omniroute-source-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $zipPath = Join-Path $tempDir 'source.zip'
            Invoke-WebRequest -UseBasicParsing "https://codeload.github.com/ChrisCompton/omniroute/zip/$sourceCommit" -OutFile $zipPath
            Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
            Move-Item -LiteralPath (Join-Path $tempDir "omniroute-$sourceCommit") -Destination $project
        } finally { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Set-Location -LiteralPath $project
    $package = Get-Content -LiteralPath (Join-Path $project 'package.json') -Raw | ConvertFrom-Json
    if ($package.name -ne 'omniroute' -or !(Test-Path '.\scripts\run-next.mjs')) {
        throw 'This folder does not contain the expected OmniRoute source. Nothing was overwritten.'
    }
    New-Item -ItemType Directory -Path $launcher -Force | Out-Null
    New-Item -ItemType Directory -Path $env:DATA_DIR -Force | Out-Null
    $envFile = Join-Path $project '.env'
    if (!(Test-Path $envFile)) {
        $password = ([guid]::NewGuid().ToString('N')).Substring(0,24)
        [IO.File]::WriteAllText($envFile, "INITIAL_PASSWORD=$password`r`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $launcher 'LOGIN.txt'), "OmniRoute initial dashboard password: $password`r`nChange it in Settings after signing in. Keep this file private.`r`n", $utf8)
        Write-Host "Initial login password saved in $launcher\LOGIN.txt" -ForegroundColor Yellow
    }
    # Blank project values override server.env and can regenerate encryption keys.
    # Remove only empty secret assignments; preserve populated keys and database files.
    foreach ($configFile in @($envFile, (Join-Path $env:DATA_DIR '.env'))) {
        if (!(Test-Path $configFile)) { continue }
        $original = [IO.File]::ReadAllText($configFile)
        $cleaned = [regex]::Replace($original, '(?m)^[ \t]*(JWT_SECRET|STORAGE_ENCRYPTION_KEY|API_KEY_SECRET)[ \t]*=[ \t]*\r?\n', '')
        if ($cleaned -ne $original) {
            Copy-Item -LiteralPath $configFile -Destination ($configFile + '.before-oneclick-' + [guid]::NewGuid().ToString('N'))
            [IO.File]::WriteAllText($configFile, $cleaned, $utf8)
        }
    }
    if ($Mode -eq 'Setup') {
        if (!(Test-Path '.\node_modules\next\package.json')) {
            Write-Host 'Installing dependencies. This can take several minutes...'
            if (Test-Path '.\package-lock.json') { Run-Npm -NpmArguments @('ci','--include=dev') } else { Run-Npm -NpmArguments @('install','--include=dev') }
        }
        # Postinstall creates root app/node_modules, which shadows src/app routes.
        if (Test-Path '.\app') {
            Rename-Item -LiteralPath '.\app' -NewName ('app-standalone-backup-' + [guid]::NewGuid().ToString('N'))
        }
        Write-Host 'Building production pages ONCE. Please wait for completion...'
        Run-Npm -NpmArguments @('run','build')
        foreach ($name in @('OmniRoute.ps1','Setup.cmd','Start-OmniRoute.cmd','README.txt')) {
            $from = Join-Path $PSScriptRoot $name
            $to = Join-Path $launcher $name
            if ([IO.Path]::GetFullPath($from) -ne [IO.Path]::GetFullPath($to)) { Copy-Item -LiteralPath $from -Destination $to -Force }
        }
        $shell = New-Object -ComObject WScript.Shell
        $desktop = [Environment]::GetFolderPath('Desktop')
        $shortcut = $shell.CreateShortcut((Join-Path $desktop 'Start OmniRoute.lnk'))
        $shortcut.TargetPath = Join-Path $launcher 'Start-OmniRoute.cmd'
        $shortcut.WorkingDirectory = $launcher
        $shortcut.Description = 'Start OmniRoute in production mode on localhost:20130'
        $shortcut.Save()
    }
    if (!(Test-Path '.\.next\BUILD_ID')) { throw 'Production build is missing. Run Setup.cmd first.' }
    if (Test-Path '.\app') { throw 'A root app folder has reappeared. Run Setup.cmd to repair routing and rebuild.' }
    Write-Host "Starting http://localhost:$portNumber/dashboard" -ForegroundColor Green
    Write-Host 'Keep this window open. Press Ctrl+C here to stop OmniRoute.'
    $browserJob = Start-Job -ArgumentList $portNumber -ScriptBlock {
        param($p)
        for ($attempt = 0; $attempt -lt 90; $attempt++) {
            try {
                $r = Invoke-WebRequest -UseBasicParsing "http://localhost:$p/login" -TimeoutSec 2
                if ($r.StatusCode -eq 200) { Start-Process "http://localhost:$p/dashboard"; break }
            } catch { }
            Start-Sleep -Seconds 2
        }
    }
    try { Run-Npm -NpmArguments @('run','start') }
    finally { Stop-Job $browserJob -ErrorAction SilentlyContinue; Remove-Job $browserJob -Force -ErrorAction SilentlyContinue }
} catch {
    Write-Host "`nSETUP/START STOPPED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Copy the error above for troubleshooting. Your database was not deleted.'
    exit 1
}
