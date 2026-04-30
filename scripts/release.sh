#!/usr/bin/env bash
# scripts/release.sh
# Tags a release and pushes the tag. The GitHub Action (.github/workflows/release.yml)
# will build the zip and create the GitHub Release automatically.
#
# Usage:
#   bash scripts/release.sh 1.0.0
#
# This:
#   1. Verifies the working tree is clean.
#   2. Updates Decay/Decay.toc Version field to match.
#   3. Commits the version bump.
#   4. Creates an annotated git tag v<version>.
#   5. Pushes main and the tag.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: bash scripts/release.sh <version>"
  echo "Example: bash scripts/release.sh 1.0.0"
  exit 1
fi

VERSION="$1"
TAG="v${VERSION}"
TOC="Decay/Decay.toc"

# --- sanity checks ------------------------------------------------------------

if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$ ]]; then
  echo "[release] Version must be semver: MAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH-prerelease"
  exit 1
fi

if [ ! -f "${TOC}" ]; then
  echo "[release] ${TOC} not found. Run from repo root."
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "[release] Working tree is not clean. Commit or stash first."
  git status --short
  exit 1
fi

if git rev-parse "${TAG}" >/dev/null 2>&1; then
  echo "[release] Tag ${TAG} already exists."
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "${CURRENT_BRANCH}" != "main" ]; then
  echo "[release] Releases must be cut from main. You are on ${CURRENT_BRANCH}."
  exit 1
fi

# --- update .toc --------------------------------------------------------------

echo "[release] Updating ${TOC} Version field to ${VERSION}..."
# Cross-platform sed: write to temp then move, avoids -i flag differences
sed "s/^## Version: .*/## Version: ${VERSION}/" "${TOC}" > "${TOC}.tmp"
mv "${TOC}.tmp" "${TOC}"

if ! grep -q "^## Version: ${VERSION}$" "${TOC}"; then
  echo "[release] Failed to update version in ${TOC}. Inspect the file."
  exit 1
fi

# --- commit and tag -----------------------------------------------------------

if git diff --quiet -- "${TOC}"; then
  echo "[release] ${TOC} already at version ${VERSION}, skipping bump commit."
else
  git add "${TOC}"
  git commit -m "release: ${VERSION}"
fi
git tag -a "${TAG}" -m "Release ${VERSION}"

# --- push ---------------------------------------------------------------------

echo "[release] Pushing main and tag ${TAG}..."
git push origin main
git push origin "${TAG}"

echo ""
echo "[release] Done."
echo ""
echo "GitHub Action 'release.yml' is now building the zip and creating the release."
echo "Watch progress: gh run watch"
echo "Or visit: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions"
