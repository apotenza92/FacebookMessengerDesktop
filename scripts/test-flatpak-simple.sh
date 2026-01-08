#!/bin/bash
# Simple Flatpak Build Test - runs entirely in ~/flatpak-test to avoid /tmp limits
#
# curl -sSL https://raw.githubusercontent.com/apotenza92/facebook-messenger-desktop/main/scripts/test-flatpak-simple.sh | bash

set -e

APP_ID="io.github.apotenza92.messenger"

echo "=== Simple Flatpak Build Test ==="
echo ""

cd ~
rm -rf ~/flatpak-test
mkdir -p ~/flatpak-test
cd ~/flatpak-test

echo "[1/3] Installing runtimes..."
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
flatpak install --user -y flathub org.freedesktop.Platform//24.08 org.freedesktop.Sdk//24.08 org.freedesktop.Sdk.Extension.node20//24.08 org.electronjs.Electron2.BaseApp//24.08 2>/dev/null || true
echo "✓ Runtimes ready"

echo "[2/3] Building flatpak..."
# Download manifest
curl -sL "https://raw.githubusercontent.com/apotenza92/facebook-messenger-desktop/main/scripts/test-manifest.yml" -o manifest.yml

# Build with state-dir in home to avoid /tmp
flatpak-builder --user --install --force-clean \
  --state-dir="$HOME/flatpak-test/state" \
  build-dir manifest.yml

echo "✓ Build complete"

echo "[3/3] Testing launch..."
timeout 10 flatpak run "$APP_ID" 2>&1 || true

echo ""
echo "=== Done ==="
echo "Run:       flatpak run $APP_ID"
echo "Uninstall: flatpak uninstall --user $APP_ID"
echo "Cleanup:   rm -rf ~/flatpak-test"
