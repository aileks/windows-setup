function Step-PersonalSetup {
    $script:PersonalSetupSelected = $false

    if (-not (Ask-YesNo "Use personal setup?" $true)) {
        return
    }

    $script:PersonalSetupSelected = $true

    $personalDir = "$script:RootDir/personal"
    if (-not (Test-Path $personalDir)) {
        $script:PersonalSetupSelected = $false
        Write-Log "Personal setup directory not found at $personalDir" "WARN"
        return
    }

    Write-Log "Running personal setup..." "INFO"
    $failed = $false
    $personalSteps = Get-ChildItem "$personalDir/*.ps1" | Sort-Object Name
    foreach ($personalStep in $personalSteps) {
        try {
            . $personalStep.FullName
        } catch {
            $failed = $true
            Write-Log "Personal step $($personalStep.Name) failed: $($_.Exception.Message)" "ERROR"
        }
    }

    if ($failed) {
        Write-Log "Personal setup completed with errors; re-run after addressing the failures." "WARN"
    } else {
        Write-Log "Personal setup complete" "SUCCESS"
    }

    $rebootRequired = Get-StateValue "rebootRequired"
    $question = if ($rebootRequired -eq $true) {
        "A reboot is required. Reboot now?"
    } else {
        "Reboot now?"
    }

    if (Ask-YesNo $question $true) {
        Write-Log "Rebooting..." "INFO"
        Restart-Computer
    } else {
        Write-Log "Reboot skipped; reboot manually before relying on WSL feature changes." "WARN"
    }

    $script:PersonalSetupSelected = $false
}
Step-PersonalSetup
