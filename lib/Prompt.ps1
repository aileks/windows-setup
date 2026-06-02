function Ask-YesNo {
    param(
        [Parameter(Mandatory)][string]$Question,
        [bool]$Default = $true
    )

    $hint = if ($Default) { "[Y/n]" } else { "[y/N]" }
    $prompt = "$Question $hint"

    Write-Host $prompt -NoNewline -ForegroundColor White
    Write-Host " " -NoNewline
    $reply = Read-Host

    if ([string]::IsNullOrWhiteSpace($reply)) { return $Default }
    return $reply.Trim() -match "^[Yy]"
}

function Ask-Input {
    param(
        [Parameter(Mandatory)][string]$Question,
        [string]$Default = ""
    )

    if ($Default) {
        Write-Host "$Question " -NoNewline -ForegroundColor White
        Write-Host "($Default)" -NoNewline -ForegroundColor DarkGray
        Write-Host ": " -NoNewline
    } else {
        Write-Host "$Question: " -NoNewline -ForegroundColor White
    }
    $reply = Read-Host

    if ([string]::IsNullOrWhiteSpace($reply)) { return $Default }
    return $reply.Trim()
}
