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
            if ($null -eq $existing -or $existing -ne $Value) {
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

function Remove-RegistryKey {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force
    }
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
    $msg = "Applied $count registry values"
    if ($failed -gt 0) { $msg += " ($failed failed)" }
    Write-Log $msg "SUCCESS"
}
