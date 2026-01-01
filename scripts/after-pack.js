const fs = require('fs');
const path = require('path');

/**
 * electron-builder afterPack hook
 * Adds an instructional text file alongside the .app bundle for macOS
 */
exports.default = async function afterPack(context) {
  if (context.electronPlatformName !== 'darwin') {
    return;
  }

  const appOutDir = context.appOutDir;
  const fileName = 'Drag Messenger to Applications folder.txt';
  const filePath = path.join(appOutDir, fileName);

  const content = `To install Messenger:

1. Open your Applications folder (Cmd + Shift + A in Finder)
2. Drag "Messenger.app" from this folder into Applications
3. Eject or delete this folder
4. Launch Messenger from Applications

Messenger works best when installed in your Applications folder.
Auto-updates and macOS integration require the app to be in Applications.
`;

  fs.writeFileSync(filePath, content, 'utf8');
  console.log(`✓ Created install instructions: ${fileName}`);
};

