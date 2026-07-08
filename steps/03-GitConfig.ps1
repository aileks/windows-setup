function Step-GitConfig {
    if (Test-StateCompleted "03-GitConfig") { return }

    Refresh-EnvironmentPath
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "Git is not installed or not on PATH." "WARN"
        Write-Log "  Install Git manually and re-run setup if you want this stage to configure .gitconfig." "WARN"
        return
    }

    if (-not (Ask-YesNo "Set up global Git config?" $false)) {
        Set-StateCompleted "03-GitConfig"
        return
    }

    $existingName = git config --global user.name 2>$null
    $existingEmail = git config --global user.email 2>$null

    do {
        $name = Ask-Input "Git user name" $existingName
        if ([string]::IsNullOrWhiteSpace($name)) {
            Write-Log "  Git user name is required." "WARN"
        }
    } while ([string]::IsNullOrWhiteSpace($name))

    do {
        $email = Ask-Input "Git user email" $existingEmail
        if ([string]::IsNullOrWhiteSpace($email)) {
            Write-Log "  Git user email is required." "WARN"
        }
    } while ([string]::IsNullOrWhiteSpace($email))

    Write-Log "Configuring global Git defaults..." "INFO"

    $settings = [ordered]@{
        "user.name"           = $name
        "user.email"          = $email
        "init.defaultBranch"  = "main"
        "core.autocrlf"       = "true"
        "core.filemode"       = "false"
        "core.ignorecase"     = "true"
        "core.longpaths"      = "true"
        "core.editor"         = "code --wait"
        "credential.helper"   = "manager"
        "pull.rebase"         = "true"
        "rebase.autoStash"    = "true"
        "fetch.prune"         = "true"
        "push.default"        = "simple"
        "push.autoSetupRemote" = "true"
        "merge.conflictStyle" = "zdiff3"
        "diff.algorithm"      = "histogram"
        "rerere.enabled"      = "true"
        "commit.verbose"      = "true"
        "branch.sort"         = "-committerdate"
        "tag.sort"            = "version:refname"
        "color.ui"            = "auto"
    }

    foreach ($key in $settings.Keys) {
        $value = $settings[$key]
        git config --global --replace-all $key $value
        if ($LASTEXITCODE -ne 0) {
            throw "git config failed while setting $key"
        }
    }

    $gitConfigPath = Join-Path $env:USERPROFILE ".gitconfig"
    Write-Log "Git configured at $gitConfigPath" "SUCCESS"
    Set-StateCompleted "03-GitConfig"
}
Step-GitConfig
