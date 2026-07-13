function Invoke-ConfigDeploy {
    Write-Log "Deploying config files..." "INFO"
    $ok = $true

    New-ConfigLink "$script:RootDir/configs/starship/starship.toml" "$env:USERPROFILE\.config\starship.toml"
    New-ConfigLink "$script:RootDir/configs/bat/config" "$env:APPDATA\bat\config"
    New-ConfigLink "$script:RootDir/configs/bat/ashen.tmTheme" "$env:APPDATA\bat\themes\ashen.tmTheme"

    if (Test-SoftwareInstalled -Commands @("bat")) {
        $nativeResult = Invoke-NativeCommand -FilePath "bat" -ArgumentList @("cache", "--build")
        if ($nativeResult.ExitCode -eq 0) {
            Write-Log "  Rebuilt bat cache" "INFO"
        } else {
            Write-Log "  bat cache rebuild failed with exit code $($nativeResult.ExitCode)" "WARN"
            $ok = $false
        }
    }

    $termPkgDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe"
    if (Test-SoftwareInstalled -Commands @("wt.exe") -Detector { Test-Path $termPkgDir }) {
        $termDir = "$termPkgDir\LocalState"
        $termSettingsPath = "$termDir\settings.json"

        if (Test-Path $termSettingsPath) {
            $settingsBackup = "$termSettingsPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item -LiteralPath $termSettingsPath -Destination $settingsBackup
            $settings = Get-Content $termSettingsPath -Raw | ConvertFrom-Json

            $ashenScheme = Get-Content "$script:RootDir/configs/windows-terminal/settings.json" -Raw | ConvertFrom-Json
            $ashenColors = $ashenScheme.schemes[0]

            if (-not $settings.schemes) { $settings | Add-Member -NotePropertyName "schemes" -NotePropertyValue @() -Force }
            $existing = $settings.schemes | Where-Object { $_.name -eq "Ashen" }
            if (-not $existing) {
                $settings.schemes += $ashenColors
            }

            if (-not $settings.profiles) {
                $settings | Add-Member -NotePropertyName "profiles" -NotePropertyValue ([PSCustomObject]@{}) -Force
            }
            if (-not $settings.profiles.defaults) {
                $settings.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue @{} -Force
            }
            $defaults = $settings.profiles.defaults
            $defaults | Add-Member -NotePropertyName "colorScheme" -NotePropertyValue "Ashen" -Force
            $defaults | Add-Member -NotePropertyName "useAcrylic" -NotePropertyValue $true -Force
            $defaults | Add-Member -NotePropertyName "opacity" -NotePropertyValue 85 -Force
            $monoFontFace = Get-SelectedNerdFontMonoFace
            if (-not $monoFontFace) { $monoFontFace = "AdwaitaMono Nerd Font Mono" }
            $defaults | Add-Member -NotePropertyName "font" -NotePropertyValue @{ face = $monoFontFace; size = 13 } -Force
            $defaults | Add-Member -NotePropertyName "padding" -NotePropertyValue "12" -Force
            $defaults | Add-Member -NotePropertyName "cursorShape" -NotePropertyValue "bar" -Force

            $settings | ConvertTo-Json -Depth 20 | Set-Content $termSettingsPath -Encoding UTF8
            Write-Log "  Merged Ashen theme into Windows Terminal" "INFO"
        } elseif (Test-Path $termPkgDir) {
            if (-not (Test-Path $termDir)) { New-Item -Path $termDir -ItemType Directory -Force | Out-Null }
            $settings = Get-Content "$script:RootDir/configs/windows-terminal/settings.json" -Raw | ConvertFrom-Json
            $monoFontFace = Get-SelectedNerdFontMonoFace
            if ($monoFontFace) {
                $settings.profiles.defaults.font.face = $monoFontFace
            }
            $settings | ConvertTo-Json -Depth 20 | Set-Content $termSettingsPath -Encoding UTF8
            Write-Log "  Deployed fresh Windows Terminal settings" "INFO"
        } else {
            Write-Log "  Windows Terminal was detected, but its settings directory was not found" "WARN"
        }
    } else {
        Write-Log "  Windows Terminal not detected; skipping Terminal settings merge" "INFO"
    }

    Write-Log "Config files deployed" "SUCCESS"
    return $ok
}
