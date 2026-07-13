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

function Resolve-OptionalSoftwareSelection {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items,
        [AllowNull()][AllowEmptyString()][string]$Response
    )

    if ([string]::IsNullOrWhiteSpace($Response)) {
        return [PSCustomObject]@{ Valid = $true; Items = @(); Message = "" }
    }
    if ($Response.Trim() -ieq "a") {
        return [PSCustomObject]@{ Valid = $true; Items = @($Items); Message = "" }
    }

    $tokens = @($Response -split "[,\s]+" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $selectedIndexes = New-Object System.Collections.Generic.List[int]
    $seen = @{}
    foreach ($token in $tokens) {
        $number = 0
        if (-not [int]::TryParse($token, [ref]$number) -or $number -lt 1 -or $number -gt $Items.Count) {
            return [PSCustomObject]@{
                Valid   = $false
                Items   = @()
                Message = "Use only numbers 1-$($Items.Count), separated by commas or spaces; 'a' selects all."
            }
        }
        if (-not $seen.ContainsKey($number)) {
            $seen[$number] = $true
            $selectedIndexes.Add($number - 1)
        }
    }

    $selectedItems = @($selectedIndexes | ForEach-Object { $Items[$_] })
    return [PSCustomObject]@{ Valid = $true; Items = $selectedItems; Message = "" }
}

function Read-OptionalSoftwareSelection {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items)

    if ($Items.Count -eq 0) {
        return [PSCustomObject]@{ Cancelled = $false; Items = @() }
    }

    try {
        if ([Console]::IsInputRedirected) {
            Write-Log "Input is redirected; no optional software was selected." "INFO"
            return [PSCustomObject]@{ Cancelled = $false; Items = @() }
        }
    } catch {
        Write-Log "Console input is unavailable; no optional software was selected." "WARN"
        return [PSCustomObject]@{ Cancelled = $false; Items = @() }
    }

    Write-Host ""
    Write-Host "Optional software" -ForegroundColor White
    for ($index = 0; $index -lt $Items.Count; $index++) {
        $item = $Items[$index]
        Write-Host ("  {0}. {1} - {2}" -f ($index + 1), $item.name, $item.description)
    }
    Write-Host "Enter numbers separated by commas or spaces, 'a' for all, or press Enter for none." -ForegroundColor DarkGray

    while ($true) {
        $resolved = Resolve-OptionalSoftwareSelection -Items $Items -Response (Read-Host "Optional software")
        if ($resolved.Valid) {
            return [PSCustomObject]@{ Cancelled = $false; Items = @($resolved.Items) }
        }
        Write-Host "Invalid selection. $($resolved.Message)" -ForegroundColor Yellow
    }
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
        Install-PackageProvider -Name NuGet -Force | Out-Host
        $repository = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        $originalPolicy = if ($repository) { $repository.InstallationPolicy } else { "Untrusted" }
        try {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
            Install-Module -Name Microsoft.WinGet.Client -Force -AllowClobber -Verbose
            Repair-WinGetPackageManager -AllUsers | Out-Host
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

function Test-WinGetPackageId {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [string]$Source = ""
    )

    $arguments = @("show", "--id", $PackageId, "--exact", "--accept-source-agreements", "--disable-interactivity")
    if (-not [string]::IsNullOrWhiteSpace($Source)) { $arguments += @("--source", $Source) }
    $result = Invoke-NativeCommand -FilePath "winget" -ArgumentList $arguments -OutputPrefix "    " -NoConsole
    return $result.ExitCode -eq 0
}

function Test-WinGetPackageInstalled {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [string]$Source = ""
    )

    $arguments = @("list", "--id", $PackageId, "--exact", "--accept-source-agreements", "--disable-interactivity")
    if (-not [string]::IsNullOrWhiteSpace($Source)) { $arguments += @("--source", $Source) }
    $result = Invoke-NativeCommand -FilePath "winget" -ArgumentList $arguments -OutputPrefix "    " -NoConsole
    return $result.ExitCode -eq 0
}

function Test-BitwardenInstalled {
    $wingetRegistered = (Test-WinGetPackageInstalled -PackageId "Bitwarden.Bitwarden")
    if (-not $wingetRegistered) {
        $wingetRegistered = Test-WinGetPackageInstalled -PackageId "9PJSDV0VPK04" -Source "msstore"
    }

    $userRegistered = $false
    foreach ($uninstallRoot in @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )) {
        $registration = Get-ItemProperty -Path $uninstallRoot -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "Bitwarden*" } |
            Select-Object -First 1
        if ($null -ne $registration) {
            $userRegistered = $true
            break
        }
    }

    if (-not $userRegistered -and (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
        $appxRegistration = Get-AppxPackage -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*Bitwarden*" -or $_.PackageFamilyName -like "*Bitwarden*" } |
            Select-Object -First 1
        $userRegistered = $null -ne $appxRegistration
    }

    if (-not $wingetRegistered) {
        Write-Log "  Bitwarden was not found in winget's installed-package registration." "WARN"
    }
    if (-not $userRegistered) {
        Write-Log "  Bitwarden has no per-user uninstall or Appx registration." "WARN"
    }
    return $wingetRegistered -and $userRegistered
}

function New-SoftwarePackageResult {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$Name
    )

    [PSCustomObject]@{
        Id           = $PackageId
        Name         = $Name
        Status       = "Pending"
        Attempts     = @()
        ExitCode     = 0
        Verified     = $false
        Verification = "pending"
    }
}

function Install-WinGetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$Name,
        [string]$Source = "",
        [string]$Scope = "",
        [string]$FallbackId = "",
        [string]$FallbackSource = "",
        [switch]$PassThru
    )

    $packageResult = New-SoftwarePackageResult -PackageId $PackageId -Name $Name
    $isBitwarden = $PackageId -eq "Bitwarden.Bitwarden"

    $alreadyInstalled = if ($isBitwarden) {
        Test-BitwardenInstalled
    } else {
        Test-WinGetPackageInstalled -PackageId $PackageId -Source $Source
    }
    Write-Log "  Validating $Name package ID ($PackageId)..." "INFO"
    $primaryValid = Test-WinGetPackageId -PackageId $PackageId -Source $Source
    if ($alreadyInstalled) {
        $packageResult.Status = "Skipped"
        $packageResult.Verified = $true
        $packageResult.Verification = "already installed and verified"
        if (-not $primaryValid) {
            Write-Log "  $Name is installed, but its source ID could not be validated right now." "WARN"
        }
        Write-Log "  Skipped $Name; it is already installed and verified." "SUCCESS"
        if ($PassThru) { return $packageResult }
        return $true
    }

    $candidates = New-Object System.Collections.Generic.List[object]
    $candidates.Add([PSCustomObject]@{ Id = $PackageId; Source = $Source; Scope = $Scope; Valid = $primaryValid })
    if (-not [string]::IsNullOrWhiteSpace($FallbackId)) {
        Write-Log "  Validating fallback package ID ($FallbackId)..." "INFO"
        $fallbackValid = Test-WinGetPackageId -PackageId $FallbackId -Source $FallbackSource
        $candidates.Add([PSCustomObject]@{ Id = $FallbackId; Source = $FallbackSource; Scope = ""; Valid = $fallbackValid })
    }

    foreach ($candidate in $candidates) {
        if (-not $candidate.Valid) {
            $packageResult.Attempts += [PSCustomObject]@{
                PackageId = $candidate.Id
                Source    = if ($candidate.Source) { $candidate.Source } else { "winget" }
                Scope     = $candidate.Scope
                ExitCode  = 2
                Status    = "InvalidPackageId"
            }
            Write-Log "  Exact winget lookup failed for $($candidate.Id); skipping that installer." "WARN"
            continue
        }

        $sourceLabel = if ($candidate.Source) { $candidate.Source } else { "winget" }
        Write-Log "  Installing $Name ($($candidate.Id)) via $sourceLabel..." "INFO"
        $arguments = @(
            "install", "--id", $candidate.Id, "--exact",
            "--accept-package-agreements", "--accept-source-agreements",
            "--disable-interactivity"
        )
        if (-not [string]::IsNullOrWhiteSpace($candidate.Source)) {
            $arguments += @("--source", $candidate.Source)
        }
        if (-not [string]::IsNullOrWhiteSpace($candidate.Scope)) {
            $arguments += @("--scope", $candidate.Scope)
        }

        $nativeResult = Invoke-NativeCommand -FilePath "winget" -ArgumentList $arguments -OutputPrefix "    "
        $attemptStatus = if ($nativeResult.ExitCode -eq 0) { "Completed" } else { "Failed" }
        $packageResult.Attempts += [PSCustomObject]@{
            PackageId = $candidate.Id
            Source    = $sourceLabel
            Scope     = $candidate.Scope
            ExitCode  = $nativeResult.ExitCode
            Status    = $attemptStatus
        }
        $packageResult.ExitCode = $nativeResult.ExitCode

        if ($nativeResult.ExitCode -ne 0) {
            Write-Log "  Installer failed for $Name ($($candidate.Id)) with exit code $($nativeResult.ExitCode)." "WARN"
            continue
        }

        $verified = if ($isBitwarden) {
            Test-BitwardenInstalled
        } else {
            Test-WinGetPackageInstalled -PackageId $candidate.Id -Source $candidate.Source
        }
        if ($verified) {
            $packageResult.Status = "Success"
            $packageResult.Verified = $true
            $packageResult.Verification = "winget and installation registration verified"
            Write-Log "  Installed and verified $Name" "SUCCESS"
            if ($PassThru) { return $packageResult }
            return $true
        }

        $packageResult.Verification = "installer exited successfully, but verification failed"
        $packageResult.ExitCode = 1
        Write-Log "  $Name installer exited successfully, but post-install verification failed." "WARN"
    }

    $packageResult.Status = "Failed"
    if ($packageResult.Attempts.Count -eq 0) { $packageResult.ExitCode = 2 }
    if ($packageResult.Verification -eq "pending") { $packageResult.Verification = "not installed" }
    Write-Log "  Failed to install and verify $Name after $($packageResult.Attempts.Count) attempt(s)." "ERROR"
    if ($PassThru) { return $packageResult }
    return $false
}

function Invoke-SoftwareInstall {
    param([object[]]$OptionalItems = @())

    $catalog = Get-SoftwareCatalog
    $selected = @(@($catalog.required) + @($OptionalItems))
    Set-StateValue -Key "selectedOptionalSoftwareIds" -Value @($OptionalItems | ForEach-Object { $_.id })

    if (-not (Ensure-WinGet)) {
        $script:LastSoftwarePackageResults = @($selected | ForEach-Object {
            $failedResult = New-SoftwarePackageResult -PackageId $_.id -Name $_.name
            $failedResult.Status = "Failed"
            $failedResult.ExitCode = 1
            $failedResult.Verification = "winget unavailable"
            $failedResult
        })
        Set-StateValue -Key "softwarePackageResults" -Value @($script:LastSoftwarePackageResults)
        return $false
    }

    Write-Log "Installing Windows software..." "INFO"
    $packageResults = New-Object System.Collections.Generic.List[object]
    foreach ($item in $selected) {
        $result = Install-WinGetPackage -PackageId $item.id -Name $item.name -Source $item.source `
            -Scope $item.scope -FallbackId $item.fallbackId -FallbackSource $item.fallbackSource -PassThru
        $packageResults.Add($result)
    }

    # Windows PowerShell 5.1 can throw "Argument types do not match" when an
    # array subexpression enumerates a generic List[object]. ToArray() avoids
    # the dynamic binder path and gives state/result handling a real object[].
    $script:LastSoftwarePackageResults = $packageResults.ToArray()
    Set-StateValue -Key "softwarePackageResults" -Value @($script:LastSoftwarePackageResults)
    Refresh-EnvironmentPath
    return @($script:LastSoftwarePackageResults | Where-Object { $_.Status -eq "Failed" }).Count -eq 0
}
