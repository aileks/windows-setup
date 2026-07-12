function Test-TuiAvailable {
    try {
        -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected -and
            [Console]::WindowWidth -ge 70 -and [Console]::WindowHeight -ge 18
    } catch { $false }
}

function Reset-TuiConsole {
    $script:TuiActive = $false
    try {
        [Console]::CursorVisible = $true
        [Console]::ResetColor()
        [Console]::Clear()
    } catch {}
}

function Write-TuiLine {
    param([string]$Text = "", [ConsoleColor]$Color = [ConsoleColor]::Gray)
    [Console]::ForegroundColor = $Color
    $width = [Math]::Max(1, [Console]::WindowWidth - 1)
    if ($Text.Length -gt $width) { $Text = $Text.Substring(0, $width) }
    [Console]::WriteLine($Text.PadRight($width))
}

function Read-OptionalSoftwareTui {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items)

    if ($Items.Count -eq 0) {
        return [PSCustomObject]@{ Cancelled = $false; Items = @() }
    }
    if (-not (Test-TuiAvailable)) {
        return [PSCustomObject]@{ Cancelled = $false; Items = @($Items) }
    }
    $selected = @{}
    foreach ($item in $Items) { $selected[$item.id] = $true }
    $cursor = 0
    $offset = 0
    $script:TuiActive = $true
    [Console]::CursorVisible = $false
    [Console]::Clear()

    try {
        while ($true) {
            [Console]::SetCursorPosition(0, 0)
            Write-TuiLine " win-setup / optional software" Cyan
            Write-TuiLine " Opinionated defaults are selected. Space toggles, A toggles all, Enter continues, Esc cancels." DarkGray
            Write-TuiLine
            $visibleCount = [Math]::Min($Items.Count, [Math]::Max(1, [Console]::WindowHeight - 6))
            if ($cursor -lt $offset) { $offset = $cursor }
            if ($cursor -ge $offset + $visibleCount) { $offset = $cursor - $visibleCount + 1 }
            $lastVisible = [Math]::Min($Items.Count - 1, $offset + $visibleCount - 1)
            for ($i = $offset; $i -le $lastVisible; $i++) {
                $item = $Items[$i]
                $mark = if ($selected[$item.id]) { "[x]" } else { "[ ]" }
                $prefix = if ($i -eq $cursor) { ">" } else { " " }
                $color = if ($i -eq $cursor) { [ConsoleColor]::White } else { [ConsoleColor]::Gray }
                Write-TuiLine (" {0} {1} {2}  {3}" -f $prefix, $mark, $item.name, $item.description) $color
            }
            Write-TuiLine
            Write-TuiLine (" Selected: {0}/{1}  Showing: {2}-{3}" -f `
                @($Items | Where-Object { $selected[$_.id] }).Count, $Items.Count, ($offset + 1), ($lastVisible + 1)) DarkCyan

            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                "UpArrow" { $cursor = if ($cursor -le 0) { $Items.Count - 1 } else { $cursor - 1 } }
                "DownArrow" { $cursor = if ($cursor -ge $Items.Count - 1) { 0 } else { $cursor + 1 } }
                "Spacebar" { $selected[$Items[$cursor].id] = -not $selected[$Items[$cursor].id] }
                "A" {
                    $enable = @($Items | Where-Object { -not $selected[$_.id] }).Count -gt 0
                    foreach ($item in $Items) { $selected[$item.id] = $enable }
                }
                "Enter" { return [PSCustomObject]@{ Cancelled = $false; Items = @($Items | Where-Object { $selected[$_.id] }) } }
                "Escape" { return [PSCustomObject]@{ Cancelled = $true; Items = @() } }
            }
        }
    } finally {
        Reset-TuiConsole
    }
}

function Show-SetupProgress {
    param([Parameter(Mandatory)][object[]]$Results, [string]$Heading = "Applying setup")
    if (-not (Test-TuiAvailable)) { return }

    $script:TuiActive = $true
    [Console]::CursorVisible = $false
    [Console]::Clear()
    [Console]::SetCursorPosition(0, 0)
    Write-TuiLine " win-setup / $Heading" Cyan
    Write-TuiLine
    foreach ($result in $Results) {
        $symbol = switch ($result.Status) {
            "Success" { "[ok]" }
            "Skipped" { "[--]" }
            "Failed" { "[!!]" }
            "Running" { "[..]" }
            default { "[  ]" }
        }
        $color = switch ($result.Status) {
            "Success" { [ConsoleColor]::Green }
            "Failed" { [ConsoleColor]::Red }
            "Running" { [ConsoleColor]::Cyan }
            default { [ConsoleColor]::DarkGray }
        }
        Write-TuiLine (" {0} {1}" -f $symbol, $result.Name) $color
    }
}

function Show-SetupResults {
    param([Parameter(Mandatory)][object[]]$Results, [string]$LogPath)
    Reset-TuiConsole
    Write-Host "Setup results" -ForegroundColor White
    foreach ($result in $Results) {
        $color = if ($result.Status -eq "Failed") { "Red" } elseif ($result.Status -eq "Success") { "Green" } else { "Yellow" }
        $detail = if ($result.Message) { " - $($result.Message)" } else { "" }
        Write-Host ("  [{0}] {1}{2}" -f $result.Status, $result.Name, $detail) -ForegroundColor $color
    }
    Write-Host "Log: $LogPath" -ForegroundColor DarkGray
}
