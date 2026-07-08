function Step-PowerPlan {
    if (Test-StateCompleted "Personal.PowerPlan") { return }
    Write-Log "Enabling Ultimate Performance power plan..." "INFO"

    $existing = powercfg /list | Select-String "Ultimate Performance"
    if (-not $existing) {
        powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null
    }

    $match = powercfg /list | Select-String "Ultimate Performance"
    if ($match) {
        $guid = ($match.Line -split '\s+')[3]
        powercfg -setactive $guid
        Write-Log "Ultimate Performance plan active: $guid" "SUCCESS"
    } else {
        Write-Log "Could not activate Ultimate Performance plan" "WARN"
    }

    Set-StateCompleted "Personal.PowerPlan"
}
Step-PowerPlan
