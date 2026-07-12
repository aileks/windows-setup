function New-SetupResult {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet("Pending", "Running", "Success", "Skipped", "Failed")]
        [string]$Status = "Pending",
        [int]$ExitCode = 0,
        [string]$Message = "",
        [bool]$RebootRequired = $false
    )

    [PSCustomObject]@{
        Id             = $Id
        Name           = $Name
        Status         = $Status
        ExitCode       = $ExitCode
        Message        = $Message
        RebootRequired = $RebootRequired
    }
}

function Test-SetupResultSuccessful {
    param([Parameter(Mandatory)]$Result)
    @("Success", "Skipped") -contains $Result.Status
}
