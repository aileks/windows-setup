$env:EDITOR = "code --wait"
$env:VISUAL = $env:EDITOR

Set-Alias ff fastfetch

if (Get-Command coreutils-manager -ErrorAction SilentlyContinue) {
    @("cat", "cp", "echo", "ls", "mv", "pwd", "rm", "rmdir", "sleep", "sort", "tee") |
        ForEach-Object { Remove-Item "Alias:$_" -Force -ErrorAction SilentlyContinue }
    Remove-Item Function:mkdir -Force -ErrorAction SilentlyContinue
}

Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineOption -Colors @{
    Default                = "#BBB3A9"
    Comment                = "#58534C"
    Keyword                = "#9A788F"
    String                 = "#879B5C"
    Operator               = "#6785A1"
    Variable               = "#BBB3A9"
    Command                = "#6785A1"
    Parameter              = "#C87546"
    Type                   = "#58918C"
    Number                 = "#58918C"
    Member                 = "#DDD5CA"
    Error                  = "#B34A45"
    Emphasis               = "#D9A441"
    Selection              = "#23201C"
    InlinePrediction       = "#58534C"
    ListPredictionSelected = "#23201C"
}

$env:FZF_DEFAULT_OPTS = @(
    "--color=fg:#ACA49B,fg+:#DDD5CA,bg:#131210,bg+:#34312D"
    "--color=hl:#C87546,hl+:#E8A64D,info:#ACA49B,marker:#C87546"
    "--color=prompt:#C87546,spinner:#C87546,pointer:#D9A441,header:#B34A45"
    "--color=border:#ACA49B,query:#DDD5CA,gutter:#131210"
    "--highlight-line --info=inline-right --layout=reverse --pointer=█ --scrollbar=▌ --multi --border=top"
) -join " "

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
