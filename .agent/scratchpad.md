# Issue #33: Microphone Not Released Post Call

## Root Cause Analysis

**CRITICAL BUG FOUND:** The `call-window-preload.ts` script is injected via `executeJavaScript` in the `did-finish-load` event, which is **TOO LATE**. By the time the script is injected:
1. The page has already loaded
2. Messenger's JavaScript may have already called `navigator.mediaDevices.getUserMedia()`
3. Those early MediaStreams are NOT tracked and therefore NOT cleaned up

### Evidence:
- Line 2832-2848 & 3610-3626 in main.ts: Script is injected on `did-finish-load`
- Call window preload overrides `getUserMedia` but only AFTER it's already been called
- Result: Some streams are tracked, some are not → inconsistent cleanup

## Solution

Use `setWindowOpenHandler` to set the preload script as an actual preload, not inject it post-load. This ensures the override is in place BEFORE any JavaScript runs.

**BUT WAIT:** Looking at the code again, the current implementation uses `preload.js` in `webPreferences`. We need to either:
1. Use `call-window-preload.js` AS the preload script for call windows, OR
2. Inject it BEFORE any page script runs using `webContents.on('dom-ready')` event (but this is still after preload)

**Better approach:** Change the preload in `overrideBrowserWindowOptions` to `call-window-preload.js` for call windows.

## Tasks

- [x] Task 1: Update setWindowOpenHandler to use call-window-preload.js as preload for call windows (both contentView and mainWindow handlers)
- [~] Task 2: Merge call-window-preload with necessary preload APIs (contextBridge) - NOT NEEDED, call windows only need MediaStream cleanup
- [x] Task 3: Remove the executeJavaScript injection in did-finish-load (now redundant)
- [x] Task 4: Build and verify TypeScript compiles
- [ ] Task 5: Test manually

## Changes Made

### Fixed: call-window-preload.js now loaded as actual preload script

**Before (BROKEN):**
1. Call window opens with `preload.js` as preload
2. Page loads and Messenger's JavaScript calls `getUserMedia()`
3. THEN `did-finish-load` fires and injects call-window-preload.js
4. The override happens TOO LATE - streams already acquired are NOT tracked

**After (FIXED):**
1. Call window opens with `call-window-preload.js` as preload
2. Preload script runs BEFORE any page JavaScript
3. `getUserMedia` is overridden BEFORE Messenger can call it
4. ALL MediaStreams are tracked from the start
5. `beforeunload` event stops ALL tracks reliably

Files changed:
- `src/main/main.ts`: Changed preload from `preload.js` to `call-window-preload.js` for call windows (2 locations), removed redundant executeJavaScript injection (2 locations)
