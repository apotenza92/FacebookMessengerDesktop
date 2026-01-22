# Cursor Lag & Input Responsiveness Issue Analysis

## Problem Statement
User reports:
- Cursor isn't updating properly to match what's under it
- Slight lag in cursor behavior
- Sometimes requires extra click to perform actions
- UI feels like there's an extra layer on top
- Doesn't feel native, feels like there's something in between the user and the content

## Root Cause Analysis

### On macOS (Primary Suspect):
The app uses a **hybrid architecture** with two separate views:
1. **Main BrowserWindow** with `titleBarStyle: "hiddenInset"` and `titleBarOverlay` (32px height)
2. **BrowserView (contentView)** for the actual messenger.com content, positioned at y=16px with height offset

**Key Issue**: The titleBarOverlay in BrowserWindow may be intercepting mouse events before they reach the contentView, creating event propagation delays and preventing proper cursor tracking.

### Architecture Details:
```
BrowserWindow (main window with titleBarOverlay - 32px)
  ↓
  titleBarOverlay (Electron's native overlay) - height: 32px, color configured
  ↓
  BrowserView (contentView) - starts at y: 16px, height: windowHeight - 16px
```

The titleBarOverlay and its positioning may be:
1. **Blocking/delaying mouse events** - events are processed by overlay before contentView
2. **Preventing hover state updates** - cursor isn't properly tracked when over the overlay area
3. **Creating event propagation delays** - extra event bubbling/filtering overhead
4. **Not respecting pointer-events properties** - overlay may not be transparent to pointer events

### Secondary Issues (All Platforms):
1. **Event Handler Chain**: Mouse movement events are being tracked and sent via IPC (`sendMousePosition`) for menu bar hover detection on Windows/Linux. This creates overhead even on macOS where it's not needed.
2. **Event Delegation**: The preload script listens to `mousemove` globally on document and sends data via IPC, which adds latency.
3. **No `pointerrawupdate` handler**: The app only tracks `mousemove`, missing raw pointer updates that could provide smoother tracking.

## Specific Code Locations:

### macOS titleBarOverlay issue:
[src/main/main.ts#L2213-L2218](file:///Users/alex/code/facebook-messenger-desktop/src/main/main.ts#L2213-L2218)
```typescript
titleBarOverlay: {
  color: colors.background,
  symbolColor: colors.symbols,
  height: overlayHeight,  // 32px - may intercept events
},
```

### BrowserView positioning:
[src/main/main.ts#L2277-L2305](file:///Users/alex/code/facebook-messenger-desktop/src/main/main.ts#L2277-L2305)
```typescript
const contentOffset = 16;
contentView.setBounds({
  x: 0,
  y: contentOffset,  // Offset by 16px to account for overlay
  width: windowBounds.width,
  height: windowBounds.height - contentOffset,
});
```

### Mouse tracking overhead:
[src/preload/preload.ts#L179-L210](file:///Users/alex/code/facebook-messenger-desktop/src/preload/preload.ts#L179-L210)
- Listening to every `mousemove` event globally
- Sending via IPC even when unnecessary
- No debouncing or throttling on the events themselves

## Solution Approach

### Priority 1 (macOS Focus):
1. **Investigate titleBarOverlay event handling** - Check if overlay is receiving and blocking events
   - Consider using `acceptFirstMouse` on the overlay if it exists as a separate view
   - Add CSS `pointer-events: none` to overlay if CSS-accessible
   - Test if disabling titleBarOverlay fixes the issue

2. **Optimize event propagation** - Reduce event processing overhead
   - Implement proper event delegation
   - Use passive event listeners where safe
   - Add `capture: true` phase handlers if needed for event interception

### Priority 2 (All Platforms):
1. **Mouse tracking efficiency**
   - Only enable mouse tracking on Windows/Linux (not macOS)
   - Use `requestAnimationFrame` for mouse position updates instead of every event
   - Add threshold-based event sending (only send if moved > N pixels)

2. **Pointer events optimization**
   - Listen to `pointerrawupdate` in addition to `mousemove` for smoother tracking
   - Use `event.isPrimary` to avoid duplicate events

### Testing Strategy:
1. Test cursor behavior in different areas of messenger.com
2. Test with and without the titleBarOverlay enabled
3. Monitor IPC message frequency during mouse movement
4. Profile event dispatch latency with browser DevTools

## Expected Outcome
- Cursor updates should feel instant and match what's under it
- No extra clicks needed to activate buttons/links
- UI should feel native with no perceived "extra layer"
- Input responsiveness should match native apps

## Files to Modify
- `src/main/main.ts` - titleBarOverlay configuration, event handling
- `src/preload/preload.ts` - Mouse tracking optimization
- Potentially: new CSS in the injected styles for pointer-events transparency
