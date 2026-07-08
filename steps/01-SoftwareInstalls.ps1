function Step-SoftwareInstalls {
    if (Test-StateCompleted "01-SoftwareInstalls") { return }

    Write-Log "Selecting Windows software to install..." "INFO"
    if (Invoke-SoftwareSelectionInstall) {
        Set-StateCompleted "01-SoftwareInstalls"
        Write-Log "Software installation step complete" "SUCCESS"
    }
}
Step-SoftwareInstalls
