param(
    [Parameter(Mandatory)][string]$PowerToysPath,
    [ValidateRange(1, 300)][int]$TimeoutSeconds = 60,
    [string[]]$RequiredProcesses = @("komorebi", "whkd", "komorebi-bar", "masir")
)

$ErrorActionPreference = "Stop"

if (Get-Process -Name "PowerToys" -ErrorAction SilentlyContinue) { exit 0 }
if (-not (Test-Path -LiteralPath $PowerToysPath -PathType Leaf)) { exit 1 }

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)

do {
    $missingProcesses = @($RequiredProcesses | Where-Object {
        -not (Get-Process -Name $_ -ErrorAction SilentlyContinue)
    })
    if ($missingProcesses.Count -eq 0) {
        Start-Process -FilePath $PowerToysPath
        exit 0
    }
    Start-Sleep -Milliseconds 250
} while ((Get-Date) -lt $deadline)

exit 1
