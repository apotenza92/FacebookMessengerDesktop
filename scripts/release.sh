#!/bin/bash
set -euo pipefail

# Release script for Facebook Messenger Desktop
# Creates a version tag and pushes it to trigger CI builds

VERSION="${1:-}"

if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/release.sh <version>"
  echo "Examples:"
  echo "  ./scripts/release.sh 1.2.3"
  echo "  ./scripts/release.sh 1.2.3-beta.1"
  exit 1
fi

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  echo "Error: Invalid version format. Use semver (e.g., 1.2.3 or 1.2.3-beta.1)"
  exit 1
fi

TAG="v$VERSION"

echo "========================================"
echo "Release: $TAG"
echo "========================================"
echo ""

# Check we're on main branch
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
  echo "Warning: You're on branch '$BRANCH', not 'main'"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  echo "Error: You have uncommitted changes. Please commit or stash them first."
  exit 1
fi

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Error: Tag $TAG already exists"
  exit 1
fi

# Verify CHANGELOG.md has entry for this version
if ! grep -q "\[$VERSION\]" CHANGELOG.md; then
  echo "Error: No CHANGELOG.md entry found for version $VERSION"
  echo "Please add changelog entry before releasing."
  exit 1
fi

# Verify package.json version matches
PKG_VERSION=$(node -p "require('./package.json').version")
if [ "$PKG_VERSION" != "$VERSION" ]; then
  echo "Error: package.json version ($PKG_VERSION) doesn't match release version ($VERSION)"
  echo "Please update package.json first."
  exit 1
fi

echo "✓ Pre-flight checks passed"
echo ""

# Create the tag and push
echo "Creating tag $TAG..."
git tag "$TAG"
git push origin "$TAG"

echo ""
echo "========================================"
echo "Release $TAG initiated!"
echo "========================================"
echo ""
echo "CI is now building all platforms..."
echo "Monitor at: https://github.com/apotenza92/facebook-messenger-desktop/actions"
