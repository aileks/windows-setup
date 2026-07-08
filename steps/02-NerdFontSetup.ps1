function Step-NerdFontSetup {
    if (Test-StateCompleted "02-NerdFontSetup") { return }

    if (Invoke-NerdFontSetup) {
        Set-StateCompleted "02-NerdFontSetup"
        Write-Log "Nerd Font setup step complete" "SUCCESS"
    }
}
Step-NerdFontSetup
