# Fix Issue #33: Microphone Not Released Post Call

## Problem
With audio calls, the microphone is not consistently released after the call ends. This leaves an orange microphone icon in the macOS menu bar indicating the microphone is still in use.

## Root Cause Analysis
- Messenger always opens calls in new windows (via setWindowOpenHandler in main.ts)
- Call windows should have MediaStream cleanup via call-window-preload.ts
- Inconsistency suggests call-window-preload.ts may not be executing or may have gaps

## Investigation Required
1. Verify call-window-preload.ts is actually injected into call windows
2. Check if there are code paths where getUserMedia is called but not tracked
3. Verify cleanup happens on both "user hangs up" and "other person hangs up"
4. Check for race conditions in track.stop() or stream cleanup
5. Ensure the script injection timing is correct (did-finish-load event)

## Success Criteria
- Microphone is reliably released regardless of who terminates the call
- Orange microphone icon disappears from menu bar when call ends
- All MediaStream tracks are properly stopped in all code paths
