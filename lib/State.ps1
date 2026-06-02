$script:StateFile = ""
$script:State = @{}

function Load-State {
    param([string]$Path)
    $script:StateFile = $Path

    if (Test-Path $Path) {
        $json = Get-Content $Path -Raw | ConvertFrom-Json
        $script:State = @{}
        $json.PSObject.Properties | ForEach-Object {
            $script:State[$_.Name] = $_.Value
        }
    } else {
        $dir = Split-Path $Path -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        $script:State = @{
            completed           = @()
            resumeAfterReboot   = $false
        }
    }
    $script:State
}

function Save-State {
    $obj = [PSCustomObject]$script:State
    $obj | ConvertTo-Json -Depth 5 | Set-Content $script:StateFile -Encoding UTF8
}

function Test-StateCompleted {
    param([string]$StepId)
    $list = $script:State["completed"]
    if ($null -eq $list) { return $false }
    $list -contains $StepId
}

function Set-StateCompleted {
    param([string]$StepId)
    $list = @($script:State["completed"])
    if ($list -notcontains $StepId) {
        $list += $StepId
        $script:State["completed"] = $list
    }
    Save-State
}

function Get-StateValue {
    param([string]$Key)
    $script:State[$Key]
}

function Set-StateValue {
    param([string]$Key, $Value)
    $script:State[$Key] = $Value
    Save-State
}
