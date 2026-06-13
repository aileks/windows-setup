function Step-ConfigDeploy {
    Write-Log "Deploying config files..." "INFO"

    $pwshProfileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'
    New-ConfigLink "$script:RootDir/configs/powershell/Microsoft.PowerShell_profile.ps1" "$pwshProfileDir\Microsoft.PowerShell_profile.ps1"
    Write-Log "  Linked PowerShell 7 profile" "INFO"

    $starshipDir = "$env:USERPROFILE\.config"
    New-ConfigLink "$script:RootDir/configs/starship/starship.toml" "$starshipDir\starship.toml"
    Write-Log "  Linked starship.toml" "INFO"

    $batDir = "$env:APPDATA\bat"
    New-ConfigLink "$script:RootDir/configs/bat/config" "$batDir\config"
    New-ConfigLink "$script:RootDir/configs/bat/ashen.tmTheme" "$batDir\themes\ashen.tmTheme"
    if (Get-Command bat -ErrorAction SilentlyContinue) {
        bat cache --build 2>&1 | Write-Host
        Write-Log "  Linked bat config; cache rebuilt" "INFO"
    } else {
        Write-Log "  Linked bat config; bat not on PATH, run 'bat cache --build' after install" "WARN"
    }

    $termPkgDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe"
    $termDir = "$termPkgDir\LocalState"
    $termSettingsPath = "$termDir\settings.json"

    if (Test-Path $termSettingsPath) {
        $settings = Get-Content $termSettingsPath -Raw | ConvertFrom-Json

        $ashenScheme = Get-Content "$script:RootDir/configs/windows-terminal/settings.json" -Raw | ConvertFrom-Json
        $ashenColors = $ashenScheme.schemes[0]

        if (-not $settings.schemes) { $settings | Add-Member -NotePropertyName "schemes" -NotePropertyValue @() -Force }
        $existing = $settings.schemes | Where-Object { $_.name -eq "Ashen" }
        if (-not $existing) {
            $settings.schemes += $ashenColors
        }

        if (-not $settings.profiles.defaults) {
            $settings.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue @{} -Force
        }
        $defaults = $settings.profiles.defaults
        $defaults | Add-Member -NotePropertyName "colorScheme" -NotePropertyValue "Ashen" -Force
        $defaults | Add-Member -NotePropertyName "useAcrylic" -NotePropertyValue $true -Force
        $defaults | Add-Member -NotePropertyName "opacity" -NotePropertyValue 85 -Force
        $defaults | Add-Member -NotePropertyName "font" -NotePropertyValue @{ face = "CommitMono Nerd Font Mono"; size = 13 } -Force
        $defaults | Add-Member -NotePropertyName "padding" -NotePropertyValue "12" -Force
        $defaults | Add-Member -NotePropertyName "cursorShape" -NotePropertyValue "bar" -Force

        $settings | ConvertTo-Json -Depth 20 | Set-Content $termSettingsPath -Encoding UTF8
        Write-Log "  Merged Ashen theme into Windows Terminal" "INFO"
    } elseif (Test-Path $termPkgDir) {
        if (-not (Test-Path $termDir)) { New-Item -Path $termDir -ItemType Directory -Force | Out-Null }
        Copy-Item "$script:RootDir/configs/windows-terminal/settings.json" $termSettingsPath -Force
        Write-Log "  Deployed fresh Windows Terminal settings" "INFO"
    } else {
        Write-Log "  Windows Terminal not installed, skipping Terminal config" "WARN"
    }

    Write-Log "Config files deployed" "SUCCESS"
}
Step-ConfigDeploy
