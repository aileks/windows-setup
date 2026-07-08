function Step-WslFeatures {
    if (Test-StateCompleted "Personal.WslFeatures") { return }
    Write-Log "Enabling WSL and Virtual Machine Platform..." "INFO"

    $needsReboot = $false
    foreach ($feature in @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
        if ($state -ne "Enabled") {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart
            if ($result.RestartNeeded) { $needsReboot = $true }
        }
    }

    Set-StateCompleted "Personal.WslFeatures"

    if ($needsReboot) {
        Set-StateValue "rebootRequired" $true
        Write-Log "WSL features enabled, but a reboot is required before WSL will work." "WARN"
        Write-Log "  Reboot manually when setup finishes, then WSL/Ubuntu will be usable." "WARN"
    }
}
Step-WslFeatures
