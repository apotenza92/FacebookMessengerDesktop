// Notification injection script - injected into page context after load

((window, notification) => {
  const DEBUG_FALLBACK = true;
  const notifications = new Map<number, any>();
  let fallbackEnabled = false;
  let lastUnreadNotified = 0;

  const emitFallbackLog = (eventName: string, payload?: any) => {
    try {
      window.postMessage(
        {
          type: 'electron-fallback-log',
          data: {
            event: eventName,
            payload,
          },
        },
        '*',
      );
    } catch (_) {}
  };

  // Helper to get text content including emoji from img alt attributes
  // Messenger renders emojis as <img alt="😀"> elements
  const getTextWithEmoji = (el: Element): string => {
    let result = '';
    const walk = (node: Node) => {
      if (node.nodeType === Node.TEXT_NODE) {
        result += node.textContent || '';
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        const elem = node as Element;
        // Check if it's an emoji img
        if (elem.tagName === 'IMG') {
          const alt = elem.getAttribute('alt') || '';
          // Only include if it looks like an emoji (short, usually 1-2 chars)
          if (alt && alt.length <= 4) {
            result += alt;
          }
        } else {
          // Recurse into child nodes
          for (const child of Array.from(node.childNodes)) {
            walk(child);
          }
        }
      }
    };
    walk(el);
    return result.trim();
  };

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
          try {
            console.log('[Notif Inject] Forwarding via bridge', { id: this._id, title, body });
          } catch (_) {}
          (window as any).__electronNotificationBridge({
            title: String(title),
            body: String(body),
            id: this._id,
            icon: options?.icon,
            tag: options?.tag,
            silent: options?.silent,
          });
        } else {
          try {
            console.warn('[Notif Inject] Bridge missing, falling back to postMessage', { id: this._id, title, body });
          } catch (_) {}
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

      // Messenger sometimes tries to set Notification.permission; provide a harmless setter to avoid errors
      static set permission(_value: NotificationPermission) {
        // no-op
      }
    },
    notification,
  );

  // Best-effort fallback: if Messenger's service worker never registers (common when blocked),
  // watch unread count bumps and raise our own notification so the user still gets a banner.
  const setupFallbackIfNoServiceWorker = () => {
    const parseUnreadCount = (title: string): number => {
      const match = title.match(/^\((\d+)\)/);
      return match ? parseInt(match[1], 10) : 0;
    };

    // Get the first thread from the chat list (new messages bump threads to top)
    const getNewestThread = (): { name: string; snippet: string } | null => {
      const chatsGrid = document.querySelector('[role="grid"][aria-label="Chats"]');
      if (!chatsGrid) return null;

      const rows = Array.from(chatsGrid.querySelectorAll('[role="row"]'));
      
      for (const row of rows) {
        const firstCell = row.querySelector('[role="gridcell"]');
        if (!firstCell) continue;
        const cellAria = (firstCell.getAttribute('aria-label') || '').trim();
        if (cellAria.startsWith('More options')) continue;

        // Extract name from nested elements
        const nameEl = firstCell.querySelector('[dir="auto"]');
        const name = nameEl ? getTextWithEmoji(nameEl) : '';
        if (!name) continue;
        
        // Find the message preview
        const allDirAuto = firstCell.querySelectorAll('[dir="auto"]');
        let snippet = '';
        allDirAuto.forEach((el, idx) => {
          const t = getTextWithEmoji(el);
          if (idx > 0 && t && !/^\d+[mhdw]$/.test(t) && t !== '·' && t !== 'Unread message:') {
            if (!snippet) snippet = t;
          }
        });
        
        return { name, snippet: snippet || 'New message' };
      }
      return null;
    };

    // Track notified thread+message combos to avoid duplicates
    const notifiedThreads = new Map<string, number>(); // key: "name|snippet", value: timestamp
    const NOTIFIED_EXPIRY_MS = 300000; // Forget notified threads after 5 minutes (prevents re-notifying same message)

    const sendSingleNotification = (title: string, body: string) => {
      if ((window as any).__electronNotificationBridge) {
        (window as any).__electronNotificationBridge({
          title: String(title),
          body: String(body),
          id: Date.now() + Math.random(),
          silent: false,
        });
      } else {
        window.postMessage(
          {
            type: 'notification',
            data: {
              title: String(title),
              body: String(body),
              id: Date.now() + Math.random(),
              silent: false,
            },
          },
          '*',
        );
      }
    };

    const sendFallbackNotification = (unreadCount: number) => {
      const now = Date.now();

      // Clean up old notified entries
      for (const [key, ts] of notifiedThreads.entries()) {
        if (now - ts > NOTIFIED_EXPIRY_MS) {
          notifiedThreads.delete(key);
        }
      }

      // Get the newest thread (new messages bump their thread to top of list)
      const thread = getNewestThread();
      
      if (thread) {
        const key = `${thread.name}|${thread.snippet}`;
        const lastNotified = notifiedThreads.get(key);
        if (lastNotified && now - lastNotified < NOTIFIED_EXPIRY_MS) {
          if (DEBUG_FALLBACK) {
            try {
              emitFallbackLog('thread-already-notified', { name: thread.name });
            } catch (_) {}
          }
          return;
        }

        // Send notification
        notifiedThreads.set(key, now);
        
        if (DEBUG_FALLBACK) {
          try {
            emitFallbackLog('send-notification', { name: thread.name, snippet: thread.snippet.slice(0, 100) });
          } catch (_) {}
        }

        sendSingleNotification(thread.name, thread.snippet);
        return;
      }

      // Fallback: couldn't find thread info even with scroll
      // Send a generic notification so the user still knows they have a message
      const genericKey = `__generic__|${unreadCount}`;
      const lastGeneric = notifiedThreads.get(genericKey);
      if (lastGeneric && now - lastGeneric < NOTIFIED_EXPIRY_MS) {
        if (DEBUG_FALLBACK) {
          try {
            emitFallbackLog('generic-already-notified');
          } catch (_) {}
        }
        return;
      }

      notifiedThreads.set(genericKey, now);
      
      if (DEBUG_FALLBACK) {
        try {
          emitFallbackLog('send-generic-notification', { unreadCount });
        } catch (_) {}
      }

      const plural = unreadCount === 1 ? 'message' : 'messages';
      sendSingleNotification('Messenger', `You have ${unreadCount} unread ${plural}`);
    };

    const watchTitleChanges = () => {
      let lastTitle = document.title;
      lastUnreadNotified = parseUnreadCount(lastTitle);
      let pendingNotification: ReturnType<typeof setTimeout> | null = null;

      const observer = new MutationObserver(() => {
        if (document.title === lastTitle) return;
        lastTitle = document.title;
        const unread = parseUnreadCount(lastTitle);
        
        // Only notify when count increases and window not focused
        if (
          unread > lastUnreadNotified &&
          (document.visibilityState === 'hidden' || !document.hasFocus())
        ) {
          if (DEBUG_FALLBACK) {
            try {
              emitFallbackLog('title-trigger', { prev: lastUnreadNotified, next: unread });
            } catch (_) {}
          }
          lastUnreadNotified = unread;
          
          // Clear any pending notification to avoid duplicates
          if (pendingNotification) {
            clearTimeout(pendingNotification);
          }
          
          // Wait a moment for DOM to update, then send notification
          pendingNotification = setTimeout(() => {
            pendingNotification = null;
            sendFallbackNotification(unread);
          }, 300);
        } else if (unread < lastUnreadNotified) {
          // Reset when unread decreases (user read messages) - no log needed
          lastUnreadNotified = unread;
        }
      });

      observer.observe(document.querySelector('title') || document.head, {
        childList: true,
        subtree: true,
        characterData: true,
      });
    };

    // Delay slightly to let the page settle, then check for a service worker
    setTimeout(() => {
      navigator.serviceWorker
        ?.getRegistration()
        .then((reg) => {
          if (reg) {
            try {
              console.log('[Notif Fallback] Service worker present, fallback not needed');
              emitFallbackLog('sw-present');
            } catch (_) {}
            return;
          }
          fallbackEnabled = true;
          try {
            console.warn('[Notif Fallback] No service worker found, enabling title-based notifications');
            emitFallbackLog('fallback-enabled');
          } catch (_) {}
          watchTitleChanges();
        })
        .catch(() => {
          // If the check fails, enable fallback to be safe
          fallbackEnabled = true;
          watchTitleChanges();
        });
    }, 1500);
  };

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

  setupFallbackIfNoServiceWorker();
})(window, Notification);

