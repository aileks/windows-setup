function Invoke-KomorebiSetup {
    if (-not (Test-SoftwareInstalled -Commands @("komorebic"))) {
        Write-Log "Komorebi is unavailable" "ERROR"
        return $false
    }

    $komorebiConfig = "$env:USERPROFILE\komorebi.json"
    $komorebiBarConfig = "$env:USERPROFILE\komorebi.bar.json"
    $whkdConfig = "$env:USERPROFILE\.config\whkdrc"

    New-ConfigLink "$script:RootDir/configs/komorebi/komorebi.json" $komorebiConfig
    New-ConfigLink "$script:RootDir/configs/komorebi/komorebi.bar.json" $komorebiBarConfig
    New-ConfigLink "$script:RootDir/configs/komorebi/whkdrc" $whkdConfig
    Write-Log "  Linked komorebi config files" "INFO"

    Write-Log "Setting up komorebi..." "INFO"

    Refresh-EnvironmentPath

    # Frees Win+L for whkd by disabling the OS lock; Win+Escape locks via KomorebiLock below.
    if (-not (Set-RegistrySafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        -Name "DisableLockWorkstation" -Value 1 -Type DWord -PassThru)) { return $false }
    Write-Log "  Set DisableLockWorkstation=1 to free Win+L for komorebi" "INFO"

    # Elevated on-demand task: non-elevated whkd can't toggle the policy, so this re-enables locking, locks, then disables it again to keep Win+L free.
    $lockCmd = '/c reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLockWorkstation /t REG_DWORD /d 0 /f && rundll32.exe user32.dll,LockWorkStation && ping 127.0.0.1 -n 2 >nul && reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLockWorkstation /t REG_DWORD /d 1 /f'
    $action    = New-ScheduledTaskAction -Execute "cmd.exe" -Argument $lockCmd
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                     -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName "KomorebiLock" -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    Write-Log "  Registered KomorebiLock scheduled task for Win+Escape lock" "INFO"

    if (-not (Get-Command komorebic -ErrorAction SilentlyContinue)) {
        Write-Log "  komorebic not found; fetch-asc and autostart are unavailable" "WARN"
        return $false
    }

    $nativeResult = Invoke-NativeCommand -FilePath "komorebic" -ArgumentList @("fetch-asc")
    if ($nativeResult.ExitCode -ne 0) { return $false }
    Write-Log "  Fetched application-specific configs" "INFO"

    Get-ScheduledTask -TaskName 'Komorebi' -ErrorAction SilentlyContinue |
        Unregister-ScheduledTask -Confirm:$false

    $nativeResult = Invoke-NativeCommand -FilePath "komorebic" -ArgumentList @(
        "enable-autostart", "--whkd", "--bar", "--masir"
    )
    if ($nativeResult.ExitCode -ne 0) { return $false }
    Write-Log "  Enabled autostart" "INFO"

    Write-Log "Komorebi configured." "SUCCESS"
    Write-Log "  To start now without signing out, run in a normal non-admin terminal: komorebic start --whkd --bar --masir" "INFO"
    return $true
}
