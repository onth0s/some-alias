param(
    [Alias('S', 'files')]
    [switch]$SortByFiles,
    [Alias('T', 'time')]
    [switch]$SortByTime,
    [Alias('X')]
    [switch]$Reverse,
    [Alias('J', 'jobs')]
    [int]$ThrottleLimit = 16,
    [switch]$Serial
)

# PowerShell does not split combined short switches (e.g. -tx into -t -x), so
# normalize clustered S/T/X flags that landed in $args before defining roots.
foreach ($token in @($args)) {
    if ($token -is [string] -and $token -match '^-[stxSTX]{2,}$') {
        foreach ($ch in $token.Substring(1).ToCharArray()) {
            switch ($ch.ToString().ToUpperInvariant()) {
                'S' { $SortByFiles = $true }
                'T' { $SortByTime = $true }
                'X' { $Reverse = $true }
            }
        }
    }
}

$roots = @(
    'C:\Users\Leonardo\001\00__DEV'
    'C:\Users\Leonardo\Documents\WindowsPowerShell'
    'C:\Program Files\Blender Foundation\Blender 5.2\5.2\scripts\startup'
    'C:\Users\Leonardo\001\TXT\Nothing, really'
    'C:\Users\Leonardo\001\TXT\GMRTI'
    'C:\Users\Leonardo\001\GEN\'
)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$red = if ($PSStyle) { $PSStyle.Foreground.Red } else { "$([char]27)[91m" }
$green = if ($PSStyle) { $PSStyle.Foreground.Green } else { "$([char]27)[92m" }
$cyan = if ($PSStyle) { $PSStyle.Foreground.Cyan } else { "$([char]27)[96m" }
$reset = if ($PSStyle) { $PSStyle.Reset } else { "$([char]27)[0m" }
$div = [string][char]0x2500 * 60
if ($ThrottleLimit -lt 1) { $ThrottleLimit = 1 }
if ($ThrottleLimit -gt 64) { $ThrottleLimit = 64 }
$now = [DateTimeOffset]::Now

# Phase 1: discovery (serial, cheap). Phase 2 below parallelizes the git calls.
$repoList = foreach ($root in $roots) {
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

    [PSCustomObject]@{
        RootIdx  = [array]::IndexOf($roots, $root)
        FullPath = $repo
        Root     = $root
    }
}
}

$task = {
    param($FullPath, $RootIdx, $Root, $Now)
    $porcelain = git -C $FullPath status --porcelain 2>$null
    $dirty = @($porcelain).Count -gt 0
    $filesCount = @(git -C $FullPath ls-files 2>$null).Count
    $lastUpdatedRaw = git -C $FullPath log -1 --format=%ct 2>$null | Select-Object -First 1
    $lastUpdated = 0
    $lastUpdatedHuman = ''
    $deltaHuman = ''
    if ($lastUpdatedRaw -and [long]::TryParse($lastUpdatedRaw.Trim(), [ref]$lastUpdated)) {
        try {
            $lastUpdatedDto = [DateTimeOffset]::FromUnixTimeSeconds($lastUpdated).ToLocalTime()
            $lastUpdatedHuman = $lastUpdatedDto.ToString('yyyy-MM-dd HH:mm')
            $delta = $Now - $lastUpdatedDto
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
            if ($years -gt 0) { $parts += "${years}y" }
            if ($months -gt 0) { $parts += "${months}mo" }
            if ($days -gt 0) { $parts += "${days}d" }
            if ($hours -gt 0) { $parts += "${hours}h" }
            if ($mins -gt 0 -or $parts.Count -eq 0) { $parts += "${mins}m" }
            if ($parts.Count -gt 3) { $parts = $parts[0..2] }
            $deltaHuman = ($parts -join ' ')
        } catch {
            $lastUpdatedHuman = ''
            $deltaHuman = ''
        }
    }
    [PSCustomObject]@{
        RootIdx         = $RootIdx
        Repo            = if ($FullPath -eq $Root) { Split-Path $FullPath -Leaf } else { $FullPath.Substring($Root.Length).TrimStart('\') }
        Dirty           = $dirty
        Files           = $filesCount
        LastUpdated     = $lastUpdated
        LastUpdatedHuman = $lastUpdatedHuman
        DeltaHuman      = $deltaHuman
    }
}

# Phase 2: per-repo git calls (the slow part) via runspace pool
if ($Serial -or $ThrottleLimit -le 1 -or @($repoList).Count -le 1) {
    $results = @(foreach ($r in $repoList) {
        & $task $r.FullPath $r.RootIdx $r.Root $now
    })
} else {
    $pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $ThrottleLimit)
    $pool.Open()
    try {
        $jobs = @(foreach ($r in $repoList) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript($task).AddArgument($r.FullPath).AddArgument($r.RootIdx).AddArgument($r.Root).AddArgument($now)
            [PSCustomObject]@{ PS = $ps; Handle = $ps.BeginInvoke() }
        })
        $results = @(foreach ($j in $jobs) {
            try { $j.PS.EndInvoke($j.Handle) }
            finally { $j.PS.Dispose() }
        })
    } finally {
        $pool.Close()
        $pool.Dispose()
    }
}
$sw.Stop()

# Apply sorting
$display = $results
if ($SortByFiles) {
    $display = if ($Reverse) { $results | Sort-Object Files } else { $results | Sort-Object Files -Descending }
} elseif ($SortByTime) {
    $display = if ($Reverse) { $results | Sort-Object LastUpdated } else { $results | Sort-Object LastUpdated -Descending }
}

$count = @($display).Count
$dirtyCount = @($display | Where-Object Dirty).Count
"{0} repos ({1} dirty, {2} clean) - {3:0.0}s" -f $count, $dirtyCount, ($count - $dirtyCount), $sw.Elapsed.TotalSeconds
$maxRepoLen = [Math]::Max(4, (($display | ForEach-Object { $_.Repo.Length } | Measure-Object -Maximum).Maximum))
$first = $true
for ($i = 0; $i -lt $roots.Count; $i++) {
    $group = @($display | Where-Object RootIdx -eq $i)
    if ($group.Count -eq 0) { continue }
    if (-not $first) { $div }
    $first = $false
    '{0} ({1})' -f (Split-Path $roots[$i] -Leaf), $group.Count
    $deltaWidth = [Math]::Max(5, (($group | ForEach-Object { $_.DeltaHuman.Length } | Measure-Object -Maximum).Maximum))
    $group | ForEach-Object {
        [PSCustomObject]@{
            Repo   = $_.Repo
            Status = if ($_.Dirty) { "${red}DIRTY${reset}" } else { "${green}CLEAN${reset}" }
            Time   = $_.LastUpdatedHuman
            Delta  = $_.DeltaHuman
            Files  = $_.Files
        }
    } | Format-Table @{ Label = 'Repo'; Expression = 'Repo'; Width = $maxRepoLen },
                     @{ Label = 'Status'; Expression = 'Status'; Width = 7 },
                     @{ Label = 'Time'; Expression = 'Time'; Width = 16 },
                     @{ Label = ' '; Expression = { ' ' }; Width = 2 },
                     @{ Label = 'Delta'; Expression = 'Delta'; Width = $deltaWidth; Alignment = 'Left' },
                     @{ Label = '  '; Expression = { '  ' }; Width = 2 },
                     @{ Label = 'Files'; Expression = 'Files'; Alignment = 'Right' }
}
if ($dirtyCount -eq 0) { "${cyan}`nAll gucci.${reset}" }
