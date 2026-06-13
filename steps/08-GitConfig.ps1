function Step-GitConfig {
    if (Test-StateCompleted "08-GitConfig") { return }

    if (-not (Ask-YesNo "Set up global git config?" $false)) {
        Write-Log "Skipping git config" "INFO"
        Set-StateCompleted "08-GitConfig"
        return
    }

    Write-Log "Configuring git..." "INFO"

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "  git not found, skipping git config" "WARN"
        return
    }

    $existingName = git config --global user.name 2>$null
    $existingEmail = git config --global user.email 2>$null

    $name = Ask-Input "Git user name" $existingName
    $email = Ask-Input "Git user email" $existingEmail

    git config --global user.name $name
    git config --global user.email $email
    git config --global init.defaultBranch main
    git config --global core.autocrlf true
    git config --global pull.rebase true
    git config --global core.editor "code --wait"
    git config --global core.pager ""

    Set-StateCompleted "08-GitConfig"
    Write-Log "Git configured" "SUCCESS"
}
Step-GitConfig
