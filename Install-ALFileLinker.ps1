<#
.SYNOPSIS
    Installs the ALFileLinker PowerShell module for the current user.
.DESCRIPTION
    Copies the latest version of ALFileLinker to the user's PowerShell modules folder.
    Run this script on any PC where you want to use the module.
    The module source files are expected to be in the same folder structure on OneDrive.
.NOTES
    After installation, use:
      Clone-RepoWithFileLinks  - to clone a repo and set up file links + post-checkout hook
      Set-ALFileLinks          - to set up file links on an existing repo
      Set-ALFileLinksForRepos  - to set up file links on multiple repos
#>

$ErrorActionPreference = 'Stop'

# Find the latest version folder next to this script
$scriptDir = $PSScriptRoot
$versionDirs = Get-ChildItem -LiteralPath $scriptDir -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending

if ($versionDirs.Count -eq 0) {
    throw "No version folders found in: $scriptDir"
}

$latestVersion = $versionDirs[0]
$version = $latestVersion.Name

Write-Host "Installing ALFileLinker v$version ..." -ForegroundColor Cyan

# Destination
$destBase = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules\ALFileLinker\$version"

if (-not (Test-Path -LiteralPath $destBase)) {
    New-Item -ItemType Directory -Path $destBase -Force | Out-Null
}

# Copy module files
Copy-Item -Path (Join-Path $latestVersion.FullName '*') -Destination $destBase -Force

# Verify
Import-Module ALFileLinker -Force -ErrorAction Stop
$mod = Get-Module ALFileLinker
Write-Host "ALFileLinker v$($mod.Version) installed successfully!" -ForegroundColor Green
Write-Host "Location: $destBase" -ForegroundColor Gray
Write-Host ""
Write-Host "Available commands:" -ForegroundColor Yellow
$mod.ExportedCommands.Keys | ForEach-Object { Write-Host "  - $_" }
