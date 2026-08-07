$roots = @(
    'C:\Users\Leonardo\001\00__DEV'
    'C:\Users\Leonardo\Documents\WindowsPowerShell'
    'C:\Program Files\Blender Foundation\Blender 5.2\5.2\scripts\startup'
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
            git -C $parent check-ignore --no-index --quiet $rel
            if ($LASTEXITCODE -eq 0) { $ignored = $true }
            break
        }
        $parent = Split-Path $parent -Parent
    }
    if ($ignored) { continue }

    $porcelain = git -C $repo status --porcelain 2>$null
    $dirty = @($porcelain).Count -gt 0
    [PSCustomObject]@{
        Repo  = if ($repo -eq $root) { Split-Path $repo -Leaf } else { $repo.Substring($root.Length).TrimStart('\') }
        Dirty = $dirty
        Files = @(git -C $repo ls-files).Count
    }
}
}
$sw.Stop()
$count = @($results).Count
$dirtyCount = @($results | Where-Object Dirty).Count
"{0} repos ({1} dirty, {2} clean) - {3:0.0}s" -f $count, $dirtyCount, ($count - $dirtyCount), $sw.Elapsed.TotalSeconds
$results | ForEach-Object {
    [PSCustomObject]@{
        Repo   = $_.Repo
        Status = if ($_.Dirty) { "$($PSStyle.Foreground.Red)DIRTY$($PSStyle.Reset)" } else { "$($PSStyle.Foreground.Green)CLEAN$($PSStyle.Reset)" }
        Files  = $_.Files
    }
} | Format-Table -AutoSize
