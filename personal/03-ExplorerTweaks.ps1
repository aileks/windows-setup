function Step-ExplorerTweaks {
    if (Test-StateCompleted "Personal.ExplorerTweaks") { return }
    Write-Log "Applying Explorer power-user tweaks..." "INFO"

    Set-RegistryBatch @{
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" = @{
            "HideFileExt"                   = @{ Value = 0 }
            "Hidden"                        = @{ Value = 1 }
            "ShowSyncProviderNotifications" = @{ Value = 0 }
            "ShowRecentFiles"               = @{ Value = 0 }
            "ShowFrequentFiles"             = @{ Value = 0 }
            "TaskbarAl"                     = @{ Value = 1 }
            "DisabledHotkeys"               = @{ Value = "hjklqmotpxynf1234567"; Type = "String" }
        }
        "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" = @{
            "DisableSearchBoxSuggestions" = @{ Value = 1 }
        }
    }

    Set-RegistrySafe -Path  "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(Default)" -Value "" -Type String

    $stuckRectsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    try {
        if (-not (Test-Path $stuckRectsPath)) {
            New-Item -Path $stuckRectsPath -Force | Out-Null
        }

        $settings = (Get-ItemProperty -Path $stuckRectsPath -Name Settings -ErrorAction Stop).Settings
        if ($settings -and $settings.Length -gt 8) {
            $settings[8] = 3
            Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value ([byte[]]$settings)
            Write-Log "  Enabled taskbar auto-hide" "INFO"
        } else {
            Write-Log "  Could not enable taskbar auto-hide; StuckRects3 Settings was missing or malformed." "WARN"
        }
    } catch {
        Write-Log "  Failed to enable taskbar auto-hide: $($_.Exception.Message)" "WARN"
    }

    Set-StateCompleted "Personal.ExplorerTweaks"
    Write-Log "Explorer configured" "SUCCESS"
}
Step-ExplorerTweaks
