function Get-SafetyMilestones {
    $value = Get-StateValue "safetyMilestones"
    $milestones = @{}
    if ($value -is [hashtable]) {
        foreach ($key in $value.Keys) { $milestones[$key] = $value[$key] }
    } elseif ($null -ne $value) {
        $value.PSObject.Properties | ForEach-Object { $milestones[$_.Name] = $_.Value }
    }
    $milestones
}

function Test-SafetyMilestone {
    param([Parameter(Mandatory)][string]$Name)
    $milestones = Get-SafetyMilestones
    $milestones.ContainsKey($Name) -and $milestones[$Name].completed -eq $true
}

function Set-SafetyMilestone {
    param(
        [Parameter(Mandatory)][string]$Name,
        [hashtable]$Details = @{}
    )
    $milestones = Get-SafetyMilestones
    $record = @{ completed = $true; completedAt = (Get-Date).ToString("o") }
    foreach ($key in $Details.Keys) { $record[$key] = $Details[$key] }
    $milestones[$Name] = [PSCustomObject]$record
    Set-StateValue "safetyMilestones" $milestones
}

function Enable-SetupSystemRestore {
    $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $name = "SystemRestorePointCreationFrequency"
    try {
        if ($null -eq (Get-StateValue "systemRestoreFrequencyOriginal")) {
            $value = Get-ItemPropertyValue -Path $path -Name $name -ErrorAction SilentlyContinue
            Set-StateValue "systemRestoreFrequencyOriginal" ([PSCustomObject]@{
                existed = $null -ne $value
                value   = $value
            })
        }
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        New-ItemProperty -Path $path -Name $name -Value 0 -PropertyType DWord -Force | Out-Null
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        return $true
    } catch {
        Write-Log "Restore setup failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Restore-SystemRestoreFrequency {
    $original = Get-StateValue "systemRestoreFrequencyOriginal"
    if ($null -eq $original) { return }
    $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $name = "SystemRestorePointCreationFrequency"
    try {
        if ($original.existed -eq $true) {
            New-ItemProperty -Path $path -Name $name -Value ([int]$original.value) -PropertyType DWord -Force | Out-Null
        } else {
            Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Log "Restore frequency failed: $($_.Exception.Message)" "WARN"
    }
}

function New-SetupRestorePoint {
    param(
        [Parameter(Mandatory)][string]$Milestone,
        [Parameter(Mandatory)][string]$Description
    )
    if (Test-SafetyMilestone $Milestone) {
        Write-Log "Restore point exists: $Description" "INFO"
        return $true
    }
    if (-not (Enable-SetupSystemRestore)) { return $false }
    try {
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Set-SafetyMilestone $Milestone @{ description = $Description }
        Write-Log "Restore point created: $Description" "SUCCESS"
        return $true
    } catch {
        Write-Log "Restore point failed: $Description - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Initialize-PreTweaksSafety {
    param([Parameter(Mandatory)][string]$BackupRoot)
    if (Test-SafetyMilestone "beforeTweaks") {
        $script:RegistryBackedUpPaths = @{}
        foreach ($path in @(Get-SetupRegistryBackupTargets)) { $script:RegistryBackedUpPaths[$path] = $true }
        Write-Log "Registry backup exists" "INFO"
        return $true
    }
    $registryBackup = New-RegistryBackup -Root $BackupRoot -Paths @(Get-SetupRegistryBackupTargets)
    if (-not $registryBackup.Success) { return $false }
    Set-StateValue "registryBackupPath" $registryBackup.Path
    if (-not (New-SetupRestorePoint -Milestone "beforeTweaks" -Description "win-setup before tweaks")) {
        return $false
    }
    $milestones = Get-SafetyMilestones
    $milestone = $milestones["beforeTweaks"]
    $milestone | Add-Member -NotePropertyName registryBackupPath -NotePropertyValue $registryBackup.Path -Force
    $milestones["beforeTweaks"] = $milestone
    Set-StateValue "safetyMilestones" $milestones
    return $true
}
