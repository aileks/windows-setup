$script:RegistryBackupPath = ""
$script:RegistryBackup = @()

function Initialize-RegistryBackup {
    param([Parameter(Mandatory)][string]$Path)

    $script:RegistryBackupPath = $Path
    if (Test-Path -LiteralPath $Path) {
        try {
            $script:RegistryBackup = @(Get-Content $Path -Raw | ConvertFrom-Json)
        } catch {
            $corruptPath = "$Path.corrupt-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Move-Item -LiteralPath $Path -Destination $corruptPath
            $script:RegistryBackup = @()
        }
    }
}

function Backup-RegistryValue {
    param([string]$Path, [string]$Name)

    if ([string]::IsNullOrWhiteSpace($script:RegistryBackupPath)) { return }
    if (@($script:RegistryBackup | Where-Object { $_.path -eq $Path -and $_.name -eq $Name }).Count -gt 0) { return }

    $propertyName = if ($Name -eq "(Default)") { "" } else { $Name }
    $entry = [ordered]@{ path = $Path; name = $Name; existed = $false; value = $null; kind = $null }
    try {
        if (Test-Path $Path) {
            $key = Get-Item -Path $Path
            $entry.existed = $null -ne $key.GetValue($propertyName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($entry.existed) {
                $entry.value = $key.GetValue($propertyName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $entry.kind = $key.GetValueKind($propertyName).ToString()
            }
        }
    } catch {}

    $script:RegistryBackup += [PSCustomObject]$entry
    $tempPath = "$script:RegistryBackupPath.tmp"
    $script:RegistryBackup | ConvertTo-Json -Depth 6 | Set-Content $tempPath -Encoding UTF8
    if (Test-Path -LiteralPath $script:RegistryBackupPath) {
        $backupPath = "$script:RegistryBackupPath.replace"
        try {
            [System.IO.File]::Replace($tempPath, $script:RegistryBackupPath, $backupPath)
        } finally {
            if (Test-Path -LiteralPath $backupPath) { Remove-Item -LiteralPath $backupPath -Force }
        }
    } else {
        [System.IO.File]::Move($tempPath, $script:RegistryBackupPath)
    }
}

function Set-RegistrySafe {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet("DWord","String","ExpandString","QWord")]
        [string]$Type = "DWord",
        [switch]$PassThru
    )

    $success = $false
    try {
        Backup-RegistryValue -Path $Path -Name $Name
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        $propertyName = if ($Name -eq "(Default)") { "" } else { $Name }
        $kind = switch ($Type) {
            "DWord"        { [Microsoft.Win32.RegistryValueKind]::DWord }
            "String"       { [Microsoft.Win32.RegistryValueKind]::String }
            "ExpandString" { [Microsoft.Win32.RegistryValueKind]::ExpandString }
            "QWord"        { [Microsoft.Win32.RegistryValueKind]::QWord }
        }

        $root = $null
        $subKey = $null
        if ($Path -match "^HKLM:\\(.+)$") {
            $root = [Microsoft.Win32.Registry]::LocalMachine
            $subKey = $Matches[1]
        } elseif ($Path -match "^HKCU:\\(.+)$") {
            $root = [Microsoft.Win32.Registry]::CurrentUser
            $subKey = $Matches[1]
        } else {
            throw "Unsupported registry hive in path: $Path"
        }

        $key = $root.CreateSubKey($subKey)
        try {
            $existing = $key.GetValue($propertyName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $existingKind = if ($null -ne $existing) { $key.GetValueKind($propertyName) } else { $null }
            if ($null -eq $existing -or $existing -ne $Value -or $existingKind -ne $kind) {
                $key.SetValue($propertyName, $Value, $kind)
            }
            $success = $true
        } finally {
            if ($key) { $key.Dispose() }
        }
    } catch {
        Write-Log "  Failed to set registry: ${Path}\${Name} - $($_.Exception.Message)" "WARN"
    }

    if ($PassThru) { return $success }
}

function Set-RegistryBatch {
    param(
        [Parameter(Mandatory)][hashtable]$Tweaks
    )

    $count = 0
    $failed = 0
    foreach ($path in $Tweaks.Keys) {
        $props = $Tweaks[$path]
        foreach ($name in $props.Keys) {
            $entry = $props[$name]
            $value = $entry.Value
            $type = if ($entry.ContainsKey("Type")) { $entry.Type } else { "DWord" }
            if (Set-RegistrySafe -Path $path -Name $name -Value $value -Type $type -PassThru) {
                $count++
            } else {
                $failed++
            }
        }
    }
    if ($failed -gt 0) {
        Write-Log "Applied $count registry values ($failed failed)" "WARN"
        return $false
    }
    Write-Log "Applied $count registry values" "SUCCESS"
    return $true
}
