function Step-DevSettings {
    if (Test-StateCompleted "Personal.DevSettings") { return }
    Write-Log "Enabling developer settings: symlinks, long paths, sudo..." "INFO"

    Set-RegistryBatch @{
        "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" = @{
            "LongPathsEnabled" = @{ Value = 1 }
        }
    }

    fsutil behavior set SymlinkEvaluation L2L:1 R2R:1 L2R:1 R2L:1 | Out-Null

    if (Get-Command sudo -ErrorAction SilentlyContinue) {
        sudo config --enable normal 2>&1 | Write-Host
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Sudo enabled in normal mode" "SUCCESS"
        } else {
            Write-Log "  sudo config returned exit code $LASTEXITCODE; enable sudo manually in Windows Settings." "WARN"
        }
    } else {
        Write-Log "  sudo command not found; Sudo for Windows requires Windows 11 24H2+." "WARN"
    }

    Set-StateCompleted "Personal.DevSettings"
    Write-Log "Developer settings processed" "SUCCESS"
}
Step-DevSettings
