import { Notification, nativeImage, BrowserWindow } from 'electron';

export interface NotificationData {
  title: string;
  body: string;
  icon?: string;
  tag?: string;
  silent?: boolean;
  requireInteraction?: boolean;
}

export class NotificationHandler {
  private activeNotifications: Map<string, Notification> = new Map();
  private getMainWindow: () => BrowserWindow | null;

  constructor(getMainWindow: () => BrowserWindow | null) {
    this.getMainWindow = getMainWindow;
  }

  showNotification(data: NotificationData): void {
    if (!Notification.isSupported()) {
      console.warn('[NotificationHandler] Notifications are not supported on this system');
      return;
    }

    console.log('[NotificationHandler] Showing notification:', { title: data.title, body: data.body });

    const notificationOptions: Electron.NotificationConstructorOptions = {
      title: data.title,
      body: data.body,
      silent: data.silent || false,
    };

    if (data.icon) {
      try {
        notificationOptions.icon = nativeImage.createFromDataURL(data.icon);
      } catch (e) {
        // If data URL is invalid, try as file path
        try {
          notificationOptions.icon = nativeImage.createFromPath(data.icon);
        } catch (e2) {
          // Ignore icon errors
        }
      }
    }

    const notification = new Notification(notificationOptions);

    // Handle notification click
    notification.on('click', () => {
      const mainWindow = this.getMainWindow();
      if (mainWindow) {
        mainWindow.show();
        mainWindow.focus();
      } else {
        // If no window exists, create one
        const windows = BrowserWindow.getAllWindows();
        if (windows.length > 0) {
          const win = windows[0];
          win.show();
          win.focus();
        }
      }
    });

    // Handle notification close
    notification.on('close', () => {
      if (data.tag) {
        this.activeNotifications.delete(data.tag);
      }
    });

    // Show the notification
    notification.show();

    // Store notification if it has a tag
    if (data.tag) {
      this.activeNotifications.set(data.tag, notification);
    }
  }

  showTrayNotification(): void {
    if (!Notification.isSupported()) {
      return;
    }

    const notification = new Notification({
      title: 'Messenger',
      body: 'Messenger is running in the background. Click the tray icon to open.',
      silent: true,
    });

    notification.show();
  }

  closeNotification(tag: string): void {
    const notification = this.activeNotifications.get(tag);
    if (notification) {
      notification.close();
      this.activeNotifications.delete(tag);
    }
  }

  closeAllNotifications(): void {
    this.activeNotifications.forEach((notification) => {
      notification.close();
    });
    this.activeNotifications.clear();
  }
}

