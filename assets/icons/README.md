# Icons

The Messenger app icons are generated from `messenger-icon.svg`.

## Generating Icons

To regenerate all icons from the SVG source:

```bash
npm run generate-icons
```

This will create:
- `icon.icns` - macOS icon (multi-size iconset)
- `icon.ico` - Windows icon (256x256 PNG, can be converted to proper ICO)
- `icon.png` - Linux icon (512x512 PNG)
- Various size PNGs for different use cases

## Icon Source

The `messenger-icon.svg` file contains the Messenger logo - a blue gradient background with a white lightning bolt, matching the official Messenger branding.

