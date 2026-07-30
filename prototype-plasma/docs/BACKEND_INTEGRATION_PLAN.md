# OpenLinkHub Plasma Backend Integration Plan

Status: planning baseline; no prototype networking or hardware callbacks are
authorized by this document.

Source baseline: `src/server/server.go`, `src/server/requests/requests.go`,
`src/config/config.go`, `src/devices/`, and the service-owned profile modules at
OpenLinkHub commit `9c242a17`.

## Outcome

Keep one hardware authority and offer two first-class clients:

```text
Corsair hardware
       │
OpenLinkHub Go service
       ├── existing Web client
       ├── native Plasma client
       └── read-only monitoring integrations
```

The Go service remains responsible for USB access, device discovery, capability
truth, validation, safety limits, persistence, automation, and recovery. The
Plasma application presents that state through Qt models and submits typed
commands. It never opens HID devices or edits files in `database/` directly.

“Expose every capability” means that every registered route and every
service-owned feature has one documented disposition:

1. a clear user-facing control;
2. background state used by another control;
3. an advanced/diagnostic control;
4. an intentionally unavailable control with a reason; or
5. a backend contract gap that must be filled before the UI can expose it.

It does not mean making 155 raw API operations into 155 buttons.

## Source-derived API facts

- The service currently registers 155 `/api` routes: 42 `GET`, 100 `POST`,
  7 `PUT`, and 6 `DELETE`. `/api/metrics` is one of those routes but is
  conditional on `config.metrics`; 154 routes are unconditional.
- The default listener is `127.0.0.1:27003`. The current API has no
  authentication boundary, so the desktop client must default to loopback and
  must not silently expose the listener on another interface.
- JSON responses use a loose envelope containing `code`, `status`, `message`,
  and one of `data`, `device`, `devices`, or `dashboard`.
- Many validation failures still return HTTP 200 with `status: 0`. The client
  must normalize both HTTP failures and envelope failures.
- Most writes decode one very large catch-all `requests.Payload`. The native
  client must use narrow command types rather than reproduce that object in QML.
- `/api/devices/` returns a partial wrapper whose per-device `GetDevice` value
  is a product-specific Go structure. The partial wrapper deliberately removes
  stable product/device type data, so UI capability inference from it is not a
  durable contract.
- Some state is injected only into server-rendered HTML: scheduler state,
  build/system information, and LCD profile collections are examples. Those
  need JSON endpoints before a native client can consume them reliably.
- Existing “user profiles” are device-local snapshots. They are not the
  cross-device global profiles represented by the prototype.
- Prometheus telemetry already covers product information, temperatures, RPM,
  storage temperature, CPU temperature, and GPU temperature when metrics are
  enabled.

## Native client boundary

The production client should keep QML presentation-only:

```text
QML pages and dialogs
        │ properties, signals, Qt roles
Application store / view models
        │ typed domain operations
Repositories and legacy adapters
        │ normalized models and errors
Qt network transport
        │ HTTP/JSON or file transfer
OpenLinkHub loopback API
```

Recommended initial implementation:

- PyQt6/QML remains acceptable for the first production-capable client.
- Use Qt's asynchronous network stack so requests share the Qt event loop.
- QML must not construct URLs, decode arbitrary JSON, or decide whether a
  device supports a feature.
- One transport handles timeouts, cancellation, content types, response
  envelopes, and connection state.
- Narrow repositories expose inventory, telemetry, cooling profiles, lighting
  profiles, device profiles, global profiles, and service administration.
- Legacy adapters translate the current product-specific payloads into domain
  models until an additive versioned API is available.
- Mutations return a command result containing status, user-safe message,
  validation details, changed revision, and whether a refresh is required.

## Required additive backend contracts

The existing Web UI must continue to work. Add versioned endpoints rather than
breaking legacy routes.

### Service descriptor and health

Provide a machine-readable descriptor containing:

- API and service version;
- build information;
- listener mode and whether the connection is local;
- service/manual/frontend/metrics state;
- device discovery state;
- persistence health;
- feature flags;
- restart-required settings;
- warnings such as unavailable sensor sources or permissions.

The health response must not leak secrets, arbitrary paths, or log contents.

### Capability manifest

Add one normalized capability document. At minimum it should identify:

- stable device ID, product ID/type, semantic device type, firmware, online
  state, transport, battery support, and paired/dongle relationships;
- channels and their stable IDs, labels, temperature/RPM values, pump/fan/probe
  role, PWM mode, RGB zones/LED count, LCD attachment, and topology;
- supported operations and valid ranges/options for each device or channel;
- available profile types and whether hardware/offline profiles are supported;
- environment-dependent features such as PipeWire audio, virtual gamepad,
  motherboard PWM, memory control, OpenRGB, metrics, and display geometry.

The UI generates device tabs from these semantic features. Product names may
choose presentation details, but they must not be the authorization predicate.

### Complete read contracts

Add JSON reads for state that is currently HTML-only or write-only:

- scheduler and lights-out state;
- build, version, system, and service configuration summaries;
- custom LCD profile/mode inventory;
- active and saved device profile inventory in normalized form;
- safe configuration values and restart requirements;
- long-running backup, restore, upload, or reinitialization job status.

### State revisions and events

Add a monotonically increasing state revision and an event stream or equivalent
change feed for device add/remove, telemetry, active-profile, job, and service
state changes. Polling remains a fallback. Commands should accept an expected
revision where stale writes could overwrite newer state.

### Validation and dry run

Safety-sensitive and compound changes need a backend validation operation that
returns:

- resolved targets and references;
- unsupported or offline devices;
- range and dependency errors;
- warnings;
- restart requirement;
- the state revision against which validation occurred.

The backend remains the final validator even when the UI has already constrained
inputs.

## Capability-to-interface map

| User workspace | Backend capabilities presented there |
|---|---|
| Overview | Connection/health, active global profile, device health, CPU/GPU/storage telemetry, liquid/probe temperatures, fan/pump RPM, battery state, warnings, and user-selected dashboard cells |
| Profiles | Global compositions, purpose-specific cooling/lighting/LCD/audio/input/device profiles, app/game launch rules, missing-device policy, validation, import/export, and activation history |
| Devices | Discovery, topology, firmware/build identity, labels, positions, channel roles, per-device snapshots, hardware/offline behavior, pairing/dongle relationships, and only the tabs supported by the manifest |
| Cooling | Temperature sources, probes, fixed and graph curves, fan/pump assignment, zero-RPM policy, PWM operating mode, PSU fan mode, live RPM/temperature, and protected manual tests |
| Lighting | RGB profile editor, static/global/per-zone color, gradients, temperature reactions, clusters, adapters/strips, LED layout, hardware lighting, brightness, OpenRGB ownership, and lights-out behavior |
| Input | Keyboard profiles/layout/dial/polling/sleep/brightness/debounce, assignments, macros, actuation, performance locks, FlashTap, mouse DPI/gestures/polling/sensor options, controller maps/curves/emulation/vibration/sleep |
| Audio | Headset assignments, sleep, mute indicator, ANC, sidetone, wheel behavior, equalizers, output device, virtual audio, controller audio, and media state/control |
| Displays | LCD attachment, modes/custom layouts, sensor selection, rotation, brightness, images/animation uploads, panel placement, and Xeneon/display geometry |
| Automations | Existing time-based RGB/LCD schedule, display-idle lights out, global-profile process rules, priority/conflict policy, restore-on-exit, and automation history |
| Integrations | OpenRGB ownership, Prometheus, future Plasma System Monitor sensor publication, system tray, media/PipeWire, and environment capability checks |
| Service | Health/version, safe configuration, supported-device exclusions, backup/restore, language, diagnostics, permissions, logs, and restart-required changes |

Purpose-specific profiles remain independently editable. A global profile
references their stable IDs and versions; it does not flatten them into an
opaque duplicate.

## Registered route-family disposition

The detailed 155-route snapshot is in `BACKEND_ROUTE_INVENTORY.md`. The
user-facing disposition is:

| Route family | Count | Disposition |
|---|---:|---|
| Root, CPU/GPU/storage, battery | 10 | Background read models for Overview and monitoring; formatted and clean temperature duplicates collapse into one typed value |
| `devices`, `label`, `position`, `operatingMode` | 8 | Device inventory/topology and capability-gated device or cooling controls |
| `temperatures`, `speed`, `psu` | 10 | Cooling workspace; manual speed is a protected diagnostic session |
| `color`, `brightness`, `argb`, `hub`, `led`, `misc`, `scheduler` | 32 | Lighting editor, topology, hardware lighting, brightness, and Automations; helper reads stay internal |
| `keyboard`, `mouse`, `controller`, `input`, `macro` | 56 | Input workspace and reusable macro library; key lookup routes remain background helpers |
| `headset`, `audio`, `media` | 14 | Audio workspace; media reads/commands appear only when the environment supports them |
| `lcd`, `display` | 9 | Displays workspace with capability-gated file upload |
| `dashboard` | 6 | Migrate useful presentation preferences into client-local settings; backend-owned device selection remains a compatibility feature |
| `userProfile` | 3 | Per-device snapshot library, surfaced under the relevant device and available to global composition |
| `metrics` | 1 | Read-only Integrations feature; conditional and advanced |
| `systray` | 1 | Background compatibility data for tray integration |
| `backup`, `restore`, supported devices, language | 5 | Service workspace; restore is destructive and requires preview/confirmation |

No raw helper endpoint gets its own navigation destination merely to satisfy
coverage. Coverage is proven by mapping routes to a domain operation and testing
that every registered route has a disposition.

## Global profile contract

A global profile is backend-owned and contains stable references such as:

- cooling profile and per-channel exceptions;
- lighting scene plus hardware-lighting behavior;
- keyboard, mouse, controller, headset/audio, and LCD profile assignments;
- optional per-device snapshot references;
- automation rules, priority, restore-on-exit behavior, and fallback profile;
- missing/offline device policy;
- schema version and revision.

Names are presentation; references use immutable IDs. Renaming a component must
not break a global profile.

Suggested additive operations:

- list/read/create/update/delete global profiles;
- validate a draft against a specified state revision;
- preview the resolved change set;
- apply with an idempotency key and expected revision;
- read the active profile and last apply report;
- list automation rules and recent activation decisions.

Apply sequence:

1. snapshot relevant current service state;
2. resolve every referenced component;
3. validate every target, range, safety invariant, and missing-device rule;
4. produce the complete plan before touching hardware;
5. apply safety-critical cooling state and then the remaining components;
6. persist the active global profile only after success;
7. on failure, perform backend-owned best-effort rollback and return an explicit
   per-component report.

The UI must never approximate atomic apply with an untracked chain of legacy
requests.

## Cooling and destructive-operation safety

- Pump minimums, valid PWM modes, temperature-source validity, and emergency
  behavior are service policy, not client policy.
- A lost desktop connection must not stop the service's monitoring or fan
  control.
- Manual fan/pump output is an explicitly timed test with visible target,
  remaining duration, and automatic reversion.
- Cooling changes use edit, validate, apply, verify. The UI shows observed
  profile/RPM state after apply rather than assuming success.
- The client must not toggle the service's `manual` configuration merely because
  it is a custom UI; that mode disables normal temperature monitoring and
  automatic speed adjustment.
- Restore, supported-device removal, device reinitialization, and any future
  firmware operation require target-specific confirmation and a backout or
  recovery description.
- Backup and restore are file-transfer jobs, not ordinary JSON toggles.
- Remote/non-loopback service connections are out of initial scope. Supporting
  them later requires an authentication and transport-security design.

## Plasma System Monitor sensors

The existing optional Prometheus endpoint is useful but does not by itself make
Corsair telemetry native Plasma sensors.

Plan a read-only bridge with two layers:

1. the service publishes a normalized sensor catalog and current values, with
   stable sensor IDs, units, labels, availability, device/channel identity, and
   timestamps;
2. an optional KDE integration publishes those values through the Plasma system
   monitoring framework.

The bridge receives no hardware-control authority. The Plasma client exposes an
Integrations page where users can enable publication and choose sensors such as
coolant temperature, probe temperatures, pump/fan RPM, battery, and PSU values.
Prometheus remains available independently for non-Plasma monitoring.

The exact KDE plugin boundary should be confirmed against the installed Plasma
development API before implementation; the service-side sensor schema should
not depend on that choice.

## Phased implementation

### Phase 0 — contract fixtures and route coverage

- Freeze sanitized response fixtures for each connected product family and major
  profile type.
- Add a route inventory check that fails when a registered route has no
  disposition.
- Define normalized models and error taxonomy.
- Keep the prototype offline.

Exit: all 155 current routes are classified and representative payloads parse
without QML involvement.

### Phase 1 — read-only legacy client

- Add asynchronous Qt transport, connection state, timeouts, cancellation, and
  legacy response normalization.
- Connect health probing, `/api/devices/`, per-device detail, telemetry,
  temperature profiles, RGB data, battery, and dashboard-compatible reads.
- Replace mock values only in Overview, Devices, and read-only Cooling sensor
  cells.
- Preserve an explicit demo-data mode for UI development.

Exit: unplug/replug, service restart, malformed payload, timeout, and unsupported
device states are visible and cannot trigger a write.

### Phase 2 — additive service contract

- Add versioned service descriptor, capability manifest, normalized snapshot,
  missing JSON reads, revisions, and change events.
- Keep legacy routes and the Web UI working.
- Switch the native adapters to prefer the versioned contract and fall back only
  where explicitly supported.

Exit: device tabs and valid controls are derived entirely from semantic
capabilities.

### Phase 3 — low-risk mutations and profile editors

- Labels, positions, presentation selections, lighting preview/brightness, and
  non-destructive profile CRUD.
- Consistent dirty/validate/apply/revert interaction.
- Verify every mutation with refreshed backend state.

Exit: failures are actionable, stale writes are rejected, and controls never
  imply success from HTTP 200 alone.

### Phase 4 — cooling and hardware/offline behavior

- Cooling profile assignment/editing, graph curves, PWM mode, protected manual
  tests, PSU control, hardware lighting, and LCD behavior.
- Add safety validation, verification, and rollback reporting first.

Exit: service-enforced invariants and live-hardware tests pass on explicitly
approved hardware without weakening service safeguards.

### Phase 5 — peripheral depth

- Keyboard, mouse, controller, macros, headset/audio, LCD/media, hub/adapter,
  OpenRGB, and display controls.
- Capability fixtures and tests for each supported operation shape.

Exit: every current route family has a tested domain operation or documented
background-only disposition.

### Phase 6 — global profiles and automations

- Backend persistence, validation, preview, atomic apply/recovery, process rules,
  priorities, fallback, and activation history.
- Top-bar selector reads only the backend's active global profile.

Exit: a failed component cannot silently leave the UI claiming that the global
profile is active.

### Phase 7 — monitoring and administration

- Plasma sensor bridge, Prometheus controls, safe service settings, backup and
  restore jobs, diagnostics, permissions guidance, and supported-device
  exclusions.

Exit: administration is recoverable, privileged boundaries are explicit, and
monitoring remains read-only.

## Verification strategy

- Unit tests for the envelope parser, error normalization, domain adapters,
  capability predicates, profile references, and stale revision handling.
- Golden fixture tests for every supported product family represented in
  `src/devices/`.
- A mock HTTP service for success, validation failure, malformed data, delay,
  disconnect, reconnect, device hotplug, and partial global-profile failure.
- Backend contract tests for additive endpoints and legacy-Web-UI compatibility.
- Route coverage test generated from `setRoutes()`.
- No-hardware smoke tests that instantiate every workspace and capability shell.
- Opt-in live-hardware tests with an inventory snapshot, explicit target list,
  observed-state verification, and a safe restoration step.
- Accessibility checks for keyboard navigation, focus, labels, contrast, reduced
  motion, and non-color status cues.

## First implementation slice

The first coding slice should be intentionally read-only:

1. introduce the Qt transport and connection-state model;
2. add typed legacy envelope and error handling;
3. read `/api/devices/` and selected per-device details;
4. normalize connected devices, channels, temperature, RPM, and battery;
5. bind Overview and Devices to real read models behind a demo/live switch;
6. add fixtures and disconnect/reconnect tests;
7. make no `POST`, `PUT`, or `DELETE` calls.

This slice proves the process boundary and the hardest compatibility problem
without risking cooling behavior. The additive capability manifest is the first
backend change after that read-only client demonstrates what data the current
API cannot express safely.

## Planning acceptance checklist

- Every registered route is represented in the inventory.
- Every family has a user-facing, background, advanced, unavailable, or contract
  gap disposition.
- Device controls are capability-driven.
- Global profiles compose stable purpose-specific references.
- Cooling and destructive operations have backend-owned validation and recovery.
- Existing Web UI routes remain compatible.
- Plasma sensor publication is read-only and separate from hardware control.
- Initial implementation is loopback-only and read-only.

