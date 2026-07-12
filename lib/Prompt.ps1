function Ask-YesNo {
    param(
        [Parameter(Mandatory)][string]$Question,
        [bool]$Default = $true
    )

    $hint = if ($Default) { "[Y/n]" } else { "[y/N]" }
    Write-Host "$Question $hint " -NoNewline -ForegroundColor White
    $reply = Read-Host
    if ([string]::IsNullOrWhiteSpace($reply)) { return $Default }
    return $reply.Trim() -match "^[Yy]"
}

function Ask-Input {
    param(
        [Parameter(Mandatory)][string]$Question,
        [string]$Default = ""
    )

    $suffix = if ($Default) { " ($Default): " } else { ": " }
    Write-Host "$Question$suffix" -NoNewline -ForegroundColor White
    $reply = Read-Host
    if ([string]::IsNullOrWhiteSpace($reply)) { return $Default }
    return $reply.Trim()
}
