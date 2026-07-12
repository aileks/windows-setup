param()

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor `
    [Net.SecurityProtocolType]::Tls12

$archiveUrl = "https://codeberg.org/aileks/win-setup/archive/main.zip"
$stateRoot = Join-Path $env:USERPROFILE ".win-setup"
$sourcePath = Join-Path $stateRoot "source"
$tempPath = Join-Path $env:TEMP "win-setup-bootstrap-$([guid]::NewGuid())"
$archivePath = Join-Path $tempPath "win-setup.zip"
$extractPath = Join-Path $tempPath "extract"
$stagingPath = Join-Path $stateRoot ".source-new-$([guid]::NewGuid())"
$backupPath = $null

try {
    New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
    Write-Host "Downloading win-setup..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -UseBasicParsing
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force

    $sourceCandidates = @(Get-ChildItem -Path $extractPath -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName "setup.ps1")
    })
    if ($sourceCandidates.Count -ne 1) {
        throw "Downloaded archive did not contain one win-setup source directory"
    }

    $downloadedSource = $sourceCandidates[0].FullName
    foreach ($requiredPath in @("configs", "data", "helpers", "lib", "personal", "setup.ps1")) {
        if (-not (Test-Path -LiteralPath (Join-Path $downloadedSource $requiredPath))) {
            throw "Downloaded archive is missing $requiredPath"
        }
    }

    if (-not (Test-Path -LiteralPath $stateRoot)) {
        New-Item -Path $stateRoot -ItemType Directory -Force | Out-Null
    }
    Move-Item -LiteralPath $downloadedSource -Destination $stagingPath

    if (Test-Path -LiteralPath $sourcePath) {
        $backupPath = Join-Path $stateRoot "source.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
        Move-Item -LiteralPath $sourcePath -Destination $backupPath
    }

    try {
        Move-Item -LiteralPath $stagingPath -Destination $sourcePath
    } catch {
        if ($backupPath -and -not (Test-Path -LiteralPath $sourcePath) -and (Test-Path -LiteralPath $backupPath)) {
            Move-Item -LiteralPath $backupPath -Destination $sourcePath
        }
        throw
    }

    $setupPath = Join-Path $sourcePath "setup.ps1"
    Write-Host "Source installed at $sourcePath" -ForegroundColor Green
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setupPath
    if ($LASTEXITCODE -ne 0) {
        throw "setup.ps1 exited with code $LASTEXITCODE"
    }
} finally {
    if (Test-Path -LiteralPath $stagingPath) {
        Remove-Item -LiteralPath $stagingPath -Recurse -Force
    }
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Recurse -Force
    }
}
