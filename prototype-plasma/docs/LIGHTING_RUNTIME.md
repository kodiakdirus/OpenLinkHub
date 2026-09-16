# Lighting runtime recovery and identification

Source checkpoint, 2026-09-10. Deployment and physical acceptance are deferred.
This implements renderer recovery and a temporary whole-Cluster-member locator;
it does not claim to detect or program hardware-memory lighting.

## Source audit

| Family/path | Existing mode operations | Read-back and blocking findings | New boundary |
| --- | --- | --- | --- |
| LINK Hub (`lsh`) | Existing software/hardware mode transfers; software mode participates in device initialization | No reviewed physical-mode reader. RGB writes hold device locks and use HID transfers. | Physical mode `unknown`; existing brightness/current limiting remains downstream of the locator. No guessed mode writes. |
| K100 AIR (`k100airWU`, plus receiver-backed `k100airW`) | Existing hardware/software mode transfers; receiver-backed hardware handoff runs during receiver cleanup | No reviewed physical-mode reader. `ActiveRGB.Stop()` and HID/mutex waits can block cleanup. | Physical mode `unknown`; no inference from `GetRgbCluster()` or optional legacy JSON. |
| Scimitar wireless (`scimitarWU`) | Existing hardware/software mode transfers | No reviewed physical-mode reader. Driver shutdown and writes can block; this is the actual wireless driver, not the wired namesake. | Physical mode `unknown`; existing Cluster frame writer is retained. |
| SLIPSTREAM | Stops paired devices before hardware-mode handoff and HID close | September 10 log lacks receiver stop completion. Exact blocked instruction remains unproven without a runtime trace. | Resume processing independent of cleanup; termination deadline. |
| Cluster | Saved effect renderer, no hardware-mode authority | Unbuffered stop sends depended on a renderer waiting for all device writers. | Cancellation is independent of a receiver; replacement waits for actual old-generation completion. A stalled writer returns a bounded failure rather than spawning another writer. |
| Versioned reads and lighting writes | Shared registry/command locks | A blocked legacy dispatch could hold snapshot and write callers indefinitely. | Three-second HTTP deadline; one retained worker slot per read/mutation group prevents unbounded retries. Timeout is an unverified outcome, not driver cancellation. |

## Runtime contract

- `GET /api/v1/lighting/runtime`: `lighting-runtime` document, no-store.
- `PUT /api/v1/lighting/recover`: restart the saved **whole Cluster** renderer.
- `PUT /api/v1/lighting/identify`: temporary whole-member locator.
- `DELETE /api/v1/lighting/identify`: remove a matching lease.

The runtime document reports `mode`, `renderer`, `profile`, `members`,
`operations`, and optional `lease`. Physical `mode` remains `unknown` for the
reviewed families. `renderer=running` means frame callbacks completed recently;
legacy void callbacks do not prove HID success or visible LED output.

`expectedRevision` comes from this runtime catalog, not `/api/v1/snapshot`.
It fingerprints the saved scene name and member IDs, fits a JavaScript safe
integer, and stays stable across heartbeat and lease updates. Configuration
snapshot revisions are unaffected by identification. Catalog revision is not a
physical-state attestation or an atomic guard against unrelated legacy clients.

Recovery returns `effect-restarted` only after a new renderer completes a frame
and the catalog precondition still matches. It does not reassert a device's
physical software-mode handshake: support for measured physical mode and safely
verified handshake recovery remains a protocol-specific follow-up under #63.
A permanently blocked kernel/HID writer remains unrecoverable in-process; the
new operation reports failure, and process restart remains the fallback.

Identification accepts one published whole member and 1000–5000 ms, using a
fixed modest-white overlay. The first implementation intentionally has one
lease across the synchronized renderer, rather than independent concurrent
leases for each physical member. Matching lease replacement restores the old
overlay first; unrelated leases get `busy`. Cancel is idempotent. Expiry is
checked in frame generation independently of client lifetime, and a server
timer removes the overlay. Shutdown removes the overlay. No profile save,
assignment, membership, or cooling mutation is used. Individual/channel
identification is not advertised in this checkpoint.

Restoration verifies removal of the in-memory override. The next successful
frame uses the current saved scene. A frame already inside an unresponsive HID
write cannot be retracted, so physical restoration remains unverified until
hardware output is observed. Failed cleanup retains an explicit
`restore-unverified` lease. No timeout releases the actual driver operation slot.

## Plasma interaction

The device Lighting page has a live-health card that refreshes independently of
the potentially stalled normal snapshot. Older backends disable its operations.
The ownership card and Cluster editor show the runtime catalog's configured
scene (for example, Nebula) and renderer status for the selected Cluster member.
Saved individual effects remain separate, explicitly inactive, and collapsed
while Cluster or OpenRGB controls the device. They do not describe the Cluster
scene. Missing runtime data shows “Not reported” rather than an individual effect;
scene and renderer updates do not replace local effect drafts.
Recovery has a review dialog naming its whole-Cluster effect. Identification is
an explicit three-second action for the selected whole member; switching device
or closing the editor requests cancellation, and server expiry is the final
fallback. This does not automatically identify an individual Hub channel.

## Validation and remaining acceptance

Fake tests cover blocked renderer/writer completion, bounded HTTP responses and
retained slots, stale/invalid requests, lease expiry, replacement, cancellation,
restoration failure, shutdown, and isolation of selected-member overlay bytes.
No tests send real HID commands. Before deployment, preserve accepted source
`07b215cc` / selector `60` and run the canonical CanisLabus Runbook 32.11 hardware
acceptance, including cooling assignments and user-confirmed visible lighting.

## Candidate review hardening

The subsequent source review found and corrected these gaps before packaging:

- Runtime operations now share admission with legacy/versioned lighting writes;
  the active-lease guard runs inside that gate. A late runtime driver retains
  both gates until actual completion, preventing a race with legacy mutations.
- Recovery and identification pass the expected catalog revision into the
  adapter and check it again under the Cluster lifecycle lock. Multiple channel
  controllers belonging to one physical member are deduplicated in the catalog.
- Lease expiry is installed before identification dispatch. Errors, panics,
  cancellation, and late completion remove the override before releasing the
  operation slot. Shutdown closes admission and joins in-flight identification
  before checking/restoring its lease; a stalled restore has a bounded caller.
- Sleep and normal shutdown invoke runtime cleanup before stopping devices.
- Plasma discards pre-command polls, queues cancellation when an editor closes
  during a request, and rejects malformed runtime catalogs. Oversized HTTP
  command bodies are rejected rather than silently truncated.

The family investigation confirmed ordinary blocking `Read` calls in LINK Hub,
K100 AIR USB, receiver-backed K100, and Scimitar USB transfer methods. K100 AIR
USB mode helpers call `Fatal` on transfer errors; the other reviewed helpers
log errors without returning a verified physical mode. K100 connection-mode and
sleep-mode commands are not hardware/software lighting-mode read-back. None is
repurposed into a physical-mode recovery operation in this candidate.

The reviewed binary must include the separately tracked CanisLabus K100 toggle
patch in an isolated build tree, with source/patch/binary/UI checksums recorded.
Building the unpatched source alone is not an equivalent deployment candidate.
