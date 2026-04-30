# scripts/release.ps1
# Tags a release and pushes the tag. The GitHub Action (.github/workflows/release.yml)
# will build the zip and create the GitHub Release automatically.
#
# Usage:
#   pwsh scripts/release.ps1 1.0.0
#   (or from PowerShell: .\scripts\release.ps1 1.0.0)
#
# This:
#   1. Verifies the working tree is clean.
#   2. Updates Decay/Decay.toc Version field to match.
#   3. Commits the version bump.
#   4. Creates an annotated git tag v<version>.
#   5. Pushes main and the tag.

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

$Tag = "v$Version"
$Toc = "Decay\Decay.toc"

function Assert-LastExitCode($context) {
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[release] Command failed: $context (exit $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
}

# --- sanity checks ------------------------------------------------------------

if ($Version -notmatch '^\d+\.\d+\.\d+(-[a-z0-9.]+)?$') {
    Write-Host "[release] Version must be semver: MAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH-prerelease" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Toc)) {
    Write-Host "[release] $Toc not found. Run from repo root." -ForegroundColor Red
    exit 1
}

$dirty = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($dirty)) {
    Write-Host "[release] Working tree is not clean. Commit or stash first." -ForegroundColor Red
    git status --short
    exit 1
}

git rev-parse $Tag 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[release] Tag $Tag already exists." -ForegroundColor Red
    exit 1
}

$currentBranch = git rev-parse --abbrev-ref HEAD
Assert-LastExitCode "git rev-parse --abbrev-ref HEAD"
if ($currentBranch -ne "main") {
    Write-Host "[release] Releases must be cut from main. You are on $currentBranch." -ForegroundColor Red
    exit 1
}

# --- update .toc --------------------------------------------------------------

Write-Host "[release] Updating $Toc Version field to $Version..."
$content = Get-Content $Toc -Raw
$updated = $content -replace '(?m)^## Version: .*$', "## Version: $Version"
# Preserve LF endings (no BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Resolve-Path $Toc), $updated, $utf8NoBom)

if (-not (Select-String -Path $Toc -Pattern "^## Version: $([regex]::Escape($Version))$" -Quiet)) {
    Write-Host "[release] Failed to update version in $Toc. Inspect the file." -ForegroundColor Red
    exit 1
}

# --- commit and tag -----------------------------------------------------------

git diff --quiet -- $Toc
$tocChanged = ($LASTEXITCODE -ne 0)
$global:LASTEXITCODE = 0

if ($tocChanged) {
    git add $Toc
    Assert-LastExitCode "git add"

    git commit -m "release: $Version"
    Assert-LastExitCode "git commit"
} else {
    Write-Host "[release] $Toc already at version $Version, skipping bump commit."
}

git tag -a $Tag -m "Release $Version"
Assert-LastExitCode "git tag"

# --- push ---------------------------------------------------------------------

Write-Host "[release] Pushing main and tag $Tag..."
git push origin main
Assert-LastExitCode "git push origin main"

git push origin $Tag
Assert-LastExitCode "git push origin $Tag"

# --- post -----------------------------------------------------------------

Write-Host ""
Write-Host "[release] Done." -ForegroundColor Green
Write-Host ""
Write-Host "GitHub Action 'release.yml' is now building the zip and creating the release."
Write-Host "Watch progress: gh run watch"

$repo = gh repo view --json nameWithOwner -q .nameWithOwner
if ($LASTEXITCODE -eq 0) {
    Write-Host "Or visit: https://github.com/$repo/actions"
}
