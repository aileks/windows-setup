function Register-ResumeAfterReboot {
    param([string]$ScriptPath)

    $runOnce = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    if (-not (Test-Path $runOnce)) { New-Item -Path $runOnce -Force | Out-Null }
    New-ItemProperty -Path $runOnce `
        -Name "WinSetup_Resume" `
        -Value "powershell.exe -NoExit -ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`"" `
        -PropertyType String -Force | Out-Null

    Set-StateValue "resumeAfterReboot" $true
}

function Clear-ResumeAfterReboot {
    $key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    $existing = Get-ItemProperty -Path $key -Name "WinSetup_Resume" -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        Remove-ItemProperty -Path $key -Name "WinSetup_Resume" -Force
    }
    Set-StateValue "resumeAfterReboot" $false
}

function Test-ResumingAfterReboot {
    $val = Get-StateValue "resumeAfterReboot"
    ($val -eq $true)
}
