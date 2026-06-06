function Step-PwshSetup {
    if (Test-StateCompleted "11-PwshSetup") { return }
    Write-Log "Configuring PowerShell 7 modules..." "INFO"

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Log "  pwsh not found; skipping module setup. Install PowerShell 7 and re-run." "WARN"
        return
    }

    # setup.ps1 runs under Windows PowerShell 5.1; shell into pwsh so PSFzf lands in the PS7 module path
    $cmd = @'
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
if (-not (Get-Module -ListAvailable PSFzf)) {
    Install-Module PSFzf -Scope CurrentUser -Force -AllowClobber
}
'@
    pwsh -NoProfile -Command $cmd 2>&1 | Write-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Log "  PSFzf install returned exit code $LASTEXITCODE; Ctrl+R/Ctrl+T fzf bindings may be unavailable." "WARN"
    }

    Set-StateCompleted "11-PwshSetup"
    Write-Log "PowerShell 7 modules configured: PSFzf" "SUCCESS"
}
Step-PwshSetup
