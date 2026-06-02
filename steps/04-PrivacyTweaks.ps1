function Step-PrivacyTweaks {
    if (Test-StateCompleted "04-PrivacyTweaks") { return }
    Write-Log "Applying privacy tweaks..." "INFO"

    Set-RegistryBatch @{
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" = @{
            "AllowTelemetry" = @{ Value = 1 }
        }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" = @{
            "Enabled" = @{ Value = 0 }
        }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" = @{
            "TailoredExperiencesWithDiagnosticDataEnabled" = @{ Value = 0 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" = @{
            "EnableActivityFeed" = @{ Value = 0 }
            "PublishUserActivities" = @{ Value = 0 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" = @{
            "DisableWindowsLocationProvider" = @{ Value = 1 }
        }
        "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" = @{
            "NumberOfSIUFInPeriod" = @{ Value = 0 }
        }
    }

    Set-StateCompleted "04-PrivacyTweaks"
    Write-Log "Privacy settings applied" "SUCCESS"
}
Step-PrivacyTweaks
