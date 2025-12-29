# Facebook Messenger Desktop

A self-contained desktop application for Facebook Messenger, built with Electron. This app wraps messenger.com and provides enhanced native notifications, badge counts, and cross-platform support.

## Features

- 🖥️ Cross-platform support (macOS, Windows, Linux)
- 🔔 Native desktop notifications
- 🔴 Badge counts for unread messages
- 📱 System tray integration
- 🔕 Background notifications when window is closed
- ⚡ Fast and lightweight

## Development

```bash
# Install dependencies
npm install

# Generate app icons from SVG (first time setup)
npm run generate-icons

# Build TypeScript
npm run build

# Run in development mode
npm start

# Build for distribution
npm run dist
```

## Building for Specific Platforms

```bash
# macOS
npm run dist:mac

# Windows
npm run dist:win

# Linux
npm run dist:linux
```

## License

MIT

