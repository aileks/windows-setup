function Refresh-EnvironmentPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Get-SoftwareCatalog {
    $catalogPath = Join-Path $script:RootDir "data/software.json"
    if (-not (Test-Path $catalogPath)) {
        throw "Software catalog not found at $catalogPath"
    }

    Get-Content $catalogPath -Raw | ConvertFrom-Json
}

function Test-SoftwareInstalled {
    param(
        [string[]]$Commands = @(),
        [scriptblock]$Detector
    )

    Refresh-EnvironmentPath
    foreach ($command in $Commands) {
        if (Get-Command $command -ErrorAction SilentlyContinue) { return $true }
    }

    if ($Detector) {
        try {
            if (& $Detector) { return $true }
        } catch {
            Write-Log "  Install detection failed: $($_.Exception.Message)" "WARN"
        }
    }

    return $false
}

function Ensure-WinGet {
    Refresh-EnvironmentPath
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }

    Write-Log "winget not found, installing via Microsoft.WinGet.Client..." "INFO"
    try {
        Install-PackageProvider -Name NuGet -Force | Out-Null
        $repository = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        $originalPolicy = if ($repository) { $repository.InstallationPolicy } else { "Untrusted" }
        try {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
            Install-Module -Name Microsoft.WinGet.Client -Force -AllowClobber
            Repair-WinGetPackageManager -AllUsers | Out-Null
        } finally {
            Set-PSRepository -Name PSGallery -InstallationPolicy $originalPolicy -ErrorAction SilentlyContinue
        }
        Refresh-EnvironmentPath
    } catch {
        Write-Log "  Failed to install winget: $($_.Exception.Message)" "ERROR"
        return $false
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "  winget still not found. Install winget manually and re-run." "ERROR"
        return $false
    }

    Write-Log "winget is available" "SUCCESS"
    return $true
}

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$Name,
        [string]$Source = ""
    )

    Write-Log "  Installing $Name ($PackageId) via winget..." "INFO"
    $arguments = @(
        "install",
        "--id",
        $PackageId,
        "--exact",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    )
    if (-not [string]::IsNullOrWhiteSpace($Source)) {
        $arguments += @("--source", $Source)
    }

    $output = @(& winget @arguments 2>&1)
    $exitCode = $LASTEXITCODE
    foreach ($line in $output) { Write-Log "    $line" "INFO" }
    if ($exitCode -eq 0) {
        Write-Log "  Installed $Name" "SUCCESS"
        return $true
    } else {
        Write-Log "  winget install failed for $Name ($PackageId) with exit code $exitCode" "WARN"
        return $false
    }
}

function Invoke-SoftwareInstall {
    param([object[]]$OptionalItems = @())

    if (-not (Ensure-WinGet)) { return $false }

    $catalog = Get-SoftwareCatalog
    $selected = @(@($catalog.required) + @($OptionalItems))
    Set-StateValue -Key "selectedOptionalSoftwareIds" -Value @($OptionalItems | ForEach-Object { $_.id })

    Write-Log "Installing Windows software..." "INFO"
    $succeeded = $true
    foreach ($item in $selected) {
        if (-not (Install-WinGetPackage -PackageId $item.id -Name $item.name -Source $item.source)) {
            $succeeded = $false
        }
    }

    Refresh-EnvironmentPath
    return $succeeded
}
