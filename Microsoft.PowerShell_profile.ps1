if (Test-Path Alias:gp) { Remove-Item Alias:gp -Force }

function global:ConvertFrom-ClipboardPath {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$Text,
        [switch]$Basic,
        [switch]$Junk,
        [switch]$IncludeBytes
    )
    process {
        if ($null -eq $Text) { return }
        $out = $Text
        $out = $out -replace "'" -replace '`'
        if (-not $Basic) {
            $out = $out -replace '^[\s\-*>#]+'
            if ($Junk) {
                $out = $out -replace '^(?:[^\w\s\:\\/]|✓|Success:?\s*Found\s*match:?)+\s*'
            }
            $out = $out -replace '^~', "$env:USERPROFILE"
            $out = $out -replace '\s+$'
        }
        if ($IncludeBytes) {
            $out = $out -replace '\s*\[[\d\.,\s]+\s*(?:B|KB|MB|GB|TB)\s*,\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\]\s*$'
        } else {
            $out = $out -replace '\s*\[[\d\.,\s]+\s*(?:KB|MB|GB)\s*,\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\]\s*$'
        }
        $out
    }
}

function global:Resolve-PathString {
    param(
        [Parameter(Position = 0)]
        [string]$Path
    )
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($resolved) { return $resolved.Path }
    return (Join-Path (Get-Location).Path $Path)
}

function global:uprof {
    $profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    if (Test-Path -LiteralPath $profilePath) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$null, [ref]$null)
        $definedFuncs = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
            ForEach-Object { $_.Name -replace '^global:', '' }

        if ($global:__profile_functions) {
            foreach ($func in $global:__profile_functions) {
                if ($func -notin $definedFuncs -and (Test-Path "Function:\$func")) {
                    Remove-Item "Function:\$func" -Force -ErrorAction SilentlyContinue
                }
            }
        }
        $global:__profile_functions = $definedFuncs
    }
    . "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
}
function global:gp {
    $target = if ($args.Count -gt 0) { $args -join ' ' } else { Get-Location }
    $target = $target | ConvertFrom-ClipboardPath -Basic
    $resolved = Resolve-Path -LiteralPath $target -ErrorAction SilentlyContinue
    if ($resolved) {
        $resolved.Path | Set-Clipboard
        Write-Host "Path copied to clipboard:" -ForegroundColor DarkGray -NoNewline
        Write-Host "`n$($resolved.Path)" -ForegroundColor Blue
    } else {
        Write-Error "Not found: $target"
    }
}
function global:gotp {
    $path = Get-Clipboard
    if ($path) {
        $path = $path | ConvertFrom-ClipboardPath
        if (Test-Path -LiteralPath $path -PathType Leaf) { $path = Split-Path -Parent $path }
        if (Test-Path -LiteralPath $path -PathType Container) {
            Set-Location -LiteralPath $path
            Write-Host "cd to: $path" -ForegroundColor Green
        } else {
            Write-Error "Not found: $path"
        }
    } else {
        Write-Error "Clipboard is empty"
    }
}
function global:stp {
    $path = Get-Clipboard
    if ($path) {
        $path = $path | ConvertFrom-ClipboardPath
        if (Test-Path -LiteralPath $path -PathType Leaf) { $path = Split-Path -Parent $path }
        if (Test-Path -LiteralPath $path -PathType Container) {
            Start-Process explorer.exe $path
            Write-Host "opened: $path" -ForegroundColor Green
        } else {
            Write-Error "Not found: $path"
        }
    } else {
        Write-Error "Clipboard is empty"
    }
}
function global:opf {
    if ($args.Count -gt 0) {
        $target = ($args -join ' ') | ConvertFrom-ClipboardPath -IncludeBytes
        $full = Resolve-PathString $target
        if ([System.IO.File]::Exists($full) -or [System.IO.Directory]::Exists($full)) {
            Start-Process $full
            Write-Host "opened: $full" -ForegroundColor Green
        } else {
            Write-Error "Not found: $full"
        }
        return
    }
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    $text = [System.Windows.Forms.Clipboard]::GetText() -replace "$([char]27)\[[\d;]*[a-zA-Z]" -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\p{Cf}]'
    $rawLines = $text -split '\r?\n' | Where-Object { $_ }
    $cleanedLines = $rawLines | ForEach-Object { $_ | ConvertFrom-ClipboardPath -Junk -IncludeBytes } | Where-Object { $_ }
    $candidates = @()
    $candidates += $cleanedLines
    if ($rawLines.Count -gt 1) {
        $candidates += (($rawLines -join ' ') | ConvertFrom-ClipboardPath -Junk -IncludeBytes)
        $candidates += (($rawLines -join '') | ConvertFrom-ClipboardPath -Junk -IncludeBytes)
    }
    foreach ($p in $candidates) {
        if ($p) {
            $full = Resolve-PathString $p
            if ([System.IO.File]::Exists($full) -or [System.IO.Directory]::Exists($full)) {
                Start-Process $full
                Write-Host "opened: $full" -ForegroundColor Green
                return
            }
        }
    }
    Write-Error "No valid file path in clipboard"
}
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
        $Url = ("$(Get-Clipboard -Raw -ErrorAction SilentlyContinue)").Trim()
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
            $match = Get-ChildItem -Path . -Filter "*$vidId*" -ErrorAction SilentlyContinue
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
    }
    if ($N -ge 0) { $argsList += $Url }
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
function global:Resolve-GotoUrl {
    param(
        [Parameter(Position = 0)]
        [string]$Query
    )
    if ($Query -match '^\w+://') {
        return $Query
    } elseif ($Query -match '^www\.') {
        return "https://$Query"
    } elseif ($Query -match '^localhost(:\d+)?(/[^\s]*)?$' -or $Query -match '^\d{1,3}(\.\d{1,3}){3}(:\d+)?(/[^\s]*)?$') {
        return "http://$Query"
    } elseif ($Query -match '^[\w][\w.-]*\.\w{2,}(:\d+)?(/[^\s]*)?$') {
        return "https://$Query"
    }
    return $null
}

function global:Save-GotoStore {
    param(
        [Parameter(Position = 0)]
        [string]$StorePath,
        [Parameter(Position = 1)]
        [object]$Aliases
    )
    $sorted = [pscustomobject]@{}
    foreach ($prop in ($Aliases.PSObject.Properties | Where-Object { $_.Name -notlike '_*' } | Sort-Object { $_.Name.ToLowerInvariant() })) {
        $sorted | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
    }
    $sorted | ConvertTo-Json | Set-Content -LiteralPath $StorePath -Encoding utf8
}

function global:Find-GotoAlias {
    param(
        [Parameter(Position = 0)]
        [object]$Aliases,
        [Parameter(Position = 1)]
        [string]$Name
    )
    $Aliases.PSObject.Properties | Where-Object { $_.Name -ceq $Name } | Select-Object -First 1
}

function global:goto {
    param(
        [switch]$d,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )
    $help = @'
goto <url-or-search> [-a <NAME> | --add-alias <NAME>]
                     [-d <NAME> | --del-alias <NAME>] [-ls | --list-alias]

  goto google.com          open a URL in the browser
  goto localhost:3000      open a local host/port
  goto how to make omelete
                           Google-search the text (quotes optional)
  goto onth0s.github.io/markdown-viewer -a MD
                           open it and save the target as alias 'MD'
  goto MD                  open a previously saved alias

Options:
  -h, --help               show this help
  -a, --add-alias <NAME>   save an alias for the target
  -d, --del-alias <NAME>   delete a saved alias
  -ls, --list-alias        list saved aliases
'@
    $aName = $null
    $dName = $null
    $list = $false
    $tokens = @()
    $i = 0
    while ($i -lt $Rest.Count) {
        $tok = $Rest[$i]
        if ($tok -in @('-a', '--add-alias')) {
            if ($i + 1 -lt $Rest.Count) {
                if ($dName -or $list) { Write-Error "goto: cannot combine --add-alias with --del-alias/--list-alias."; return }
                $aName = $Rest[$i + 1]
                $i += 2
                continue
            }
            Write-Error "goto: --add-alias requires a name."
            return
        } elseif ($tok -in @('-d', '--del-alias')) {
            if ($i + 1 -lt $Rest.Count) {
                if ($aName -or $list) { Write-Error "goto: cannot combine --del-alias with --add-alias/--list-alias."; return }
                $dName = $Rest[$i + 1]
                $i += 2
                continue
            }
            Write-Error "goto: --del-alias requires a name."
            return
        } elseif ($tok -in @('-ls', '--list-alias')) {
            if ($aName -or $dName) { Write-Error "goto: cannot combine --list-alias with --add-alias/--del-alias."; return }
            $list = $true
            $i++
            continue
        }
        $tokens += $tok
        $i++
    }
    if ($d) {
        if ($aName -or $list) { Write-Error "goto: cannot combine --del-alias with --add-alias/--list-alias."; return }
        if ($tokens.Count -eq 0) { Write-Error "goto: --del-alias requires a name."; return }
        $dName = $tokens[0]
        $tokens = @($tokens | Select-Object -Skip 1)
    }
    $q = ($tokens | Where-Object { $_ }) -join ' '
    if ($q -in @('-h', '--help')) { Write-Host $help -ForegroundColor DarkGray; return }
    if (-not $q -and -not ($aName -or $dName -or $list)) { Write-Host $help -ForegroundColor DarkGray; return }
    if ($list -and $q) { Write-Error "goto: --list-alias takes no target."; return }
    if ($aName -and -not $q) { Write-Error "goto: --add-alias requires a target."; return }
    if ($dName -and $q) { Write-Error "goto: --del-alias does not take a target."; return }
    foreach ($n in @($aName, $dName)) {
        if ($n -and $n -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') {
            Write-Error "goto: invalid alias name '$n' (use letters, digits, - and _)."
            return
        }
    }

    $storePath = Join-Path $HOME '.goto-aliases.json'
    $aliases = $null
    if (Test-Path -LiteralPath $storePath) {
        try {
            $raw = Get-Content -LiteralPath $storePath -Raw
            if ($raw) { $aliases = $raw | ConvertFrom-Json }
        } catch { $aliases = $null }
    }
    if ($null -eq $aliases) { $aliases = [pscustomobject]@{} }

    if ($list) {
        $props = @($aliases.PSObject.Properties | Where-Object { $_.Name -notlike '_*' } | Sort-Object { $_.Name.ToLowerInvariant() })
        if ($props.Count -eq 0) {
            Write-Host "no aliases saved" -ForegroundColor DarkGray
        } else {
            foreach ($p in $props) {
                Write-Host ("{0,-20}" -f $p.Name) -ForegroundColor Cyan -NoNewline
                Write-Host $p.Value -ForegroundColor DarkGray
            }
        }
        return
    }

    if ($dName) {
        $hit = Find-GotoAlias $aliases $dName
        if (-not $hit) {
            Write-Host "no alias '$dName'" -ForegroundColor Yellow
            return
        }
        $old = $hit.Value
        Write-Host "Alias '$($hit.Name)' -> $old" -ForegroundColor DarkGray
        $resp = Read-Host "Delete? (Y/n)"
        if ("$resp".Trim() -ieq 'n') { return }
        $null = $aliases.PSObject.Properties.Remove($hit.Name)
        Save-GotoStore $storePath $aliases
        Write-Host "removed alias $($hit.Name) (was $old)" -ForegroundColor Green
        return
    }

    if (-not $aName -and $tokens.Count -eq 1) {
        $hit = Find-GotoAlias $aliases $q
        if ($hit) {
            Write-Host "goto: $($hit.Value)" -ForegroundColor Green
            Start-Process $hit.Value
            return
        }
    }

    $url = Resolve-GotoUrl $q
    $isSearch = $false
    if (-not $url) {
        $isSearch = $true
        $url = "https://www.google.com/search?q=$([uri]::EscapeDataString($q))"
    }

    if ($aName) {
        $hit = Find-GotoAlias $aliases $aName
        if ($hit) {
            Write-Host "Alias '$aName' already exists:" -ForegroundColor Yellow
            Write-Host "  old: $($hit.Value)" -ForegroundColor DarkGray
            Write-Host "  new: $url" -ForegroundColor DarkGray
            $resp = Read-Host "Overwrite? (Y/n)"
            if ("$resp".Trim() -ieq 'n') { return }
            $null = $aliases.PSObject.Properties.Remove($hit.Name)
        }
        $aliases | Add-Member -NotePropertyName $aName -NotePropertyValue $url -Force
        Save-GotoStore $storePath $aliases
        Write-Host "alias $aName -> $url" -ForegroundColor Green
        Start-Process $url
        return
    }

    if ($isSearch) {
        Write-Host "searching: $q" -ForegroundColor Cyan -NoNewline
        Write-Host " -> $url" -ForegroundColor DarkGray
    } else {
        Write-Host "goto: $url" -ForegroundColor Green
    }
    Start-Process $url
}
function global:ow {
    param(
        [Parameter(Position = 0)]
        [string]$Action
    )
    if ($Action -in @('nuke', 'kill')) {
        Write-Host "Killing openwhispr services..." -ForegroundColor Yellow
        pm2 stop openwhispr openwhispr-preview 2>$null | Out-Null
        pm2 delete openwhispr openwhispr-preview 2>$null | Out-Null
        Write-Host "Nuked." -ForegroundColor Green
        return
    }
    $names = @('openwhispr', 'openwhispr-preview')
    $procs = pm2 jlist 2>$null | ConvertFrom-Json -AsHashtable
    $online = @()
    $offline = @()
    foreach ($name in $names) {
        $p = $procs | Where-Object { $_['name'] -eq $name }
        if ($p -and $p['pm2_env']['status'] -eq 'online') {
            $online += $name
        } else {
            $offline += $name
        }
    }
    if ($online.Count -eq 2) {
        Write-Host "Both running, restarting..." -ForegroundColor Yellow
        pm2 restart openwhispr openwhispr-preview
    } elseif ($offline.Count -eq 2) {
        Write-Host "Starting openwhispr services..." -ForegroundColor Cyan
        pm2 start "C:\Users\Leonardo\001\00__DEV\OpenWhispr\ecosystem.config.cjs"
    } else {
        Write-Host "Mixed state, restarting..." -ForegroundColor Yellow
        pm2 restart openwhispr openwhispr-preview
    }
}
Set-Alias -Name c -Value cls -Option AllScope -Force
# GNU-style ls flags: -a -l -t -S -X -r -R (combined tokens like -ltr supported).
# Shadow the built-in 'ls' alias (Get-ChildItem); no flags = exact same behavior.
if (Test-Path Alias:ls) { Remove-Item Alias:ls -Force }

function global:ls {
    $named    = @{}
    $paths    = [System.Collections.Generic.List[string]]::new()
    $long     = $false
    $sortTime = $false
    $sortSize = $false
    $sortExt  = $false
    $reverse  = $false

    $valueParams  = @('Path','LiteralPath','Filter','Include','Exclude','Depth','Attributes','ErrorAction','WarningAction','InformationAction','ProgressAction','ErrorVariable','WarningVariable','InformationVariable','OutVariable','OutBuffer','PipelineVariable')
    $switchParams = @('Recurse','Force','Name','FollowSymlink','Directory','File','Hidden','ReadOnly','System','Verbose','Debug')
    $allParams    = @($valueParams + $switchParams)

    $i = 0
    $tokens = @($args)
    while ($i -lt $tokens.Count) {
        $tok = $tokens[$i]
        if ($tok.Length -gt 1 -and $tok[0] -eq '-') {
            $chars = $tok.Substring(1).ToCharArray()
            $pure = $true
            foreach ($ch in $chars) {
                if ($ch -notin [char[]]'altSXrR') { $pure = $false; break }
            }
            if ($pure) {
                foreach ($ch in $chars) {
                    switch -CaseSensitive ($ch) {
                        'a' { $named['Force'] = $true }
                        'l' { $long = $true }
                        't' { $sortTime = $true }
                        'S' { $sortSize = $true }
                        'X' { $sortExt = $true }
                        'r' { $reverse = $true }
                        'R' { $named['Recurse'] = $true }
                    }
                }
                $i++
                continue
            }

            $name = $tok.TrimStart('-')
            if ($name -notin $valueParams -and $name -notin $switchParams) {
                $hits = @($allParams | Where-Object { $_.StartsWith($name, [System.StringComparison]::OrdinalIgnoreCase) })
                if ($hits.Count -eq 1) { $name = $hits[0] }
            }
            if ($name -in $valueParams) {
                if ($i + 1 -lt $tokens.Count) {
                    $val = $tokens[$i + 1]
                    if ($named.ContainsKey($name)) { $named[$name] = @($named[$name]) + $val }
                    else { $named[$name] = $val }
                    $i += 2
                    continue
                }
            } elseif ($name -in $switchParams) {
                $named[$name] = $true
                $i++
                continue
            }
        }
        $paths.Add($tok)
        $i++
    }

    if ($paths.Count -gt 0) {
        if ($named.ContainsKey('Path')) { $named['Path'] = @($named['Path']) + @($paths) }
        elseif ($named.ContainsKey('LiteralPath')) { $named['LiteralPath'] = @($named['LiteralPath']) + @($paths) }
        else { $named['Path'] = @($paths) }
    }

    $items = Get-ChildItem @named
    $sorting = $sortTime -or $sortSize -or $sortExt -or $reverse

    if (-not $sorting -and -not $long) {
        $items
        return
    }

    $spec = [System.Collections.Generic.List[object]]::new()
    $spec.Add(@{ Expression = { -not $_.PSIsContainer }; Ascending = $true })
    if ($sortTime) {
        $spec.Add(@{ Expression = 'LastWriteTime'; Ascending = $reverse })
    } elseif ($sortSize) {
        $spec.Add(@{ Expression = 'Length'; Ascending = $reverse })
    } elseif ($sortExt) {
        $spec.Add(@{ Expression = 'Extension'; Ascending = -not $reverse })
        $spec.Add(@{ Expression = 'Name'; Ascending = -not $reverse })
    } else {
        $spec.Add(@{ Expression = 'Name'; Ascending = -not $reverse })
    }

    $sorted = $items | Sort-Object $spec
    if ($long) {
        $sorted | Format-Table Mode, LastWriteTime, Length, Name -AutoSize
    } else {
        $sorted
    }
}
function global:tree { npx tree-node-cli -I 'node_modules|.next' @args }
function global:gs { git status @args }
function global:gsall { & "C:\Users\Leonardo\Documents\WindowsPowerShell\check-repos.ps1" @args }
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
function global:xxx { exit }
function global:upkey {
    Stop-Process -Name "AutoHotkey*" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    & python "C:\Users\Leonardo\001\00__DEV\zz - VAR\AutoHotkey\merge.py"
    Start-Process "C:\Users\Leonardo\001\00__DEV\zz - VAR\AutoHotkey\STD_HotKeys.ahk"
}







# Waypoint - path bookmark CLI (ASCII only: profiles may not be UTF-8)
# Session history shared by cd, cd.. / cd~ / cd\ and wp jumps.
# cd - toggles to the previous location; wp undo / wp history use the
# CLI's persistent stack instead.
$global:WpHistory = [System.Collections.Generic.List[string]]::new()
$global:WpMaxHistory = 50

function global:Set-WaypointLocation {
    param(
        [switch]$Literal,
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$PathArgs
    )
    $target = $PathArgs -join ' '
    if ($target -eq '-') {
        if ($global:WpHistory.Count -lt 2) {
            Write-Warning "No previous location in history."
            return
        }
        $target = $global:WpHistory[$global:WpHistory.Count - 2]
    }
    $before = (Get-Location).Path
    if ($target) {
        if ($Literal) { Set-Location -LiteralPath $target } else { Set-Location -Path $target }
    } else {
        Set-Location ~
    }
    $current = (Get-Location).Path
    if ($current -ne $before) {
        # Track both the dir we left and the dir we arrived at (each deduped),
        # so the newest persistent history entry is always the current dir.
        # A fresh tab can then wp h / wp u 0 to land where the last tab was.
        & python "C:\Users\Leonardo\001\00__DEV\Waypoint\waypoint\__main__.py" _record_history $before > $null 2>&1
        & python "C:\Users\Leonardo\001\00__DEV\Waypoint\waypoint\__main__.py" _record_history $current > $null 2>&1
        if ($global:WpHistory.Count -eq 0 -or $global:WpHistory[$global:WpHistory.Count - 1] -ne $before) {
            $global:WpHistory.Add($before)
        }
        if ($global:WpHistory.Count -eq 0 -or $global:WpHistory[$global:WpHistory.Count - 1] -ne $current) {
            $global:WpHistory.Add($current)
        }
        while ($global:WpHistory.Count -gt $global:WpMaxHistory) { $global:WpHistory.RemoveAt(0) }
    }
}

# Override the built-in cd/chdir aliases so every directory change feeds history.
# cd's alias is AllScope; a plain -Force would try to drop that option and fail.
Set-Alias -Name cd -Value Set-WaypointLocation -Option AllScope -Scope Global -Force
Set-Alias -Name chdir -Value Set-WaypointLocation -Option AllScope -Scope Global -Force

# The no-space shortcuts (cd.., cd~, cd\) are single tokens that PowerShell
# resolves to native Set-Location, bypassing the cd alias. Define same-named
# functions so they route through Set-WaypointLocation and feed history too.
function global:cd.. { Set-WaypointLocation .. }
function global:cd~ { Set-WaypointLocation ~ }
function global:cd\ { Set-WaypointLocation \ }

function global:cdh {
    $global:WpHistory
}

function global:wp {
    $env:WP_FORCE_COLOR = if ([Environment]::UserInteractive) { "1" } else { "0" }
    # Commands that perform interactive rich prompts (Prompt.ask). Capturing stdout via @()
    # would buffer stdout on the pipe, causing invisible prompts. Run live.
    $interactiveCmds = @('add')
    if ($args.Count -gt 0 -and $interactiveCmds -contains $args[0]) {
        & python "C:\Users\Leonardo\001\00__DEV\Waypoint\waypoint\__main__.py" @args
        Remove-Item Env:WP_FORCE_COLOR -ErrorAction SilentlyContinue
        return
    }
    $lines = @(& python "C:\Users\Leonardo\001\00__DEV\Waypoint\waypoint\__main__.py" @args)
    Remove-Item Env:WP_FORCE_COLOR -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -eq 0 -and $lines.Count -eq 1 -and $lines[0]) {
        try {
            $ok = Test-Path -LiteralPath $lines[0] -ErrorAction Stop
        } catch {
            # Non-path single-line output (e.g. "Saved demo -> C:\...") must
            # never surface as a red error; it is just echoed below.
            $ok = $false
        }
        if ($ok) {
            Set-WaypointLocation -Literal $lines[0]
        } else {
            Write-Output $lines[0]
        }
    } else {
        $lines | ForEach-Object { Write-Output $_ }
    }
}

# End Waypoint block







