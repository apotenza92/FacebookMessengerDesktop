#!/bin/bash
# Flathub Submission Test Script
# Based on https://docs.flathub.org/docs/for-app-authors/requirements
#
# Run from anywhere:
#   curl -sSL https://raw.githubusercontent.com/apotenza92/facebook-messenger-desktop/main/scripts/test-flathub.sh | bash
#
# Or from cloned repo:
#   ./scripts/test-flathub.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Flathub Test: io.github.apotenza92.messenger             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

APP_ID="io.github.apotenza92.messenger"
MANIFEST="${APP_ID}.yml"
METAINFO="${APP_ID}.metainfo.xml"
DESKTOP="${APP_ID}.desktop"
RUNTIME_VERSION="24.08"
REPO_RAW="https://raw.githubusercontent.com/apotenza92/facebook-messenger-desktop/main"

# Detect if running from repo or standalone
if [ -f "$MANIFEST" ] && [ -f "$METAINFO" ]; then
  echo -e "${BLUE}Running from repository${NC}"
  WORK_DIR=$(pwd)
  CLEANUP_DIR=""
else
  echo -e "${BLUE}Downloading files (~10KB total)...${NC}"
  CLEANUP_DIR="/tmp/flathub-test-$$"
  WORK_DIR="$CLEANUP_DIR"
  mkdir -p "$WORK_DIR"
  cd "$WORK_DIR"
  
  # Download only the 3 files we need
  curl -sSLO "$REPO_RAW/$MANIFEST"
  curl -sSLO "$REPO_RAW/$METAINFO"
  curl -sSLO "$REPO_RAW/$DESKTOP"
  
  echo -e "${GREEN}✓ Done${NC}"
fi
echo ""

cleanup() {
  [ -n "$CLEANUP_DIR" ] && rm -rf "$CLEANUP_DIR"
}
trap cleanup EXIT

# Install dependencies
echo -e "${YELLOW}[1/5] Installing dependencies...${NC}"
if command -v dnf &> /dev/null; then
  sudo dnf install -y flatpak flatpak-builder appstream curl 2>/dev/null || true
elif command -v apt &> /dev/null; then
  sudo apt update && sudo apt install -y flatpak flatpak-builder appstream curl 2>/dev/null || true
elif command -v pacman &> /dev/null; then
  sudo pacman -Sy --noconfirm flatpak flatpak-builder appstream curl 2>/dev/null || true
fi
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
echo -e "${GREEN}✓ Done${NC}"
echo ""

# Install runtimes
echo -e "${YELLOW}[2/5] Installing Flatpak runtimes...${NC}"
flatpak install --user -y flathub org.freedesktop.Platform//${RUNTIME_VERSION} 2>/dev/null || true
flatpak install --user -y flathub org.freedesktop.Sdk//${RUNTIME_VERSION} 2>/dev/null || true
flatpak install --user -y flathub org.electronjs.Electron2.BaseApp//${RUNTIME_VERSION} 2>/dev/null || true
echo -e "${GREEN}✓ Done${NC}"
echo ""

# Validate metainfo
echo -e "${YELLOW}[3/5] Validating metainfo...${NC}"
if command -v appstreamcli &> /dev/null; then
  appstreamcli validate "$METAINFO" || true
fi
echo -e "${GREEN}✓ Done${NC}"
echo ""

# Update placeholders and build
echo -e "${YELLOW}[4/5] Building Flatpak...${NC}"

# Get latest release tag
LATEST_TAG=$(curl -sL "https://api.github.com/repos/apotenza92/facebook-messenger-desktop/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
[ -z "$LATEST_TAG" ] && LATEST_TAG="v0.9.1"
echo -e "${BLUE}  Release: $LATEST_TAG${NC}"

if grep -q "REPLACE_WITH" "$MANIFEST"; then
  echo -e "${BLUE}  Fetching SHA256 hashes...${NC}"
  
  # AppImage URLs
  X64_URL="https://github.com/apotenza92/facebook-messenger-desktop/releases/download/${LATEST_TAG}/facebook-messenger-desktop-x86_64.AppImage"
  ARM64_URL="https://github.com/apotenza92/facebook-messenger-desktop/releases/download/${LATEST_TAG}/facebook-messenger-desktop-arm64.AppImage"
  DESKTOP_URL="https://raw.githubusercontent.com/apotenza92/facebook-messenger-desktop/${LATEST_TAG}/${DESKTOP}"
  METAINFO_URL="https://raw.githubusercontent.com/apotenza92/facebook-messenger-desktop/${LATEST_TAG}/${METAINFO}"
  
  # Fetch hashes
  X64_SHA=$(curl -sL "$X64_URL" | sha256sum | cut -d' ' -f1)
  ARM64_SHA=$(curl -sL "$ARM64_URL" | sha256sum | cut -d' ' -f1)
  DESKTOP_SHA=$(curl -sL "$DESKTOP_URL" | sha256sum | cut -d' ' -f1)
  METAINFO_SHA=$(curl -sL "$METAINFO_URL" | sha256sum | cut -d' ' -f1)
  
  echo -e "${BLUE}  x86_64 AppImage: ${X64_SHA:0:12}...${NC}"
  echo -e "${BLUE}  arm64 AppImage:  ${ARM64_SHA:0:12}...${NC}"
  echo -e "${BLUE}  Desktop file:    ${DESKTOP_SHA:0:12}...${NC}"
  echo -e "${BLUE}  Metainfo file:   ${METAINFO_SHA:0:12}...${NC}"
  
  # Update manifest
  sed -i "s|REPLACE_WITH_X64_SHA256|$X64_SHA|g" "$MANIFEST"
  sed -i "s|REPLACE_WITH_ARM64_SHA256|$ARM64_SHA|g" "$MANIFEST"
  sed -i "s|REPLACE_WITH_DESKTOP_SHA256|$DESKTOP_SHA|g" "$MANIFEST"
  sed -i "s|REPLACE_WITH_METAINFO_SHA256|$METAINFO_SHA|g" "$MANIFEST"
  sed -i "s|/v[0-9.]*[-a-z0-9]*/|/${LATEST_TAG}/|g" "$MANIFEST"
fi

echo -e "${BLUE}  Running flatpak-builder...${NC}"
rm -rf build-dir .flatpak-builder 2>/dev/null || true
flatpak-builder --user --install --force-clean build-dir "$MANIFEST"

# Show final size
SIZE=$(du -sh build-dir 2>/dev/null | cut -f1)
echo -e "${GREEN}✓ Build successful (${SIZE})${NC}"
echo ""

# Run
echo -e "${YELLOW}[5/5] Launching app (close window when done)...${NC}"
flatpak run "$APP_ID" || true

echo ""
echo -e "${GREEN}✓ Flathub test complete!${NC}"
echo ""
echo -e "Run again:  flatpak run $APP_ID"
echo -e "Uninstall:  flatpak uninstall --user $APP_ID"
