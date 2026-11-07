# Midnight Aurora

Select **Midnight Aurora** (`midnight-aurora`) in RGB Cluster's effect selector.
It is a separate effect; Nebula remains available with its original palette.

The exact palette anchors are `#080B14`, `#10162F`, `#252558`, `#7248D9`,
`#29D3C2`, `#EC6F78`, and `#F2B45F`, interpolated in RGB. Nebula's slow
sinusoidal movement and subdued base brightness are retained. Sparse twinkles
use the same palette at the selected brightness rather than random hues.

The new default profile uses speed 5, matching Nebula. Existing Cluster catalogs
receive the missing profile additively at startup; saved effect selection,
brightness and existing profiles are preserved. Individual device effect
catalogs are unchanged. The native Cluster selector consumes the backend catalog.

A backend binary plus the updated `database/rgb.json` must be deployed before
this effect is available on hardware. Source tests do not establish physical
LED appearance. Select Nebula again to restore the previous effect.
