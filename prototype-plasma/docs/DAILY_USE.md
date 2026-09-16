# Plasma daily-use implementation checkpoint

This pass connects the existing live editors to the primary workspaces and
finishes client presentation persistence and fan-curve draft handling. Launch
the source client with `./prototype-plasma/run.sh --live`. No backend deployment
or service restart is required for these client changes.

## Live workspace behavior

| Workspace | Behavior |
| --- | --- |
| Overview | Real telemetry and shortcuts to Cooling, Lighting, Devices and Service. |
| Devices | Current inventory and capability-aware device tabs. |
| Cooling | Real grouped channel telemetry; saved fan-curve editing with backup and verified read-back. Simulated curves, safety assertions and assignment controls remain in Demo. |
| Lighting | Opens directly into lighting assignment, ownership and runtime controls for the selected device. |
| Input | Groups sensitivity, key/button assignments, controller behavior and input performance together. Only reported input capabilities appear. |
| Audio, Displays | Show headset audio or LCD information respectively, with no unrelated device controls. Unsupported settings remain read-only. |
| Profiles, Automations | Explain that live editing/activation is unavailable and offer navigation to working editors or Demo. |
| Integrations | Shows actual versioned service feature status. Configuration and Plasma sensor export remain unavailable. |
| Service | Appearance, layout reset, reported service version, connection and command feedback. |

Workspaces have a compact device selector and a View device action. The full
device header, capability badges, cross-domain tab bar and device footer appear
only under Devices. Missing values are consolidated into a capability-specific
explanation instead of rows of empty placeholders. Input and display workspaces
do not instantiate the lighting editor or poll lighting runtime.

Selections and lighting drafts survive normal polls. A removed selected device falls back to an
available device with its identity visible. Device tabs retain their read-only
unavailable descriptions, but unavailable capabilities do not qualify a device
for a live workspace. Offline/degraded connections show an explicit banner and
a retry action; retained device data is marked as last known state.

## Client state

Only appearance, data-source preference and cell order/width are persisted.
Preferences use a versioned JSON document and atomic replacement. Invalid fields
are ignored, unreadable files fall back to defaults with a visible error, and a
failed save retains the previous saved values. No hardware state is restored
from client preferences.

Device layouts are keyed by stable device ID and tab; workspace layouts use a
workspace identity. New cells append to saved order; removed cells disappear.
Reset presentation restores default appearance and layouts while preserving
the data-source preference. The lighting scene concept retains its own Demo
layout. Local hardware previews continue to reset on exit.

The curve editor validates drafts, preserves them through polls, updates its
baseline after a verified save, and requires an explicit discard for unsaved
close. Command verification prevents window close and data-source switching
until it completes. Existing service-side stale checks, recovery and leases
remain responsible for hardware behavior.

Backend setup is an optional dialog opened from Service, the setup reminder,
or the existing connection-failure banner. It never opens automatically. The
reminder appears only in Demo/legacy mode, waits for startup to settle, and
remembers dismissal separately from appearance settings. Routine reconnects
retain the last setup assessment to avoid flashing the reminder. Missing data
is not treated as proof that the service needs installing. The dialog provides
an explicit connection check and installation guidance; this alpha has no
compatible backend package or in-app installer.

## Verification

`python3 -m unittest discover -s prototype-plasma/tests` includes persistence,
malformed preferences, failed writes, actual QML navigation, layout restoration,
capability filtering, curve validation, polling, save-baseline handling, and
modal/window close checks. The new QML test records and rejects all mutations;
it uses sanitized fixtures and temporary preferences.

Both `--smoke-test` and `--live --smoke-test` instantiate all workspaces and each
device tab, fail on QML warnings, and use temporary preferences. The live test
waits for a service connection and fails if none arrives. Offscreen live renders
read real telemetry and saved curves without applying hardware changes.

Physical lighting acceptance, new peripheral write support, global-profile
composition, automation persistence, sensor export and administrative operations
remain separate work. This checkpoint does not claim full feature parity with
the existing Web UI.
