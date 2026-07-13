function Invoke-ExplorerTweaks {
    Write-Log "Applying Explorer and taskbar settings..." "INFO"
    $ok = Set-RegistryBatch @{
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" = @{
            "HideFileExt"                   = @{ Value = 0 }
            "Hidden"                        = @{ Value = 1 }
            "ShowSyncProviderNotifications" = @{ Value = 0 }
            "ShowRecentFiles"               = @{ Value = 0 }
            "ShowFrequentFiles"              = @{ Value = 0 }
            "TaskbarAl"                     = @{ Value = 1 }
            "TaskbarMn"                     = @{ Value = 0 }
            "ShowTaskViewButton"            = @{ Value = 0 }
            "ShowCopilotButton"             = @{ Value = 0 }
            "DisabledHotkeys"               = @{ Value = "hjklqmotpxynf1234567"; Type = "String" }
        }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" = @{
            "SearchboxTaskbarMode" = @{ Value = 0 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" = @{
            "AllowNewsAndInterests" = @{ Value = 0 }
        }
        "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" = @{
            "DisableSearchBoxSuggestions" = @{ Value = 1 }
        }
        "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" = @{
            "TurnOffWindowsCopilot" = @{ Value = 1 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" = @{
            "AllowCortana"             = @{ Value = 0 }
            "AllowCloudSearch"         = @{ Value = 0 }
            "AllowSearchToUseLocation" = @{ Value = 1 }
            "ConnectedSearchUseWeb"    = @{ Value = 0 }
            "DisableWebSearch"         = @{ Value = 1 }
        }
    }

    # TaskbarDa is protected or unsupported on some Windows 11 builds. The
    # AllowNewsAndInterests policy above is the supported enforcement point.
    Write-Log "  Widgets are disabled through HKLM policy; skipping legacy TaskbarDa" "INFO"

    if (-not (Set-RegistrySafe -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(Default)" -Value "" -Type String -PassThru)) {
        $ok = $false
    }

    $stuckRectsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    try {
        if (-not (Test-RegistryPathBackedUp $stuckRectsPath)) {
            throw "Taskbar registry path was not included in the native backup"
        }
        $settings = (Get-ItemProperty -Path $stuckRectsPath -Name Settings -ErrorAction Stop).Settings
        if ($settings -and $settings.Length -gt 8) {
            $settings[8] = 3
            Set-ItemProperty -Path $stuckRectsPath -Name Settings -Value ([byte[]]$settings)
        } else {
            Write-Log "Taskbar auto-hide settings were missing or malformed" "WARN"
            $ok = $false
        }
    } catch {
        Write-Log "Taskbar auto-hide failed: $($_.Exception.Message)" "WARN"
        $ok = $false
    }
    return $ok
}
