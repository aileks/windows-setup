$env:EDITOR = "code --wait"
$env:VISUAL = $env:EDITOR

if (Get-Command coreutils-manager -ErrorAction SilentlyContinue) {
    @("cat", "cp", "echo", "ls", "mv", "pwd", "rm", "rmdir", "sleep", "sort", "tee") |
        ForEach-Object { Remove-Item "Alias:$_" -Force -ErrorAction SilentlyContinue }
    Remove-Item Function:mkdir -Force -ErrorAction SilentlyContinue
}

Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History
}

if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider "Ctrl+t" -PSReadlineChordReverseHistory "Ctrl+r"
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
