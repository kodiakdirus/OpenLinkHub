# Guarded lighting command design

**Status:** Assignment checkpoint implemented for capability-authorized iCUE
LINK System Hub channels. Identification remains design-only.

**Structural progress:** The typed application service, narrow ports, locked
registry snapshot, target metadata, fake recovery tests, fail-closed legacy
adapter, versioned route, and Plasma client adapter are implemented. An exact
LINK Hub driver/method check publishes `assign-profile` only on channel targets.
No target publishes `identify`.

## Goal

Expose the useful parts of OpenLinkHub lighting as typed, capability-gated
operations without handing clients the legacy catch-all payloads. The first
write checkpoint changes one published target's assigned profile and verifies
the normalized result. A separate leased operation identifies a physical
target without changing persistent configuration.

This design keeps the Go service as the only USB/HID and persistence authority.
The Web UI and legacy routes remain available. The Plasma client never calls a
driver method or constructs a legacy request.

## Source audit

The existing backend has several distinct lighting families:

| Family | Legacy routes or methods | Persistence and risk |
|---|---|---|
| Profile assignment | `POST /api/color`, `UpdateRgbProfile`, bulk/global variants | Usually updates the device profile, saves it, restarts the renderer, and can affect one channel, a whole device, or every device |
| Profile definition | `PUT /api/color/change`, gradient add/delete | Rewrites a device RGB library; editing a shared active profile can affect several targets immediately |
| LINK adapters | `POST /api/color/linkAdapter`, bulk variant | Uses nested channel/adapter identifiers and separate profile maps |
| Per-LED and override data | `setLedData`, override and cluster routes | Device-specific shapes; may transfer ownership or rewrite topology-sized maps |
| Peripheral zones | Keyboard, mouse, controller, headset, and miscellaneous color routes | Product-specific payloads and persistence behavior |
| Hardware/offline lighting | `POST /api/color/hardware` | Changes the lighting used without the running service |
| Global and scheduled lighting | global/all-device routes and scheduler | Broad blast radius and different recovery requirements |

The legacy profile-assignment handler validates a device and profile, invokes a
driver, and trusts its integer return code. LINK System Hub assignment also
saves the device profile and restarts the active renderer. It does not provide
an independent persistence result or normalized verification. Global and bulk
routes are therefore unsuitable as the first versioned lighting write.

## Deliberate first boundary

The first implementation should add only:

1. one persistent profile assignment for one published target; and
2. one non-persistent identification lease for one published target.

Profile editing, gradients, brightness, global scenes, bulk assignment,
hardware/offline lighting, LINK adapter subdevices, per-key/per-LED data,
OpenRGB ownership, clusters, schedules, and peripheral-specific zones remain
read-only or local previews. Each requires its own target and recovery model.

## Read-model extension

The existing `lighting.targets` entries need enough authorization data to stop
clients from guessing driver identifiers:

```json
{
  "id": "channel:13",
  "scope": "channel",
  "channelId": 13,
  "name": "Top radiator fan",
  "description": "RX RGB · channel 13",
  "activeProfile": "static",
  "supportedProfileIds": ["static", "liquid-temperature"],
  "operations": ["read", "assign-profile", "identify"],
  "identifiable": true
}
```

Stable target IDs are `device`, `channel:<id>`, and later
`adapter:<channel>:<subdevice>`. The first write implementation accepts only
`device` and `channel:<id>`. A target publishes `assign-profile` only when the
service can dispatch and read back that exact assignment. It publishes
`identify` only when the driver provides a transient, non-persistent override
and OpenRGB/cluster/external ownership does not prevent safe control.

The device lighting capability remains `read` unless at least one target has a
write operation. It then advertises only the union of implemented operations,
for example `read`, `assign-lighting`, and `identify-lighting`. A profile ID is
valid only when it appears in both the device library and the target's
`supportedProfileIds`.

## Persistent assignment

Proposed route:

```text
PUT /api/v1/lighting/assignment
```

Request:

```json
{
  "expectedRevision": 41,
  "deviceId": "hub-serial",
  "targetId": "channel:13",
  "profileId": "static"
}
```

The server must, under the same mutation lock used by guarded labels:

1. rebuild current normalized state;
2. reject a stale revision before driver dispatch;
3. resolve the device and target only from published capability data;
4. require `assign-profile` and a published supported profile;
5. capture the target's current profile as the recovery value;
6. dispatch one target-specific driver operation;
7. invalidate the lighting-library cache when a future definition operation
   can affect the verification projection;
8. rebuild state and require exact target/profile read-back;
9. return success only after verification.

Assignment changes persistent configuration, so successful read-back advances
the state revision. A driver success with mismatched read-back is a failed
command. The server should immediately attempt to restore the captured profile,
then report one of:

- `succeeded` — requested assignment verified;
- `failed-restored` — requested state did not verify, but the previous profile
  was restored and verified;
- `failed-restore-unverified` — neither requested nor recovery state could be
  proven; the client must show a persistent high-severity warning.

The response includes previous/requested/observed profiles and recovery status.
It must not claim durable persistence while service persistence remains
`unknown`. A no-op request returns `succeeded`, `changed: false`, and does not
dispatch to the driver.

## Transient target identification

Proposed routes:

```text
PUT    /api/v1/lighting/identify
DELETE /api/v1/lighting/identify
```

Starting identification requires the current state revision, a published
target, and a duration from 1,000 through 5,000 milliseconds. The client does
not choose arbitrary colors or animation data in the first slice. The service
uses one tested high-contrast pattern so the operation stays narrow.

Identification requires a new driver boundary; it must not call
`UpdateRgbProfile`, because that method persists assignments. A conforming
driver pauses or overlays its runtime renderer, illuminates only the target,
and resumes the renderer from current persistent state. Resuming the same
profile is guaranteed; resuming the exact animation phase is not.

The server owns a single lease per physical device. It returns an opaque lease
ID and bounded expiry. Starting another target with the same lease replaces the
old target after restoration; an unrelated lease receives `409 busy`.
Cancellation is idempotent and requires the matching lease ID. The server
restores on explicit cancel, target change, dialog close, Apply, Cancel,
timeout, command failure, or service shutdown. HTTP cannot reliably detect a
client disappearing, so the short server-side expiry is the final guarantee.

Identification is runtime state, not configuration. Starting, renewing, or
cancelling a lease does not advance the configuration revision and never saves
a profile. The GUI provides both a strong selected-row highlight and the
channel/name text; physical color is an additional locator, not the only cue.
Selecting a new target triggers one short identification pulse, and an
**Identify again** action renews it.

## Validation and error mapping

| Condition | HTTP | Driver called | User result |
|---|---:|---:|---|
| Malformed or unknown field | 400 | No | Correct the request |
| Unknown device/target/profile | 404 | No | Refresh inventory |
| Stale state revision | 409 | No | Refresh and review selection |
| Device externally owned or lease busy | 409 | No | Explain the owning feature |
| Unsupported operation or invalid duration | 422 | No | Control becomes unavailable |
| Driver rejection | 500 | Yes | Failure with observed current state |
| Read-back mismatch, recovery verified | 500 | Yes | Failed, safely restored |
| Recovery unverified | 500 | Yes | Persistent high-severity warning |

All command responses use `Cache-Control: no-store`. Logs may contain stable
device and target IDs but not HID handles, arbitrary payload dumps, or profile
file paths.

## Client interaction

- Demo mode previews assignment and identification locally with zero requests.
- Legacy compatibility mode shows the lighting library read-only and explains
  that the installed service lacks guarded lighting commands.
- Contract mode enables controls only from target operations.
- The editor keeps one local draft. Apply shows affected target, previous
  profile, requested profile, and recovery implications.
- While a command is pending, the target/profile controls are locked but live
  telemetry continues.
- A stale response refreshes the model without silently reapplying the draft.
- `failed-restored` keeps the dialog open with the prior profile selected.
- `failed-restore-unverified` cannot be dismissed as success and links to
  recovery guidance.

## Implementation checkpoints

1. Extend normalized target identity and capability publication with fixtures
   and Go tests; keep operations read-only.
2. Add a fake dispatcher and server tests for assignment validation, no-op,
   stale revision, driver failure, read-back, and recovery outcomes.
3. Connect the assignment route and Plasma adapter behind the published
   operation; perform no live hardware test.
4. Add the transient driver interface, fake lease manager, timeout/cancel tests,
   and client UI behavior; keep real drivers non-identifiable by default.
5. Review the UI and recovery presentation in Demo/fake mode.
6. Prepare a separate, explicitly authorized live plan using one known channel,
   a byte-for-byte profile backup, exact before/after reads, a short identify
   lease, one reversible assignment, cooling/input validation, and full backout.

No later checkpoint is authorized merely by accepting this design.
When a device reports that OpenRGB integration or RGB Cluster control is
active, its physical lighting targets remain visible but do not publish
`assign-profile`. The target description identifies the controlling subsystem;
the client must not imply that a per-target assignment can succeed while that
subsystem owns the device.
