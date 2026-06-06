function Step-DevSettings {
    if (Test-StateCompleted "02-DevSettings") { return }
    Write-Log "Enabling developer settings: symlinks, long paths..." "INFO"

    Set-RegistryBatch @{
        "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" = @{
            "LongPathsEnabled" = @{ Value = 1 }
        }
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" = @{
            "AllowDevelopmentWithoutDevLicense" = @{ Value = 1 }
        }
    }

    fsutil behavior set SymlinkEvaluation L2L:1 R2R:1 L2R:1 R2L:1 | Out-Null

    Set-StateCompleted "02-DevSettings"
    Write-Log "Symlinks and long paths enabled" "SUCCESS"
}
Step-DevSettings
