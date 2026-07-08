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

function Get-SelectedSoftwareIds {
    $selected = Get-StateValue "selectedSoftwareIds"
    if ($null -eq $selected) { return @() }
    @($selected) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
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

function Test-SoftwareSelectedOrInstalled {
    param(
        [string[]]$PackageIds = @(),
        [string[]]$Commands = @(),
        [scriptblock]$Detector
    )

    $selected = @(Get-SelectedSoftwareIds)
    foreach ($id in $PackageIds) {
        if ($selected -contains $id) { return $true }
    }

    Test-SoftwareInstalled -Commands $Commands -Detector $Detector
}

function Ensure-WinGet {
    Refresh-EnvironmentPath
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }

    Write-Log "winget not found, installing via Microsoft.WinGet.Client..." "INFO"
    try {
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name Microsoft.WinGet.Client -Force -AllowClobber
        Repair-WinGetPackageManager -AllUsers
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

function Read-SoftwareCategorySelection {
    param(
        [Parameter(Mandatory)]$Category
    )

    $items = @($Category.items)
    while ($true) {
        Write-Host ""
        Write-Host $Category.name -ForegroundColor White

        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            $label = "  {0}. {1}" -f ($i + 1), $item.name
            if ($item.description) {
                $label = "$label - $($item.description)"
            }
            Write-Host $label -ForegroundColor Cyan
        }

        $prompt = if ($Category.allowMultiple) {
            "Select $($Category.name) (comma-separated numbers, a for all, blank to skip)"
        } else {
            "Select $($Category.name) (one number, blank to skip)"
        }

        $reply = Ask-Input $prompt ""
        if ([string]::IsNullOrWhiteSpace($reply)) { return @() }

        $normalized = $reply.Trim().ToLowerInvariant()
        if ($normalized -eq "a") {
            if ($Category.allowMultiple) { return $items }
            Write-Log "  Pick a single window management option, or leave blank to skip." "WARN"
            continue
        }

        $tokens = @($reply -split "[,\s]+" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $invalid = @()
        $indexes = @()

        foreach ($token in $tokens) {
            if ($token -notmatch "^\d+$") {
                $invalid += $token
                continue
            }

            $index = [int]$token
            if ($index -lt 1 -or $index -gt $items.Count) {
                $invalid += $token
            } else {
                $indexes += $index
            }
        }

        $indexes = @($indexes | Select-Object -Unique)
        if ($invalid.Count -gt 0) {
            Write-Log "  Invalid selection: $($invalid -join ', ')" "WARN"
            continue
        }

        if (-not $Category.allowMultiple -and $indexes.Count -gt 1) {
            Write-Log "  Pick only one window management option, or leave blank to skip." "WARN"
            continue
        }

        return @($indexes | ForEach-Object {
            $selectedIndex = [int]$_ - 1
            $items[$selectedIndex]
        })
    }
}

function Get-InstallIdsForSoftwareItem {
    param([Parameter(Mandatory)]$Item)

    $ids = @()
    if ($Item.installer -eq "winget") {
        $ids += $Item.id
        if ($Item.dependencies) {
            $ids += @($Item.dependencies)
        }
    }
    $ids
}

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$Name
    )

    Write-Log "  Installing $Name ($PackageId) via winget..." "INFO"
    $arguments = @(
        "install",
        "--id", $PackageId,
        "--exact",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    )

    & winget @arguments 2>&1 | Write-Host
    if ($LASTEXITCODE -eq 0) {
        Write-Log "  Installed $Name" "SUCCESS"
    } else {
        Write-Log "  winget install failed for $Name ($PackageId) with exit code $LASTEXITCODE" "WARN"
    }
}

function Install-DirectPackage {
    param([Parameter(Mandatory)]$Item)

    $downloadDir = Join-Path $env:TEMP "win-setup-installers"
    if (-not (Test-Path $downloadDir)) {
        New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null
    }

    $installerPath = Join-Path $downloadDir $Item.fileName
    Write-Log "  Downloading $($Item.name) from $($Item.url)..." "INFO"
    try {
        Invoke-WebRequest -Uri $Item.url -OutFile $installerPath -UseBasicParsing
    } catch {
        Write-Log "  Failed to download $($Item.name): $($_.Exception.Message)" "WARN"
        return
    }

    Write-Log "  Installing $($Item.name)..." "INFO"
    try {
        $process = Start-Process -FilePath $installerPath -ArgumentList $Item.arguments -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Log "  Installed $($Item.name)" "SUCCESS"
        } else {
            Write-Log "  $($Item.name) installer returned exit code $($process.ExitCode)" "WARN"
        }
    } catch {
        Write-Log "  Failed to install $($Item.name): $($_.Exception.Message)" "WARN"
    }
}

function Install-SoftwareItem {
    param([Parameter(Mandatory)]$Item)

    switch ($Item.installer) {
        "winget" {
            foreach ($id in (Get-InstallIdsForSoftwareItem -Item $Item)) {
                $name = if ($id -eq $Item.id) { $Item.name } else { $id }
                Install-WinGetPackage -PackageId $id -Name $name
            }
        }
        "direct" {
            Install-DirectPackage $Item
        }
        default {
            Write-Log "  Unknown installer '$($Item.installer)' for $($Item.name); skipping." "WARN"
        }
    }
}

function Invoke-SoftwareSelectionInstall {
    if (-not (Ensure-WinGet)) { return $false }

    $catalog = Get-SoftwareCatalog
    $selected = New-Object System.Collections.Generic.List[object]

    foreach ($category in @($catalog.categories)) {
        foreach ($item in @(Read-SoftwareCategorySelection $category)) {
            $selected.Add($item)
        }
    }

    $selectedIds = @($selected | ForEach-Object { $_.id })
    Set-StateValue -Key "selectedSoftwareIds" -Value $selectedIds

    if ($selected.Count -eq 0) {
        Write-Log "No software selected." "INFO"
        return $true
    }

    Write-Log "Installing selected software..." "INFO"
    foreach ($item in $selected) {
        Install-SoftwareItem $item
    }

    Refresh-EnvironmentPath
    return $true
}
