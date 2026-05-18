#Requires -Version 7.5

<#
.SYNOPSIS
    Increments the build (patch) version in DataForNerdsCollectors.psd1.

.DESCRIPTION
    Called by the pre-commit git hook. Only fires when staged changes include
    files inside Modules/DataForNerdsCollectors/ (excluding the manifest itself).
    Increments the patch number (1.0.x -> 1.0.x+1), writes the file back,
    and stages it so the version change is included in the commit.

    Minor version (1.x.0) should be incremented manually when merging to main,
    then reset patch to 0.
#>

$repoRoot   = & git rev-parse --show-toplevel
$moduleDir  = 'Modules/DataForNerdsCollectors/'
$psd1       = Join-Path $repoRoot 'Modules/DataForNerdsCollectors/DataForNerdsCollectors.psd1'
$psd1Rel    = 'Modules/DataForNerdsCollectors/DataForNerdsCollectors.psd1'

# Only bump when staged files include module source (not just the manifest itself)
$stagedFiles = & git diff --cached --name-only
$moduleChanged = $stagedFiles | Where-Object { $_ -like "$moduleDir*" -and $_ -ne $psd1Rel }
if (-not $moduleChanged) {
    exit 0
}

if (-not (Test-Path $psd1)) {
    Write-Host "Version bump: manifest not found at $psd1 — skipping"
    exit 0
}

$content = Get-Content $psd1 -Raw
$match   = [regex]::Match($content, "ModuleVersion\s*=\s*'(\d+)\.(\d+)\.(\d+)'")

if (-not $match.Success) {
    Write-Host "Version bump: ModuleVersion not found in manifest — skipping"
    exit 0
}

$major      = $match.Groups[1].Value
$minor      = $match.Groups[2].Value
$build      = [int]$match.Groups[3].Value + 1
$newVersion = "$major.$minor.$build"

# Replace only the version number, preserving surrounding formatting
$updated = $content -replace "(?<=ModuleVersion\s*=\s*')[\d.]+(?=')", $newVersion
[System.IO.File]::WriteAllText($psd1, $updated)

& git add $psd1
Write-Host "Version bumped to $newVersion"
