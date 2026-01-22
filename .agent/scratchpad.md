# Issue: Cursor Lag & Input Responsiveness (macOS)

## Root Cause Analysis

**CONFIRMED BUG:** The `titleOverlay` BrowserView blocks mouse events from reaching `contentView`.

### Architecture:
```
BrowserWindow (main window)
  ├── contentView (BrowserView) - y: 16px, loads messenger.com
  └── titleOverlay (BrowserView) - y: 0px, height: 32px, ADDED LAST = ON TOP
```

### Problem:
1. `titleOverlay` is added AFTER `contentView` → sits on top in z-order
2. `titleOverlay` is 32px tall, but `contentView` starts at y=16px
3. **16px overlap zone** where titleOverlay blocks events from reaching content
4. CSS has `-webkit-app-region: drag` but NO `pointer-events: none`
5. Result: clicks/hovers in top ~32px area are intercepted by overlay

### Evidence:
- [main.ts#L8702-L8714](file:///Users/alex/code/facebook-messenger-desktop/src/main/main.ts#L8702-L8714): No pointer-events rule in overlay CSS
- [main.ts#L8681-8687](file:///Users/alex/code/facebook-messenger-desktop/src/main/main.ts#L8681-L8687): titleOverlay added after contentView

## Solution

Add `pointer-events: none` to the overlay HTML/CSS. The `-webkit-app-region: drag` will still work for window dragging, but non-drag clicks will pass through to contentView.

## Tasks

- [x] Task 1: Add `pointer-events: none` to titleOverlay CSS (html, body, .bar elements)
- [x] Task 2: Build and verify TypeScript compiles
- [ ] Task 3: Test manually - cursor should now respond properly in top area
