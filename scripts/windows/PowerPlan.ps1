function Invoke-PowerPlanTweaks {
    Write-Log "Configuring power plan" "INFO"
    $listResult = Invoke-NativeCommand -FilePath "powercfg" -ArgumentList @("/list")
    if ($listResult.ExitCode -ne 0) {
        Write-Log "Power plans unavailable" "ERROR"
        return $false
    }
    $existing = @($listResult.Output) | Select-String "Ultimate Performance"
    if (-not $existing) {
        $duplicateResult = Invoke-NativeCommand -FilePath "powercfg" -ArgumentList @(
            "-duplicatescheme", "e9a42b02-d5df-448d-aa00-03f14749eb61"
        )
        if ($duplicateResult.ExitCode -ne 0) {
            Write-Log "Power plan creation failed" "ERROR"
            return $false
        }
    }

    $listResult = Invoke-NativeCommand -FilePath "powercfg" -ArgumentList @("/list")
    $match = @($listResult.Output) | Select-String "Ultimate Performance" | Select-Object -First 1
    if (-not $match) {
        Write-Log "Power plan unavailable" "ERROR"
        return $false
    }
    $guid = ($match.Line -split '\s+')[3]
    $activeResult = Invoke-NativeCommand -FilePath "powercfg" -ArgumentList @("-setactive", $guid)
    if ($activeResult.ExitCode -ne 0) {
        Write-Log "Power plan activation failed" "ERROR"
        return $false
    }
    Write-Log "Power plan configured" "SUCCESS"
    return $true
}
