// Notification injection script - injected into page context after load
// Based on Caprine's approach: https://github.com/raztronaut/caprine

((window, notification) => {
  const notifications = new Map<number, any>();

  // Handle events sent from the browser process (via preload)
  window.addEventListener('message', ({data}: MessageEvent) => {
    if (!data || typeof data !== 'object') return;
    
    const {type, data: eventData} = data as {type: string; data: any};
    
    if (type === 'notification-callback') {
      const {callbackName, id} = eventData;
      const notification = notifications.get(id);
      if (!notification) return;
      
      if (notification[callbackName]) {
        notification[callbackName]();
      }
      
      if (callbackName === 'onclose') {
        notifications.delete(id);
      }
    }
  });

  let counter = 1;

  const augmentedNotification = Object.assign(
    class {
      private readonly _id: number;

      constructor(title: string, options?: NotificationOptions) {
        // According to Caprine, Messenger can call Notification with React props
        // Handle React props in title and body
        let {body} = options || {};
        const bodyProperties = (body as any)?.props;
        body = bodyProperties ? bodyProperties.content?.[0] : (options?.body || '');

        const titleProperties = (title as any)?.props;
        title = titleProperties ? titleProperties.content?.[0] : (title || '');

        this._id = counter++;
        notifications.set(this._id, this as any);

        // Send notification via a bridge function exposed by preload
        // The preload script will inject a bridge function into the page context
        if ((window as any).__electronNotificationBridge) {
          (window as any).__electronNotificationBridge({
            title: String(title),
            body: String(body),
            id: this._id,
            icon: options?.icon,
            tag: options?.tag,
            silent: options?.silent,
          });
        } else {
          // Fallback: try postMessage (may not work with context isolation)
          window.postMessage(
            {
              type: 'notification',
              data: {
                title: String(title),
                body: String(body),
                id: this._id,
                icon: options?.icon,
                tag: options?.tag,
                silent: options?.silent,
              },
            },
            '*',
          );
        }
      }

      // No-op, but Messenger expects this method to be present
      close(): void {
        // Notifications are handled by the main process
      }

      addEventListener(event: string, listener: EventListener | null): void {
        // Store listeners for callback handling
        if (!listener) return;
        if (!(this as any).listeners) {
          (this as any).listeners = new Map();
        }
        if (!(this as any).listeners.has(event)) {
          (this as any).listeners.set(event, []);
        }
        (this as any).listeners.get(event).push(listener);
      }

      removeEventListener(event: string, listener: EventListener | null): void {
        if (!listener || !(this as any).listeners) return;
        const listeners = (this as any).listeners.get(event);
        if (listeners) {
          const index = listeners.indexOf(listener);
          if (index > -1) {
            listeners.splice(index, 1);
          }
        }
      }

      static requestPermission(): Promise<NotificationPermission> {
        return Promise.resolve('granted');
      }

      static get permission(): NotificationPermission {
        return 'granted';
      }
    },
    notification,
  );

  // Override window.Notification
  Object.assign(window, {Notification: augmentedNotification});
  
  // Also try to make it non-configurable (may fail in some contexts)
  try {
    Object.defineProperty(window, 'Notification', {
      value: augmentedNotification,
      writable: false,
      configurable: false,
      enumerable: true,
    });
  } catch (e) {
    // Fallback - already set via Object.assign above
    console.log('[Notification Inject] Using fallback override method');
  }
})(window, Notification);

