$script:WslDistro = "Ubuntu-26.04"
$script:NpipeRelayVersion = "1.11.4"
$script:NpipeRelaySha256 = "cea82cf5c9c22a28bef8075750acb7958f766393baebff4597cf21442f71c4b3"

function Test-WslPlatformEnabled {
    try {
        $result = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @("--list", "--quiet")
        return $result.ExitCode -eq 0
    } catch {
        Write-Log "WSL failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Enable-WslPlatformAndReboot {
    Register-ResumeAfterReboot -ScriptPath $script:SetupScript
    Write-Log "Installing WSL" "INFO"
    $result = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @("--install", "--no-distribution")
    if ($result.ExitCode -ne 0) {
        Clear-ResumeAfterReboot
        Write-Log "WSL enablement failed: exit $($result.ExitCode)" "ERROR"
        return $false
    }

    Set-StateValue "rebootRequired" $true
    Write-Log "WSL enabled" "SUCCESS"
    Restore-SystemRestoreFrequency
    Restart-Computer
    return $true
}

function Get-WslDistroNames {
    $result = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @("--list", "--quiet")
    if ($result.ExitCode -ne 0) { return @() }
    @($result.Output | ForEach-Object { ([string]$_).Replace([string][char]0, "").Trim() } | Where-Object { $_ })
}

function Test-WslDistroInstalled {
    @(Get-WslDistroNames) -contains $script:WslDistro
}

function Resolve-WslDistro {
    if (Test-WslDistroInstalled) {
        Set-StateValue "selectedWslDistro" $script:WslDistro
        return
    }
    if (@(Get-WslDistroNames) -notcontains "Ubuntu") { return }
    try {
        $registration = @(Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss" -ErrorAction Stop |
            ForEach-Object { Get-ItemProperty -LiteralPath $_.PSPath }) |
            Where-Object { $_.DistributionName -eq "Ubuntu" -and [uint32]$_.DefaultUid -ne 0 } |
            Select-Object -First 1
        if ($null -eq $registration) { return }
        $version = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @(
            "--distribution", "Ubuntu", "--user", "root", "--exec", "sh", "-c",
            '. /etc/os-release; printf %s "$VERSION_ID"'
        ) -NoConsole
        $versionText = (@($version.Output) -join "").Trim()
        if ($version.ExitCode -eq 0 -and $versionText -eq "26.04") {
            $script:WslDistro = "Ubuntu"
            Set-StateValue "selectedWslDistro" $script:WslDistro
            Write-Log "Ubuntu 26.04 found" "INFO"
        }
    } catch {
        Write-Log "Ubuntu validation failed: $($_.Exception.Message)" "WARN"
    }
}

function Install-WslDistro {
    Resolve-WslDistro
    if (Test-WslDistroInstalled) { return $true }

    Write-Log "Installing Ubuntu 26.04" "INFO"
    $result = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @(
        "--install", "--distribution", $script:WslDistro, "--no-launch"
    )
    if ($result.ExitCode -ne 0) {
        Write-Log "Ubuntu Store install failed: exit $($result.ExitCode)" "WARN"
        $result = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @(
            "--install", "--distribution", $script:WslDistro, "--no-launch", "--web-download"
        )
        if ($result.ExitCode -ne 0) {
            Write-Log "Ubuntu install failed: exit $($result.ExitCode)" "ERROR"
            return $false
        }
    }
    Set-StateValue "selectedWslDistro" $script:WslDistro
    return $true
}

function Get-WslDefaultUser {
    if (-not (Test-WslDistroInstalled)) { return "" }

    # Read the registered UID before invoking the distro. Calling `wsl --exec`
    # against an uninitialized distro can consume its first launch as root and
    # bypass the interactive Ubuntu user-creation flow we need to show.
    try {
        $registrations = @(Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss" -ErrorAction Stop)
        $registration = $registrations | ForEach-Object { Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction Stop } | `
            Where-Object { $_.DistributionName -eq $script:WslDistro } | `
            Select-Object -First 1
    } catch {
        Write-Log "Ubuntu registration failed: $($_.Exception.Message)" "WARN"
        return ""
    }
    if ($null -eq $registration -or $null -eq $registration.DefaultUid) { return "" }
    $defaultUid = [uint32]$registration.DefaultUid
    if ($defaultUid -eq 0) { return "" }

    $result = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @(
        "--distribution", $script:WslDistro, "--user", "root", "--exec", "id", "-un", $defaultUid
    )
    if ($result.ExitCode -ne 0) { return "" }
    $outputLines = @($result.Output | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
    $lastLine = $outputLines | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($lastLine)) { return "" }
    $name = ([string]$lastLine).Trim()
    if ($name -eq "root") { return "" }
    return $name
}

function Initialize-WslUser {
    $user = Get-WslDefaultUser
    if ($user) { return $user }

    Write-Host "Create Ubuntu user, then exit" -ForegroundColor Yellow
    $result = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @("--distribution", $script:WslDistro)
    if ($result.ExitCode -ne 0) {
        Write-Log "Ubuntu first run failed: exit $($result.ExitCode)" "ERROR"
        return ""
    }

    $user = Get-WslDefaultUser
    if ([string]::IsNullOrWhiteSpace($user)) {
        Write-Log "Ubuntu user incomplete" "ERROR"
        return ""
    }
    return $user
}

function ConvertTo-WslPath {
    param([Parameter(Mandatory)][string]$WindowsPath)

    $result = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @(
        "--distribution", $script:WslDistro, "--exec", "wslpath", "-u", $WindowsPath
    )
    if ($result.ExitCode -ne 0) { return "" }
    (($result.Output | Select-Object -First 1) -as [string]).Trim()
}

function Copy-WslConfigPayload {
    param([Parameter(Mandatory)][string]$LinuxUser)

    $uncHome = "\\wsl.localhost\$script:WslDistro\home\$LinuxUser"
    if (-not (Test-Path -LiteralPath $uncHome)) {
        Write-Log "Ubuntu home unavailable: $uncHome" "ERROR"
        return $null
    }

    $managedRoot = Join-Path $uncHome ".local\share\win-setup-configs"
    $stagingRoot = "$managedRoot.stage-$([guid]::NewGuid())"
    $payloadFiles = @(
        @{ Source = "configs\wsl\bootstrap.sh"; Relative = "wsl\bootstrap.sh" }
        @{ Source = "configs\wsl\zsh"; Relative = "zsh" }
        @{ Source = "configs\wsl\wsl.conf"; Relative = "wsl\wsl.conf" }
        @{ Source = "configs\wsl\bitwarden-ssh-agent.zsh"; Relative = "wsl\bitwarden-ssh-agent.zsh" }
        @{ Source = "configs\wsl\nvim"; Relative = "nvim" }
        @{ Source = "configs\common\starship\starship.toml"; Relative = "starship\starship.toml" }
        @{ Source = "configs\wsl\bat"; Relative = "bat" }
        @{ Source = "configs\common\bat\themes"; Relative = "bat\themes" }
        @{ Source = "configs\wsl\btop"; Relative = "btop" }
        @{ Source = "configs\common\btop\themes"; Relative = "btop\themes" }
    )

    try {
        foreach ($entry in $payloadFiles) {
            $source = Join-Path $script:RootDir $entry.Source
            if (-not (Test-Path -LiteralPath $source)) {
                throw "WSL config source is missing: $source"
            }
            $destination = Join-Path $stagingRoot $entry.Relative
            $parent = Split-Path $destination -Parent
            if (-not (Test-Path -LiteralPath $parent)) {
                New-Item -Path $parent -ItemType Directory -Force | Out-Null
            }
            if ((Get-Item -LiteralPath $source).PSIsContainer) {
                Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
            } else {
                Copy-Item -LiteralPath $source -Destination $destination -Force
            }
        }

        if (Test-Path -LiteralPath $managedRoot) {
            Remove-Item -LiteralPath $managedRoot -Recurse -Force
        }
        Move-Item -LiteralPath $stagingRoot -Destination $managedRoot
        $linuxRoot = "/home/$LinuxUser/.local/share/win-setup-configs"
        Write-Log "WSL configs copied" "SUCCESS"
        return [PSCustomObject]@{ UncPath = $managedRoot; LinuxPath = $linuxRoot }
    } catch {
        Write-Log "WSL config copy failed: $($_.Exception.Message)" "ERROR"
        return $null
    } finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-NpipeRelay {
    $installDir = Join-Path $env:LOCALAPPDATA "Programs\npiperelay"
    $executable = Join-Path $installDir "npiperelay.exe"
    if (Test-Path -LiteralPath $executable) {
        $installedHash = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($installedHash -eq $script:NpipeRelaySha256) {
            Write-Log "npiperelay exists" "INFO"
            return $true
        }
        $backupPath = "$executable.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $executable -Destination $backupPath
        Write-Log "npiperelay backed up" "INFO"
    }

    $tempDir = Join-Path $env:TEMP "win-setup-npiperelay-$([guid]::NewGuid())"
    $downloadPath = Join-Path $tempDir "npiperelay.exe"
    $url = "https://github.com/albertony/npiperelay/releases/download/v$script:NpipeRelayVersion/npiperelay_windows_amd64.exe"
    try {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        Write-Log "Downloading npiperelay" "INFO"
        Invoke-WebRequest -Uri $url -OutFile $downloadPath -UseBasicParsing
        $actualHash = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $script:NpipeRelaySha256) { throw "npiperelay checksum mismatch" }

        New-Item -Path $installDir -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $downloadPath -Destination $executable -Force
        Write-Log "npiperelay installed" "SUCCESS"
        return $true
    } catch {
        Write-Log "npiperelay failed: $($_.Exception.Message)" "ERROR"
        return $false
    } finally {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force
        }
    }
}

function Invoke-WslBootstrap {
    param([AllowNull()][string]$RelayPath = $null)

    New-ConfigLink "$script:RootDir/configs/wsl/.wslconfig" "$env:USERPROFILE\.wslconfig"
    Write-Log "Updating WSL" "INFO"
    $updateResult = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @("--update")
    if ($updateResult.ExitCode -ne 0) {
        Write-Log "WSL Store update failed: exit $($updateResult.ExitCode)" "WARN"
        $updateResult = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @("--update", "--web-download")
        if ($updateResult.ExitCode -ne 0) {
            Write-Log "WSL update failed: exit $($updateResult.ExitCode)" "ERROR"
            return $false
        }
    }

    if (-not (Install-WslDistro)) { return $false }

    # Applying .wslconfig requires all WSL instances to stop before Ubuntu is
    # relaunched. A non-zero shutdown here is reported but does not prevent the
    # first-run experience from repairing an otherwise healthy installation.
    $initialShutdown = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @("--shutdown")
    if ($initialShutdown.ExitCode -ne 0) {
        Write-Log "WSL shutdown failed: exit $($initialShutdown.ExitCode)" "WARN"
    }

    try {
        $linuxUser = Initialize-WslUser
        if ([string]::IsNullOrWhiteSpace($linuxUser)) {
            return $false
        }

        $configPayload = Copy-WslConfigPayload -LinuxUser $linuxUser
        if ($null -eq $configPayload) {
            return $false
        }
        $configRoot = $configPayload.LinuxPath

        if ($null -eq $RelayPath) {
            $windowsRelayPath = Join-Path $env:LOCALAPPDATA "Programs\npiperelay\npiperelay.exe"
            $RelayPath = if (Test-Path -LiteralPath $windowsRelayPath) { $windowsRelayPath } else { "" }
        }
        $wslRelayPath = ""
        if (-not [string]::IsNullOrWhiteSpace($RelayPath)) {
            $wslRelayPath = ConvertTo-WslPath $RelayPath
            if ([string]::IsNullOrWhiteSpace($wslRelayPath)) {
                Write-Log "npiperelay path failed" "ERROR"
                return $false
            }
        } else {
            Write-Log "Bitwarden relay unavailable" "WARN"
        }

        Write-Log "Configuring Ubuntu" "INFO"
        $bootstrapPath = "$configRoot/wsl/bootstrap.sh"
        $bootstrapArguments = @(
            "--distribution", $script:WslDistro, "--user", "root", "--exec",
            "bash", $bootstrapPath, $linuxUser, $configRoot, $wslRelayPath
        )
        $bootstrapResult = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList $bootstrapArguments
        if ($bootstrapResult.ExitCode -ne 0) {
            $bootstrapText = @($bootstrapResult.Output) -join "`n"
            if ($bootstrapText -match '(?im)Release file(?: for)? .* is not valid yet') {
                Write-Log "Ubuntu clock skew detected" "WARN"
                $terminateResult = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @("--terminate", $script:WslDistro)
                if ($terminateResult.ExitCode -ne 0) {
                    Write-Log "Ubuntu restart failed: exit $($terminateResult.ExitCode)" "WARN"
                }
                $bootstrapResult = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList $bootstrapArguments
            }
        }
        if ($bootstrapResult.ExitCode -ne 0) {
            Write-Log "Ubuntu setup failed: exit $($bootstrapResult.ExitCode)" "ERROR"
            return $false
        }

        Write-Log "Ubuntu configured" "SUCCESS"
        return $true
    } finally {
        $shutdownResult = Invoke-NativeCommand -FilePath "wsl.exe" -ArgumentList @("--shutdown")
        if ($shutdownResult.ExitCode -ne 0) {
            Write-Log "WSL shutdown failed: exit $($shutdownResult.ExitCode)" "WARN"
        }
    }
}

function Disable-WindowsOpenSshAgent {
    $service = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
    if ($null -eq $service) { return $true }
    try {
        if ($service.Status -ne "Stopped") { Stop-Service -Name "ssh-agent" -Force }
        Set-Service -Name "ssh-agent" -StartupType Disabled
        Write-Log "OpenSSH agent disabled" "SUCCESS"
        return $true
    } catch {
        Write-Log "OpenSSH agent failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-VsCodeWslExtension {
    Refresh-EnvironmentPath
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Log "VS Code CLI unavailable" "WARN"
        return $false
    }
    $result = Invoke-NativeCommand -FilePath "code" -ArgumentList @(
        "--install-extension", "ms-vscode-remote.remote-wsl", "--force"
    )
    return $result.ExitCode -eq 0
}
