function Set-ObjectProperty {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value
    )
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}

function Invoke-WindowsTerminalSetup {
    Write-Log "Configuring Windows Terminal" "INFO"
    $termPkgDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe"
    if (-not (Test-SoftwareInstalled -Commands @("wt.exe") -Detector { Test-Path $termPkgDir })) {
        Write-Log "Windows Terminal not detected" "ERROR"
        return $false
    }

    $termDir = "$termPkgDir\LocalState"
    $termSettingsPath = "$termDir\settings.json"
    if (-not (Test-Path $termDir)) { New-Item -Path $termDir -ItemType Directory -Force | Out-Null }
    if (Test-Path $termSettingsPath) {
        Copy-Item -LiteralPath $termSettingsPath `
            -Destination "$termSettingsPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        $settings = Get-Content $termSettingsPath -Raw | ConvertFrom-Json
    } else {
        $settings = Get-Content "$script:RootDir/configs/windows/terminal/settings.json" -Raw | ConvertFrom-Json
    }
    $managed = Get-Content "$script:RootDir/configs/windows/terminal/settings.json" -Raw | ConvertFrom-Json

    Set-ObjectProperty $settings "alwaysShowTabs" $false
    Set-ObjectProperty $settings "showTabsInTitlebar" $false
    Set-ObjectProperty $settings "showTabsFullscreen" $false

    $schemes = @($settings.schemes | Where-Object { $_.name -notin @("Ashen", "Cinder Grove") })
    Set-ObjectProperty $settings "schemes" @($schemes + $managed.schemes[0])

    if (-not $settings.profiles) { Set-ObjectProperty $settings "profiles" ([PSCustomObject]@{}) }
    if (-not $settings.profiles.defaults) { Set-ObjectProperty $settings.profiles "defaults" ([PSCustomObject]@{}) }
    $defaults = $settings.profiles.defaults
    foreach ($property in $managed.profiles.defaults.PSObject.Properties) {
        Set-ObjectProperty $defaults $property.Name $property.Value
    }
    $monoFontFace = Get-SelectedNerdFontMonoFace
    if (-not $monoFontFace) { $monoFontFace = "AdwaitaMono Nerd Font Mono" }
    Set-ObjectProperty $defaults "font" ([PSCustomObject]@{ face = $monoFontFace; size = 13 })

    $profileGuid = "{a1d66d88-5f1f-4b6d-a7df-9c768f5bf278}"
    $distro = Get-StateValue "selectedWslDistro"
    if ([string]::IsNullOrWhiteSpace($distro)) { $distro = "Ubuntu-26.04" }
    $profiles = @()
    if ($settings.profiles.PSObject.Properties.Name -contains "list") {
        $profiles = @($settings.profiles.list | Where-Object { $_.guid -ne $profileGuid })
    }
    $profiles += [PSCustomObject]@{
        guid              = $profileGuid
        name              = "Ubuntu"
        commandline       = "wsl.exe --distribution $distro --cd ~"
        icon              = "ms-appx:///ProfileIcons/{9acb9455-ca41-5af7-950f-6bca1bc9722f}.png"
    }
    Set-ObjectProperty $settings.profiles "list" $profiles
    Set-ObjectProperty $settings "defaultProfile" $profileGuid
    $disabledSources = @($settings.disabledProfileSources | Where-Object { $_ -ne "Windows.Terminal.Wsl" })
    Set-ObjectProperty $settings "disabledProfileSources" @($disabledSources + "Windows.Terminal.Wsl")

    $json = $settings | ConvertTo-Json -Depth 30
    [IO.File]::WriteAllText($termSettingsPath, $json, [Text.UTF8Encoding]::new($false))
    Write-Log "Windows Terminal configured" "SUCCESS"
    return $true
}
