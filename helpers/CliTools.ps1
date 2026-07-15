function Get-CliToolsCatalog {
    $catalogPath = Join-Path $script:RootDir "data/cli-tools.json"
    if (-not (Test-Path $catalogPath)) {
        throw "CLI tools catalog not found at $catalogPath"
    }

    Get-Content $catalogPath -Raw | ConvertFrom-Json
}

function Invoke-CliToolsInstall {
    $catalog = Get-CliToolsCatalog
    if (-not (Ensure-WinGet)) { return $false }

    Write-Log "Installing CLI tools" "INFO"
    $succeeded = $true
    foreach ($tool in @($catalog.tools)) {
        if (-not (Install-WinGetPackage -PackageId $tool.id -Name $tool.name)) {
            $succeeded = $false
        }
    }

    Refresh-EnvironmentPath
    return $succeeded
}
