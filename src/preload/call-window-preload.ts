/**
 * Preload script for call windows that ensures proper cleanup of MediaStreams
 * Fixes issue #33: Microphone not released after calls end
 */

// Track all active MediaStreams
const activeStreams = new Set<MediaStream>();

// Store original getUserMedia function
const originalGetUserMedia = navigator.mediaDevices.getUserMedia.bind(
  navigator.mediaDevices,
);

/**
 * Check if all tracks in a stream have ended and clean up if so
 */
function checkStreamEnded(stream: MediaStream): void {
  const tracks = stream.getTracks();
  const allEnded = tracks.every((track) => track.readyState === "ended");

  if (allEnded && activeStreams.has(stream)) {
    console.log(
      `[Call Window] All tracks ended for stream ${stream.id} - cleaning up`,
    );
    activeStreams.delete(stream);
    console.log(
      `[Call Window] Stream removed. Active streams remaining: ${activeStreams.size}`,
    );
  }
}

/**
 * Override getUserMedia to track all MediaStreams created during calls
 * Listens for track 'ended' events to release microphone when call ends
 */
navigator.mediaDevices.getUserMedia = async function (
  constraints?: MediaStreamConstraints,
): Promise<MediaStream> {
  console.log("[Call Window] getUserMedia called with constraints:", constraints);

  try {
    const stream = await originalGetUserMedia(constraints);
    activeStreams.add(stream);

    console.log(
      `[Call Window] MediaStream acquired: ${stream.id} (tracks: ${stream.getTracks().length})`,
    );

    // Log details about each track and listen for 'ended' events
    stream.getTracks().forEach((track) => {
      console.log(
        `[Call Window]   - ${track.kind} track: ${track.id} (enabled: ${track.enabled})`,
      );

      // Listen for track ended event - fires when call ends or track is stopped
      track.addEventListener("ended", () => {
        console.log(
          `[Call Window] Track ended: ${track.kind} ${track.id}`,
        );
        checkStreamEnded(stream);
      });
    });

    return stream;
  } catch (error) {
    console.error("[Call Window] getUserMedia error:", error);
    throw error;
  }
};

/**
 * Stop all MediaStream tracks to release microphone/camera
 */
function stopAllMediaTracks(): void {
  console.log(
    `[Call Window] Cleanup: Stopping all media tracks (${activeStreams.size} streams)`,
  );

  let tracksStopped = 0;

  activeStreams.forEach((stream) => {
    stream.getTracks().forEach((track) => {
      if (track.readyState !== "ended") {
        console.log(
          `[Call Window] Stopping ${track.kind} track: ${track.id} (state: ${track.readyState})`,
        );
        track.stop();
        tracksStopped++;
      } else {
        console.log(
          `[Call Window] Track already ended: ${track.kind} ${track.id}`,
        );
      }
    });
  });

  activeStreams.clear();
  console.log(`[Call Window] Cleanup complete: ${tracksStopped} tracks stopped`);
}

/**
 * Cleanup when window is about to close
 * This event fires before the window is destroyed, ensuring reliable cleanup
 */
window.addEventListener("beforeunload", () => {
  stopAllMediaTracks();
});

/**
 * Additional cleanup on page hide (mobile/visibility changes)
 */
window.addEventListener("pagehide", () => {
  console.log("[Call Window] Page hide event - ensuring cleanup");
  stopAllMediaTracks();
});

/**
 * Detect when call ends via DOM observation
 * Messenger shows "Call ended" or similar UI when a call terminates
 */
function setupCallEndedDetection(): void {
  // Patterns that indicate the call has ended
  const callEndedPatterns = [
    /call ended/i,
    /call has ended/i,
    /you left the call/i,
    /left the call/i,
    /no answer/i,
    /unavailable/i,
    /couldn't connect/i,
    /connection lost/i,
    /call declined/i,
    /busy/i,
  ];

  let hasDetectedCallEnd = false;

  const checkForCallEnded = (text: string): boolean => {
    return callEndedPatterns.some((pattern) => pattern.test(text));
  };

  const handleCallEnded = (reason: string): void => {
    if (hasDetectedCallEnd) return;
    hasDetectedCallEnd = true;

    console.log(`[Call Window] Call ended detected: ${reason}`);
    console.log("[Call Window] Releasing microphone/camera...");
    stopAllMediaTracks();

    // Reset flag after a delay to handle multiple calls in same window
    setTimeout(() => {
      hasDetectedCallEnd = false;
    }, 5000);
  };

  // Observe DOM for call ended indicators
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      // Check added nodes
      for (const node of Array.from(mutation.addedNodes)) {
        if (node.nodeType === Node.ELEMENT_NODE) {
          const element = node as Element;
          const text = element.textContent || "";
          if (checkForCallEnded(text)) {
            handleCallEnded(`DOM text: "${text.slice(0, 50)}"`);
            return;
          }
        }
      }

      // Check modified text content
      if (mutation.type === "characterData") {
        const text = mutation.target.textContent || "";
        if (checkForCallEnded(text)) {
          handleCallEnded(`Text change: "${text.slice(0, 50)}"`);
          return;
        }
      }
    }
  });

  // Start observing once DOM is ready
  const startObserving = () => {
    observer.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true,
    });
    console.log("[Call Window] Call-ended detection active");
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", startObserving);
  } else {
    startObserving();
  }
}

// Initialize call-ended detection
setupCallEndedDetection();

console.log("[Call Window] Preload script loaded - MediaStream cleanup enabled");
