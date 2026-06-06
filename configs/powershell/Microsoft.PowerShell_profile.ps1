$env:EDITOR = 'zed --wait'
$env:VISUAL = $env:EDITOR

$env:PATH = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;$env:PATH"

$env:FZF_DEFAULT_OPTS = @'
  --color=fg:#a7a7a7
  --color=fg+:#d5d5d5
  --color=bg:-1
  --color=bg+:#323232
  --color=hl:#C4693D
  --color=hl+:#E49A44
  --color=info:#a7a7a7
  --color=marker:#C4693D
  --color=prompt:#C4693D
  --color=spinner:#D87C4A
  --color=pointer:#E5A72A
  --color=header:#B14242
  --color=border:#a7a7a7
  --color=query:#d5d5d5
  --color=gutter:-1
  --highlight-line
  --info=inline-right
  --layout=reverse
  --pointer=█
  --scrollbar=▌
  --multi
  --border=top
'@
$env:FZF_CTRL_T_OPTS = @'
  --walker-skip .git,node_modules,target
  --preview "bat -n --color=always {}"
  --bind "ctrl-/:change-preview-window(down|hidden|)"
'@
$env:FZF_ALT_C_OPTS = '--walker-skip .git,node_modules,target'
$env:_ZO_FZF_OPTS = $env:FZF_DEFAULT_OPTS + "`n  --height=50%"

Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Cursor
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -MaximumHistoryCount 50000
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
                    -PSReadlineChordReverseHistory 'Ctrl+r'
}

# Microsoft's coreutils replace these
'ls', 'cat', 'cp', 'mv', 'rm', 'echo', 'sort', 'tee', 'pwd' |
    ForEach-Object { Remove-Item "Alias:$_" -Force -ErrorAction SilentlyContinue }
Remove-Item Function:mkdir -Force -ErrorAction SilentlyContinue

Set-Alias c Clear-Host
function ll { ls -la @args }
function la { ls -a @args }
function fzf { fzf.exe --style full @args }

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
