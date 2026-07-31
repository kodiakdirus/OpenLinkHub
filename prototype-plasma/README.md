# OpenLinkHub Plasma Prototype

This is a native Qt 6/Kirigami prototype for an OpenLinkHub desktop client.
It starts in self-contained Demo mode. Phase 2 adds an opt-in, GET-only
connection that prefers OpenLinkHub's additive contract 1.0 snapshot and
explicitly falls back to the legacy loopback reads on older services. No
hardware mutation callback or persistence path is implemented.

## Run

From the OpenLinkHub repository root:

```bash
./prototype-plasma/run.sh
```

The launcher checks for Python 3, PyQt6, and the system Kirigami QML module
before starting. SparkleDog already has those dependencies through its Plasma
installation.

To start directly in read-only Live mode:

```bash
./prototype-plasma/run.sh --live
```

Live mode is fixed to `http://127.0.0.1:27003`. The top-bar data-source selector
can switch between Demo and Live at runtime.

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

To instantiate every workspace and device shell without opening a visible
window:

```bash
./prototype-plasma/run.sh --smoke-test
./prototype-plasma/run.sh --live --smoke-test
python3 -m unittest discover -s prototype-plasma/tests -v
```

## Included interactions

- Native Breeze/Plasma controls and icon theme
- Searchable global workspaces and device commands
- Dedicated global profile library with game/application launch-rule concepts
- Persistent global-profile selector and a composition editor that references
  saved cooling, lighting, keyboard, mouse, controller, audio, and LCD profiles
- Capability-aware device tabs
- Asynchronous GET-only loopback transport with explicit connection, degraded,
  stale-data, refresh, and Demo/Live states
- Additive `GET /api/v1/service`, `/api/v1/capabilities`, and
  `/api/v1/snapshot` documents with semantic capabilities, safe configuration
  summaries, normalized devices/channels/profiles, and monotonic revisions
- One-request contract snapshot refresh with strict version/kind validation and
  an explicit legacy compatibility fallback for deployed older services
- Separate configuration and telemetry revisions, strong ETag revalidation,
  and no model replacement on `304 Not Modified`
- Legacy response normalization for product-specific hub, keyboard, mouse, and
  other device payloads
- Read-only live CPU, GPU, coolant, fan/pump RPM, firmware, battery, channel,
  profile, and capability summaries
- Per-device live Lighting tabs with physical target selection, the backend's
  complete device-filtered effect library, and a local-only parameter draft
- Stable device and tab identities plus a presentation-stable tab model, so
  both loaded content and the visible tab indicator survive telemetry refresh
- Background polls retain the last connection state and unchanged header,
  capability, target, and effect models instead of flashing application chrome
- Telemetry updates values through stable identity-keyed presentation models;
  open cooling/profile choices, expanded channel details, global search,
  per-device controls, Overview cells, filters, and scroll owners are not
  recreated on an ordinary poll
- Stable Devices-page filter/card presentation with deterministic card ordering;
  user-relevant hidden wireless transports appear as receiver cards while
  internal cluster/helper records remain excluded
- Sanitized response fixtures, GET-only reconnect/failure tests, a GUI-wide
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
- Local notifications and explicit demo/read-only-live state

Demo values and local control previews reset when the application exits. Live
values are read from the service and never written back. `POST`, `PUT`, and
`DELETE` transport methods do not exist in Phase 2.

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
HTTP requests to `/api/...`. The Phase 2 client first reads
`/api/v1/snapshot`; strict contract validation rejects the generic legacy
`/api/` response returned by older services and selects the typed compatibility
adapter instead. It never accesses Corsair USB devices or service-owned files.
Global profiles still require a backend-owned composition contract so their
cooling, lighting, and per-device references can eventually be validated,
applied, and recovered as one operation.
