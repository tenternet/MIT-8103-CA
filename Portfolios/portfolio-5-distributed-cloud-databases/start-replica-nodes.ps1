$ErrorActionPreference = "Stop"

$replicaSetName = "mivaBitesRS"
$ports = @(27117, 27118, 27119)
$labRoot = Join-Path $env:LOCALAPPDATA "MivaBitesReplicaLab"

function Test-LocalPortOpen {
    param([int]$Port)

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $client.Connect("127.0.0.1", $Port)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

$mongodPath = $null
$serverRoot = Join-Path $env:ProgramFiles "MongoDB\Server"
if (Test-Path -LiteralPath $serverRoot) {
    $serverFolders = Get-ChildItem -LiteralPath $serverRoot -Directory |
        Sort-Object { try { [version]::Parse($_.Name) } catch { [version]"0.0" } } -Descending

    foreach ($folder in $serverFolders) {
        $candidate = Join-Path $folder.FullName "bin\mongod.exe"
        if (Test-Path -LiteralPath $candidate) {
            $mongodPath = $candidate
            break
        }
    }
}

if (-not $mongodPath) {
    $mongodCommand = Get-Command mongod.exe -ErrorAction SilentlyContinue
    if ($mongodCommand) {
        $mongodPath = $mongodCommand.Source
    }
}

if (-not $mongodPath) {
    throw "Could not find mongod.exe. Confirm MongoDB Community Server is installed, then send me this message."
}

$occupiedPorts = @($ports | Where-Object { Test-LocalPortOpen -Port $_ })
if ($occupiedPorts.Count -gt 0) {
    throw "These lab ports are already in use: $($occupiedPorts -join ', '). No nodes were started. If you already started the lab, do not run this script again."
}

New-Item -ItemType Directory -Path $labRoot -Force | Out-Null
$startedNodes = @()

foreach ($port in $ports) {
    $nodeRoot = Join-Path $labRoot "node-$port"
    $dataPath = Join-Path $nodeRoot "data"
    $logPath = Join-Path $nodeRoot "mongod.log"
    New-Item -ItemType Directory -Path $dataPath -Force | Out-Null

    $arguments = @(
        "--replSet", $replicaSetName,
        "--bind_ip", "localhost",
        "--port", "$port",
        "--dbpath", "`"$dataPath`"",
        "--logpath", "`"$logPath`"",
        "--logappend"
    )

    $process = Start-Process -FilePath $mongodPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $startedNodes += [pscustomobject]@{ Port = $port; ProcessId = $process.Id; LogPath = $logPath }
    Write-Host "Started mongod for port $port (PID $($process.Id))."
}

$deadline = (Get-Date).AddSeconds(30)
$allReady = $false
while ((Get-Date) -lt $deadline) {
    $allReady = @($ports | Where-Object { -not (Test-LocalPortOpen -Port $_) }).Count -eq 0
    if ($allReady) {
        break
    }
    Start-Sleep -Milliseconds 500
}

if (-not $allReady) {
    $logList = ($startedNodes | ForEach-Object { $_.LogPath }) -join [Environment]::NewLine
    throw "Not all replica-set nodes started. Check these logs and send me the error: $logList"
}

Write-Host "All three MongoDB lab nodes are listening on ports $($ports -join ', ')."
Write-Host "Their logs and separate data folders are under $labRoot"
Write-Host "The existing MongoDB service on port 27017 was not changed."
