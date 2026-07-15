function Test-SupportedEnvironment {
    if (-not [Environment]::Is64BitOperatingSystem) {
        Write-Host "x64 Windows required" -ForegroundColor Red
        return $false
    }
    $installationType = Get-ItemPropertyValue `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" `
        -Name "InstallationType" -ErrorAction SilentlyContinue
    $buildText = Get-ItemPropertyValue `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" `
        -Name "CurrentBuildNumber" -ErrorAction SilentlyContinue
    $build = 0
    if (-not [int]::TryParse([string]$buildText, [ref]$build) -or
        $installationType -ne "Client" -or $build -lt 26100) {
        Write-Host "Windows 11 24H2+ required" -ForegroundColor Red
        return $false
    }
    return $true
}
