function Step-DevSettings {
    if (Test-StateCompleted "02-DevSettings") { return }
    Write-Log "Enabling developer settings: symlinks, long paths, sudo..." "INFO"

    Set-RegistryBatch @{
        "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" = @{
            "LongPathsEnabled" = @{ Value = 1 }
        }
        # Sudo Enabled: 3 = inline, like Linux sudo
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" = @{
            "Enabled" = @{ Value = 3 }
        }
    }

    fsutil behavior set SymlinkEvaluation L2L:1 R2R:1 L2R:1 R2L:1 | Out-Null

    Set-StateCompleted "02-DevSettings"
    Write-Log "Symlinks, long paths, and sudo enabled" "SUCCESS"
}
Step-DevSettings
