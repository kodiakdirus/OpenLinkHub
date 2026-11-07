# Midnight Aurora

Select **Midnight Aurora** (`midnight-aurora`) in RGB Cluster's effect selector.
It is a separate effect; Nebula remains available with its original palette.

The active palette is bright indigo `#5858D0`, violet `#7248D9`, teal
`#29D3C2`, coral `#EC6F78`, and amber `#F2B45F`. The reference image's two
near-black background stops (`#080B14` and `#10162F`) are omitted; the original
indigo (`#252558`) is lifted at the same hue/saturation. This removes intentional
near-black dimming phases on keys and fans, while retaining
the chromatic range. Physical visibility remains a user-observed property.

Hue/saturation/value interpolation preserves saturation through the teal/coral
transition; it routes through blue/violet. Coral and amber retain their accepted
25% saturation lift. Sparse twinkles use the same palette at selected brightness.
Global brightness controls and base gain are retained.

The new default profile uses speed 5, matching Nebula. Existing Cluster catalogs
receive the missing profile additively at startup; saved effect selection,
brightness and existing profiles are preserved. Individual device effect
catalogs are unchanged. The native Cluster selector consumes the backend catalog.

A backend binary plus the updated `database/rgb.json` must be deployed before
this effect is available on hardware. Source tests do not establish physical
LED appearance. Select Nebula again to restore the previous effect.

After physical acceptance of the richer warm colors, spatial waves were shortened
to a 24-LED wavelength (or the full LED count on smaller standalone frames).
This keeps warm and cool colors visible together within short spans of a
large Cluster instead of stretching one wave across every concatenated device.
Accepted saturation and brightness remain unchanged. A later motion refinement
shortens the default cycle from 25 seconds to 10 seconds so the shorter waves
visibly travel across LEDs (about 2.4 LEDs/second) rather than appearing static.
The speed control still scales the cycle duration.
