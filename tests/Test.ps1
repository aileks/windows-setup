$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$script:Passed = 0

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
    $script:Passed++
}

function Assert-Equal {
    param($Expected, $Actual, [Parameter(Mandatory)][string]$Message)
    if ($Expected -ne $Actual) { throw "$Message. Expected '$Expected', got '$Actual'." }
    $script:Passed++
}

function Write-Log { param([string]$Message, [string]$Level = "INFO") }

$powerShellFiles = @(Get-ChildItem "$root\*.ps1", "$root\lib\*.ps1", "$root\helpers\*.ps1", "$root\personal\*.ps1", "$root\tests\*.ps1")
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert-Equal 0 @($errors).Count "PowerShell syntax errors in $($file.FullName)"
    if ($file.Name -eq "setup.ps1") {
        Assert-Equal 0 @($ast.ParamBlock.Parameters).Count "setup.ps1 must remain parameterless"
    }
}

foreach ($jsonFile in @(Get-ChildItem "$root\data\*.json", "$root\configs\*\*.json")) {
    $null = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
    $script:Passed++
}

$software = Get-Content "$root\data\software.json" -Raw | ConvertFrom-Json
$expectedRequired = @("VS Code", "LocalSend", "VLC", "Zen Browser", "PowerShell 7", "Windows Terminal", "Bitwarden", "Komorebi", "whkd", "masir")
Assert-Equal $expectedRequired.Count @($software.required).Count "Required software count"
for ($i = 0; $i -lt $expectedRequired.Count; $i++) {
    Assert-Equal $expectedRequired[$i] $software.required[$i].name "Required software order"
}

$expectedOptional = @("BCUninstaller", "Signal", "NVCleanInstall", "7-Zip", "PowerToys", "Raycast", "Windhawk")
$optionalNames = @($software.optional | ForEach-Object { $_.name })
Assert-Equal $optionalNames.Count @($optionalNames | Select-Object -Unique).Count "Optional software names must be unique"
foreach ($name in $expectedOptional) {
    Assert-True ($optionalNames -contains $name) "Optional software must include $name"
}

$allSoftware = @(@($software.required) + @($software.optional))
$softwareIds = @($allSoftware | ForEach-Object { $_.id })
Assert-Equal $softwareIds.Count @($softwareIds | Select-Object -Unique).Count "Software IDs must be unique"
foreach ($item in $allSoftware) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($item.name)) "Software name is required"
    Assert-True (-not [string]::IsNullOrWhiteSpace($item.id)) "Software ID is required for $($item.name)"
}
Assert-True ($softwareIds -notcontains "Git.Git") "Git for Windows must not be installed"
Assert-True ($softwareIds -notcontains "GitHub.cli") "GitHub CLI for Windows must not be installed"

$cli = Get-Content "$root\data\cli-tools.json" -Raw | ConvertFrom-Json
$cliIds = @($cli.tools | ForEach-Object { $_.id })
Assert-Equal $cliIds.Count @($cliIds | Select-Object -Unique).Count "CLI package IDs must be unique"
Assert-True ($cliIds -notcontains "Git.Git") "Git for Windows must not be installed as a CLI tool"
Assert-True ($cliIds -notcontains "GitHub.cli") "GitHub CLI for Windows must not be installed as a CLI tool"
foreach ($tool in @($cli.tools)) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($tool.command)) "CLI command is required for $($tool.name)"
}

$fonts = Get-Content "$root\data\fonts.json" -Raw | ConvertFrom-Json
Assert-Equal 1 @($fonts.fonts).Count "Only the opinionated font should be available"
$adwaita = @($fonts.fonts | Where-Object { $_.name -eq "Adwaita Mono" })
Assert-Equal 1 $adwaita.Count "Adwaita Mono must be available"
Assert-Equal "AdwaitaMono Nerd Font Mono" $adwaita[0].monoFace "Adwaita mono face"
Assert-Equal "AdwaitaMono Nerd Font Propo" $adwaita[0].propoFace "Adwaita proportional face"
Assert-True ($adwaita[0].archiveUrl -match "^https://github.com/ryanoasis/nerd-fonts/releases/download/") "Adwaita must use an upstream release archive"
Assert-True ($adwaita[0].sha256 -match "^[a-f0-9]{64}$") "Adwaita archive must have a SHA-256 checksum"

$terminal = Get-Content "$root\configs\windows-terminal\settings.json" -Raw | ConvertFrom-Json
Assert-Equal "AdwaitaMono Nerd Font Mono" $terminal.profiles.defaults.font.face "Windows Terminal font"
$bar = Get-Content "$root\configs\komorebi\komorebi.bar.json" -Raw | ConvertFrom-Json
Assert-Equal "AdwaitaMono Nerd Font Propo" $bar.font_family "Komorebi bar font"

$setupText = Get-Content "$root\setup.ps1" -Raw
Assert-True ($setupText.Contains("WSL not enabled! Would you like to enable and reboot?")) "WSL gate prompt is required"
Assert-True ($setupText.Contains("Continue with setup?")) "Setup confirmation is required"
Assert-True ($setupText.Contains("Read-OptionalSoftwareTui")) "Full-screen optional software selection is required"
Assert-True (-not $setupText.Contains("Read-CatalogCategorySelection")) "Numbered catalog selection must be removed"
$registryBackupIndex = $setupText.IndexOf("New-RegistryBackup")
$actionsIndex = $setupText.IndexOf('$actions = @(')
Assert-True ($registryBackupIndex -ge 0 -and $registryBackupIndex -lt $actionsIndex) "Registry backup must run before setup actions"
$developerText = Get-Content "$root\personal\02-DevSettings.ps1" -Raw
foreach ($requiredText in @("LongPathsEnabled", "AllowDevelopmentWithoutDevLicense", "L2L:1", "R2R:1", "L2R:1", "R2L:1", "sudo config --enable normal")) {
    Assert-True ($developerText.Contains($requiredText)) "Developer tweaks must contain $requiredText"
}
$explorerText = Get-Content "$root\personal\03-ExplorerTweaks.ps1" -Raw
foreach ($requiredText in @("TaskbarDa", "SearchboxTaskbarMode", "ShowTaskViewButton", "TurnOffWindowsCopilot")) {
    Assert-True ($explorerText.Contains($requiredText)) "Explorer tweaks must contain $requiredText"
}
$privacyText = Get-Content "$root\personal\04-PrivacyTweaks.ps1" -Raw
foreach ($requiredText in @("AllowTelemetry", "CEIPEnable", "DisableInventory", "DODownloadMode", "AllowRecallEnablement")) {
    Assert-True ($privacyText.Contains($requiredText)) "Privacy tweaks must contain $requiredText"
}

. "$root\lib\Tui.ps1"
function Test-TuiAvailable { return $false }
$fallbackItems = @([PSCustomObject]@{ id = "one" }, [PSCustomObject]@{ id = "two" })
$fallbackSelection = Read-OptionalSoftwareTui -Items $fallbackItems
Assert-True (-not $fallbackSelection.Cancelled) "Non-interactive selection must continue"
Assert-Equal 2 @($fallbackSelection.Items).Count "Non-interactive selection must keep all opinionated extras"
$emptySelection = Read-OptionalSoftwareTui -Items @()
Assert-True (-not $emptySelection.Cancelled) "Empty optional catalog must continue"
Assert-Equal 0 @($emptySelection.Items).Count "Empty optional catalog must stay empty"

$profileText = Get-Content "$root\configs\powershell\Microsoft.PowerShell_profile.ps1" -Raw
foreach ($requiredText in @("Set-PSReadLineOption", "PSFzf", "starship init powershell", "zoxide init powershell")) {
    Assert-True ($profileText.Contains($requiredText)) "PowerShell profile must contain $requiredText"
}
Assert-True (-not ($profileText -match "function\s+g[a-z]*\s*\{")) "PowerShell profile must not contain Git aliases"

$bootstrapText = Get-Content "$root\configs\wsl\bootstrap.sh" -Raw
foreach ($requiredText in @("git", "openssh-client", "zsh", "socat", "iproute2", "fastfetch", "starship", "core.autocrlf input", "npiperelay.exe")) {
    Assert-True ($bootstrapText.Contains($requiredText)) "WSL bootstrap must contain $requiredText"
}
Assert-True ($bootstrapText.Contains("/etc/wsl.conf.bak-")) "WSL system config must be backed up"
$relayText = Get-Content "$root\configs\wsl\bitwarden-ssh-agent.zsh" -Raw
Assert-True ($relayText.Contains("//./pipe/openssh-ssh-agent")) "Bitwarden relay must target the OpenSSH named pipe"
Assert-True ($relayText.Contains("mode=600")) "Bitwarden relay socket must be private"

. "$root\lib\Result.ps1"
$result = New-SetupResult -Id "test" -Name "Test" -Status Success
Assert-True (Test-SetupResultSuccessful $result) "Successful result detection"
$result.Status = "Failed"
Assert-True (-not (Test-SetupResultSuccessful $result)) "Failed result detection"

. "$root\lib\State.ps1"
$tempRoot = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$tempDir = Join-Path $tempRoot "win-setup-test-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    $statePath = Join-Path $tempDir "state.json"
    Load-State $statePath | Out-Null
    $stateResult = New-SetupResult -Id "atomic" -Name "Atomic" -Status Success
    Set-StateResult $stateResult
    Assert-True (Test-Path $statePath) "State file must be written"
    Assert-True (-not (Test-Path "$statePath.tmp")) "Atomic state temp file must be replaced"
    Set-StateValue "secondWrite" $true
    Load-State $statePath | Out-Null
    Assert-True (Test-StateCompleted "atomic") "Completed state must reload"
    Assert-True ((Get-StateValue "secondWrite") -eq $true) "Atomic state replacement must preserve later writes"
} finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force
}

. "$root\helpers\Software.ps1"
$script:WingetArguments = @()
function winget {
    $script:WingetArguments = @($args)
    $global:LASTEXITCODE = 0
    "installed"
}
$wingetResult = Install-WinGetPackage -PackageId "Example.Package" -Name "Example"
Assert-True $wingetResult "WinGet mock install should succeed"
Assert-True ($script:WingetArguments -contains "--id") "WinGet install must constrain by ID"
Assert-True ($script:WingetArguments -contains "--exact") "WinGet install must require an exact match"

. "$root\lib\Registry.ps1"
$registryTargets = @(Get-SetupRegistryBackupTargets)
Assert-Equal $registryTargets.Count @($registryTargets | Select-Object -Unique).Count "Registry backup targets must be unique"
foreach ($requiredTarget in @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
    "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
)) {
    Assert-True ($registryTargets -contains $requiredTarget) "Registry backup must include $requiredTarget"
}
$registrySourceFiles = @(
    Get-ChildItem "$root\personal\*.ps1"
    Get-Item "$root\helpers\Fonts.ps1"
)
$registrySourceText = ($registrySourceFiles | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
$literalRegistryPaths = @([regex]::Matches($registrySourceText, '(?:HKLM|HKCU):\\[^"`\r\n]+') | ForEach-Object { $_.Value } | Select-Object -Unique)
foreach ($literalPath in $literalRegistryPaths) {
    Assert-True ($registryTargets -contains $literalPath) "Literal registry path must be backed up: $literalPath"
}
Assert-Equal "HKCU\Software\Test" (ConvertTo-NativeRegistryPath "HKCU:\Software\Test") "Native registry path conversion"
Assert-Equal "HKEY_CURRENT_USER\Software\Test" (ConvertTo-RegFileRegistryPath "HKCU:\Software\Test") "REG file path conversion"
$missingKeyContent = Get-MissingRegistryKeyFileContent "HKLM:\Software\Test"
Assert-True ($missingKeyContent.Contains("[-HKEY_LOCAL_MACHINE\Software\Test]")) "Missing registry keys need deletion-form REG files"
$backupFile = Get-RegistryBackupFilePath -BackupDirectory $tempRoot -RegistryPath "HKLM:\Software\Test"
Assert-True ($backupFile.EndsWith("Test.reg")) "Registry backup files must use the REG extension"

$script:ExportedRegistryPaths = @()
function Export-RegistryKey {
    param([string]$Path, [string]$BackupDirectory)
    $script:ExportedRegistryPaths += $Path
    return $true
}
$registryTempRoot = Join-Path $tempRoot "win-setup-registry-test-$([guid]::NewGuid())"
try {
    $registryResult = New-RegistryBackup -Root $registryTempRoot -Paths @("HKCU:\One", "HKCU:\Two", "HKCU:\One")
    Assert-True $registryResult.Success "Mock registry backup must succeed"
    Assert-Equal 2 $registryResult.Count "Registry backup must deduplicate targets"
    Assert-Equal 2 $script:ExportedRegistryPaths.Count "Every unique registry target must be exported"
    Assert-True (Test-Path -LiteralPath $registryResult.Path) "Registry backup directory must be created"
    Assert-True (Test-RegistryPathBackedUp "HKCU:\One") "Exported registry targets must be marked as backed up"
    Assert-True (-not (Test-RegistryPathBackedUp "HKCU:\Three")) "Unexported registry targets must not pass the backup guard"
} finally {
    if (Test-Path -LiteralPath $registryTempRoot) { Remove-Item -LiteralPath $registryTempRoot -Recurse -Force }
}
$unbackedWrite = Set-RegistrySafe -Path "HKCU:\Three" -Name "Value" -Value 1 -PassThru
Assert-True (-not $unbackedWrite) "Registry writes without a native backup must fail"

function Set-RegistrySafe {
    param([string]$Path, [string]$Name, $Value, [string]$Type, [switch]$PassThru)
    return $Name -ne "Bad"
}
$batchResult = Set-RegistryBatch @{ "HKCU:\Test" = @{ "Good" = @{ Value = 1 }; "Bad" = @{ Value = 0 } } }
Assert-True (-not $batchResult) "Registry batch must report partial failure"

. "$root\helpers\Wsl.ps1"
Assert-True ($script:NpipeRelayVersion -match "^\d+\.\d+\.\d+$") "npiperelay version must be pinned"
Assert-True ($script:NpipeRelaySha256 -match "^[a-f0-9]{64}$") "npiperelay archive must have a SHA-256 checksum"
$wslHelperText = Get-Content "$root\helpers\Wsl.ps1" -Raw
Assert-True ($wslHelperText.Contains("github.com/albertony/npiperelay")) "npiperelay must use the maintained fork"
Assert-True ($wslHelperText.Contains("--web-download")) "WSL must retry without Microsoft Store delivery"
$fontHelperText = Get-Content "$root\helpers\Fonts.ps1" -Raw
Assert-True ($fontHelperText.Contains("Set-RegistrySafe")) "Font registration must use the shared registry writer"
function Get-WindowsOptionalFeature {
    param([switch]$Online, [string]$FeatureName)
    [PSCustomObject]@{ State = "Enabled" }
}
Assert-True (Test-WslPlatformEnabled) "WSL platform detection should require both enabled features"

$implementationFiles = @($powerShellFiles | Where-Object { $_.DirectoryName -ne (Join-Path $root "tests") })
$allPowerShellText = ($implementationFiles | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
Assert-True (-not ($allPowerShellText -match "Ensure-Scoop|scoop install|Scoop Git")) "Windows setup must not depend on Scoop or Git"
Assert-True (-not $allPowerShellText.Contains("registry-backup.json")) "Registry backup must not use JSON"

$readme = Get-Content "$root\README.md" -Raw
Assert-True ($readme.Contains("registry-backups\")) "README must document native registry backups"
Assert-True (-not $readme.Contains("registry-backup.json")) "README must not document JSON registry backup"

Write-Host "$script:Passed assertions passed" -ForegroundColor Green
