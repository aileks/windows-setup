function New-ConfigLink {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Dest
    )

    $parent = Split-Path $Dest -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    $sourceFull = (Resolve-Path $Source).Path

    if (Test-Path $Dest) {
        $item = Get-Item $Dest -Force
        if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -eq $sourceFull) {
            Write-Log "  Already linked: $Dest" "INFO"
            return
        }
        if ($item.LinkType -ne 'SymbolicLink' -and -not (Test-Path "$Dest.bak")) {
            Move-Item $Dest "$Dest.bak" -Force
            Write-Log "  Backed up existing $Dest -> $Dest.bak" "INFO"
        } else {
            Remove-Item $Dest -Force -Recurse
        }
    }

    New-Item -ItemType SymbolicLink -Path $Dest -Target $sourceFull -Force | Out-Null
    Write-Log "  Linked $Dest -> $sourceFull" "INFO"
}
