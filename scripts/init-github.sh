#!/usr/bin/env bash
# scripts/init-github.sh
# One-time bootstrap. Run from the repo root in WSL or any Linux/macOS shell.
# Creates the GitHub repo, sets the remote, makes the initial commit, pushes main.
#
# Prereqs:
#   - git installed
#   - gh CLI installed and authenticated (`gh auth login`, SSH protocol)
#   - SSH key already added to your GitHub account
#
# Usage:
#   bash scripts/init-github.sh

set -euo pipefail

REPO_OWNER="spyspott3d"
REPO_NAME="Decay"
VISIBILITY="public"   # change to "private" if preferred

# --- sanity checks ------------------------------------------------------------

if ! command -v git >/dev/null 2>&1; then
  echo "[init-github] git is not installed. Aborting."
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "[init-github] gh CLI is not installed."
  echo "  Install: https://cli.github.com/"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[init-github] gh CLI is not authenticated."
  echo "  Run: gh auth login   (pick GitHub.com, SSH, follow prompts)"
  exit 1
fi

if [ -d ".git" ]; then
  echo "[init-github] .git already exists. This script is for first-time setup only."
  echo "  If you want to re-link to a different remote, do it manually with:"
  echo "    git remote set-url origin git@github.com:${REPO_OWNER}/${REPO_NAME}.git"
  exit 1
fi

# --- init local repo ----------------------------------------------------------

echo "[init-github] Initializing local repo..."
git init -b main
git config core.autocrlf input

echo "[init-github] Adding files and creating initial commit..."
git add -A
git commit -m "chore: initial commit (SPEC, architecture, roadmap, CLAUDE.md)"

# --- create remote repo -------------------------------------------------------

echo "[init-github] Creating ${VISIBILITY} repo ${REPO_OWNER}/${REPO_NAME} on GitHub..."
gh repo create "${REPO_OWNER}/${REPO_NAME}" \
  --"${VISIBILITY}" \
  --source=. \
  --remote=origin \
  --description="Self-buff and target-debuff tracker for WoW 3.3.5a (Ascension)." \
  --push

# --- post-setup ---------------------------------------------------------------

echo ""
echo "[init-github] Done."
echo ""
echo "Repo URL:    https://github.com/${REPO_OWNER}/${REPO_NAME}"
echo "Remote URL:  $(git remote get-url origin)"
echo "Default branch: main"
echo ""
echo "Next steps:"
echo "  1. Verify the repo is visible at https://github.com/${REPO_OWNER}/${REPO_NAME}"
echo "  2. Open the repo in Claude Code and start Phase 0."
echo "  3. After every phase, Claude Code commits and pushes via 'git push origin main'."
echo "  4. To cut a release: bash scripts/release.sh 1.0.0"
