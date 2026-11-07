# Animation temperature refresh

The LINK Hub driver renders animation frames incrementally, using a telemetry
sample refreshed on the ordinary one-second LCD cadence. A long GIF no longer
holds the same readings until its entire loop completes. Source sensor polling
(e.g. the cooler's own temperature updates) remains unchanged.

Frame order and delay continue independently, including the last frame's delay;
updating readings does not restart the animation. Frames own their composition
buffers so live text never changes a cached background. CPU/GPU sensor getters
are rate-limited to the sampling cadence, not called for every animation frame.

The existing batch renderer remains available for other device drivers; this
incremental playback integration currently applies to LINK Hub animation mode.
No route, LCD setting, sensor assignment, font, color or layout change is needed.

Tests use distinct backgrounds, a real bundled font, changed sensor values,
frame wrap and a fake clock over an eight-second loop. They verify overlay
refresh, phase/timing preservation, cache immutability, bounded sampling and
legacy batch equivalence. Hardware playback/refresh remains a separate check.
