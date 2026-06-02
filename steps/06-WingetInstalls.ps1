function Step-WingetInstalls {
    if (Test-StateCompleted "06-WingetInstalls") { return }
    Write-Log "Installing packages via winget..." "INFO"

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "  winget not found, installing via Microsoft.WinGet.Client..." "INFO"
        try {
            Install-PackageProvider -Name NuGet -Force | Out-Null
            Install-Module -Name Microsoft.WinGet.Client -Force
            Repair-WinGetPackageManager -AllUsers
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        } catch {
            Write-Log "  Failed to install winget: $($_.Exception.Message)" "ERROR"
            return
        }
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "  winget still not found. Install winget manually and re-run." "ERROR"
        return
    }

    $packages = @(
        @{ Id = "Zen-Team.Zen-Browser";           Name = "Zen Browser" }
        @{ Id = "ZedIndustries.Zed";              Name = "Zed" }
        @{ Id = "Bitwarden.Bitwarden";            Name = "Bitwarden" }
        @{ Id = "OpenWhisperSystems.Signal";      Name = "Signal" }
        @{ Id = "VideoLAN.VLC";                   Name = "VLC" }
        @{ Id = "Nushell.Nushell";                Name = "Nushell" }
        @{ Id = "LGUG2Z.komorebi";               Name = "Komorebi" }
        @{ Id = "LGUG2Z.whkd";                   Name = "whkd" }
        @{ Id = "Microsoft.WindowsTerminal";     Name = "Windows Terminal" }
        @{ Id = "Microsoft.PowerToys";           Name = "PowerToys" }
        @{ Id = "sharkdp.bat";                    Name = "bat" }
        @{ Id = "ajeetdsouza.zoxide";            Name = "zoxide" }
        @{ Id = "junegunn.fzf";                   Name = "fzf" }
        @{ Id = "fastfetch-cli.fastfetch";        Name = "fastfetch" }
        @{ Id = "Clement.bottom";                 Name = "bottom" }
    )

    $installed = 0
    $skipped = 0
    $failed = 0

    foreach ($pkg in $packages) {
        $already = winget list --id $pkg.Id --accept-source-agreements 2>$null | Select-String $pkg.Id
        if ($already) {
            $skipped++
            continue
        }

        Write-Log "  Installing $($pkg.Name)..." "INFO"
        $result = winget install -e --id $pkg.Id --accept-source-agreements --accept-package-agreements 2>&1

        if ($LASTEXITCODE -eq 0) {
            $installed++
        } else {
            $failed++
            Write-Log "  Failed to install $($pkg.Name): $result" "WARN"
        }
    }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    Write-Log "winget: $installed installed, $skipped already present, $failed failed" "SUCCESS"
    Set-StateCompleted "06-WingetInstalls"
}
Step-WingetInstalls
