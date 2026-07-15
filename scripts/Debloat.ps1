function Remove-InboxPackage {
    param([Parameter(Mandatory)][string]$PackageId)
    $ok = $true
    $installed = @(Get-AppxPackage -AllUsers -Name $PackageId -ErrorAction SilentlyContinue)
    foreach ($package in $installed) {
        try {
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
            Write-Log "App removed: $($package.Name)" "INFO"
        } catch {
            Write-Log "App removal failed: $($package.Name) - $($_.Exception.Message)" "WARN"
            $ok = $false
        }
    }
    $provisioned = @(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $PackageId })
    foreach ($package in $provisioned) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -AllUsers -ErrorAction Stop | Out-Null
            Write-Log "Provision removed: $PackageId" "INFO"
        } catch {
            Write-Log "Provision removal failed: $PackageId - $($_.Exception.Message)" "WARN"
            $ok = $false
        }
    }
    return $ok
}

function Remove-OneDriveCompletely {
    Write-Log "Removing OneDrive" "INFO"
    Stop-Process -Name OneDrive,FileCoAuth -Force -ErrorAction SilentlyContinue
    $setup = @(
        "$env:SystemRoot\System32\OneDriveSetup.exe",
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($setup) {
        $result = Invoke-NativeCommand -FilePath $setup -ArgumentList @("/uninstall") -NoConsole
        if ($result.ExitCode -ne 0) {
            Write-Log "OneDrive uninstall failed: exit $($result.ExitCode)" "WARN"
        }
    }
    $paths = @(
        $env:OneDrive,
        (Join-Path $env:USERPROFILE "OneDrive"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive"),
        (Join-Path $env:PROGRAMDATA "Microsoft OneDrive"),
        (Join-Path $env:ProgramFiles "Microsoft OneDrive"),
        $(if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} "Microsoft OneDrive" })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
            Write-Log "Deleted: $path" "INFO"
        }
    }
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
        -Name "OneDrive" -ErrorAction SilentlyContinue
    return $true
}

function Disable-WindowsAiComponents {
    $ok = $true
    $corePackages = @(Get-AppxPackage -AllUsers -Name "MicrosoftWindows.Client.CoreAI" -ErrorAction SilentlyContinue)
    foreach ($package in $corePackages) {
        try {
            $sid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
            $eol = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\EndOfLife\$sid\$($package.PackageFullName)"
            New-Item -Path $eol -Force | Out-Null
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
        } catch {
            Write-Log "CoreAI removal failed: $($_.Exception.Message)" "WARN"
            $ok = $false
        }
    }
    $provisioned = @(Get-AppxProvisionedPackage -Online |
        Where-Object { $_.DisplayName -eq "MicrosoftWindows.Client.CoreAI" })
    foreach ($package in $provisioned) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName `
                -AllUsers -ErrorAction Stop | Out-Null
        } catch {
            Write-Log "CoreAI provision failed: $($_.Exception.Message)" "WARN"
            $ok = $false
        }
    }
    $service = Get-Service -Name "WSAIFabricSvc" -ErrorAction SilentlyContinue
    if ($service) {
        Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service.Name -StartupType Disabled
    }
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue
    if ($feature -and $feature.State -ne "Disabled") {
        $result = Disable-WindowsOptionalFeature -FeatureName "Recall" -Online -NoRestart -ErrorAction Stop
        if ($result.RestartNeeded) { Set-StateValue "rebootRequired" $true }
    }
    return $ok
}

function Invoke-WindowsDebloat {
    Write-Log "Removing inbox apps" "INFO"
    $packageIds = @(
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.GetHelp",
        "Microsoft.MicrosoftOfficeHub",
        "Clipchamp.Clipchamp",
        "Microsoft.WindowsAlarms",
        "MicrosoftCorporationII.QuickAssist",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.MicrosoftStickyNotes",
        "Microsoft.Todos",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.Windows.DevHome",
        "Microsoft.BingWeather",
        "Microsoft.BingNews",
        "Microsoft.Copilot",
        "Microsoft.BingSearch",
        "Microsoft.StartExperiencesApp",
        "MicrosoftWindows.Client.WebExperience",
        "Microsoft.WidgetsPlatformRuntime"
    )
    $ok = $true
    foreach ($packageId in $packageIds) {
        if (-not (Remove-InboxPackage $packageId)) { $ok = $false }
    }
    try {
        if (-not (Remove-OneDriveCompletely)) { $ok = $false }
    } catch {
        Write-Log "OneDrive removal failed: $($_.Exception.Message)" "WARN"
        $ok = $false
    }
    if (-not (Disable-WindowsAiComponents)) { $ok = $false }
    return $ok
}
