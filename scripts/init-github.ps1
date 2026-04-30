# scripts/init-github.ps1
# One-time bootstrap. Run from the repo root in PowerShell on Windows.
# Creates the GitHub repo, sets the remote, makes the initial commit, pushes main.
# Also configures gh CLI as the git credential helper so subsequent pushes
# work without SSH keys.
#
# Prereqs:
#   - git installed (Git for Windows; verify with: git --version)
#   - gh CLI installed and authenticated (gh auth login -> GitHub.com -> HTTPS)
#
# Usage:
#   pwsh scripts/init-github.ps1
#   (or run from PowerShell: .\scripts\init-github.ps1)

$ErrorActionPreference = "Stop"

$RepoOwner = "spyspott3d"
$RepoName  = "Decay"
$Visibility = "public"   # change to "private" if preferred

function Test-Command($name) {
    $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

function Assert-LastExitCode($context) {
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[init-github] Command failed: $context (exit $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
}

# --- sanity checks ------------------------------------------------------------

if (-not (Test-Command "git")) {
    Write-Host "[init-github] git is not installed." -ForegroundColor Red
    Write-Host "  Install Git for Windows: https://git-scm.com/download/win"
    exit 1
}

if (-not (Test-Command "gh")) {
    Write-Host "[init-github] gh CLI is not installed." -ForegroundColor Red
    Write-Host "  Install: https://cli.github.com/"
    exit 1
}

gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[init-github] gh CLI is not authenticated." -ForegroundColor Red
    Write-Host "  Run: gh auth login   (pick GitHub.com, HTTPS, follow prompts)"
    exit 1
}

if (Test-Path ".git") {
    Write-Host "[init-github] .git already exists. This script is for first-time setup only." -ForegroundColor Yellow
    Write-Host "  If you want to re-link to a different remote:"
    Write-Host "    git remote set-url origin https://github.com/$RepoOwner/$RepoName.git"
    exit 1
}

# --- configure gh as git credential helper ------------------------------------

Write-Host "[init-github] Configuring gh as git credential helper..."
gh auth setup-git
Assert-LastExitCode "gh auth setup-git"

# --- init local repo ----------------------------------------------------------

Write-Host "[init-github] Initializing local repo..."
git init -b main
Assert-LastExitCode "git init"

git config core.autocrlf input
Assert-LastExitCode "git config autocrlf"

# Set user identity locally if not configured globally
$gitName = git config user.name
if ([string]::IsNullOrWhiteSpace($gitName)) {
    $ghUser = gh api user --jq .login
    Assert-LastExitCode "gh api user"
    git config user.name "$ghUser"
    git config user.email "$ghUser@users.noreply.github.com"
    Write-Host "[init-github] Set local git user to: $ghUser"
}

Write-Host "[init-github] Adding files and creating initial commit..."
git add -A
Assert-LastExitCode "git add"

git commit -m "chore: initial commit (specs, architecture, roadmap)"
Assert-LastExitCode "git commit"

# --- create remote repo -------------------------------------------------------

Write-Host "[init-github] Creating $Visibility repo $RepoOwner/$RepoName on GitHub..."
gh repo create "$RepoOwner/$RepoName" `
    --"$Visibility" `
    --source="." `
    --remote="origin" `
    --description="Self-buff and target-debuff tracker for WoW 3.3.5a (Ascension)." `
    --push
Assert-LastExitCode "gh repo create"

# --- post-setup ---------------------------------------------------------------

Write-Host ""
Write-Host "[init-github] Done." -ForegroundColor Green
Write-Host ""
Write-Host "Repo URL:    https://github.com/$RepoOwner/$RepoName"
$remoteUrl = git remote get-url origin
Write-Host "Remote URL:  $remoteUrl"
Write-Host "Default branch: main"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Verify the repo is visible at https://github.com/$RepoOwner/$RepoName"
Write-Host "  2. Open the repo in your editor and start Phase 0."
Write-Host "  3. After every phase, commit and push via 'git push origin main'."
Write-Host "  4. To cut a release: pwsh scripts/release.ps1 1.0.0"
