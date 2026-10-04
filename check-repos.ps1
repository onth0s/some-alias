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
    $deltaHuman = ''
    $now = [DateTimeOffset]::Now
    if ($lastUpdatedRaw -and [long]::TryParse($lastUpdatedRaw.Trim(), [ref]$lastUpdated)) {
        try {
            $lastUpdatedDto = [DateTimeOffset]::FromUnixTimeSeconds($lastUpdated).ToLocalTime()
            $lastUpdatedHuman = $lastUpdatedDto.ToString('yyyy-MM-dd HH:mm')
            $delta = $now - $lastUpdatedDto
            $totalMinutes = [Math]::Floor($delta.TotalMinutes)
            $years = [Math]::Floor($totalMinutes / (525600))
            $rem = $totalMinutes % (525600)
            $months = [Math]::Floor($rem / (43800))
            $rem2 = $rem % (43800)
            $days = [Math]::Floor($rem2 / (1440))
            $rem3 = $rem2 % (1440)
            $hours = [Math]::Floor($rem3 / 60)
            $mins = $rem3 % 60
            $parts = @()
            if ($years -gt 0) { $parts += "$years" + ($years -eq 1 ? 'y' : 'y') }
            if ($months -gt 0 -or $years -gt 0) { if ($months -gt 0) { $parts += "$months" + ($months -eq 1 ? 'm' : 'm') } }
            if ($days -gt 0 -or $months -gt 0 -or $years -gt 0) { if ($days -gt 0) { $parts += "$days" + ($days -eq 1 ? 'd' : 'd') } }
            if ($hours -gt 0 -or $parts.Count -gt 0) { if ($hours -gt 0) { $parts += "$hours" + ($hours -eq 1 ? 'h' : 'h') } }
            $parts += "$mins" + ($mins -eq 1 ? 'm' : 'm')
            if ($parts.Count -gt 3) { $parts = $parts[0..2] }
            $deltaHuman = ($parts -join ' ')
        } catch {
            $lastUpdatedHuman = ''
            $deltaHuman = ''
        }
    }
    [PSCustomObject]@{
        RootIdx         = [array]::IndexOf($roots, $root)
        Repo            = if ($repo -eq $root) { Split-Path $repo -Leaf } else { $repo.Substring($root.Length).TrimStart('\') }
        Dirty           = $dirty
        Files           = $filesCount
        LastUpdated     = $lastUpdated
        LastUpdatedHuman = $lastUpdatedHuman
        DeltaHuman      = $deltaHuman
    }
}
}
$sw.Stop()

# Apply sorting
$display = $results
if ($SortByFiles -and -not $SortByTime) {
    if ($Reverse) {
        $display = $results | Sort-Object Files
    } else {
        $display = $results | Sort-Object Files -Descending
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
        $display = $results | Sort-Object Files
    } else {
        $display = $results | Sort-Object Files -Descending
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
    $deltaWidth = [Math]::Max(5, (($group | ForEach-Object { $_.DeltaHuman.Length } | Measure-Object -Maximum).Maximum))
    $group | ForEach-Object {
        [PSCustomObject]@{
            Repo   = $_.Repo
            Status = if ($_.Dirty) { "$($PSStyle.Foreground.Red)DIRTY$($PSStyle.Reset)" } else { "$($PSStyle.Foreground.Green)CLEAN$($PSStyle.Reset)" }
            Time   = $_.LastUpdatedHuman
            Delta  = $_.DeltaHuman
            Files  = $_.Files
        }
    } | Format-Table @{ Label = 'Repo'; Expression = 'Repo'; Width = $maxRepoLen },
                     @{ Label = 'Status'; Expression = 'Status'; Width = 7 },
                     @{ Label = 'Time'; Expression = 'Time'; Width = 16 },
                     @{ Label = 'Delta'; Expression = 'Delta'; Width = $deltaWidth; Alignment = 'Left' },
                     @{ Label = ' '; Expression = { ' ' }; Width = 1 },
                     @{ Label = 'Files'; Expression = 'Files'; Alignment = 'Right' }
}
if ($dirtyCount -eq 0) { "$($PSStyle.Foreground.Cyan)`nAll gucci$($PSStyle.Reset)" }
