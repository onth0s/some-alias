<#
.SYNOPSIS
    Deploys start_menu.lnk from this repo into the current user's Startup folder.

.DESCRIPTION
    Explorer's logon pass only executes a .lnk that sits in the Startup folder, so the
    shortcut cannot live in the repo. This copies the tracked master into place and
    then verifies the deployed copy is byte-identical, keeping the repo the source of
    truth and making drift detectable.

    Re-run after editing start_menu.lnk, or on a new machine, to (re)deploy.

.EXAMPLE
    .\Install-StartupShortcut.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repo     = $PSScriptRoot
$master   = Join-Path $repo 'start_menu.lnk'
$script   = Join-Path $repo 'start_menu.ps1'
$startup  = [Environment]::GetFolderPath('Startup')
$deployed = Join-Path $startup 'start_menu.lnk'

foreach ($required in @($master, $script)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Missing required file: $required"
    }
}

Copy-Item -LiteralPath $master -Destination $deployed -Force

$masterHash   = (Get-FileHash -LiteralPath $master   -Algorithm SHA256).Hash
$deployedHash = (Get-FileHash -LiteralPath $deployed -Algorithm SHA256).Hash
if ($masterHash -ne $deployedHash) {
    throw "Deployed copy does not match the master (SHA256 mismatch). Master=$masterHash Deployed=$deployedHash"
}

Write-Host "deployed: $deployed"
Write-Host "sha256  : $masterHash  (matches master)" -ForegroundColor DarkGray
Write-Host "StartupApproved entry for start_menu.lnk is written by Explorer at next logon." -ForegroundColor DarkGray
