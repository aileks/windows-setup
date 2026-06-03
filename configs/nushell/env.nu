$env.EDITOR = "zed --wait"
$env.VISUAL = $env.EDITOR
$env.MANPAGER = 'bat --theme="ashen" -plman'

$env.PATH = ($env.PATH | split row (char esep) | prepend [
    ($env.USERPROFILE | path join ".local" "bin")
    ($env.USERPROFILE | path join ".cargo" "bin")
])

$env.FZF_DEFAULT_OPTS = "
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
  --pointer='█'
  --scrollbar='▌'
  --multi
  --border=top
"
$env.FZF_CTRL_T_OPTS = "
  --walker-skip .git,node_modules,target
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"
$env.FZF_ALT_C_OPTS = "
  --walker-skip .git,node_modules,target"
$env._ZO_FZF_OPTS = ($env.FZF_DEFAULT_OPTS + "
  --height=50%")

zoxide init nushell | save -f ~/.zoxide.nu
