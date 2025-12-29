# Setup Guide

## Prerequisites

- Node.js 18+ and npm
- For building: platform-specific build tools (Xcode on macOS, Visual Studio on Windows, etc.)

## Installation

1. Install dependencies:
```bash
npm install
```

2. Build the TypeScript code:
```bash
npm run build
```

3. Run the app:
```bash
npm start
```

## Icons

The app will work without custom icons, but for a polished look, add icons to:

- `assets/icons/` - Main app icons (see README in that folder)
- `assets/tray/` - System tray icons (see README in that folder)

## Development

Run in watch mode for development:
```bash
npm run dev
```

This will watch for TypeScript changes and automatically rebuild.

## Building for Distribution

Build for your current platform:
```bash
npm run dist
```

Build for specific platforms:
```bash
npm run dist:mac    # macOS (DMG)
npm run dist:win    # Windows (NSIS installer + portable)
npm run dist:linux  # Linux (AppImage, DEB, RPM)
```

Built applications will be in the `release/` directory.

## Features

- ✅ Native desktop notifications
- ✅ Badge counts (macOS dock badge, system tray on others)
- ✅ System tray integration
- ✅ Background notifications when window is closed
- ✅ Cross-platform support

## Troubleshooting

### Notifications not working
- Make sure notification permissions are granted in your system settings
- On macOS: System Preferences > Notifications > Messenger
- On Windows: Settings > System > Notifications

### Badge counts not updating
- The app monitors the page title for unread counts (format: "(5) Messenger")
- If messenger.com changes their title format, the detection may need updating

### App won't start
- Make sure you've run `npm install` and `npm run build`
- Check that Node.js version is 18 or higher
- Check console for error messages

