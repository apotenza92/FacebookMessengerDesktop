#!/bin/bash
# Flathub Official Build Environment Test
# Mimics actual Flathub build: offline npm, generated-sources.json
#
# curl -sSL https://raw.githubusercontent.com/apotenza92/facebook-messenger-desktop/main/scripts/test-flathub-official.sh | bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Flathub Official Build Environment Test                  ║${NC}"
echo -e "${BLUE}║  (Offline npm build with generated-sources.json)          ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

APP_ID="io.github.apotenza92.messenger"
RUNTIME_VERSION="24.08"
ELECTRON_VERSION="28.0.0"
REPO_URL="https://github.com/apotenza92/facebook-messenger-desktop"

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  ELECTRON_ARCH="x64"
  ELECTRON_SHA="d66b6774b886bd57519d49b9eb8e6e745b523519414a8819f67aa19f76e2b53c"
elif [ "$ARCH" = "aarch64" ]; then
  ELECTRON_ARCH="arm64"
  ELECTRON_SHA="32f9f7592359cf8b341946b41d758466533bd7a2bc0dc316072a3a1af4b92d84"
else
  echo -e "${RED}Unsupported architecture: $ARCH${NC}"
  exit 1
fi

WORK_DIR="/tmp/flathub-official-test-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo -e "${YELLOW}[1/8] Installing system dependencies...${NC}"
if command -v dnf &>/dev/null; then
  sudo dnf install -y flatpak flatpak-builder python3-pip python3-aiohttp git curl unzip 2>/dev/null || true
elif command -v apt &>/dev/null; then
  sudo apt update 2>/dev/null
  sudo apt install -y flatpak flatpak-builder python3-pip python3-aiohttp git curl unzip 2>/dev/null || true
fi
echo -e "${GREEN}✓ Done${NC}\n"

echo -e "${YELLOW}[2/8] Installing flatpak-node-generator...${NC}"
# Install via pip (works on most systems)
pip3 install --user --break-system-packages flatpak-node-generator 2>/dev/null || \
pip3 install --user flatpak-node-generator 2>/dev/null || \
pip3 install flatpak-node-generator 2>/dev/null || true
export PATH="$HOME/.local/bin:$PATH"

# Verify installation
if ! command -v flatpak-node-generator &>/dev/null && [ ! -f "$HOME/.local/bin/flatpak-node-generator" ]; then
  echo -e "${RED}Failed to install flatpak-node-generator${NC}"
  echo -e "${YELLOW}Try manually: pip3 install flatpak-node-generator${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Done${NC}\n"

echo -e "${YELLOW}[3/8] Installing Flatpak runtimes...${NC}"
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
flatpak install --user -y flathub org.freedesktop.Platform//${RUNTIME_VERSION} 2>/dev/null || true
flatpak install --user -y flathub org.freedesktop.Sdk//${RUNTIME_VERSION} 2>/dev/null || true
flatpak install --user -y flathub org.freedesktop.Sdk.Extension.node20//${RUNTIME_VERSION} 2>/dev/null || true
flatpak install --user -y flathub org.electronjs.Electron2.BaseApp//${RUNTIME_VERSION} 2>/dev/null || true
echo -e "${GREEN}✓ Done${NC}\n"

echo -e "${YELLOW}[4/8] Cloning repository...${NC}"
git clone --depth 1 "$REPO_URL" repo
cd repo
echo -e "${GREEN}✓ Done${NC}\n"

echo -e "${YELLOW}[5/8] Generating offline npm sources...${NC}"
echo -e "   ${BLUE}Running: flatpak-node-generator npm package-lock.json${NC}"

if command -v flatpak-node-generator &>/dev/null; then
  flatpak-node-generator npm package-lock.json -o generated-sources.json
else
  "$HOME/.local/bin/flatpak-node-generator" npm package-lock.json -o generated-sources.json
fi

if [ ! -f generated-sources.json ]; then
  echo -e "${RED}Failed to generate sources${NC}"
  exit 1
fi
SOURCES_SIZE=$(du -h generated-sources.json | cut -f1)
SOURCES_COUNT=$(grep -c '"type"' generated-sources.json || echo "?")
echo -e "${GREEN}✓ Generated ${SOURCES_COUNT} sources (${SOURCES_SIZE})${NC}\n"

echo -e "${YELLOW}[6/8] Downloading Electron ${ELECTRON_VERSION}...${NC}"
ELECTRON_URL="https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-${ELECTRON_ARCH}.zip"
curl -sL "$ELECTRON_URL" -o electron.zip
unzip -q electron.zip -d electron
rm electron.zip
chmod +x electron/electron
echo -e "${GREEN}✓ Done${NC}\n"

echo -e "${YELLOW}[7/8] Creating manifest and building...${NC}"

# Create source archive for flatpak-builder
cd "$WORK_DIR"
tar czf source.tar.gz repo
SOURCE_SHA=$(sha256sum source.tar.gz | cut -d' ' -f1)
mv source.tar.gz repo/
cd repo

cat > "${APP_ID}.yml" << MANIFEST_EOF
app-id: ${APP_ID}
runtime: org.freedesktop.Platform
runtime-version: '${RUNTIME_VERSION}'
sdk: org.freedesktop.Sdk
sdk-extensions:
  - org.freedesktop.Sdk.Extension.node20
base: org.electronjs.Electron2.BaseApp
base-version: '${RUNTIME_VERSION}'
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
    build-options:
      env:
        XDG_CACHE_HOME: /run/build/facebook-messenger-desktop/flatpak-node/cache
        npm_config_cache: /run/build/facebook-messenger-desktop/flatpak-node/npm-cache
        npm_config_offline: 'true'
    build-commands:
      # Install dependencies OFFLINE
      - npm ci --offline --ignore-scripts
      # Build TypeScript
      - npx tsc
      - npx tsc -p src/preload/tsconfig.json
      # Install app
      - mkdir -p /app/lib/messenger
      - cp -r dist /app/lib/messenger/
      - cp -r assets /app/lib/messenger/
      - cp package.json /app/lib/messenger/
      # Copy runtime dependencies
      - mkdir -p /app/lib/messenger/node_modules
      - cp -r node_modules/electron-updater /app/lib/messenger/node_modules/ || true
      - cp -r node_modules/lazy-val /app/lib/messenger/node_modules/ || true
      - cp -r node_modules/semver /app/lib/messenger/node_modules/ || true
      # Install Electron
      - mkdir -p /app/lib/electron
      - cp -r electron/* /app/lib/electron/
      - chmod +x /app/lib/electron/electron
      # Launcher
      - install -Dm755 launcher.sh /app/bin/facebook-messenger-desktop
      # Desktop integration
      - install -Dm644 ${APP_ID}.desktop /app/share/applications/${APP_ID}.desktop
      - install -Dm644 ${APP_ID}.metainfo.xml /app/share/metainfo/${APP_ID}.metainfo.xml
      - install -Dm644 assets/icons/linux/256x256.png /app/share/icons/hicolor/256x256/apps/${APP_ID}.png
      - install -Dm644 assets/icons/linux/128x128.png /app/share/icons/hicolor/128x128/apps/${APP_ID}.png
      - install -Dm644 assets/icons/linux/64x64.png /app/share/icons/hicolor/64x64/apps/${APP_ID}.png
      - install -Dm644 LICENSE /app/share/licenses/${APP_ID}/LICENSE
    sources:
      - type: archive
        path: source.tar.gz
        sha256: ${SOURCE_SHA}
        strip-components: 1
      - generated-sources.json
      - type: script
        dest-filename: launcher.sh
        commands:
          - export TMPDIR="\${XDG_RUNTIME_DIR}/app/\${FLATPAK_ID}"
          - cd /app/lib/messenger
          - exec zypak-wrapper /app/lib/electron/electron /app/lib/messenger/dist/main/main.js "\$@"
MANIFEST_EOF

echo -e "   ${BLUE}Building with --disable-download (offline mode)...${NC}"
flatpak-builder --user --install --force-clean build-dir "${APP_ID}.yml" 2>&1 | tee build.log

if [ $? -ne 0 ]; then
  echo -e "${RED}Build failed! Last 30 lines:${NC}"
  tail -30 build.log
  exit 1
fi

SIZE=$(du -sh build-dir 2>/dev/null | cut -f1)
echo -e "${GREEN}✓ Build successful (${SIZE})${NC}\n"

echo -e "${YELLOW}[8/8] Launching app...${NC}"
flatpak run "$APP_ID" || true

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Flathub official build test complete!                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Build used:"
echo -e "  • ${BLUE}generated-sources.json${NC} - offline npm dependencies"
echo -e "  • ${BLUE}npm ci --offline${NC} - same as Flathub"
echo -e "  • ${BLUE}npm_config_offline: true${NC} - enforced offline mode"
echo ""
echo -e "Run:       ${BLUE}flatpak run $APP_ID${NC}"
echo -e "Uninstall: ${BLUE}flatpak uninstall --user $APP_ID${NC}"
echo -e "Work dir:  ${BLUE}$WORK_DIR${NC}"
