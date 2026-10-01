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
            $out = [System.Environment]::ExpandEnvironmentVariables($out)
            $out = [regex]::Replace($out, '\$env:([A-Za-z_][A-Za-z0-9_]*)', {
                param($m)
                $name = $m.Groups[1].Value
                $val = [System.Environment]::GetEnvironmentVariable($name, 'Process')
                if ($null -eq $val) { $val = [System.Environment]::GetEnvironmentVariable($name, 'User') }
                if ($null -eq $val) { $val = [System.Environment]::GetEnvironmentVariable($name, 'Machine') }
                if ($null -eq $val) { return $m.Value }
                return $val
            })
            $out = $out -replace '\$HOME\b', "$env:USERPROFILE"
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

function global:Get-NearestExistingPath {
    param(
        [Parameter(Position = 0)]
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $current = $Path.Trim()
    while ($current) {
        $probe = $current.TrimEnd('\', '/')
        if ($probe -match '^[A-Za-z]:$') { $probe += '\' }
        if ($probe) { $current = $probe }
        if (Test-Path -LiteralPath $current) { return $current }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }
    return $null
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
        $nearest = Get-NearestExistingPath $target
        if ($nearest) {
            Write-Host "Not found: $target" -ForegroundColor Yellow
            $nearest | Set-Clipboard
            Write-Host "Path copied to clipboard:" -ForegroundColor DarkGray -NoNewline
            Write-Host "`n$($nearest)" -ForegroundColor Blue
        } else {
            Write-Error "Not found: $target"
        }
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
            $nearest = Get-NearestExistingPath $path
            if ($nearest) {
                Write-Host "Not found: $path" -ForegroundColor Yellow
                Set-Location -LiteralPath $nearest
                Write-Host "cd to: $nearest" -ForegroundColor Green
            } else {
                Write-Error "Not found: $path"
            }
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
            $nearest = Get-NearestExistingPath $path
            if ($nearest) {
                Write-Host "Not found: $path" -ForegroundColor Yellow
                Start-Process explorer.exe $nearest
                Write-Host "opened: $nearest" -ForegroundColor Green
            } else {
                Write-Error "Not found: $path"
            }
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
function global:Get-CookieHeaderString {
    <# Builds a "Cookie: k=v; k=v" header from a Netscape-format cookie jar (yt-dlp's format).
       Returns $null when no jar is found. Without cookies TikTok serves a challenge stub
       instead of the real page, so imagePost never shows up. #>
    param([string]$CookieFile, [string]$CookieHost = "www.tiktok.com")
    if (-not $CookieFile) {
        $store = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\cookies"
        $cand = Join-Path $store "${CookieHost}_cookies.txt"
        if (Test-Path -LiteralPath $cand) { $CookieFile = $cand }
    }
    if (-not $CookieFile -or -not (Test-Path -LiteralPath $CookieFile)) { return $null }
    try { $lines = Get-Content -LiteralPath $CookieFile -ErrorAction Stop } catch { return $null }
    $pairs = @()
    foreach ($line in $lines) {
        if (-not $line -or $line.StartsWith('#')) { continue }
        $p = $line -split "`t"
        if ($p.Count -ge 7 -and $p[5] -and $p[6]) { $pairs += "$($p[5])=$($p[6])" }
    }
    if ($pairs.Count -eq 0) { return $null }
    return ($pairs -join '; ')
}
function global:Get-TikTokPhotoPost {
    <#
        yt-dlp's TikTok extractor has no photo/slideshow support, so those posts fail with
        "No video formats found!". The image URLs live in the page's __UNIVERSAL_DATA_FOR_REHYDRATION__
        blob under imagePost.images[]. Returns an array of image URLs, or empty if not a photo post.
    #>
    param([Parameter(Mandatory)][string]$Url, [string]$Referer, [int]$Attempts = 3)
    $start = -1
    $html = ''
    $headers = @{
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        "Referer"    = if ($Referer) { $Referer } else { "https://www.tiktok.com/" }
        "Accept-Language" = "en-US,en;q=0.9"
    }
    $cookieStr = Get-CookieHeaderString
    for ($try = 1; $try -le $Attempts; $try++) {
        $h = @{} + $headers
        if ($cookieStr) { $h["Cookie"] = $cookieStr }
        try {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30 -Headers $h
            $html = $resp.Content
        } catch {
            $html = ''
        }
        if (-not $html) { $html = (curl -s -L -A $headers["User-Agent"] $Url 2>&1) | Out-String }
        # Some responses double-encode the JSON (\" escapes); normalise before searching.
        if ($html -match '\\"imagePost\\"') { $html = $html -replace '\\"', '"' }
        $start = $html.IndexOf('"imagePost"')
        if ($start -lt 0) { $start = $html.IndexOf('imagePost') }
        if ($start -ge 0) { break }
        if ($try -lt $Attempts) { Start-Sleep -Seconds (2 * $try) }
    }
    if ($start -lt 0) { return @() }
    $block = $html.Substring($start, [Math]::Min(40000, $html.Length - $start))
    $arrStart = $block.IndexOf('"images":[')
    if ($arrStart -lt 0) {
        $arrStart = $block.IndexOf('images":[')
        if ($arrStart -lt 0) { return @() }
    }
    $coverIdx = $block.IndexOf('"cover":', $arrStart)
    if ($coverIdx -lt 0) { $coverIdx = $block.IndexOf('cover":', $arrStart) }
    if ($coverIdx -lt 0) { $coverIdx = $block.Length }
    $arr = $block.Substring($arrStart, $coverIdx - $arrStart)
    $urls = @()
    $seen = @{}
    foreach ($ul in [regex]::Matches($arr, '"urlList"\s*:\s*\[((?:[^]]|(?<=\\)])*)\]')) {
        $list = $ul.Groups[1].Value
        foreach ($u in [regex]::Matches($list, '"([^"]+)"')) {
            $uu = $u.Groups[1].Value -replace '\\u002F', '/' -replace '\\/', '/' -replace '%3A', ':' -replace '%2F', '/'
            $sig = (($uu -split '\?')[0]) -replace 'https?://p1[69]-common-sign[^/]*', 'H'
            if ($seen.ContainsKey($sig)) { continue }
            $seen[$sig] = $true
            $urls += $uu
        }
    }
    if ($urls.Count -eq 0) {
        foreach ($m in [regex]::Matches($arr, 'https?(?::|%3A)(?:\\u002F\\u002F|\\/\\/|//|%2F%2F)[^"\\\s,]+?(?=\?|\s|"|,|\])')) {
            $uu = $m.Value -replace '\\u002F','/' -replace '\\/','/' -replace '%3A',':' -replace '%2F','/'
            $sig = (($uu -split '\?')[0]) -replace 'https?://p1[69]-common-sign[^/]*', 'H'
            if ($seen.ContainsKey($sig)) { continue }
            $seen[$sig] = $true
            $urls += $uu
        }
    }
    return $urls
}
function global:Get-TikTokPostDesc {
    <# The caption of a TikTok post, read from the page HTML. yt-dlp cannot supply this for
       photo posts because extraction fails before the title is parsed. #>
    param([Parameter(Mandatory)][string]$Url, [int]$Attempts = 3)
    $html = ''
    $headers = @{
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        "Referer"    = "https://www.tiktok.com/"
    }
    $cookieStr = Get-CookieHeaderString
    for ($try = 1; $try -le $Attempts; $try++) {
        $h = @{} + $headers
        if ($cookieStr) { $h["Cookie"] = $cookieStr }
        try {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30 -Headers $h
            $html = $resp.Content
        } catch { $html = '' }
        if ($html -and $html -match '"desc"\s*:\s*"') { break }
        if ($try -lt $Attempts) { Start-Sleep -Seconds (2 * $try) }
    }
    if (-not $html) { return $null }
    $m = [regex]::Match($html, '"desc"\s*:\s*"((?:[^"\\]|\\.)*)"')
    if (-not $m.Success) { return $null }
    $d = $m.Groups[1].Value -replace '\\u002F', '/' -replace '\\"', '"' -replace '\\n', ' ' -replace '\\u0026', '&'
    $d = $d -replace '\\u([0-9a-fA-F]{4})', { param($x) [char][Convert]::ToInt32($x.Groups[1].Value, 16) }
    return $d.Trim()
}
function global:Save-TikTokPhotoPost {
    <# Downloads a TikTok photo/slideshow post as individual images. Returns $true if anything was written. #>
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$BaseName = (Split-Path $Url -Leaf)
    )
    $urls = Get-TikTokPhotoPost -Url $Url
    if (-not $urls -or $urls.Count -eq 0) { return $false }
    $safe = ($BaseName -replace '[\\/:*?"<>|]', '_')
    if ($safe.Length -gt 120) { $safe = $safe.Substring(0, 120).Trim() }
    $written = 0
    $n = 0
    foreach ($u in $urls) {
        $n++
        $ext = [System.IO.Path]::GetExtension(($u -split '\?')[0])
        if (-not $ext -or $ext.Length -gt 5) { $ext = ".jpg" }
        $dest = Join-Path (Get-Location).Path ("{0} [{1:d2}]{2}" -f $safe, $n, $ext)
        try {
            Invoke-WebRequest -Uri $u -OutFile $dest -UseBasicParsing -TimeoutSec 60 -Headers @{
                "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                "Referer"    = "https://www.tiktok.com/"
            }
            $written++
            Write-Host "  saved $(Split-Path $dest -Leaf)" -ForegroundColor DarkGray
        } catch {
            Write-Host "  image $n failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    return ($written -gt 0)
}
function global:yt {
    param(
        [Parameter(Position = 0)]
        [string]$Url,
        [switch]$s,
        [switch]$song,
        [string]$c,
        [switch]$v,
        [switch]$video,
        [Parameter(Position = 1)]
        [int]$N = 0,
        [Alias('Sleep', 'Delay')]
        [double]$SleepInterval = 1.5,
        [double]$SleepRequests = 0.8,
        [switch]$IgnoreErrors,
        [switch]$AbortOnError,
        [string]$Archive,
        [switch]$NoArchive,
        [switch]$Photos,
        [switch]$Images,
        [switch]$NoImages
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
            $global:LASTEXITCODE = 1
            return
        }
        Write-Host "Using URL from clipboard: " -ForegroundColor DarkGray -NoNewline
        Write-Host $Url -ForegroundColor Blue
    }
    # TikTok's yt-dlp extractor only understands /video/<id>. A /photo/<id> URL falls
    # through to the generic extractor and dies with a bare "ERROR: Unsupported URL:"
    # that carries no [TikTok] <id> tag, so the photo fallback can never see it.
    # Normalising to /video/ is what makes a single image+audio post resolvable.
    if ($Url -match '/photo/(\d+)') {
        $Url = $Url -replace '/photo/\d+', "/video/$($Matches[1])"
    }
    $isTiktok = ($Url -match 'tiktok\.com')
    # Photos are dissociated by default on TikTok: image posts ship as audio-only m4a
    # with the picture present only as embedded cover art, so save the full-res
    # original alongside. -NoImages forces the old audio-only behaviour.
    $trackImages = ($isTiktok -and -not $NoImages)
    if ($NoImages) { $trackImages = $false }
    $argsList = @()
    if ($isVideo) {
        $argsList += @("-f", "bestvideo+bestaudio/best")
    } else {
        $argsList += @("-x", "--audio-format", "mp3", "-f", "bestaudio/best")
    }
    $argsList += @("--embed-thumbnail", "--embed-metadata", "-w", "-c")
    # Multi-item runs should not die on one guardrail-blocked video; single videos should fail loudly.
    $multiItem = ($N -gt 0) -or ($Url -notmatch '/(video|shorts|watch|photo|reel|p|status|clip)/\d')
    $useIgnore = if ($IgnoreErrors) { $true } elseif ($AbortOnError) { $false } else { $multiItem }
    if ($useIgnore) { $argsList += "--ignore-errors" } else { $argsList += "--abort-on-error" }
    if ($SleepInterval -gt 0) {
        $argsList += @("--sleep-interval", $SleepInterval, "--max-sleep-interval", ($SleepInterval * 2))
    }
    if ($SleepRequests -gt 0) {
        $argsList += @("--sleep-requests", $SleepRequests)
    }
    $argsList += @("--extractor-retries", "5", "--retry-sleep", "http:exp=1:30")
    $cookieStore = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\cookies'
    $hostName = try { ([uri]$Url).Host } catch { $null }
    $siteName = if ($hostName) { $hostName } else { 'site' }
    $mode = if ($isVideo) { 'video' } else { 'song' }
    $archivePath = $null
    if (-not $NoArchive) {
        if ($Archive) {
            $archivePath = if ([System.IO.Path]::IsPathRooted($Archive)) { $Archive } else { Join-Path (Get-Location).Path $Archive }
        } elseif ($hostName) {
            $archivePath = Join-Path (Get-Location) ".$hostName.$mode.downloaded.txt"
        } else {
            $archivePath = Join-Path (Get-Location) ".$mode.downloaded.txt"
        }
        $argsList += @("--download-archive", $archivePath)
    }
    function Get-UsedCookie {
        if ($c) {
            $cookieFile = if ([System.IO.Path]::IsPathRooted($c)) { $c } else { Join-Path (Get-Location).Path $c }
            if (Test-Path -LiteralPath $cookieFile) { return $cookieFile }
            Write-Warning "yt: cookies file not found: $cookieFile"
            return $null
        }
        if ($hostName) {
            $cwdCookie = Get-ChildItem -Path . -Filter "${hostName}_cookies.txt" -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cwdCookie) { return $cwdCookie.FullName }
        }
        $cwdCookie = Get-ChildItem -Path . -Filter "*_cookies.txt" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cwdCookie) { return $cwdCookie.FullName }
        if ($hostName) {
            $hostParts = $hostName -split '\.'
            for ($i = 0; $i -lt ($hostParts.Count - 1); $i++) {
                $candHost = ($hostParts[$i..($hostParts.Count - 1)] -join '.')
                $check = Join-Path $cookieStore "${candHost}_cookies.txt"
                if (Test-Path -LiteralPath $check) { return $check }
            }
        }
        return $null
    }
    $isProfile = ($Url -notmatch '/(video|shorts|watch|photo|reel|p|status|clip)/') -and
                 ($Url -match '(tiktok\.com/@|youtube\.com/(c/|channel/|@|playlist|user/)|instagram\.com/|x\.com/|twitter\.com/)')
    $archiveSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ($archivePath -and (Test-Path -LiteralPath $archivePath)) {
        $stale = 0
        $presentIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($f in (Get-ChildItem -Path . -File -ErrorAction SilentlyContinue)) {
            foreach ($m in [regex]::Matches($f.Name, '\d{6,}')) { [void]$presentIds.Add($m.Value) }
        }
        foreach ($line in [System.IO.File]::ReadAllLines($archivePath)) {
            $t = $line.Trim()
            if (-not $t -or $t.StartsWith('#')) { continue }
            $sp = $t.LastIndexOf(' ')
            if ($sp -ge 0) { $t = $t.Substring($sp + 1) }
            if (-not $t) { continue }
            if ($presentIds.Contains($t)) { [void]$archiveSet.Add($t) } else { $stale++ }
        }
        if ($stale -gt 0) {
            Write-Host "yt: pruning $stale archive entries whose files are no longer here." -ForegroundColor DarkGray
            if ($archiveSet.Count -gt 0) {
                $keep = foreach ($line in [System.IO.File]::ReadAllLines($archivePath)) {
                    $t = $line.Trim()
                    if (-not $t -or $t.StartsWith('#')) { $line; continue }
                    $sp = $t.LastIndexOf(' ')
                    $id = if ($sp -ge 0) { $t.Substring($sp + 1) } else { $t }
                    if ($archiveSet.Contains($id)) { $line }
                }
                Set-Content -LiteralPath $archivePath -Value $keep -Encoding utf8
            } else {
                Remove-Item -LiteralPath $archivePath -Force
            }
        }
    }
    function Test-Downloaded {
        param([string]$Id)
        if (-not $Id) { return $false }
        if ($archiveSet.Contains($Id)) { return $true }
        return [bool](Get-ChildItem -Path . -Filter "*$Id*" -File -ErrorAction SilentlyContinue)
    }
    function Test-ImagesDone {
        # Image completeness is judged from the FILESYSTEM ONLY - never from the
        # download archive. The archive is the audio ledger; a photo+song post gets
        # its id appended the moment yt-dlp writes the mp3, so consulting it here
        # would report image+audio posts as done before the image was ever fetched.
        #
        # Must match ONLY a dissociated image, identified by Save-TikTokPhotoPost's
        # " [<id>] [NN]" naming. yt is invoked with -w, so yt-dlp writes its own
        # "[<id>].jpeg" thumbnail for EVERY post (verified: ordinary video posts get
        # one too). Matching any jpeg would make every post look image-complete and
        # a photo+song post in an existing folder would never be flagged.
        # Uses -Filter + Where-Object, not -Include: -Include is silently ignored for
        # a bare -Path . without -Recurse/wildcard, which would always report false.
        param([string]$Id)
        if (-not $Id) { return $true }
        $hit = Get-ChildItem -Path . -Filter "*$Id*" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '\[\d+\]\s*\[\d{2,}\]\.[A-Za-z0-9]+$' }
        return [bool]$hit
    }
    function Test-Complete {
        # A photo+audio post is only "downloaded" when BOTH halves are on disk. Without
        # this, an mp3 alone matches Test-Downloaded's "*$Id*" filter and the post is
        # skipped forever - the image could never be fetched into an existing folder.
        # Deliberately NOT folded into Test-Downloaded: the archive-pruning block above
        # shares that helper, and loosening it would prune live entries and trigger
        # mass re-downloads.
        param([string]$Id)
        if (-not (Test-Downloaded -Id $Id)) { return $false }
        if ($trackImages -and -not (Test-ImagesDone -Id $Id)) {
            # Audio is present (or archived) but no image: only a photo post can be in
            # this state, since ordinary video posts never gain a matching image file.
            # Probe it - cheap, and bounded to candidates rather than every post.
            # -ErrorAction Stop is load-bearing: a wrong command name here would
            # otherwise fail silently, return falsy, and mark EVERY candidate complete
            # - i.e. quietly disable the whole dissociation path with no symptom.
            $imgs = Get-TikTokPhotoPost -Url "$($Url.TrimEnd('/'))/video/$Id" -ErrorAction Stop
            if ($imgs) { return $false }
        }
        return $true
    }
    function Save-PhotoPosts {
        param([string[]]$Ids)
        $saved = 0
        $notphoto = @()
        foreach ($pid2 in $Ids) {
            if (Test-ImagesDone -Id $pid2) { continue }
            $vidUrl = "$($Url.TrimEnd('/'))/video/$pid2"
            $imgs = Get-TikTokPhotoPost -Url $vidUrl
            if (-not $imgs -or $imgs.Count -eq 0) { $notphoto += $pid2; continue }
            $title = Get-TikTokPostDesc -Url $vidUrl
            if (-not $title) { $title = "TikTok photo post $pid2" }
            Write-Host "Photo post $pid2 - $title ($($imgs.Count) image(s))" -ForegroundColor Cyan
            if (Save-TikTokPhotoPost -Url $vidUrl -BaseName "$title [$pid2]") {
                $saved++
                if ($archivePath) { Add-Content -LiteralPath $archivePath -Value "tiktok $pid2" -Encoding utf8 }
            } else {
                $notphoto += $pid2
            }
            Start-Sleep -Milliseconds 400
        }
        if ($saved -gt 0) { Write-Host "`nyt: saved $saved photo post(s) as images." -ForegroundColor Green }
        if ($notphoto.Count -gt 0) { Write-Host "yt: $($notphoto.Count) item(s) were not photo posts: $($notphoto -join ', ')" -ForegroundColor DarkGray }
        $script:photoStillFailed = $notphoto
        return $saved
    }
    if ($N -gt 0) {
        Write-Host "`nScanning $siteName (first $N items)..." -ForegroundColor DarkGray
        $scanArgs = @("--flat-playlist", "--no-warnings", "--print", "%(playlist_index)s|||%(id)s|||%(title)s", "-I", ":$N")
        $scanCookie = Get-UsedCookie
        if ($scanCookie) { $scanArgs += @("--cookies", $scanCookie) }
        $entries = & $ytdlp @scanArgs $Url
        $missing = @()
        $found = @()
        foreach ($entry in $entries) {
            $parts = $entry -split '\|\|\|', 3
            if ($parts.Count -lt 3) { continue }
            $idx = $parts[0].Trim()
            $vidId = $parts[1].Trim()
            $title = $parts[2].Trim()
            if (Test-Complete -Id $vidId) {
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
            Write-Host "`nAll $N items already in this folder." -ForegroundColor Yellow
            $nextStart = $N + 1
            $nextEnd = $N * 2
            $resp = Read-Host "Download next $N after item $N? (y/N)"
            if ($resp -ne 'y') { return }
            $argsList += @("-I", "${nextStart}:${nextEnd}")
        } else {
            Write-Host "`nMissing ($totalMissing):" -ForegroundColor Cyan
            foreach ($m in $missing) { Write-Host "  [$($m.Index)] $($m.Title)" -ForegroundColor White }
            $resp = Read-Host "`nDownload these $totalMissing items? (Y/n)"
            if ($resp -eq 'n') { $global:LASTEXITCODE = 0; return }
            $indices = ($missing | ForEach-Object { $_.Index }) -join ','
            $argsList += @("-I", $indices)
        }
    } elseif ($isProfile) {
        Write-Host "`nNo -N given - diffing the whole $siteName profile against this folder..." -ForegroundColor DarkGray
        $scanArgs = @("--flat-playlist", "--no-warnings", "--print", "%(playlist_index)s|||%(id)s|||%(title)s")
        $scanCookie = Get-UsedCookie
        if ($scanCookie) { $scanArgs += @("--cookies", $scanCookie) }
        $entries = & $ytdlp @scanArgs $Url
        $missing = @()
        $found = @()
        foreach ($entry in $entries) {
            $parts = $entry -split '\|\|\|', 3
            if ($parts.Count -lt 3) { continue }
            $idx = $parts[0].Trim()
            $vidId = $parts[1].Trim()
            $title = $parts[2].Trim()
            if (Test-Complete -Id $vidId) {
                $found += [PSCustomObject]@{ Index = $idx; Title = $title; Id = $vidId }
            } else {
                $missing += [PSCustomObject]@{ Index = $idx; Title = $title; Id = $vidId }
            }
        }
        Write-Host ""
        if ($found.Count -gt 0) {
            Write-Host "Already present ($($found.Count) of $($found.Count + $missing.Count)):" -ForegroundColor Green
            foreach ($f in $found) { Write-Host "  [$($f.Index)] $($f.Title)" -ForegroundColor DarkGray }
        }
        if ($missing.Count -eq 0) {
            Write-Host "`nNothing left to download from $siteName." -ForegroundColor Yellow
            $global:LASTEXITCODE = 0
            return
        }
        Write-Host "`nMissing ($($missing.Count)):" -ForegroundColor Cyan
        foreach ($m in $missing) { Write-Host "  [$($m.Index)] $($m.Title)" -ForegroundColor White }
        $resp = Read-Host "`nDownload these $($missing.Count) items? (Y/n)"
        if ($resp -eq 'n') { $global:LASTEXITCODE = 0; return }
        $indices = ($missing | ForEach-Object { $_.Index }) -join ','
        $argsList += @("-I", $indices)
    }
    if ($Photos) {
        if ($hostName -notmatch 'tiktok\.com') {
            Write-Warning "yt: -Photos only applies to TikTok photo posts."
        } else {
            $probeUrl = $Url
            if ($Url -match '/video/(\d+)') {
                $probeUrl = $Url -replace '/video/\d+.*$', "/video/$($Matches[1])"
            }
            Write-Host "`nPhoto-post mode: pulling any photo/slideshow items yt-dlp would fail on..." -ForegroundColor Cyan
            $probeArgs = @("--flat-playlist", "--no-warnings", "--print", "%(id)s")
            if ($N -gt 0) { $probeArgs += @("-I", ":$N") }
            $probeCookie = Get-UsedCookie
            if ($probeCookie) { $probeArgs += @("--cookies", $probeCookie) }
            $allIds = @(& $ytdlp @probeArgs $probeUrl 2>$null)
            $photoCount = 0
            foreach ($pid2 in $allIds) {
                $id2 = $pid2.Trim()
                if (-not $id2) { continue }
                if (Test-Downloaded -Id $id2) { continue }
                $vidUrl = if ($Url -match '/video/(\d+)') { $Url } else { "$($Url.TrimEnd('/'))/video/$id2" }
                $imgs = Get-TikTokPhotoPost -Url $vidUrl
                if (-not $imgs -or $imgs.Count -eq 0) { continue }
                $title = Get-TikTokPostDesc -Url $vidUrl
                if (-not $title) { $title = "TikTok photo post $id2" }
                Write-Host "Photo post $id2 - $title ($($imgs.Count) image(s))" -ForegroundColor Cyan
                if (Save-TikTokPhotoPost -Url $vidUrl -BaseName "$title [$id2]") {
                    $photoCount++
                    if ($archivePath) { Add-Content -LiteralPath $archivePath -Value "tiktok $id2" -Encoding utf8 }
                }
                Start-Sleep -Milliseconds 400
            }
            if ($photoCount -gt 0) { Write-Host "`nyt: saved $photoCount photo post(s)." -ForegroundColor Green }
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
    if ($archivePath) {
        Write-Host "yt: archive $(Split-Path $archivePath -Leaf)" -ForegroundColor DarkCyan
    }
    function Invoke-Dl {
        $script:usedCookie = Get-UsedCookie
        $dlArgs = @($argsList)
        if ($script:usedCookie) {
            $dlArgs += @("--cookies", $script:usedCookie)
            Write-Host "yt: using cookies from $(Split-Path $script:usedCookie -Leaf)" -ForegroundColor DarkCyan
        } else {
            $hint = if ($hostName -match 'tiktok|instagram|facebook') {
                "log in on $siteName and export cookies, or expect 403"
            } else {
                "export cookies, or expect 403"
            }
            Write-Host "yt: no cookies found for $siteName - unauthenticated; $hint" -ForegroundColor Yellow
        }
        # stderr goes to a temp file so we can parse which IDs failed (photo posts) while
        # stdout (progress) still streams live to the console. Errors are replayed after.
        $errFile = Join-Path $env:TEMP ("yt_err_{0}.txt" -f ([guid]::NewGuid().ToString('N')))
        & $ytdlp @dlArgs 2> $errFile
        $script:ytErrFile = $errFile
        $script:ytErrLines = @()
        if (Test-Path -LiteralPath $errFile) {
            $script:ytErrLines = @([System.IO.File]::ReadAllLines($errFile))
            Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
        }
        return
    }
    function Write-ErrLines {
        if (-not $script:ytErrLines) { return }
        foreach ($l in $script:ytErrLines) {
            if ($l -match '\S') { Write-Host $l -ForegroundColor Red }
        }
    }
    function Get-FailedIds {
        # ids from "ERROR: [TikTok] <id>: ..." lines, so we can try the photo fallback
        $ids = @()
        if (-not $script:ytErrLines) { return $ids }
        foreach ($line in $script:ytErrLines) {
            $m = [regex]::Match($line, '^\[?\w*\]?\s*ERROR:\s*\[[^\]]+\]\s*(\d{6,})\s*:')
            if ($m.Success) { $ids += $m.Groups[1].Value }
        }
        return $ids
    }
    Invoke-Dl
    $dlExit = $LASTEXITCODE
    # Dissociate image+audio posts: the mp3 carries the picture only as embedded
    # cover art, so save the full-res original beside it. Probed per id, and only
    # for posts whose image is still missing.
    if ($trackImages -and $isTiktok) {
        $imgIds = @()
        if ($Url -match '/video/(\d+)') { $imgIds += $Matches[1] }
        foreach ($m in $missing) { $imgIds += $m.Id }
        if ($imgIds.Count -gt 0) {
            $n = Save-PhotoPosts -Ids ($imgIds | Select-Object -Unique)
            if ($n -gt 0) {
                Write-Host "yt: saved $n full-res image(s) alongside the audio." -ForegroundColor Green
            }
        }
    }
    $failedIds = @(Get-FailedIds)
    $script:photoStillFailed = @()
    if ($failedIds.Count -gt 0 -and $hostName -match 'tiktok\.com') {
        Write-Host "`n$($failedIds.Count) item(s) yt-dlp could not fetch; trying photo mode (yt-dlp has no slideshow support)..." -ForegroundColor Cyan
        $n = Save-PhotoPosts -Ids $failedIds
        if ($n -gt 0 -and $script:photoStillFailed.Count -eq 0) {
            # Every failure was a photo post that we saved as images - that is a success.
            $dlExit = 0
            $script:ytErrLines = @()
        } elseif ($n -gt 0) {
            # Drop the "No video formats found" noise for the ones we did save.
            $stillBad = $script:photoStillFailed -join '|'
            $script:ytErrLines = @($script:ytErrLines | Where-Object { $_ -notmatch $stillBad })
        }
    }
    if ($useIgnore) {
        # --ignore-errors means the run continued past failures, so a non-zero exit is
        # "some items failed", not "cookies are stale". Do not prompt to refresh cookies.
        Write-ErrLines
        if ($dlExit -ne 0) {
            Write-Host "`nSome items failed (yt-dlp exit $dlExit) - the rest downloaded fine." -ForegroundColor Yellow
            if ($archivePath) {
                Write-Host "  rerun yt to retry only the failures; $(Split-Path $archivePath -Leaf) records what succeeded." -ForegroundColor DarkGray
            }
        }
    } elseif ($dlExit -ne 0) {
        Write-ErrLines
        Write-Host "`nDownload failed - $siteName refused it (rate limit, geo-block, or expired cookies)." -ForegroundColor Yellow
        $r = Read-Host "Open $siteName to refresh cookies, then rerun yt? (Y/n)"
        if ($r -eq 'n') { return }
        Start-Process $Url
        # No auto-retry: --cookies is read once at startup, so retrying in-session
        # re-runs against the same stale jar. Rerunning yt re-reads the jar.
        Write-Host "yt: opened $siteName. Refresh cookies, then rerun yt for this URL." -ForegroundColor DarkGray
        $global:LASTEXITCODE = $dlExit
        return
    }
    if ($script:usedCookie -and -not $script:usedCookie.StartsWith($cookieStore, [System.StringComparison]::OrdinalIgnoreCase)) {
        $storeHost = $hostName
        if (-not $storeHost) { $storeHost = ($script:usedCookie | Split-Path -Leaf) -replace '_cookies\.txt$', '' }
        New-Item -ItemType Directory -Path $cookieStore -Force | Out-Null
        Copy-Item -LiteralPath $script:usedCookie -Destination (Join-Path $cookieStore "${storeHost}_cookies.txt") -Force
        Write-Host "yt: stored cookies for $storeHost" -ForegroundColor DarkCyan
    }
    # Surface the real result to the caller instead of yt-dlp's raw exit code.
    $global:LASTEXITCODE = $dlExit
    return
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

function global:ConvertTo-GitWebUrl {
    param(
        [Parameter(Position = 0)]
        [string]$Remote,
        [Parameter(Position = 1)]
        [string]$Branch
    )
    $u = $Remote.Trim()
    if (-not $u) { return $null }
    if ($u -match '^[A-Za-z]:[\\/]' -or $u.StartsWith('/') -or $u.StartsWith('~') -or $u.StartsWith('..')) { return $null }
    $base = $null
    if ($u -match '^(?i:https?)://(?:[^@/]+@)?(?<gh>[^/:]+)(?::(?<gp>\d+))?/(?<gpath>.+)$') {
        $port = if ($Matches['gp']) { ":$($Matches['gp'])" } else { '' }
        $base = "https://$($Matches['gh'])$port/$($Matches['gpath'])"
    } elseif ($u -match '^(?i:ssh|git)://(?:[^@/]+@)?(?<gh>[^/:]+)(?::\d+)?/(?<gpath>.+)$') {
        $base = "https://$($Matches['gh'])/$($Matches['gpath'])"
    } elseif ($u -match '^[\w.+-]+@(?<gh>[^:/]+):(?<gpath>.+)$') {
        $base = "https://$($Matches['gh'])/$($Matches['gpath'])"
    } else {
        return $null
    }
    $base = ($base -replace '/+$', '') -replace '(?i)\.git$', ''
    if ($base -notmatch '^https://[^/]+/.+') { return $null }
    if (-not $Branch -or $Branch -eq 'HEAD') { return $base }
    $seg = (($Branch -split '/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $hostName = ([uri]$base).Host
    if ($hostName -eq 'bitbucket.org') { return "$base/src/$seg" }
    if ($hostName -eq 'dev.azure.com' -or $hostName -match 'visualstudio\.com$') { return "$base`?version=GB$([uri]::EscapeDataString($Branch))" }
    if ($hostName -in @('projects.blender.org', 'codeberg.org', 'gitea.com') -or $hostName -match '^(gitea|git|forgejo)\.') { return "$base/src/branch/$seg" }
    if ($hostName -match 'gitlab') { return "$base/-/tree/$seg" }
    return "$base/tree/$seg"
}

function global:Get-GitBranchRef {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$Remote,
        [switch]$Verify
    )
    function Get-RemoteDefault {
        $d = "$(& git -C $Root symbolic-ref --short "refs/remotes/$Remote/HEAD" 2>$null | Select-Object -First 1)".Trim()
        if ($d) { return ($d -replace '^[^/]+/', '' -replace '^\*', '') }
        if ($Verify) {
            $sym = @(& git -C $Root ls-remote --symref $Remote HEAD 2>$null)
            if ($LASTEXITCODE -eq 0) {
                foreach ($l in $sym) {
                    if ("$l" -match '^ref:\s+refs/heads/(?<db>\S+)\s+HEAD') { return $Matches['db'] }
                }
            }
        }
        return ''
    }

    $default = Get-RemoteDefault

    $local = "$(& git -C $Root rev-parse --abbrev-ref HEAD 2>$null | Select-Object -First 1)".Trim()
    $detached = ($local -eq 'HEAD' -or -not $local)
    $upstream = "$(& git -C $Root rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null | Select-Object -First 1)".Trim()

    function Test-RemoteBranch {
        param([string]$Name)
        if (-not $Name) { return $false }
        if ($Verify) {
            $heads = @(& git -C $Root ls-remote --heads $Remote $Name 2>$null)
            if ($LASTEXITCODE -eq 0) { return ($heads.Count -gt 0) }
            return $null
        }
        & git -C $Root rev-parse --verify --quiet "refs/remotes/$Remote/$Name" 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    }

    $branch = ''
    $source = 'home'
    $caveat = ''
    if ($detached) {
        $branch = $default
        $source = 'default'
        if ($branch) { $caveat = "detached HEAD; showing $Remote's default branch ($branch)" }
        else { $caveat = "detached HEAD and $Remote's default branch is unknown; showing the repo home" }
    } elseif ($upstream -and $upstream -match '^(?<ur>[^/]+)/(?<ub>.+)$' -and $Matches['ur'] -ceq $Remote) {
        $branch = $Matches['ub']
        $source = 'upstream'
        if ($branch -cne $local) { $caveat = "local '$local' tracks $Remote/$branch" }
    } else {
        $has = Test-RemoteBranch $local
        if ($has -eq $null) {
            $branch = $local
            $source = 'unverified'
            $caveat = "could not verify '$Remote' over the network; using '$local' as resolved locally"
        } elseif ($has) {
            $branch = $local
            $source = 'tracking'
        } else {
            $caveat = "branch '$local' is not on $Remote"
            $branch = $default
            $source = 'default'
            if ($branch) { $caveat = "$caveat; using its default ($branch)" }
            else { $caveat = "$caveat and its default branch is unknown; showing the repo home" }
        }
    }

    if ($Verify -and $branch) {
        $heads = @(& git -C $Root ls-remote --heads $Remote $branch 2>$null)
        if ($LASTEXITCODE -eq 0 -and $heads.Count -eq 0) {
            $gone = $branch
            $branch = $default
            $source = 'default'
            if ($branch) { $caveat = "verified: '$gone' no longer exists on $Remote; using its default ($branch)" }
            else { $caveat = "verified: '$gone' no longer exists on $Remote and its default branch is unknown; showing the repo home" }
        }
    }
    if (-not $branch) { $caveat = "$caveat".Trim(';', ' ') }
    [pscustomobject]@{ Branch = $branch; Source = $source; Detached = $detached; Local = $local; Upstream = $upstream; Caveat = $caveat }
}

function global:Get-GitRepoWebUrl {
    param([switch]$Verify)
    $root = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        Write-Error "goto: not a git repository: $PWD"
        return $null
    }
    $root = "$($root | Select-Object -First 1)".Trim()
    if ($IsWindows -or $env:OS -eq 'Windows_NT') { $root = $root -replace '/', '\' }

    $remotes = [ordered]@{}
    foreach ($line in @(& git -C $root remote -v 2>$null)) {
        if ("$line" -match '^(?<rn>\S+)\s+(?<ru>\S+)\s+\((?<rd>fetch|push)\)$' -and -not $remotes.Contains($Matches['rn'])) {
            $remotes[$Matches['rn']] = $Matches['ru']
        }
    }
    if ($remotes.Count -eq 0) {
        Write-Error "goto: no remotes configured for $root."
        return $null
    }
    $names = @($remotes.Keys)
    if ($names.Count -gt 1) {
        Write-Host "remotes for $root" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $names.Count; $i++) {
            Write-Host ("  {0}) {1,-10} {2}" -f ($i + 1), $names[$i], $remotes[$names[$i]]) -ForegroundColor DarkGray
        }
        $pick = $null
        while (-not $pick) {
            $ans = "$((Read-Host "open which remote? (1-$($names.Count), blank cancels)"))".Trim()
            if (-not $ans -or $ans -in @('q', 'Q')) { return $null }
            if ($ans -match '^\d+$' -and [int]$ans -ge 1 -and [int]$ans -le $names.Count) {
                $pick = $names[[int]$ans - 1]
            } elseif ($names -ccontains $ans) {
                $pick = $ans
            } else {
                Write-Host "not one of: $($names -join ', ')" -ForegroundColor Yellow
            }
        }
        $chosen = $pick
    } else {
        $chosen = $names[0]
    }
    $bref = Get-GitBranchRef -Root $root -Remote $chosen -Verify:$Verify
    $url = ConvertTo-GitWebUrl $remotes[$chosen] $bref.Branch
    if (-not $url) {
        Write-Error "goto: cannot open remote '$($remotes[$chosen])' in a browser (local path or unknown host)."
        return $null
    }
    [pscustomobject]@{ Url = $url; Remote = $chosen; Branch = $bref.Branch; BranchSource = $bref.Source; Caveat = $bref.Caveat; Root = $root }
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
goto [<url-or-search>] [-a <NAME> | --add-alias <NAME>]
                       [-d <NAME> | --del-alias <NAME>] [-ls | --list-alias]
                       [-G | --github]

  goto                     open the URL/text in the clipboard
  goto google.com          open a URL in the browser
  goto localhost:3000      open a local host/port
  goto how to make omelete
                           Google-search the text (quotes optional)
  goto onth0s.github.io/markdown-viewer -a MD
                           open it and save the target as alias 'MD'
  goto -a MD               same, with the clipboard as the target
  goto MD                  open a previously saved alias
  goto -G                  open the git repo for the current directory
                           in the browser, at the current branch

Options:
  -h, --help               show this help
  -G, --github             open the current git repo in the browser
                           (prompts if the repo has more than one remote)
  --verify, -verify       with -G, confirm the branch against the remote
                           over the network instead of using local refs
  -a, --add-alias <NAME>   save an alias for the target (or the clipboard
                           when no target is given)
  -d, --del-alias <NAME>   delete a saved alias
  -ls, --list-alias        list saved aliases
'@
    $aName = $null
    $dName = $null
    $list = $false
    $gh = $false
    $verify = $false
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
        } elseif ($tok -in @('-G', '--github')) {
            if ($dName -or $list) { Write-Error "goto: cannot combine --github with --del-alias/--list-alias."; return }
            $gh = $true
            $i++
            continue
        } elseif ($tok -in @('--verify', '-verify')) {
            $verify = $true
            $i++
            continue
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
        if ($gh) { Write-Error "goto: cannot combine --del-alias with --github."; return }
        if ($tokens.Count -eq 0) { Write-Error "goto: --del-alias requires a name."; return }
        $dName = $tokens[0]
        $tokens = @($tokens | Select-Object -Skip 1)
    }
    $q = ($tokens | Where-Object { $_ }) -join ' '
    if ($q -in @('-h', '--help')) { Write-Host $help -ForegroundColor DarkGray; return }
    if ($list -and $q) { Write-Error "goto: --list-alias takes no target."; return }
    if ($dName -and $q) { Write-Error "goto: --del-alias does not take a target."; return }
    if ($gh -and ($dName -or $list)) { Write-Error "goto: cannot combine --github with --del-alias/--list-alias."; return }
    if ($gh -and $q) { Write-Error "goto: --github does not take a target."; return }
    if ($verify -and -not $gh) { Write-Error "goto: --verify only applies to --github."; return }

    $src = 'args'
    if (-not $q -and -not $list -and -not $gh) {
        $clip = Get-Clipboard -Raw
        if ($clip) { $clip = ($clip -replace '\s+', ' ').Trim() }
        if (-not $clip) { Write-Error "goto: clipboard is empty."; return }
        $q = $clip
        $src = 'clipboard'
    }
    foreach ($n in @($aName, $dName)) {
        if ($n -and $n -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') {
            Write-Error "goto: invalid alias name '$n' (use letters, digits, - and _)."
            return
        }
    }

    $storePath = Join-Path $HOME '.config' 'goto-aliases.json'
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

    $viaAlias = $false
    $isSearch = $false
    $url = $null
    $repo = $null
    if ($gh) {
        $repo = Get-GitRepoWebUrl -Verify:$verify
        if (-not $repo) { return }
        $url = $repo.Url
        $src = 'git'
    } else {
        if (-not $aName -and $src -eq 'args' -and $q -notmatch '\s') {
            $hit = Find-GotoAlias $aliases $q
            if ($hit) {
                $url = $hit.Value
                $viaAlias = $true
            }
        }
        if (-not $viaAlias) {
            $url = Resolve-GotoUrl $q
            if (-not $url) {
                $isSearch = $true
                $url = "https://www.google.com/search?q=$([uri]::EscapeDataString($q))"
            }
        }
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
        Write-Host "alias saved: $aName" -ForegroundColor Cyan -NoNewline
        Write-Host " -> $url" -ForegroundColor Green
    }

    if ($src -eq 'git') {
        Write-Host "opening repo " -ForegroundColor Cyan -NoNewline
        Write-Host $repo.Remote -ForegroundColor DarkGray -NoNewline
        if ($repo.Branch) {
            Write-Host " ($($repo.Branch))" -ForegroundColor DarkGray -NoNewline
        }
        Write-Host " -> $url" -ForegroundColor Green
        if ($repo.Caveat) {
            Write-Host "  $($repo.Caveat)" -ForegroundColor DarkGray
        }
    } elseif ($viaAlias) {
        Write-Host "opening $q" -ForegroundColor Cyan -NoNewline
        Write-Host " -> $url" -ForegroundColor Green
    } elseif ($isSearch) {
        Write-Host "searching $q" -ForegroundColor Cyan -NoNewline
        Write-Host " -> $url" -ForegroundColor DarkGray
    } elseif ($src -eq 'clipboard') {
        Write-Host "opening (clipboard)" -ForegroundColor Cyan -NoNewline
        Write-Host " $url" -ForegroundColor Green
    } elseif ($url -ne $q) {
        Write-Host "opening $q" -ForegroundColor Cyan -NoNewline
        Write-Host " -> $url" -ForegroundColor Green
    } else {
        Write-Host "opening $url" -ForegroundColor Green
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

# Shadow the ollama.exe executable so serve/kill/restart are CWD-safe: they never
# inherit (or hold) the caller's working directory, so Ollama can't lock a stray
# folder. Every other subcommand passes through to the binary by absolute path.
function global:ollama {
    $exe = "C:\Users\Leonardo\AppData\Local\Programs\Ollama\ollama.exe"
    $cmd = if ($args.Count -gt 0) { [string]$args[0] } else { '' }
    switch ($cmd) {
        'serve' {
            $running = Get-Process -Name ollama -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }
            if ($running) {
                Write-Host "ollama already running" -ForegroundColor Yellow
            } else {
                Start-Process $exe -ArgumentList 'serve' -WorkingDirectory $HOME -WindowStyle Hidden
                Write-Host "ollama serve started from $HOME" -ForegroundColor Green
            }
            return
        }
        'status' {
            $p = Get-Process -Name ollama -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $p) {
                Write-Host "ollama not running" -ForegroundColor Yellow
                return
            }
            Write-Host "ollama running (pid $($p.Id))" -ForegroundColor Green
            try {
                $count = (Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 3).models.Count
                Write-Host "server responding: $count models" -ForegroundColor Cyan
            } catch {
                Write-Host "process up but server not responding" -ForegroundColor Yellow
            }
            return
        }
        'kill' {
            Stop-Process -Name ollama -Force -ErrorAction SilentlyContinue
            Write-Host "ollama killed" -ForegroundColor Green
            return
        }
        'restart' {
            Stop-Process -Name ollama -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            Start-Process $exe -ArgumentList 'serve' -WorkingDirectory $HOME -WindowStyle Hidden
            Write-Host "ollama restarted from $HOME" -ForegroundColor Green
            return
        }
    }
    & $exe @args
}
Set-Alias -Name c -Value cls -Option AllScope -Force
# GNU-style ls flags: -a -l -t -S -X -r -R (combined tokens like -ltr supported).
# Shadow the built-in 'ls' alias (Get-ChildItem); no flags = exact same behavior.
#
# Replace the default FileInfo/DirectoryInfo console table with one showing a
# human-readable Size column next to the raw byte Length column (MM/dd/yyyy
# HH:mm timestamps, zero-padded month/day/hour, no seconds). Formatting-only:
# the objects on the pipeline still carry raw byte Length, so piping is
# unaffected.
#
# Rendering: when ls output goes straight to the console it draws its own
# fixed-width text table (Format-LsLines) with exactly two spaces between every
# column; when piped or assigned it emits the raw decorated objects and the
# ps1xml view below is the fallback (and applies to Get-ChildItem/dir too).
# Reloads whenever the format file changes (so uprof picks up edits mid-session)
# and skips reloads otherwise, so repeated reloads don't stack duplicate views.
$fmtFile = Join-Path $PSScriptRoot 'FileSystemSize.format.ps1xml'
if (Test-Path -LiteralPath $fmtFile) {
    $fmtStamp = (Get-Item -LiteralPath $fmtFile).LastWriteTimeUtc.Ticks
    if ($global:__FileSystemSizeFormatStamp -ne $fmtStamp) {
        Update-FormatData -PrependPath $fmtFile
        $global:__FileSystemSizeFormatStamp = $fmtStamp
    }
}
if (Test-Path Alias:ls) { Remove-Item Alias:ls -Force }

<#
.SYNOPSIS
    GNU-style ls wrapper around Get-ChildItem.

.DESCRIPTION
    Shadows the built-in ls alias. With no flags it behaves exactly like plain
    Get-ChildItem, except filesystem items render with a human-readable Size
    column next to the raw byte Length column, and timestamps show as
    MM/dd/yyyy HH:mm (no seconds, everything zero-padded). Short
    flags from the set a l t S X r R combine into single
    tokens (-lat). Any sort groups directories first; -r reverses within each
    group. When several sort flags are given, precedence is -t, then -S, then
    -X.

    Recursive listings (-R) are grouped by directory: the format view renders
    one "Directory: <path>" section per folder, and sort flags (-l/-t/-S/-X/
    -r) apply within each directory instead of across the whole tree (GNU
    ls -R style), so identical filenames in different folders stay
    distinguishable.

    Tokens are classified as: (1) pure short-flag combos; (2) Get-ChildItem
    parameter names or unique prefixes (-fil -> -Filter), where value-taking
    parameters consume the next token; (3) everything else, treated as a
    literal path. Beware: -h is not help - it expands to -Hidden and lists
    hidden items only. Use -? or --help for the usage text.

    Every FileInfo/DirectoryInfo item gets a human-readable Size NoteProperty
    (e.g. "7.07 GB"); the raw byte Length is kept alongside it for sorting and
    piping, and is displayed as its own column. Directories have no Length and
    show blank Size/Length columns.

.EXAMPLE
    PS> ls -lat
    Long listing of all items (hidden included), newest first, dirs first.

.EXAMPLE
    PS> ls -fil *.txt
    Lists *.txt entries in the current directory via Get-ChildItem's -Filter.

.NOTES
    Part of the personal PowerShell profile. Extended documentation lives in
    this repo's README.md under "ls".
#>
function global:Format-FileSize {
    param([Nullable[int64]]$Bytes)
    if ($null -eq $Bytes) { return '' }
    if ($Bytes -lt 1024) { return "$Bytes B" }
    $units = 'B', 'KB', 'MB', 'GB', 'TB'
    $i = 0
    $v = [double]$Bytes
    while ($v -ge 1024 -and $i -lt $units.Count - 1) { $v /= 1024; $i++ }
    '{0:N2} {1}' -f $v, $units[$i]
}

# Renders filesystem items as a fixed-width text table with EXACTLY two spaces
# between every column — in the header AND in every data row. Every cell is
# padded to its column's exact width (Mode 5, LastWriteTime 16, Size 9,
# Length 10), so each column's text ends at the same x position; numeric
# columns (Size, Length) and all headers are right-aligned so the 2-space
# separator after them is constant. Size values float inside their column
# (right-aligned numbers), but column boundaries and gaps never move.
#
# Used by ls ONLY when the output goes straight to the console (no pipeline):
# piped/assigned output keeps emitting the raw decorated objects so filtering
# and sorting on the byte Length keep working.
function global:Format-LsLines {
    param([object[]]$Items)
    if ($Items -isnot [array]) { $Items = @($Items) }
    if ($Items.Count -eq 0) { return }
    $fs = @($Items | Where-Object { $_ -is [System.IO.FileInfo] -or $_ -is [System.IO.DirectoryInfo] })
    if ($fs.Count -eq 0) { $Items; return }   # not filesystem items (e.g. ls -name) -> pass through

    $headFmt = '{0,5}  {1,16}  {2,9}  {3,10}  {4}'
    $rowFmt  = '{0,-5}  {1,-16}  {2,9}  {3,10}  {4}'
    $headFmt -f 'Mode', 'LastWriteTime', 'Size', 'Length', 'Name'
    $headFmt -f ('-' * 4), ('-' * 13), ('-' * 4), ('-' * 6), ('-' * 4)
    foreach ($it in $Items) {
        $size = if ($it.PSIsContainer) { '<DIR>' } else { Format-FileSize $it.Length }
        $len  = if ($it.PSIsContainer) { '' } else { [string]$it.Length }
        $rowFmt -f $it.Mode, ('{0:MM/dd/yyyy HH:mm}' -f $it.LastWriteTime), $size, $len, $it.Name
    }
}

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
        if ($tok -in @('--help', '-?')) {
            Write-Host @'
Usage: ls [OPTIONS] [PATH...]

GNU-style flags (combinable, e.g. -lat):

  -a                 Show hidden items (Force)
  -l                 Long listing (Mode, LastWriteTime, Size, Length, Name)
  -t                 Sort by LastWriteTime
  -S                 Sort by file size
  -X                 Sort by extension
  -r                 Reverse sort order
  -R                 Recursive; prints a Directory: section per folder
                     (pass -Depth N separately for a limit)

  -?, --help         Show this help

Without flags, behaves identically to Get-ChildItem (but filesystem items
render with a human-readable Size column next to raw Length).
Get-ChildItem parameter names may be abbreviated to a unique prefix
(-fil -> -Filter, -rec -> -Recurse); value-taking ones consume the next token.
Note: -h expands to -Hidden (hidden items only) -- use -? or --help instead.
Anything unrecognized is treated as a path.
'@
            return
        }
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

    $items = Get-ChildItem @named | ForEach-Object {
        if ($_ -is [System.IO.FileInfo] -or $_ -is [System.IO.DirectoryInfo]) {
            # Directories report Length 1 via the filesystem provider; show blank.
            $size = if ($_.PSIsContainer) { '' } else { Format-FileSize $_.Length }
            $_ | Add-Member -NotePropertyName Size -NotePropertyValue $size -PassThru
        } else {
            $_
        }
    }
    $sorting = $sortTime -or $sortSize -or $sortExt -or $reverse
    $sortOrLong = $sorting -or $long
    $recurse = $named.ContainsKey('Recurse') -and -not $named.ContainsKey('Name')

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

    if ($recurse) {
        # Recursive (-R): keep each directory's items together (first-seen
        # order) so the format view renders one "Directory: <path>" section per
        # folder. Sorting (-l/-t/-S/-X/-r) applies WITHIN each directory, the
        # way GNU ls -R behaves, instead of across the whole flat stream.
        $byDir = [System.Collections.Generic.Dictionary[string, [System.Collections.Generic.List[object]]]]::new()
        $dirOrder = [System.Collections.Generic.List[string]]::new()
        foreach ($it in $items) {
            $key = [string]$it.PSParentPath
            if (-not $byDir.ContainsKey($key)) {
                $byDir[$key] = [System.Collections.Generic.List[object]]::new()
                $dirOrder.Add($key)
            }
            $byDir[$key].Add($it)
        }
        foreach ($key in $dirOrder) {
            $group = $byDir[$key]
            if ($sortOrLong) { $group | Sort-Object $spec } else { $group }
        }
        return
    }

    if (-not $sortOrLong) {
        $items
        return
    }
    $items | Sort-Object $spec
}
function global:tree { npx tree-node-cli -I 'node_modules|.next' @args 2>$null }
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
    # Commands that perform interactive rich prompts (Prompt.ask / Confirm.ask).
    # Capturing stdout via @() would buffer stdout on the pipe, causing invisible
    # prompts. Run live.
    $interactiveCmds = @('add')
    # -F may prompt to create a missing target directory, so it runs live as well.
    $force = $args -contains '-F'
    if ($force -or ($args.Count -gt 0 -and $interactiveCmds -contains $args[0])) {
        # A live process cannot hand its navigation target back over the captured
        # stdout the cd protocol depends on, so -F returns it through this file.
        $navOut = $null
        if ($force) {
            $navOut = Join-Path ([System.IO.Path]::GetTempPath()) ('wp_nav_' + [guid]::NewGuid().ToString('N') + '.txt')
            $env:WP_NAV_OUT = $navOut
        }
        try {
            & python "C:\Users\Leonardo\001\00__DEV\Waypoint\waypoint\__main__.py" @args
        } finally {
            Remove-Item Env:WP_FORCE_COLOR -ErrorAction SilentlyContinue
            Remove-Item Env:WP_NAV_OUT -ErrorAction SilentlyContinue
        }
        if ($navOut) {
            $target = $null
            try {
                if (Test-Path -LiteralPath $navOut) {
                    $target = (Get-Content -LiteralPath $navOut -Raw -Encoding UTF8).Trim()
                }
            } catch {
                $target = $null
            }
            Remove-Item -LiteralPath $navOut -Force -ErrorAction SilentlyContinue
            if ($target) { Set-WaypointLocation -Literal $target }
        }
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

function Write-Text {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string[]]$Value,

        [Parameter(Position = 1)]
        [string]$Path,

        [Alias('F')]
        [switch]$Force
    )

    begin {
        # Argument order is fixed: wt <content> <path>. The first positional
        # argument is always content, even when it looks like a path.
        $lines = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($null -ne $Value) {
            foreach ($line in $Value) {
                $lines.Add($line)
            }
        }
    }

    end {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw "A target path must be specified. Usage: wt <content> <path>"
        }

        $filePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

        if ([System.IO.File]::Exists($filePath) -and -not $Force) {
            if (-not $PSCmdlet.ShouldProcess($filePath, "Overwrite existing file")) {
                return
            }
        }

        $parentDir = [System.IO.Path]::GetDirectoryName($filePath)

        if ($parentDir -and -not [System.IO.Directory]::Exists($parentDir)) {
            [System.IO.Directory]::CreateDirectory($parentDir) | Out-Null
        }

        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

        [System.IO.File]::WriteAllLines(
            $filePath,
            $lines,
            $utf8NoBom
        )
    }
}
Set-Alias -Name wt -Value Write-Text

