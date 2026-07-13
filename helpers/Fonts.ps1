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

function Ensure-Scoop {
    Refresh-EnvironmentPath
    if (Get-Command "scoop" -ErrorAction SilentlyContinue) { return $true }

    Write-Log "Scoop is unavailable; installing it for the current user..." "INFO"
    $tempDir = Join-Path $env:TEMP "win-setup-scoop-$([guid]::NewGuid())"
    $installerPath = Join-Path $tempDir "install.ps1"
    try {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri "https://get.scoop.sh" -OutFile $installerPath -UseBasicParsing
        $result = Invoke-NativeCommand -FilePath "powershell.exe" -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $installerPath, "-RunAsAdmin"
        )
        if ($result.ExitCode -ne 0) {
            Write-Log "Scoop installation failed with exit code $($result.ExitCode)" "ERROR"
            return $false
        }
        Refresh-EnvironmentPath
    } catch {
        Write-Log "Scoop installation failed: $($_.Exception.Message)" "ERROR"
        return $false
    } finally {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force
        }
    }

    if (-not (Get-Command "scoop" -ErrorAction SilentlyContinue)) {
        Write-Log "Scoop was installed but is not available on PATH" "ERROR"
        return $false
    }
    return $true
}

function Ensure-ScoopBucket {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Source
    )

    $scoopRoot = if ([string]::IsNullOrWhiteSpace($env:SCOOP)) {
        Join-Path $HOME "scoop"
    } else {
        $env:SCOOP
    }
    $bucketPath = Join-Path $scoopRoot "buckets\$Name"
    if (Test-Path -LiteralPath $bucketPath -PathType Container) {
        Write-Log "Scoop bucket '$Name' is already available" "INFO"
        return $true
    }

    $listResult = Invoke-NativeCommand -FilePath "scoop" -ArgumentList @("bucket", "list")
    $escapedName = [regex]::Escape($Name)
    if ($listResult.ExitCode -eq 0 -and
        (@($listResult.Output) | Where-Object {
            $_ -match "^\s*$escapedName(?:\s|$)" -or
            $_ -match "(?:^|[{;]\s*)Name\s*=\s*$escapedName(?:[;}\s]|$)"
        })) {
        Write-Log "Scoop bucket '$Name' is already available" "INFO"
        return $true
    }

    Write-Log "Adding Scoop bucket '$Name'..." "INFO"
    $addResult = Invoke-NativeCommand -FilePath "scoop" -ArgumentList @(
        "bucket", "add", $Name, $Source
    )
    if ($addResult.ExitCode -ne 0) {
        if (Test-Path -LiteralPath $bucketPath -PathType Container) {
            Write-Log "Scoop bucket '$Name' became available while it was being added" "INFO"
            return $true
        }
        Write-Log "Could not add Scoop bucket '$Name' (exit $($addResult.ExitCode))" "ERROR"
        return $false
    }
    return $true
}

function Install-ScoopNerdFont {
    param([Parameter(Mandatory)]$Font)

    $fontFile = Join-Path "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" $Font.installedFile
    $registryName = "$([IO.Path]::GetFileNameWithoutExtension($Font.installedFile)) (TrueType)"
    $registeredPath = Get-ItemPropertyValue `
        -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
        -Name $registryName -ErrorAction SilentlyContinue
    if ((Test-Path -LiteralPath $fontFile) -and -not [string]::IsNullOrWhiteSpace($registeredPath)) {
        Write-Log "$($Font.name) is already installed; skipping Scoop migration to avoid overwriting an in-use font" "INFO"
        return $true
    }

    Write-Log "Installing $($Font.name) ($($Font.package)) via Scoop..." "INFO"
    $result = Invoke-NativeCommand -FilePath "scoop" -ArgumentList @("install", $Font.package)
    if ($result.ExitCode -ne 0) {
        Write-Log "Scoop failed to install $($Font.package) (exit $($result.ExitCode))" "ERROR"
        return $false
    }
    Write-Log "Installed $($Font.name)" "SUCCESS"
    return $true
}

function Invoke-NerdFontSetup {
    $catalog = Get-FontCatalog
    $fonts = @($catalog.fonts)
    if ($fonts.Count -eq 0) {
        Write-Log "No fonts are defined in data/fonts.json" "ERROR"
        return $false
    }

    $terminalFonts = @($fonts | Where-Object { $_.role -eq "terminal" })
    if ($terminalFonts.Count -ne 1) {
        Write-Log "Font catalog must contain exactly one font with role 'terminal'" "ERROR"
        return $false
    }

    if (-not (Ensure-Scoop)) { return $false }
    if (-not (Ensure-ScoopBucket -Name $catalog.bucket.name -Source $catalog.bucket.source)) {
        return $false
    }

    $allSucceeded = $true
    $fontsChanged = $false

    foreach ($font in $fonts) {
        if (Install-ScoopNerdFont -Font $font) {
            $fontsChanged = $true
            if ($font.role -eq "terminal") {
                Set-StateValue -Key "selectedNerdFontMonoFace" -Value $font.monoFace
                Set-StateValue -Key "selectedNerdFontPropoFace" -Value ""
            }
        } else {
            $allSucceeded = $false
        }
    }

    if ($fontsChanged) { Publish-FontChange }
    return $allSucceeded
}
