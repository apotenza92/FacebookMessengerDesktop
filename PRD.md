# Product Requirements Document

## Task 1: Fix macOS notification click not navigating to chat

### Problem
On macOS, clicking a system notification does not navigate to the corresponding chat conversation. This works correctly on Windows but is broken on macOS.

### Technical Context
- Notification handling is in `src/main/notification-handler.ts`
- The `notification.on('click')` event handler should navigate to the conversation URL via `data.href`
- macOS may have different behavior for Electron's `Notification` click events compared to Windows

### Investigation Areas
1. Check if the `click` event is firing at all on macOS (add debug logging)
2. Verify `data.href` is being passed correctly from `notifications-inject.ts`
3. Research macOS-specific Electron notification click behavior (may need `NSUserNotificationCenter` or different approach)
4. Check if `notification.on('action')` is needed for macOS instead of `click`

### Acceptance Criteria
- [x] Clicking a notification on macOS opens the app and navigates to the correct chat
- [x] Existing Windows notification click behavior continues to work
- [x] Linux notification click behavior is unaffected or also works

### Automated Testing Approach
Create a test script that can be run without manual interaction:

1. **Create `scripts/test-notification-click.ts`** - A script that:
   - Launches the app in test mode
   - Waits for messenger.com to load
   - Programmatically triggers a fake notification with a known `href` (e.g., `/t/123456`)
   - Immediately invokes the click callback (bypassing actual system notification)
   - Verifies the window navigated to the correct URL by checking `window.location.pathname`
   - Exits with success/failure code

2. **Add npm script**: `"test:notification": "electron scripts/test-notification-click.ts"`

3. **Test should run on CI** for macOS, Windows, and Linux to catch platform-specific regressions

This approach tests the actual navigation logic without requiring manual clicks on system notifications.

### Files to Examine
- `src/main/notification-handler.ts` - Main notification click handler
- `src/preload/notifications-inject.ts` - Where notifications are intercepted and href is captured
- `src/main/main.ts` - App initialization and window management

---

## Task 2: Release as beta once Task 1 is complete

**Status**: Task 1 is committed. Ready for release.

### Steps
1. **Update CHANGELOG.md** - Add entry for `1.2.5-beta.4` with today's date at the top of the changelog (after the header), following the existing format:
   ```markdown
   ## [1.2.5-beta.4] - 2026-01-20
   ### Fixed
   - Fixed macOS notification click not navigating to the correct chat conversation
   ```

2. **Update package.json** - Change `"version": "1.2.5-beta.3"` to `"version": "1.2.5-beta.4"`

3. **Commit and push**:
   ```bash
   git add -A
   git commit -m "chore: prepare 1.2.5-beta.4 release"
   git push origin main
   ```

4. **Run release script** (user has granted permission):
   ```bash
   ./scripts/release.sh 1.2.5-beta.4
   ```

### Acceptance Criteria
- [x] CHANGELOG.md updated with 1.2.5-beta.4 entry
- [x] package.json version is 1.2.5-beta.4
- [ ] Changes pushed to main
- [ ] Release script executed successfully
