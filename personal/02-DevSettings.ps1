function Invoke-DeveloperTweaks {
    Write-Log "Applying developer settings..." "INFO"
    $registryOk = Set-RegistryBatch @{
        "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" = @{
            "LongPathsEnabled" = @{ Value = 1 }
        }
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" = @{
            "AllowDevelopmentWithoutDevLicense" = @{ Value = 1 }
        }
    }

    $fsutilOutput = @(& fsutil behavior set SymlinkEvaluation L2L:1 R2R:1 L2R:1 R2L:1 2>&1)
    $fsutilOk = $LASTEXITCODE -eq 0
    foreach ($line in $fsutilOutput) { Write-Log "  $line" "INFO" }
    if (-not $fsutilOk) { Write-Log "Symlink evaluation setup failed" "ERROR" }

    $sudoOk = $true
    if (Get-Command sudo -ErrorAction SilentlyContinue) {
        $sudoOutput = @(& sudo config --enable normal 2>&1)
        $sudoOk = $LASTEXITCODE -eq 0
        foreach ($line in $sudoOutput) { Write-Log "  $line" "INFO" }
        if (-not $sudoOk) { Write-Log "Sudo for Windows setup failed" "ERROR" }
    } else {
        Write-Log "Sudo for Windows is unavailable on this build" "ERROR"
        $sudoOk = $false
    }

    return $registryOk -and $fsutilOk -and $sudoOk
}
