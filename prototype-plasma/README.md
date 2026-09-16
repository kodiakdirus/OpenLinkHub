# OpenLinkHub Plasma — community alpha

The desktop client can be packaged independently of the OpenLinkHub service.
See [public testing and installation](docs/PUBLIC_TESTING.md) and
[packaging, release workflow and upstream boundaries](docs/PACKAGING.md).

This is a native Qt 6/Kirigami desktop client in development.
The first launch uses self-contained Demo mode; later launches remember the
data source selected in the top bar. The versioned contract includes guarded
label editing and one deliberately narrow lighting assignment command. Both use
typed commands, expected state revisions, and read-back verification. Lighting
assignment is limited to existing profiles on explicitly authorized LINK Hub
channel targets; profile-definition editing remains a local preview.

## Run

From the OpenLinkHub repository root:

```bash
./prototype-plasma/run.sh
```

Source runs require Python 3, PyQt6, and the system Kirigami and Qt Quick QML
modules. The Flatpak package supplies a matching runtime for these dependencies.

To start directly in Live mode:

```bash
./prototype-plasma/run.sh --live
```

Live mode is fixed to `http://127.0.0.1:27003`. The top-bar data-source selector
can switch between Demo and Live at runtime. `--demo` and `--live` override the
saved startup choice for that launch. Switching modes never applies a profile.

Appearance and cell layouts save automatically under
`$XDG_CONFIG_HOME/openlinkhub-plasma/preferences.json` (normally
`~/.config/openlinkhub-plasma/preferences.json`). Service → Reset appearance and
layouts restores presentation defaults while keeping the saved data source.
Demo hardware controls and unsaved hardware drafts are not persisted there.
Screenshot and smoke-test runs use isolated temporary preferences.

See [daily-use behavior and remaining scope](docs/DAILY_USE.md).

### Desktop portal warning when launching from a Snap editor

If startup prints `Can't manually register a io.snapcraft application`, the
desktop portal has identified the GUI process as belonging to a Snap application.
This can happen when launching the source client from Snap-installed VS Code:
the child inherits its Snap process group, even if the terminal has cleared the
`SNAP` environment variable. Qt then attempts native desktop registration while
the portal still identifies the process as a Snap.

Launch the source client from a separate desktop terminal such as Konsole to
avoid inheriting the editor's process group. Clearing `SNAP` alone does not fix
the mismatch. For normal testing, use the installed Flatpak's **OpenLinkHub
Plasma** application-menu entry; the package supplies its own desktop identity.

A source checkout without an installed desktop entry can instead report
`App info not found for 'io.github.kodiakdirus.OpenLinkHubPlasma'`. That is a
separate desktop-registration issue. The GUI can start despite these warnings,
but portal integration may be affected. Neither message reports an OpenLinkHub
service connection failure or requires a backend restart. Do not globally
disable desktop portals to suppress the output; file dialogs and other desktop
integration use them.

For a deterministic offscreen render:

```bash
./prototype-plasma/run.sh --page cooling \
  --dialog \
  --screenshot /tmp/openlinkhub-plasma.png

./prototype-plasma/run.sh --page input \
  --arrange \
  --screenshot /tmp/openlinkhub-layout.png

./prototype-plasma/run.sh --live \
  --page device \
  --device-index 0 \
  --device-tab Lighting \
  --screenshot /tmp/openlinkhub-device-lighting.png
```

To instantiate every workspace, device shell, and device tab without opening a
visible window (QML warnings fail the check; Live requires a connected service):

```bash
./prototype-plasma/run.sh --smoke-test
./prototype-plasma/run.sh --live --smoke-test
python3 -m unittest discover -s prototype-plasma/tests -v
```

## Included interactions

- Native Breeze/Plasma controls and icon theme
- Searchable global workspaces and device commands
- Dedicated global profile library with game/application launch-rule concepts
- Demo global-profile selector and a composition editor that references
  saved cooling, lighting, keyboard, mouse, controller, audio, and LCD profiles
- Capability-aware device tabs
- Live Lighting, Input, Audio, and Displays workspaces that select devices by
  available capabilities, show only their own domain's controls, and retain
  selection through telemetry refresh; the full device tab set stays in Devices
- Live integration status from the service, with explicit availability screens
  for global profiles and automation editing
- Persistent appearance, data-source preference, and per-workspace/device-tab
  cell layouts, with a working presentation reset
- Window-close protection during commands and unsaved fan-curve drafts
- Asynchronous loopback transport with explicit connection, degraded,
  stale-data, refresh, and Demo/Live states
- Additive `GET /api/v1/service`, `/api/v1/capabilities`, and
  `/api/v1/snapshot` documents with semantic capabilities, safe configuration
  summaries, normalized devices/channels/profiles, and monotonic revisions
- One-request contract snapshot refresh with strict version/kind validation and
  an explicit legacy compatibility fallback for deployed older services
- Separate configuration and telemetry revisions, strong ETag revalidation,
  and no model replacement on `304 Not Modified`
- Guarded `PUT /api/v1/devices/label` editing for backend-published device and
  channel targets, including stale-revision rejection and verified read-back
- Capability-gated `PUT /api/v1/lighting/assignment` for existing effects on
  supported LINK Hub channels, including read-back and recovery verification
- Capability-gated `PUT /api/v1/lighting/ownership` for explicit whole-device
  Individual/RGB Cluster transitions, including stale-owner checks, read-back,
  recovery verification, and one-device-at-a-time Cluster membership editing
- Legacy response normalization for product-specific hub, keyboard, mouse, and
  other device payloads
- Read-only live CPU, GPU, coolant, fan/pump RPM, firmware, battery, channel,
  profile, and capability summaries
- Per-device live Lighting tabs with physical target selection, the backend's
  complete device-filtered effect library, guarded assignment where published,
  and an explicitly local-only parameter-definition draft
- Stable device and tab identities plus a presentation-stable tab model, so
  both loaded content and the visible tab indicator survive telemetry refresh
- Background polls retain the last connection state and unchanged header,
  capability, target, and effect models instead of flashing application chrome
- Telemetry updates values through stable identity-keyed presentation models;
  open cooling/profile choices, expanded channel details, global search,
  per-device controls, RGB Cluster membership drafts, Overview cells, filters,
  and scroll owners are not recreated on an ordinary poll
- Stable Devices-page filter/card presentation with deterministic card ordering;
  user-relevant hidden wireless transports appear as receiver cards while
  internal cluster/helper records remain excluded
- Sanitized response fixtures, reconnect/failure and guarded-command tests, a GUI-wide
  refresh-state exercise, and a static guard against binding live arrays
  directly to stateful controls
- A machine-readable contract schema plus a bounded golden snapshot covering
  controller/cooling, keyboard, mouse, and receiver presentation families
- Mock Quiet, Balanced, Performance, and Custom operating modes
- Interactive cooling-curve profile manager
- Custom lighting-scene editor, targets, brightness, and hardware-lighting controls
- Display-idle lights-out automation concept
- Configurable Plasma System Monitor sensor-export concept for coolant, pump,
  fan, battery, and other read-only Corsair telemetry
- Keyboard, mouse, audio, display, automation, and integration surfaces
- VS Code-inspired Dark Modern default, retained Midnight/Dim/Light themes,
  accent choices, density, corner, and sidebar presentation controls
- Consistent nested-cell insets and fixed icon columns on Overview, plus shared
  icon/title/subtitle alignment across Service cards
- Constrained per-workspace and per-device-tab cell ordering with half/full-row
  sizing and equal-height neighbors to prevent masonry-style gaps
- Local notifications and explicit Demo, legacy-read-only, and guarded-Live state

Demo hardware values and local control previews reset when the application exits.
Live writes include published labels, capability-authorized lighting assignment,
ownership and runtime operations, and existing saved fan curves. The client
exposes no generic mutation method. Input/audio/display configuration,
global profiles, automations, integration setup and administration remain
unimplemented; Live mode shows reported state or an availability explanation.

## Source-only runtime checkpoint

The Lighting page now includes independent renderer health, a reviewed saved
Cluster renderer restart, and a three-second whole-member locator lease.
Physical mode stays `unknown` where the driver has no reviewed read-back.
The checkpoint also bounds stalled API callers and suspend/shutdown recovery.
See [runtime details and remaining hardware acceptance](docs/LIGHTING_RUNTIME.md).
Running source tests does not deploy backend changes. The client detects which
runtime operations the installed service publishes.

## Architecture boundary

The intended production boundary remains:

```text
OpenLinkHub service/API
        ├── Web client
        └── Native Plasma client
```

Device behavior, validation, safety policy, and persistent state stay in the
service. QML consumes normalized Qt properties and does not construct URLs or
decode arbitrary JSON.

The source-derived production plan is documented in:

- [Backend integration plan](docs/BACKEND_INTEGRATION_PLAN.md)
- [Complete backend route inventory](docs/BACKEND_ROUTE_INVENTORY.md)
- [Versioned read contract](docs/CONTRACT_V1.md)

The existing WebUI is served by the OpenLinkHub Go service and uses same-origin
HTTP requests to `/api/...`. The native client first reads
`/api/v1/snapshot`; strict contract validation rejects the generic legacy
`/api/` response returned by older services and selects the typed compatibility
adapter instead. It never accesses Corsair USB devices or service-owned files.
Global profiles still require a backend-owned composition contract so their
cooling, lighting, and per-device references can eventually be validated,
applied, and recovered as one operation.

## Live fan curves

Cooling → Manage cooling profiles now edits existing saved **fan** curves in
Live mode. Radiator20 is selected when available. Save applies immediately to
all fans using that profile, with a fresh-baseline check, private recovery copy,
and full-profile read-back. Pump curves and assignments are preserved. The
existing deployed graph-profile API is used; no backend restart is required.
See [Cooling curve behavior and limits](docs/COOLING_CURVES.md).
