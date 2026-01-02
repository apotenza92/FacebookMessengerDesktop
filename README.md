# Facebook Messenger Desktop

<img src="assets/icons/icon-rounded.png" alt="Facebook Messenger Desktop icon" width="128" />

A self-contained desktop application for Facebook Messenger, built with Electron. Wraps messenger.com with native platform notifications and badge counts.

This project exists because the original Facebook Desktop Messenger app was deprecated.

<a href="https://apotenza92.github.io/facebook-messenger-desktop/">
  <img src="https://img.shields.io/badge/Download-Messenger%20Desktop-0084ff?style=for-the-badge&logo=messenger&logoColor=white" alt="Download Messenger Desktop" height="40">
</a>

## ⚠️ Important Notices

- **Users on v0.5.3 or v0.5.4:** Auto-update was broken in these versions. You must [manually download](https://apotenza92.github.io/facebook-messenger-desktop/) the latest version. [See issue #6](https://github.com/apotenza92/facebook-messenger-desktop/issues/6).

- **Windows Users:** Auto-updates temporarily redirect to manual downloads while we set up code signing. If Windows blocks the installer, right-click it → **Properties** → check **"Unblock"** → **OK**, then run it.

## Package Managers

### macOS (Homebrew)

```bash
brew install --cask apotenza92/tap/facebook-messenger-desktop
```

### Windows (WinGet)

```bash
winget install apotenza92.FacebookMessengerDesktop
```