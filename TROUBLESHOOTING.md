# Troubleshooting

## App Won't Start

If the app won't start:

1. **Check for build errors:**
   ```bash
   npm run build
   ```

2. **Check Electron version:**
   ```bash
   npm list electron
   ```

3. **Try reinstalling dependencies:**
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

4. **Check console output:**
   ```bash
   npm start
   ```
   Look for error messages in the terminal

## Notifications Not Working

1. **Check system notification permissions:**
   - macOS: System Settings > Notifications > Messenger
   - Windows: Settings > System > Notifications

2. **Verify notification support:**
   - The app checks if notifications are supported on startup
   - Check console for warnings

## Badge Counts Not Updating

1. **Check if page title changes:**
   - The app monitors the page title for unread counts
   - Format should be "(5) Messenger" for 5 unread messages

2. **Open Developer Tools and check console:**
   - Look for messages about unread count detection

