import { app, BrowserWindow, nativeImage, NativeImage } from 'electron';

export class BadgeManager {
  private currentCount: number = 0;
  private getMainWindow: (() => BrowserWindow | null) | null = null;

  /**
   * Set a function to get the main window reference (needed for Windows overlay icons)
   */
  setWindowGetter(getter: () => BrowserWindow | null): void {
    this.getMainWindow = getter;
  }

  updateBadgeCount(count: number): void {
    this.currentCount = count;

    if (process.platform === 'darwin') {
      // macOS dock badge
      app.setBadgeCount(count);
    } else if (process.platform === 'win32') {
      // Windows taskbar badge (overlay icon)
      const mainWindow = this.getMainWindow?.();
      if (mainWindow && !mainWindow.isDestroyed()) {
        if (count > 0) {
          const overlayIcon = this.createWindowsBadgeIcon(count);
          mainWindow.setOverlayIcon(overlayIcon, `${count} unread messages`);
        } else {
          mainWindow.setOverlayIcon(null, '');
        }
      }
    } else {
      // Linux - use app indicator or system tray
      // Most Linux desktop environments don't support badges natively
      // We'll rely on the system tray tooltip
    }
  }

  /**
   * Show a notification dot (no count, just indicates new notifications)
   */
  showNotificationDot(): void {
    if (process.platform === 'win32') {
      const mainWindow = this.getMainWindow?.();
      if (mainWindow && !mainWindow.isDestroyed()) {
        const dotIcon = this.createWindowsDotIcon();
        mainWindow.setOverlayIcon(dotIcon, 'New notifications');
      }
    } else if (process.platform === 'darwin') {
      // On macOS, we can use a bullet character in the dock badge
      app.dock?.setBadge('•');
    }
  }

  /**
   * Create a badge overlay icon for Windows with the count number (using SVG)
   */
  private createWindowsBadgeIcon(count: number): NativeImage {
    const size = 16;
    const displayText = count > 99 ? '99+' : count.toString();
    const fontSize = count > 99 ? 6 : count > 9 ? 8 : 10;
    
    const svg = `
      <svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">
        <circle cx="${size / 2}" cy="${size / 2}" r="${size / 2}" fill="#ff3b30"/>
        <text x="${size / 2}" y="${size / 2}" 
              font-family="Segoe UI, sans-serif" 
              font-size="${fontSize}" 
              font-weight="bold" 
              fill="white" 
              text-anchor="middle" 
              dominant-baseline="central">${displayText}</text>
      </svg>
    `;
    
    const dataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
    return nativeImage.createFromDataURL(dataUrl);
  }

  /**
   * Create a simple red dot icon for Windows (using SVG)
   */
  private createWindowsDotIcon(): NativeImage {
    const size = 16;
    const dotSize = 10;
    
    const svg = `
      <svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">
        <circle cx="${size / 2}" cy="${size / 2}" r="${dotSize / 2}" fill="#ff3b30"/>
      </svg>
    `;
    
    const dataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
    return nativeImage.createFromDataURL(dataUrl);
  }

  getCurrentCount(): number {
    return this.currentCount;
  }

  clearBadge(): void {
    this.updateBadgeCount(0);
  }
}

