function Register-ResumeAfterReboot {
    param([string]$ScriptPath)

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" `
        -Name "WinSetup_Resume" `
        -Value "powershell.exe -NoExit -ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`"" `
        -Type String -Force

    Set-StateValue "resumeAfterReboot" $true
}

function Clear-ResumeAfterReboot {
    $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
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
