import { app } from 'electron';

export class BadgeManager {
  private currentCount: number = 0;

  updateBadgeCount(count: number): void {
    this.currentCount = count;

    if (process.platform === 'darwin') {
      // macOS dock badge
      app.setBadgeCount(count);
    } else if (process.platform === 'win32') {
      // Windows taskbar badge (overlay icon)
      // Note: Windows doesn't have a built-in badge API like macOS
      // We'll need to use overlay icons or system tray
      // For now, we'll rely on the system tray tooltip
    } else {
      // Linux - use app indicator or system tray
      // Most Linux desktop environments don't support badges natively
      // We'll rely on the system tray tooltip
    }
  }

  getCurrentCount(): number {
    return this.currentCount;
  }

  clearBadge(): void {
    this.updateBadgeCount(0);
  }
}

