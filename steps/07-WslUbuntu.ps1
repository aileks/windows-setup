function Step-WslUbuntu {
    if (Test-StateCompleted "07-WslUbuntu") { return }
    Write-Log "Setting up WSL with Ubuntu..." "INFO"

    Write-Log "  Updating WSL via web-download, skipping the Store..." "INFO"
    wsl --update --web-download 2>&1 | Write-Host

    wsl --set-default-version 2 2>&1 | Out-Null

    $distros = wsl --list --quiet 2>$null
    $ubuntuInstalled = $distros | Where-Object { $_ -match "Ubuntu" }
    if (-not $ubuntuInstalled) {
        Write-Log "  Installing Ubuntu distro via web-download with no-launch; create your Linux user afterward..." "INFO"
        wsl --install --web-download -d Ubuntu --no-launch 2>&1 | Write-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Log "  Ubuntu install did not complete; WSL features may need a reboot first." "WARN"
            Write-Log "  Reboot, then re-run this step or run: wsl --install --web-download -d Ubuntu" "WARN"
        }
    }

    New-ConfigLink "$script:RootDir/configs/wsl/.wslconfig" "$env:USERPROFILE\.wslconfig"
    Write-Log "  Linked .wslconfig with mirrored networking" "INFO"
    Write-Log "  configs/wsl/wsl.conf is provided to apply manually inside the distro after creating your Linux user." "INFO"

    Set-StateCompleted "07-WslUbuntu"
    Write-Log "WSL Ubuntu setup complete. Run 'wsl -d Ubuntu' to create your Linux user." "SUCCESS"
}
Step-WslUbuntu
