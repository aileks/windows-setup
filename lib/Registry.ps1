function Set-RegistrySafe {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet("DWord","String","ExpandString","QWord")]
        [string]$Type = "DWord"
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $existing -or $existing.$Name -ne $Value) {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
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
    foreach ($path in $Tweaks.Keys) {
        $props = $Tweaks[$path]
        foreach ($name in $props.Keys) {
            $entry = $props[$name]
            $value = $entry.Value
            $type = if ($entry.ContainsKey("Type")) { $entry.Type } else { "DWord" }
            Set-RegistrySafe -Path $path -Name $name -Value $value -Type $type
            $count++
        }
    }
    Write-Log "Applied $count registry values" "SUCCESS"
}
