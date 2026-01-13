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
 * Override getUserMedia to track all MediaStreams created during calls
 * This allows us to stop all tracks when the window closes
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

    // Log details about each track
    stream.getTracks().forEach((track) => {
      console.log(
        `[Call Window]   - ${track.kind} track: ${track.id} (enabled: ${track.enabled})`,
      );
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

console.log("[Call Window] Preload script loaded - MediaStream cleanup enabled");
