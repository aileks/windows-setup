function Get-CliToolsCatalog {
    $catalogPath = Join-Path $script:RootDir "data/cli-tools.json"
    if (-not (Test-Path $catalogPath)) {
        throw "CLI tools catalog not found at $catalogPath"
    }

    Get-Content $catalogPath -Raw | ConvertFrom-Json
}

function Initialize-WindowsCliToolConfigs {
    $bat = Get-Command bat -ErrorAction SilentlyContinue
    if (-not $bat) {
        Write-Log "bat unavailable for config setup" "ERROR"
        return $false
    }

    $batConfigResult = Invoke-NativeCommand -FilePath $bat.Source -ArgumentList @("--config-dir") -NoConsole
    $batConfigDir = (@($batConfigResult.Output) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Last 1).Trim()
    if ($batConfigResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($batConfigDir)) {
        Write-Log "bat config directory unavailable" "ERROR"
        return $false
    }

    New-ConfigLink "$script:RootDir/configs/common/bat/config" (Join-Path $batConfigDir "config")
    Get-ChildItem "$script:RootDir/configs/common/bat/themes" -File | ForEach-Object {
        New-ConfigLink $_.FullName (Join-Path $batConfigDir "themes/$($_.Name)")
    }
    $batCacheResult = Invoke-NativeCommand -FilePath $bat.Source -ArgumentList @("cache", "--build") -NoConsole
    if ($batCacheResult.ExitCode -ne 0) {
        Write-Log "bat theme cache failed" "ERROR"
        return $false
    }

    $btop = Get-Command btop -ErrorAction SilentlyContinue
    if (-not $btop) {
        Write-Log "btop unavailable for config setup" "ERROR"
        return $false
    }

    $btopPath = $btop.Source
    $btopCommandItem = Get-Item -LiteralPath $btopPath -Force
    if ($btopCommandItem.LinkType -eq "SymbolicLink") {
        $target = [string](@($btopCommandItem.Target) | Select-Object -First 1)
        if (-not [IO.Path]::IsPathRooted($target)) {
            $target = Join-Path (Split-Path $btopPath -Parent) $target
        }
        if (Test-Path -LiteralPath $target) { $btopPath = $target }
    }

    $btopConfigDir = Split-Path $btopPath -Parent
    New-ConfigLink "$script:RootDir/configs/common/btop/btop.conf" (Join-Path $btopConfigDir "btop.conf")
    Get-ChildItem "$script:RootDir/configs/common/btop/themes" -File | ForEach-Object {
        New-ConfigLink $_.FullName (Join-Path $btopConfigDir "themes/$($_.Name)")
    }

    Write-Log "CLI tool configs linked" "SUCCESS"
    return $true
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
    if (-not (Initialize-WindowsCliToolConfigs)) { $succeeded = $false }
    return $succeeded
}
