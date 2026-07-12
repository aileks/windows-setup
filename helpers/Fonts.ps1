function Get-FontCatalog {
    $catalogPath = Join-Path $script:RootDir "data/fonts.json"
    if (-not (Test-Path $catalogPath)) {
        throw "Font catalog not found at $catalogPath"
    }

    Get-Content $catalogPath -Raw | ConvertFrom-Json
}

function Get-SelectedNerdFontMonoFace {
    $face = Get-StateValue "selectedNerdFontMonoFace"
    if ([string]::IsNullOrWhiteSpace($face)) { return "" }
    $face
}

function Publish-FontChange {
    if (-not ("WinSetupFontChange" -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class WinSetupFontChange {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr window, uint message, UIntPtr wParam, IntPtr lParam,
        uint flags, uint timeout, out UIntPtr result);
}
'@
    }

    $result = [UIntPtr]::Zero
    [void][WinSetupFontChange]::SendMessageTimeout(
        [IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 5000, [ref]$result)
}

function Invoke-NerdFontSetup {
    $catalog = Get-FontCatalog
    $font = @($catalog.fonts) | Where-Object { $_.name -eq "Adwaita Mono" } | Select-Object -First 1
    if ($null -eq $font) { throw "Adwaita Mono is missing from data/fonts.json" }

    $tempDir = Join-Path $env:TEMP "win-setup-font-$([guid]::NewGuid())"
    $archivePath = Join-Path $tempDir "AdwaitaMono.zip"
    try {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        Write-Log "Downloading Adwaita Mono Nerd Font $($font.version)..." "INFO"
        Invoke-WebRequest -Uri $font.archiveUrl -OutFile $archivePath -UseBasicParsing
        $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $font.sha256.ToLowerInvariant()) {
            throw "Adwaita Mono archive checksum mismatch"
        }

        Expand-Archive -LiteralPath $archivePath -DestinationPath $tempDir -Force
        $fontFiles = @(Get-ChildItem -Path $tempDir -Filter "*.ttf" -File -Recurse)
        if ($fontFiles.Count -eq 0) { throw "Adwaita Mono archive contained no TrueType fonts" }

        $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
        $registryPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        New-Item -Path $fontDir -ItemType Directory -Force | Out-Null
        foreach ($file in $fontFiles) {
            $destination = Join-Path $fontDir $file.Name
            if ((Test-Path -LiteralPath $destination) -and
                (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne
                (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash) {
                Copy-Item -LiteralPath $destination -Destination "$destination.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            }
            Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
            if (-not (Set-RegistrySafe -Path $registryPath -Name "$($file.BaseName) (TrueType)" `
                -Value $destination -Type String -PassThru)) {
                throw "Could not register $($file.Name)"
            }
        }

        Set-StateValue -Key "selectedNerdFontMonoFace" -Value $font.monoFace
        Set-StateValue -Key "selectedNerdFontPropoFace" -Value $font.propoFace
        Publish-FontChange
        Write-Log "Installed Adwaita Mono Nerd Font" "SUCCESS"
        return $true
    } catch {
        Write-Log "Adwaita Mono installation failed: $($_.Exception.Message)" "ERROR"
        return $false
    } finally {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force
        }
    }
}
