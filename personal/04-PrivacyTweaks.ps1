function Invoke-PrivacyTweaks {
    Write-Log "Applying privacy policies..." "INFO"
    $ok = Set-RegistryBatch @{
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" = @{
            "AllowTelemetry"                         = @{ Value = 0 }
            "DisableTelemetryOptInSettingsUx"        = @{ Value = 1 }
            "DisableTelemetryOptInChangeNotification" = @{ Value = 1 }
            "LimitDiagnosticLogCollection"           = @{ Value = 1 }
            "LimitDumpCollection"                    = @{ Value = 1 }
            "DoNotShowFeedbackNotifications"         = @{ Value = 1 }
            "AllowDeviceNameInTelemetry"              = @{ Value = 0 }
            "AllowExperimentation"                    = @{ Value = 0 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" = @{
            "DisabledByGroupPolicy" = @{ Value = 1 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" = @{
            "AITEnable"        = @{ Value = 0 }
            "DisableInventory" = @{ Value = 1 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" = @{
            "CEIPEnable" = @{ Value = 0 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" = @{
            "Disabled" = @{ Value = 1 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" = @{
            "DODownloadMode" = @{ Value = 0 }
        }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" = @{
            "Enabled" = @{ Value = 0 }
        }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" = @{
            "TailoredExperiencesWithDiagnosticDataEnabled" = @{ Value = 0 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" = @{
            "DisableConsumerAccountStateContent" = @{ Value = 1 }
            "DisableCloudOptimizedContent"        = @{ Value = 1 }
            "DisableWindowsConsumerFeatures"      = @{ Value = 1 }
            "DisableSoftLanding"                  = @{ Value = 1 }
        }
        "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" = @{
            "DisableTailoredExperiencesWithDiagnosticData" = @{ Value = 1 }
        }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" = @{
            "ContentDeliveryAllowed"       = @{ Value = 0 }
            "OemPreInstalledAppsEnabled"   = @{ Value = 0 }
            "PreInstalledAppsEnabled"      = @{ Value = 0 }
            "SilentInstalledAppsEnabled"   = @{ Value = 0 }
            "SoftLandingEnabled"           = @{ Value = 0 }
            "SubscribedContent-338388Enabled" = @{ Value = 0 }
            "SubscribedContent-353694Enabled" = @{ Value = 0 }
            "SubscribedContent-353696Enabled" = @{ Value = 0 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" = @{
            "EnableActivityFeed"        = @{ Value = 0 }
            "PublishUserActivities"     = @{ Value = 0 }
            "UploadUserActivities"      = @{ Value = 0 }
            "AllowCrossDeviceClipboard" = @{ Value = 0 }
        }
        "HKCU:\SOFTWARE\Microsoft\Clipboard" = @{
            "EnableClipboardHistory" = @{ Value = 1 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization" = @{
            "AllowInputPersonalization" = @{ Value = 0 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" = @{
            "DisableWindowsLocationProvider" = @{ Value = 1 }
        }
        "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" = @{
            "NumberOfSIUFInPeriod" = @{ Value = 0 }
        }
        "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" = @{
            "HasAccepted" = @{ Value = 0 }
        }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" = @{
            "AllowRecallEnablement" = @{ Value = 0 }
            "DisableAIDataAnalysis"  = @{ Value = 1 }
        }
    }

    if (Get-Command Clear-WindowsDiagnosticData -ErrorAction SilentlyContinue) {
        try { Clear-WindowsDiagnosticData | Out-Null } catch { Write-Log "Could not clear existing diagnostic data: $($_.Exception.Message)" "WARN" }
    }

    try {
        $recall = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue
        if ($recall -and $recall.State -ne "DisabledWithPayloadRemoved") {
            $result = Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart
            if ($result.RestartNeeded) { Set-StateValue "rebootRequired" $true }
        }
    } catch {
        Write-Log "Recall removal failed: $($_.Exception.Message)" "WARN"
        $ok = $false
    }
    return $ok
}
