function Invoke-PowerPlanTweaks {
    Write-Log "Enabling Ultimate Performance power plan..." "INFO"
    $existing = powercfg /list | Select-String "Ultimate Performance"
    if (-not $existing) {
        $null = & powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Could not create Ultimate Performance power plan" "ERROR"
            return $false
        }
    }

    $match = powercfg /list | Select-String "Ultimate Performance" | Select-Object -First 1
    if (-not $match) {
        Write-Log "Could not find Ultimate Performance power plan" "ERROR"
        return $false
    }
    $guid = ($match.Line -split '\s+')[3]
    $null = & powercfg -setactive $guid 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Could not activate Ultimate Performance power plan" "ERROR"
        return $false
    }
    Write-Log "Ultimate Performance plan active: $guid" "SUCCESS"
    return $true
}
