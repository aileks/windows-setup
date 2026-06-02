function Set-RegistrySafe {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet("DWord","String","ExpandString","QWord")]
        [string]$Type = "DWord"
    )

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -eq $existing -or $existing.$Name -ne $Value) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        }
    } catch {
        Write-Log "  Failed to set registry: ${Path}\${Name} - $($_.Exception.Message)" "WARN"
    }
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
            try {
                Set-RegistrySafe -Path $path -Name $name -Value $value -Type $type
                $count++
            } catch {
                $failed++
                Write-Log "  Failed: ${Path}\${Name} - $($_.Exception.Message)" "WARN"
            }
        }
    }
    $msg = "Applied $count registry values"
    if ($failed -gt 0) { $msg += " ($failed failed)" }
    Write-Log $msg "SUCCESS"
}
