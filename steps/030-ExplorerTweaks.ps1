function Step-ExplorerTweaks {
    if (Test-StateCompleted "030-ExplorerTweaks") { return }
    Write-Log "Applying Explorer power-user tweaks..." "INFO"

    Set-RegistryBatch @{
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" = @{
            "HideFileExt"                    = @{ Value = 0 }
            "ShowHiddenFiles"                = @{ Value = 1 }
            "ShowSyncProviderNotifications"  = @{ Value = 0 }
            "ShowRecentFiles"                = @{ Value = 0 }
            "ShowFrequentFiles"              = @{ Value = 0 }
        }
        "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" = @{
            "DisableSearchBoxSuggestions" = @{ Value = 1 }
        }
    }

    $classicMenuPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    Set-RegistrySafe -Path $classicMenuPath -Name "(Default)" -Value "" -Type String

    $sidebarCl = @(
        @{ CLSID = "31C0DD25-9439-4F12-BF41-7FF4EDA38722"; Name = "3D Objects" }
        @{ CLSID = "A0C69A99-21C8-4671-8703-7934162FCF1D"; Name = "Music" }
        @{ CLSID = "35286A68-3C57-41A1-BBB1-0EAE73F88E1B"; Name = "Videos" }
    )
    foreach ($item in $sidebarCl) {
        $bagPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{$($item.CLSID)}\PropertyBag"
        Set-RegistrySafe -Path $bagPath -Name "ThisPCPolicy" -Value "Hide" -Type String
    }

    $ns3d = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}"
    Remove-RegistryKey $ns3d

    Set-StateCompleted "030-ExplorerTweaks"
    Write-Log "Explorer configured" "SUCCESS"
}
Step-ExplorerTweaks
