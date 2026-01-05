# Snap ARM64 Build Setup

This document explains how to set up Snap ARM64 builds using Snapcraft's remote build service.

## Overview

Due to LXD network restrictions in GitHub Actions, we use a hybrid approach:
- **x64 Snap**: Built with electron-builder (works fine)
- **ARM64 Snap**: Built with Snapcraft remote-build (via Launchpad)

## Setup Instructions

### 1. Create Snapcraft Account

1. Go to https://snapcraft.io/ and create an account
2. Register the snap name `facebook-messenger-desktop` (if not already registered)

### 2. Generate Snapcraft Login Token

Run locally:

```bash
# Install snapcraft
sudo snap install snapcraft --classic

# Login to snapcraft
snapcraft login

# Export login token for GitHub Actions
snapcraft export-login --snaps facebook-messenger-desktop -
```

This will output a token that you need to add as a GitHub secret.

### 3. Add GitHub Secret

1. Go to your repository: Settings > Secrets and variables > Actions
2. Add a new secret named `SNAPCRAFT_STORE_CREDENTIALS`
3. Paste the token from step 2

**Note**: The existing `SNAPCRAFT_STORE_CREDENTIALS` secret should work if it's already set up for x64 snap uploads.

### 4. How It Works

When you create a release (push a version tag):

1. **x64 Snap**: Built by electron-builder on `ubuntu-latest` runner
2. **ARM64 Snap**: Built by `snapcraft remote-build` on Launchpad's ARM64 infrastructure
3. Both snaps are uploaded to the Snap Store

The `snapcraft.yaml` file in the repo root is used for the remote build.

## Alternative: Snapcraft "Build from GitHub" Service

You can also use Snapcraft's automatic "Build from GitHub" service:

1. Go to https://snapcraft.io/account/snaps
2. Find `facebook-messenger-desktop`
3. Go to "Builds" tab
4. Click "Set up build service"
5. Link your GitHub repository
6. Enable automatic builds

This will automatically build ARM64 (and other architectures) whenever you push to main, without needing GitHub Actions.

## Troubleshooting

- If remote build fails, check that `SNAPCRAFT_STORE_CREDENTIALS` secret is set correctly
- The snapcraft.yaml file must be in the repo root
- Remote builds can take 10-20 minutes

