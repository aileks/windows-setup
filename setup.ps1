param()

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $elevateArgs = "-NoExit -ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $elevateArgs -Verb RunAs
    exit 0
}

$script:RootDir = $PSScriptRoot
$script:SetupScript = $PSCommandPath

foreach ($file in @(
    "lib/State.ps1",
    "lib/Logger.ps1",
    "lib/Link.ps1",
    "lib/Registry.ps1",
    "lib/Prompt.ps1",
    "lib/Reboot.ps1",
    "lib/Result.ps1"
)) {
    . "$script:RootDir/$file"
}

Get-ChildItem "$script:RootDir/helpers/*.ps1" | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem "$script:RootDir/scripts/windows/*.ps1" | Sort-Object Name | ForEach-Object { . $_.FullName }

if (-not (Test-SupportedEnvironment)) { exit 1 }

Write-Host ""
Write-Host "Installs software, Ubuntu, configs, and system tweaks." -ForegroundColor Yellow
Write-Host "Backups and restore points enabled." -ForegroundColor Yellow
Write-Host ""
if (-not (Ask-YesNo "Continue with setup?" $false)) {
    Write-Host "Setup cancelled" -ForegroundColor Yellow
    exit 0
}

$stateDir = "$env:USERPROFILE\.win-setup"
$stateFile = "$stateDir\state.json"
$logPath = "$stateDir\setup.log"
Load-State $stateFile | Out-Null
Initialize-Log $logPath

if (-not (New-SetupRestorePoint -Milestone "initial" -Description "win-setup initial state")) {
    Restore-SystemRestoreFrequency
    exit 1
}

if (-not (Test-WslPlatformEnabled)) {
    if (Ask-YesNo "WSL not enabled. Enable it and reboot?" $true) {
        if (-not (Enable-WslPlatformAndReboot)) {
            Restore-SystemRestoreFrequency
            exit 1
        }
    }
    Write-Log "WSL required" "WARN"
    Restore-SystemRestoreFrequency
    exit 0
}

if (Test-ResumingAfterReboot) {
    Clear-ResumeAfterReboot
    Set-StateValue "rebootRequired" $false
    Write-Log "Setup resumed" "INFO"
}

$profileFiles = @(Get-ChildItem "$script:RootDir/data", "$script:RootDir/configs", "$script:RootDir/lib", `
    "$script:RootDir/helpers", "$script:RootDir/scripts" -File -Recurse | Sort-Object FullName)
$profileFiles += Get-Item -LiteralPath $PSCommandPath
$profileMaterial = ($profileFiles | ForEach-Object { "{0}:{1}" -f $_.FullName, (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }) -join "|"
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $profileBytes = [Text.Encoding]::UTF8.GetBytes($profileMaterial)
    $profileFingerprint = ([BitConverter]::ToString($sha256.ComputeHash($profileBytes))).Replace("-", "")
} finally {
    $sha256.Dispose()
}
if ((Get-StateValue "profileFingerprint") -ne $profileFingerprint) {
    Clear-StateCompleted
    Set-StateValue "profileFingerprint" $profileFingerprint
}

$actions = @(
    [PSCustomObject]@{ Id = "winget"; Name = "Windows Package Manager"; Run = { Ensure-WinGet } },
    [PSCustomObject]@{ Id = "windows-software"; Name = "Windows software"; Run = { Invoke-SoftwareInstall } },
    [PSCustomObject]@{ Id = "windows-cli"; Name = "PowerShell CLI tools"; Run = { Invoke-CliToolsInstall } },
    [PSCustomObject]@{ Id = "nerd-fonts"; Name = "Nerd fonts"; Run = { Invoke-NerdFontSetup } },
    [PSCustomObject]@{ Id = "npiperelay"; Name = "Bitwarden SSH relay"; Prerequisite = { Test-BitwardenInstalled }; PrerequisiteMessage = "Bitwarden is not installed"; Run = { Install-NpipeRelay } },
    [PSCustomObject]@{ Id = "ubuntu-environment"; Name = "Ubuntu 26.04 environment"; Run = {
        $relayPath = Join-Path $env:LOCALAPPDATA "Programs\npiperelay\npiperelay.exe"
        if (-not ((Test-BitwardenInstalled) -and (Test-Path -LiteralPath $relayPath))) { $relayPath = "" }
        Invoke-WslBootstrap -RelayPath $relayPath
    } },
    [PSCustomObject]@{ Id = "vscode-wsl"; Name = "VS Code WSL extension"; Run = { Install-VsCodeWslExtension } },
    [PSCustomObject]@{ Id = "pre-tweaks-safety"; Name = "Pre-tweaks backup and restore point"; Run = { Initialize-PreTweaksSafety -BackupRoot "$stateDir\registry-backups" } },
    [PSCustomObject]@{ Id = "developer-tweaks"; Name = "Developer settings"; Run = { Invoke-DeveloperTweaks } },
    [PSCustomObject]@{ Id = "explorer-tweaks"; Name = "Explorer and taskbar tweaks"; Run = { Invoke-ExplorerTweaks } },
    [PSCustomObject]@{ Id = "privacy-tweaks"; Name = "Privacy and telemetry policies"; Run = { Invoke-PrivacyTweaks } },
    [PSCustomObject]@{ Id = "service-tweaks"; Name = "Windows service settings"; Run = { Invoke-ServiceTweaks } },
    [PSCustomObject]@{ Id = "windows-debloat"; Name = "Windows inbox app removal"; Run = { Invoke-WindowsDebloat } },
    [PSCustomObject]@{ Id = "power-plan"; Name = "Ultimate Performance power plan"; Run = { Invoke-PowerPlanTweaks } },
    [PSCustomObject]@{ Id = "bitwarden-ssh"; Name = "Windows SSH agent handoff"; Prerequisite = { Test-BitwardenInstalled }; PrerequisiteMessage = "Bitwarden is not installed; Windows ssh-agent was unchanged"; Run = { Disable-WindowsOpenSshAgent } },
    [PSCustomObject]@{ Id = "komorebi"; Name = "Komorebi configuration"; Run = { Invoke-KomorebiSetup } },
    [PSCustomObject]@{ Id = "windows-terminal"; Name = "Windows Terminal"; Run = { Invoke-WindowsTerminalSetup } },
    [PSCustomObject]@{ Id = "powershell-profile"; Name = "PowerShell profile"; Run = { Invoke-PowerShellProfileSetup } }
)

$results = @($actions | ForEach-Object { New-SetupResult -Id $_.Id -Name $_.Name })

for ($i = 0; $i -lt $actions.Count; $i++) {
    $action = $actions[$i]
    $result = $results[$i]
    if (Test-StateCompleted $action.Id) {
        $result.Status = "Skipped"
        $result.Message = "exists"
        Write-Log "Exists: $($action.Name)" "INFO"
        continue
    }
    if (($action.PSObject.Properties.Name -contains "Prerequisite") -and -not (& $action.Prerequisite)) {
        $result.Status = "Failed"
        $result.ExitCode = 1
        $result.Message = $action.PrerequisiteMessage
        Write-Log "Failed: $($action.Name) - $($result.Message)" "ERROR"
        Set-StateResult $result
        continue
    }

    $result.Status = "Running"
    $rebootWasRequired = (Get-StateValue "rebootRequired") -eq $true
    Write-Log "$($action.Name)" "INFO"
    try {
        $success = & $action.Run
        if ($action.Id -eq "windows-software") { $result.PackageResults = @($script:LastSoftwarePackageResults) }
        if ($success -eq $true) {
            $result.Status = "Success"
            Write-Log "Done: $($action.Name)" "SUCCESS"
        } else {
            $result.Status = "Failed"
            $result.ExitCode = 1
            $failedPackages = @($result.PackageResults | Where-Object { $_.Status -eq "Failed" } | ForEach-Object { $_.Name })
            $result.Message = if ($failedPackages.Count) { "failed packages: $($failedPackages -join ', ')" } else { "see setup log" }
            Write-Log "Failed: $($action.Name) - $($result.Message)" "ERROR"
        }
    } catch {
        $result.Status = "Failed"
        $result.ExitCode = 1
        $result.Message = $_.Exception.Message
        Write-Log "$($action.Name) failed: $($_.Exception.Message)" "ERROR"
    }
    if (-not $rebootWasRequired -and (Get-StateValue "rebootRequired") -eq $true) { $result.RebootRequired = $true }
    Set-StateResult $result
}

try { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue } catch {
    Write-Log "Explorer restart failed: $($_.Exception.Message)" "WARN"
}

$failed = @($results | Where-Object { $_.Status -eq "Failed" })
if ($failed.Count -eq 0) {
    if (-not (New-SetupRestorePoint -Milestone "complete" -Description "win-setup complete")) {
        $restoreResult = New-SetupResult -Id "final-restore-point" -Name "Final restore point" `
            -Status "Failed" -ExitCode 1 -Message "creation failed"
        $results += $restoreResult
        $failed = @($results | Where-Object { $_.Status -eq "Failed" })
    }
}
Restore-SystemRestoreFrequency
Show-SetupResults -Results $results -LogPath $logPath

if ($failed.Count -gt 0) {
    Write-Log "Setup failed: $($failed.Count) actions" "ERROR"
    Read-Host "Press Enter to close"
    exit 1
}

Write-Log "Setup complete" "SUCCESS"
if ((Get-StateValue "rebootRequired") -eq $true) {
    if (Ask-YesNo "A reboot is required. Reboot now?" $true) { Restart-Computer }
    else { Write-Log "Reboot skipped" "WARN" }
}
