
if (Test-Path Alias:gp) { Remove-Item Alias:gp -Force }
function global:uprof { . $PROFILE }
function global:gp { $target = if ($args.Count -gt 0) { $args -join ' ' } else { Get-Location }; $target = $target -replace "'" -replace "$([char]96)" -replace '\s*\[[\d\.,\s]+\s*(?:KB|MB|GB)\s*,\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\]\s*$'; if ([System.IO.Directory]::Exists($target) -or [System.IO.File]::Exists($target)) { $target | Set-Clipboard; Write-Host "Path copied to clipboard:" -ForegroundColor DarkGray -NoNewline; Write-Host "`n$target" -ForegroundColor Blue } else { Write-Error "Not found: $target" } }
function global:gotp { $path = Get-Clipboard; if ($path) { $path = $path -replace "'" -replace "$([char]96)" -replace '\s*\[[\d\.,\s]+\s*(?:KB|MB|GB)\s*,\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\]\s*$' -replace '^[\s\-*>#]+' -replace '\s+$' -replace '^~', "$env:USERPROFILE"; if ([System.IO.File]::Exists($path)) { $path = Split-Path -Parent $path }; if ([System.IO.Directory]::Exists($path)) { Set-Location -LiteralPath $path; Write-Host "cd to: $path" -ForegroundColor Green } else { Write-Error "Not found: $path" } } else { Write-Error "Clipboard is empty" } }
function global:stp { $path = Get-Clipboard; if ($path) { $path = $path -replace "'" -replace "$([char]96)" -replace '\s*\[[\d\.,\s]+\s*(?:KB|MB|GB)\s*,\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\]\s*$' -replace '^[\s\-*>#]+' -replace '^~', "$env:USERPROFILE" -replace '\s+$'; if ([System.IO.File]::Exists($path)) { $path = Split-Path -Parent $path }; if ([System.IO.Directory]::Exists($path)) { Start-Process explorer.exe $path; Write-Host "opened: $path" -ForegroundColor Green } else { Write-Error "Not found: $path" } } else { Write-Error "Clipboard is empty" } }
function global:opf { $target = if ($args.Count -gt 0) { ($args -join ' ') -replace "'" -replace "$([char]96)" } else { Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue; $text = [System.Windows.Forms.Clipboard]::GetText() -replace "$([char]27)\[[\d;]*[a-zA-Z]" -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\p{Cf}]'; $clean = { param($s) $s -replace "'" -replace "$([char]96)" -replace '^[\s\-*>#]+' -replace '^(?:[^\w\s\:\\/]|✔|Success:?\s*Found\s*match:?)+\s*' -replace '\s*\[[\d\.,\s]+\s*(?:B|KB|MB|GB|TB)\s*,\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\]\s*$' -replace '^~', "$env:USERPROFILE" -replace '\s+$' }; $rawLines = $text -split '\r?\n' | Where-Object { $_ }; $cleanedLines = $rawLines | ForEach-Object { & $clean $_ } | Where-Object { $_ }; $candidates = @(); $candidates += $cleanedLines; if ($rawLines.Count -gt 1) { $candidates += (& $clean ($rawLines -join ' ')); $candidates += (& $clean ($rawLines -join '')) }; foreach ($p in $candidates) { if ($p) { $full = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { $resolved = Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue; if ($resolved) { $resolved.Path } else { Join-Path (Get-Location).Path $p } }; if ([System.IO.File]::Exists($full) -or [System.IO.Directory]::Exists($full)) { Start-Process $full; Write-Host "opened: $full" -ForegroundColor Green; return } } }; Write-Error "No valid file path in clipboard"; return }; $cleanTarget = & { param($s) $s -replace "'" -replace "$([char]96)" -replace '^[\s\-*>#]+' -replace '\s*\[[\d\.,\s]+\s*(?:B|KB|MB|GB|TB)\s*,\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\]\s*$' -replace '^~', "$env:USERPROFILE" -replace '\s+$' } $target; $full = if ([System.IO.Path]::IsPathRooted($cleanTarget)) { $cleanTarget } else { $resolved = Resolve-Path -LiteralPath $cleanTarget -ErrorAction SilentlyContinue; if ($resolved) { $resolved.Path } else { Join-Path (Get-Location).Path $cleanTarget } }; if ([System.IO.File]::Exists($full) -or [System.IO.Directory]::Exists($full)) { Start-Process $full; Write-Host "opened: $full" -ForegroundColor Green } else { Write-Error "Not found: $full" } }
function global:HH { hermes gateway run -v @args }

function global:yt {
    param(
        [Parameter(Position = 0)]
        [string]$Url,
        [switch]$s,
        [switch]$song,
        [switch]$v,
        [switch]$video,
        [Parameter(Position = 1)]
        [int]$N = 0
    )

    $ytdlp = "C:\Users\Leonardo\001\00__DEV\zz - VAR\yt-dlp\yt-dlp.exe"

    $isVideo = $v -or $video

    if ($Url -and $Url -match '^\d+$' -and -not ($Url -match '^https?://')) {
        $N = [int]$Url
        $Url = $null
    }

    if (-not $Url) {
        $Url = (Get-Clipboard -Format Text -ErrorAction SilentlyContinue).Trim()
        if (-not $Url -or $Url -notmatch '^https?://') {
            Write-Error "No URL provided and clipboard does not contain a valid URL."
            return
        }
        Write-Host "Using URL from clipboard: " -ForegroundColor DarkGray -NoNewline
        Write-Host $Url -ForegroundColor Blue
    }

    $argsList = @()

    if ($isVideo) {
        $argsList += @("-f", "bestvideo+bestaudio/best")
    } else {
        $argsList += @("-x", "--audio-format", "mp3", "-f", "bestaudio/best")
    }

    $argsList += @("--embed-thumbnail", "--embed-metadata")

    $startItem = 1
    if ($N -gt 0) {
        Write-Host "`nScanning playlist (first $N items)..." -ForegroundColor DarkGray

        $entries = & $ytdlp --flat-playlist --print "%(playlist_index)s|||%(id)s|||%(title)s" -I ":$N" $Url 2>$null

        $missing = @()
        $found = @()

        foreach ($entry in $entries) {
            $parts = $entry -split '\|\|\|', 3
            if ($parts.Count -lt 3) { continue }
            $idx = $parts[0].Trim()
            $vidId = $parts[1].Trim()
            $title = $parts[2].Trim()

            $match = Get-ChildItem -Path . -Filter "*[$vidId]*" -ErrorAction SilentlyContinue
            if ($match) {
                $found += [PSCustomObject]@{ Index = $idx; Title = $title; Id = $vidId }
            } else {
                $missing += [PSCustomObject]@{ Index = $idx; Title = $title; Id = $vidId }
            }
        }

        $M = $found.Count
        $totalMissing = $missing.Count

        Write-Host ""
        if ($M -gt 0) {
            Write-Host "Already downloaded ($M):" -ForegroundColor Green
            foreach ($f in $found) { Write-Host "  [$($f.Index)] $($f.Title)" -ForegroundColor DarkGray }
        }

        if ($totalMissing -eq 0) {
            Write-Host "`nAll $N songs already in this folder." -ForegroundColor Yellow
            $nextStart = $N + 1
            $nextEnd = $N * 2
            $resp = Read-Host "Download next $N after item $N? (y/N)"
            if ($resp -ne 'y') { return }
            $argsList += @("-I", "${nextStart}:${nextEnd}")
        } else {
            Write-Host "`nMissing ($totalMissing):" -ForegroundColor Cyan
            foreach ($m in $missing) { Write-Host "  [$($m.Index)] $($m.Title)" -ForegroundColor White }
            $resp = Read-Host "`nDownload these $totalMissing songs? (Y/n)"
            if ($resp -eq 'n') { return }
            $indices = ($missing | ForEach-Object { $_.Index }) -join ','
            $argsList += @("-I", $indices)
        }
    } elseif ($N -eq 0) {
        $argsList += $Url
    }

    if ($N -gt 0) { $argsList += $Url }

    Write-Host "`nyt-dlp " -ForegroundColor DarkGray -NoNewline
    if ($isVideo) {
        Write-Host "[VIDEO]" -ForegroundColor Cyan -NoNewline
    } else {
        Write-Host "[SONG]" -ForegroundColor Magenta -NoNewline
    }
    Write-Host " $Url" -ForegroundColor White

    & $ytdlp @argsList
}

function global:sf { sempath find @args }
function global:sg {
    if ($args.Count -eq 0) { sempath get } else { sempath @args }
}
$env:HOME = $env:USERPROFILE

function global:op { opencode @args }

function global:ow {
    Set-Location -LiteralPath "C:\Users\Leonardo\001\00__DEV\OpenWhispr"
    npm run dev
}

function global:codex { ollama launch codex --model minimax-m3:cloud @args }

Set-Alias -Name c -Value cls -Option AllScope -Force
function global:tree { npx tree-node-cli -I 'node_modules|.next' @args }
function global:gs { git status @args }

function global:alias {
    if ($args.Count -eq 0) {
        Get-Alias | Sort-Object Name | Format-Table Name, Definition -AutoSize
        return
    }
    $name = $args[0]
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $cmd) { Write-Error "No command, alias, or function named '$name'"; return }
    switch ($cmd.CommandType) {
        'Alias'   { Write-Host "$($cmd.Name) -> $($cmd.ResolvedCommand)" -ForegroundColor Cyan }
        'Function'{ Write-Host "$($cmd.Name) = function" -ForegroundColor Green; Write-Host $cmd.Definition -ForegroundColor DarkGray }
        'Cmdlet'  { Write-Host "$($cmd.Name) = cmdlet ($($cmd.Source))" -ForegroundColor Yellow }
        default   { Write-Host "$($cmd.Name) = $($_) ($($cmd.Source))" -ForegroundColor White }
    }
    $searchFiles = @($PROFILE)
    if ($PROFILE.CurrentUserAllHosts -and $PROFILE.CurrentUserAllHosts -ne $PROFILE) { $searchFiles += $PROFILE.CurrentUserAllHosts }
    if ($PROFILE.AllUsersAllHosts -and (Test-Path $PROFILE.AllUsersAllHosts)) { $searchFiles += $PROFILE.AllUsersAllHosts }
    foreach ($file in $searchFiles) {
        if (-not (Test-Path $file)) { continue }
        $content = Get-Content $file -Raw
        $escapedName = [regex]::Escape($name)
        if ($cmd.CommandType -eq 'Alias') {
            if ($content -match "(?m)^\s*Set-Alias\s+-Name\s+'?$escapedName'?\s") {
                Write-Host "  defined in: $file" -ForegroundColor DarkGray
                return
            }
        } elseif ($cmd.CommandType -eq 'Function') {
            if ($content -match "(?m)^\s*function\s+.*:$escapedName\s*[{]") {
                Write-Host "  defined in: $file" -ForegroundColor DarkGray
                return
            }
        }
    }
}

function global:upkey {
    Stop-Process -Name "AutoHotkey*" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    Start-Process "C:\Users\Leonardo\001\00__DEV\zz - VAR\AutoHotkey\STD_HotKeys.ahk"
}


