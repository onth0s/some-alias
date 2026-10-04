param(
    [Alias('S', 'files')]
    [switch]$SortByFiles,
    [Alias('T', 'time')]
    [switch]$SortByTime,
    [Alias('X')]
    [switch]$Reverse
)

$roots = @(
    'C:\Users\Leonardo\001\00__DEV'
    'C:\Users\Leonardo\Documents\WindowsPowerShell'
    'C:\Program Files\Blender Foundation\Blender 5.2\5.2\scripts\startup'
    'C:\Users\Leonardo\001\TXT\Nothing, really'
    'C:\Users\Leonardo\001\TXT\GMRTI'
)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$results = foreach ($root in $roots) {
foreach ($g in Get-ChildItem -LiteralPath $root -Directory -Recurse -Force -Filter .git -Depth 3 -ErrorAction SilentlyContinue) {
    if ($g.FullName -match '\\(node_modules|\.git)\\') { continue }
    $repo = $g.Parent.FullName

    $ignored = $false
    $parent = Split-Path $repo -Parent
    while ($parent -and $parent.StartsWith($root) -and -not $ignored) {
        if (Test-Path -LiteralPath (Join-Path $parent '.git')) {
            $rel = $repo.Substring($parent.Length).TrimStart('\').Replace('\', '/')
            git -C $parent check-ignore --no-index --quiet $rel 2>$null
            if ($LASTEXITCODE -eq 0) { $ignored = $true }
            break
        }
        $parent = Split-Path $parent -Parent
    }
    if ($ignored) { continue }

    $porcelain = git -C $repo status --porcelain 2>$null
    $dirty = @($porcelain).Count -gt 0
    $filesCount = @(git -C $repo ls-files 2>$null).Count
    $lastUpdatedRaw = git -C $repo log -1 --format=%ct 2>$null | Select-Object -First 1
    $lastUpdated = 0
    $lastUpdatedHuman = ''
    if ($lastUpdatedRaw -and [long]::TryParse($lastUpdatedRaw.Trim(), [ref]$lastUpdated)) {
        try {
            $lastUpdatedHuman = [DateTimeOffset]::FromUnixTimeSeconds($lastUpdated).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
        } catch {
            $lastUpdatedHuman = ''
        }
    }
    [PSCustomObject]@{
        RootIdx         = [array]::IndexOf($roots, $root)
        Repo            = if ($repo -eq $root) { Split-Path $repo -Leaf } else { $repo.Substring($root.Length).TrimStart('\') }
        Dirty           = $dirty
        Files           = $filesCount
        LastUpdated     = $lastUpdated
        LastUpdatedHuman = $lastUpdatedHuman
    }
}
}
$sw.Stop()

# Apply sorting
$display = $results
if ($SortByFiles -and -not $SortByTime) {
    if ($Reverse) {
        $display = $results | Sort-Object Files -Descending
    } else {
        $display = $results | Sort-Object Files
    }
} elseif ($SortByTime -and -not $SortByFiles) {
    if ($Reverse) {
        $display = $results | Sort-Object LastUpdated
    } else {
        $display = $results | Sort-Object LastUpdated -Descending
    }
} elseif ($SortByFiles -and $SortByTime) {
    # If both specified, prefer sorting by files
    if ($Reverse) {
        $display = $results | Sort-Object Files -Descending
    } else {
        $display = $results | Sort-Object Files
    }
}

$count = @($display).Count
$dirtyCount = @($display | Where-Object Dirty).Count
"{0} repos ({1} dirty, {2} clean) - {3:0.0}s" -f $count, $dirtyCount, ($count - $dirtyCount), $sw.Elapsed.TotalSeconds
$maxRepoLen = [Math]::Max(4, (($display | ForEach-Object { $_.Repo.Length } | Measure-Object -Maximum).Maximum))
$first = $true
for ($i = 0; $i -lt $roots.Count; $i++) {
    $group = @($display | Where-Object RootIdx -eq $i)
    if ($group.Count -eq 0) { continue }
    if (-not $first) { '─' * 60 }
    $first = $false
    '{0} ({1})' -f (Split-Path $roots[$i] -Leaf), $group.Count
    $timeWidth = [Math]::Max(4, (($group | ForEach-Object { $_.LastUpdatedHuman.Length } | Measure-Object -Maximum).Maximum))
    $group | ForEach-Object {
        [PSCustomObject]@{
            Repo   = $_.Repo
            Status = if ($_.Dirty) { "$($PSStyle.Foreground.Red)DIRTY$($PSStyle.Reset)" } else { "$($PSStyle.Foreground.Green)CLEAN$($PSStyle.Reset)" }
            Time   = $_.LastUpdatedHuman
            Files  = $_.Files
        }
    } | Format-Table @{ Label = 'Repo'; Expression = 'Repo'; Width = $maxRepoLen },
                     @{ Label = 'Status'; Expression = 'Status'; Width = 7 },
                     @{ Label = 'Time'; Expression = 'Time'; Width = $timeWidth },
                     @{ Label = ''; Expression = { ' ' } },
                     @{ Label = 'Files'; Expression = 'Files'; Alignment = 'Right' }
}
if ($dirtyCount -eq 0) { "$($PSStyle.Foreground.Cyan)`nAll gucci$($PSStyle.Reset)" }
