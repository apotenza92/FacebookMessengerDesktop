#!/bin/bash
# Flathub Source Build Test
# Builds from source, downloads Electron separately
#
# curl -sSL https://raw.githubusercontent.com/apotenza92/facebook-messenger-desktop/main/scripts/test-flathub.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Flathub Source Build Test                                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

APP_ID="io.github.apotenza92.messenger"
MANIFEST="${APP_ID}.yml"
RUNTIME_VERSION="24.08"
ELECTRON_VERSION="28.0.0"
REPO_RAW="https://raw.githubusercontent.com/apotenza92/facebook-messenger-desktop/main"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  ELECTRON_ARCH="x64"
  FLATPAK_ARCH="x86_64"
elif [ "$ARCH" = "aarch64" ]; then
  ELECTRON_ARCH="arm64"
  FLATPAK_ARCH="aarch64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

CLEANUP_DIR="/tmp/flathub-test-$$"
mkdir -p "$CLEANUP_DIR"
cd "$CLEANUP_DIR"

cleanup() {
  rm -rf "$CLEANUP_DIR"
}
trap cleanup EXIT

# Install dependencies
echo -e "${YELLOW}[1/6] Installing dependencies...${NC}"
if command -v dnf </dev/null &>/dev/null; then
  sudo dnf install -y flatpak flatpak-builder appstream curl unzip </dev/null 2>/dev/null || true
elif command -v apt </dev/null &>/dev/null; then
  sudo apt update </dev/null 2>/dev/null && sudo apt install -y flatpak flatpak-builder appstream curl unzip </dev/null 2>/dev/null || true
fi
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo </dev/null 2>/dev/null || true
echo -e "${GREEN}✓ Done${NC}"
echo ""

# Install runtimes
echo -e "${YELLOW}[2/6] Installing Flatpak runtimes...${NC}"
flatpak install --user -y flathub org.freedesktop.Platform//${RUNTIME_VERSION} </dev/null 2>/dev/null || true
flatpak install --user -y flathub org.freedesktop.Sdk//${RUNTIME_VERSION} </dev/null 2>/dev/null || true
flatpak install --user -y flathub org.freedesktop.Sdk.Extension.node20//${RUNTIME_VERSION} </dev/null 2>/dev/null || true
flatpak install --user -y flathub org.electronjs.Electron2.BaseApp//${RUNTIME_VERSION} </dev/null 2>/dev/null || true
echo -e "${GREEN}✓ Done${NC}"
echo ""

# Download source files
echo -e "${YELLOW}[3/6] Downloading source files...${NC}"
mkdir -p repo/src/main repo/src/preload repo/assets/icons/linux repo/assets/tray

# Core files
curl -sL "${REPO_RAW}/package.json" </dev/null > repo/package.json
curl -sL "${REPO_RAW}/package-lock.json" </dev/null > repo/package-lock.json
curl -sL "${REPO_RAW}/tsconfig.json" </dev/null > repo/tsconfig.json
curl -sL "${REPO_RAW}/LICENSE" </dev/null > repo/LICENSE

# Source files
for f in main.ts notification-handler.ts badge-manager.ts background-service.ts; do
  curl -sL "${REPO_RAW}/src/main/$f" </dev/null > "repo/src/main/$f"
done
for f in preload.ts notifications-inject.ts tsconfig.json; do
  curl -sL "${REPO_RAW}/src/preload/$f" </dev/null > "repo/src/preload/$f"
done

# Icons
for size in 64x64 128x128 256x256; do
  curl -sL "${REPO_RAW}/assets/icons/linux/${size}.png" </dev/null > "repo/assets/icons/linux/${size}.png"
done
curl -sL "${REPO_RAW}/assets/tray/icon.png" </dev/null > repo/assets/tray/icon.png 2>/dev/null || true

# Flatpak files
curl -sL "${REPO_RAW}/${APP_ID}.desktop" </dev/null > "repo/${APP_ID}.desktop"
curl -sL "${REPO_RAW}/${APP_ID}.metainfo.xml" </dev/null > "repo/${APP_ID}.metainfo.xml"

echo -e "${GREEN}✓ Source files downloaded${NC}"
echo ""

# Download Electron
echo -e "${YELLOW}[4/6] Downloading Electron ${ELECTRON_VERSION} (${ELECTRON_ARCH})...${NC}"
ELECTRON_URL="https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-${ELECTRON_ARCH}.zip"
curl -sL "$ELECTRON_URL" </dev/null -o electron.zip
unzip -q electron.zip -d repo/electron
rm electron.zip
ELECTRON_SHA=$(sha256sum repo/electron/electron | cut -d' ' -f1)
echo -e "${GREEN}✓ Electron downloaded${NC}"
echo ""

# Generate npm sources
echo -e "${YELLOW}[5/6] Preparing build...${NC}"
cd repo

# Create source archive
cd ..
tar czf source.tar.gz repo
SOURCE_SHA=$(sha256sum source.tar.gz | cut -d' ' -f1)
cd repo

# Create manifest
cat > "$MANIFEST" << MANIFEST_EOF
app-id: io.github.apotenza92.messenger
runtime: org.freedesktop.Platform
runtime-version: '24.08'
sdk: org.freedesktop.Sdk
sdk-extensions:
  - org.freedesktop.Sdk.Extension.node20
base: org.electronjs.Electron2.BaseApp
base-version: '24.08'
command: facebook-messenger-desktop
separate-locales: false

finish-args:
  - --share=ipc
  - --socket=wayland
  - --socket=fallback-x11
  - --socket=pulseaudio
  - --share=network
  - --device=dri
  - --talk-name=org.freedesktop.Notifications
  - --talk-name=org.kde.StatusNotifierWatcher
  - --filesystem=xdg-download
  - --device=all

build-options:
  append-path: /usr/lib/sdk/node20/bin
  env:
    NPM_CONFIG_LOGLEVEL: info
    npm_config_nodedir: /usr/lib/sdk/node20

modules:
  - name: facebook-messenger-desktop
    buildsystem: simple
    build-commands:
      # Compile TypeScript
      - npm install --ignore-scripts typescript @types/node
      - npx tsc
      - npx tsc -p src/preload/tsconfig.json
      # Install runtime dependencies only
      - npm install --ignore-scripts --omit=dev electron-updater
      # Set up app structure
      - mkdir -p /app/lib/messenger
      - cp -r dist /app/lib/messenger/
      - cp -r assets /app/lib/messenger/
      - cp package.json /app/lib/messenger/
      - cp -r node_modules /app/lib/messenger/
      # Install Electron
      - mkdir -p /app/lib/electron
      - cp -r electron/* /app/lib/electron/
      - chmod +x /app/lib/electron/electron
      # Launcher
      - install -Dm755 launcher.sh /app/bin/facebook-messenger-desktop
      # Desktop integration
      - install -Dm644 io.github.apotenza92.messenger.desktop /app/share/applications/io.github.apotenza92.messenger.desktop
      - install -Dm644 io.github.apotenza92.messenger.metainfo.xml /app/share/metainfo/io.github.apotenza92.messenger.metainfo.xml
      - install -Dm644 assets/icons/linux/256x256.png /app/share/icons/hicolor/256x256/apps/io.github.apotenza92.messenger.png
      - install -Dm644 assets/icons/linux/128x128.png /app/share/icons/hicolor/128x128/apps/io.github.apotenza92.messenger.png
      - install -Dm644 assets/icons/linux/64x64.png /app/share/icons/hicolor/64x64/apps/io.github.apotenza92.messenger.png
      - install -Dm644 LICENSE /app/share/licenses/io.github.apotenza92.messenger/LICENSE
    sources:
      - type: archive
        path: ../source.tar.gz
        sha256: ${SOURCE_SHA}
        strip-components: 1
      - type: script
        dest-filename: launcher.sh
        commands:
          - export TMPDIR="\${XDG_RUNTIME_DIR}/app/\${FLATPAK_ID}"
          - cd /app/lib/messenger
          - exec zypak-wrapper /app/lib/electron/electron /app/lib/messenger/dist/main/main.js "\$@"
MANIFEST_EOF

echo -e "${GREEN}✓ Manifest created${NC}"
echo ""

# Build
echo -e "${YELLOW}[6/6] Building Flatpak...${NC}"
flatpak-builder --user --install --force-clean build-dir "$MANIFEST" </dev/null

SIZE=$(du -sh build-dir 2>/dev/null | cut -f1)
echo -e "${GREEN}✓ Build successful (${SIZE})${NC}"
echo ""

# Run
echo -e "${BLUE}Launching app...${NC}"
flatpak run "$APP_ID" </dev/null || true

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Build complete!                                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Run:       ${BLUE}flatpak run $APP_ID${NC}"
echo -e "Uninstall: ${BLUE}flatpak uninstall --user $APP_ID${NC}"
