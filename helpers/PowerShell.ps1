function Invoke-PowerShellProfileSetup {
    Refresh-EnvironmentPath
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Log "PowerShell 7 is unavailable" "ERROR"
        return $false
    }

    $moduleScript = @'
$ErrorActionPreference = "Stop"
$repository = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
$originalPolicy = if ($repository) { $repository.InstallationPolicy } else { "Untrusted" }
try {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    if (-not (Get-Module -ListAvailable PSFzf)) {
        Install-Module PSFzf -Scope CurrentUser -Force -AllowClobber
    }
} finally {
    Set-PSRepository -Name PSGallery -InstallationPolicy $originalPolicy -ErrorAction SilentlyContinue
}
'@
    $output = @(& pwsh -NoProfile -Command $moduleScript 2>&1)
    $exitCode = $LASTEXITCODE
    foreach ($line in $output) { Write-Log "  $line" "INFO" }
    if ($exitCode -ne 0) {
        Write-Log "PSFzf installation failed with exit code $exitCode" "ERROR"
        return $false
    }

    $profilePath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Microsoft.PowerShell_profile.ps1"
    New-ConfigLink "$script:RootDir/configs/powershell/Microsoft.PowerShell_profile.ps1" $profilePath
    Write-Log "PowerShell profile linked" "SUCCESS"
    return $true
}
