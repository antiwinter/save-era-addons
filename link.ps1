# Symlink every addon in this repo into WoW's Interface/AddOns folder.
# Usage: .\link.ps1 [TARGET]
#   TARGET defaults to the standard Classic Era install.
# Note: creating symlinks on Windows needs an elevated (admin) shell or
#       Developer Mode enabled.
[CmdletBinding()]
param(
    [string]$Target = "C:\Program Files (x86)\World of Warcraft\_classic_era_"
)

$ErrorActionPreference = "Stop"
$RepoDir = $PSScriptRoot

if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Write-Error "target not found: $Target"
    exit 1
}

$AddonsDir = Join-Path $Target "Interface\AddOns"
New-Item -ItemType Directory -Force -Path $AddonsDir | Out-Null

$linked = 0
Get-ChildItem -Path $RepoDir -Directory | ForEach-Object {
    $addonDir = $_.FullName
    $name = $_.Name

    # An addon is any subdir containing a .toc file.
    if (-not (Get-ChildItem -Path $addonDir -Filter *.toc -File)) { return }

    $dest = Join-Path $AddonsDir $name
    $item = Get-Item -LiteralPath $dest -ErrorAction SilentlyContinue

    if ($null -ne $item) {
        if ($item.LinkType -eq "SymbolicLink") {
            Remove-Item -LiteralPath $dest -Force
        } else {
            Write-Warning "skip: $name - real directory already exists at destination"
            return
        }
    }

    New-Item -ItemType SymbolicLink -Path $dest -Target $addonDir | Out-Null
    Write-Host "linked: $name -> $dest"
    $script:linked++
}

Write-Host "done: $linked addon(s) linked into $AddonsDir"
