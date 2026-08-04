# OpenLinkHub Backend Route Inventory

Snapshot source: `src/server/server.go` on the current implementation branch.
`tests/test_route_inventory.py` verifies the documented count and coverage.

This is the planning coverage baseline for the native Plasma client. Dynamic
suffixes such as a device serial, profile name, macro ID, or key ID are implied
by routes ending in `/`.

Count: 159 `/api` registrations: 45 `GET`, 100 `POST`, 8 `PUT`, and 6 `DELETE`.
`GET /api/metrics` is registered only when metrics are enabled.

## Service, overview, and monitoring

- `GET /api/v1/service` — safe versioned service/build/listener/feature descriptor.
- `GET /api/v1/capabilities` — normalized semantic device capability manifest.
- `GET /api/v1/snapshot` — normalized devices, telemetry, profiles, scheduler,
  display, dashboard, and LCD state with a monotonic process revision.
- `PUT /api/v1/devices/label` — guarded device/channel label command with
  expected-revision rejection and refreshed-state verification.
- `GET /api/` — aggregate raw device state; compatibility/background.
- `GET /api/cpuTemp` — formatted CPU temperature; collapse into typed telemetry.
- `GET /api/cpuTemp/clean` — numeric CPU temperature.
- `GET /api/cpuLoad` — CPU utilization.
- `GET /api/gpuTemp` — formatted default GPU temperature; collapse into typed telemetry.
- `GET /api/gpuTemp/clean` — numeric default GPU temperature.
- `GET /api/gpuTemps` — indexed GPU temperatures.
- `GET /api/gpuLoad` — GPU utilization.
- `GET /api/storageTemp` — storage temperatures.
- `GET /api/batteryStats` — wireless-device battery telemetry.
- `GET /api/metrics` — conditional Prometheus exposition; advanced integration.
- `GET /api/systray` — tray-compatible summary; background integration.
- `GET /api/language/` — language data; compatibility/service preferences.
- `GET /api/backup` — backup download; Service job/file flow.
- `POST /api/restore` — backup restore upload; destructive Service job/file flow.
- `GET /api/getSupportedDevices` — supported-product enablement inventory.
- `POST /api/setSupportedDevices` — persist product exclusions; advanced Service control.

## Device inventory and shared device controls

- `GET /api/devices/` — list devices or read a dynamic device detail.
- `GET /api/devices/probes/` — temperature-probe inventory.
- `GET /api/devices/mouse` — mouse-device lookup helper.
- `POST /api/devices/channel` — channel detail helper.
- `POST /api/label` — device/channel label.
- `GET /api/position/` — saved device positions.
- `POST /api/position/update` — update device position.
- `POST /api/operatingMode` — PWM operating mode; capability-gated Cooling control.

## Cooling and temperature profiles

- `GET /api/temperatures/` — list or read fixed temperature/speed profiles.
- `GET /api/temperatures/graph/` — read graph profile.
- `POST /api/temperatures/new` — create fixed/graph profile.
- `POST /api/temperatures/setLiquidTemperatureSource` — select coolant source.
- `PUT /api/temperatures/update` — update fixed profile.
- `PUT /api/temperatures/updateGraph` — update graph profile.
- `DELETE /api/temperatures/delete` — delete profile.
- `POST /api/speed` — assign a cooling profile to a channel.
- `POST /api/speed/manual` — direct output; protected timed diagnostic only.
- `POST /api/psu/speed` — PSU fan mode.

## Lighting, RGB topology, and scheduling

- `GET /api/color/` — list or read device RGB data.
- `GET /api/color/zone/` — read zone color.
- `GET /api/color/profile/` — read RGB profile data.
- `GET /api/color/override/` — read Commander Duo override.
- `POST /api/color` — assign RGB profile.
- `POST /api/color/global` — assign one device globally.
- `POST /api/color/all` — assign all devices.
- `POST /api/color/linkAdapter` — Link adapter color.
- `POST /api/color/linkAdapter/bulk` — bulk Link adapter color.
- `POST /api/color/getOverride` — read device RGB override helper.
- `POST /api/color/setOverride` — set device RGB override.
- `POST /api/color/setTemperatureProbe` — temperature-reactive probe source.
- `POST /api/color/getLedData` — read LED helper data.
- `POST /api/color/setLedData` — set LED layout data.
- `POST /api/color/setOpenRgbIntegration` — set OpenRGB ownership/integration.
- `POST /api/color/setCluster` — set RGB cluster.
- `POST /api/color/hardware` — assign hardware/offline lighting.
- `POST /api/color/gradient/add` — add gradient color stop.
- `POST /api/color/gradient/delete` — delete gradient color stop.
- `POST /api/color/override/update` — update Commander Duo override.
- `PUT /api/color/change` — update RGB profile definition.
- `POST /api/brightness` — brightness preset.
- `POST /api/brightness/gradual` — numeric brightness.
- `POST /api/argb` — ARGB device configuration.
- `POST /api/hub/strip` — external strip configuration.
- `POST /api/hub/linkAdapter` — Link adapter selection.
- `POST /api/hub/type` — external hub device type.
- `POST /api/hub/amount` — external hub device amount.
- `GET /api/led/` — all or per-device LED profile data.
- `POST /api/led/update` — update LED profile data.
- `POST /api/misc/color` — miscellaneous device color.
- `POST /api/scheduler/rgb` — time-based RGB/LCD lights-out schedule.

## Keyboard

- `GET /api/keyboard/assignmentsTypes/` — supported assignment types.
- `GET /api/keyboard/assignmentsModifiers/` — supported assignment modifiers.
- `GET /api/keyboard/getPerformance/` — performance-lock state.
- `GET /api/keyboard/getFlashTap/` — FlashTap state.
- `GET /api/keyboard/dial/getColors/` — dial colors.
- `POST /api/keyboard/liveSync` — live lighting synchronization.
- `POST /api/keyboard/color` — per-key/zone color.
- `POST /api/keyboard/profile/change` — activate keyboard profile.
- `POST /api/keyboard/profile/save` — save keyboard profile.
- `PUT /api/keyboard/profile/new` — create keyboard profile.
- `DELETE /api/keyboard/profile/delete` — delete keyboard profile.
- `POST /api/keyboard/layout` — keyboard layout.
- `POST /api/keyboard/dial` — dial behavior.
- `POST /api/keyboard/sleep` — sleep timeout.
- `POST /api/keyboard/pollingRate` — polling rate.
- `POST /api/keyboard/autoBrightness` — automatic brightness.
- `POST /api/keyboard/debounceTime` — debounce.
- `POST /api/keyboard/getKey/` — key detail helper.
- `POST /api/keyboard/getKeys/` — multi-key detail helper.
- `POST /api/keyboard/updateKeyAssignment` — key assignment.
- `POST /api/keyboard/updateActuation` — magnetic-key actuation.
- `POST /api/keyboard/setPerformance` — performance locks.
- `POST /api/keyboard/setFlashTap` — FlashTap configuration.
- `POST /api/keyboard/dial/setColors` — dial colors.

## Mouse

- `POST /api/mouse/dpi` — DPI stages.
- `POST /api/mouse/gestures` — gesture settings.
- `POST /api/mouse/zoneColors` — zone colors.
- `POST /api/mouse/dpiColors` — DPI indicator colors.
- `POST /api/mouse/sleep` — sleep timeout.
- `POST /api/mouse/pollingRate` — polling rate.
- `POST /api/mouse/angleSnapping` — angle snapping.
- `POST /api/mouse/rippleControl` — ripple control.
- `POST /api/mouse/motionSync` — motion sync.
- `POST /api/mouse/buttonOptimization` — button optimization.
- `POST /api/mouse/leftHandMode` — left-hand mode.
- `POST /api/mouse/liftHeight` — lift height.
- `POST /api/mouse/updateKeyAssignment` — button assignment.

## Controller

- `POST /api/controller/vibration` — vibration.
- `POST /api/controller/zoneColors` — lighting zones.
- `POST /api/controller/updateKeyAssignment` — control assignment.
- `POST /api/controller/emulation` — emulated controller/mode.
- `POST /api/controller/getGraph` — analog curve helper read.
- `POST /api/controller/setGraph` — analog curve.
- `POST /api/controller/sleep` — sleep mode.

## Shared input and macros

- `GET /api/input/media` — media-key lookup.
- `GET /api/input/keyboard` — keyboard-key lookup.
- `GET /api/input/mouse` — mouse-button lookup.
- `GET /api/input/controller` — controller-key lookup.
- `GET /api/macro/` — list or read macros.
- `GET /api/macro/keyInfo/` — key-name helper.
- `PUT /api/macro/new` — create macro profile.
- `POST /api/macro/newValue` — add macro action/value.
- `POST /api/macro/updateValue` — update macro action/value.
- `POST /api/macro/updateSettings` — repeat/timing settings.
- `DELETE /api/macro/value` — delete macro action/value.
- `DELETE /api/macro/profile` — delete macro profile.

## Headset, audio, and media

- `GET /api/headset/getEqualizers/` — equalizer inventory.
- `POST /api/headset/updateKeyAssignment` — headset control assignment.
- `POST /api/headset/zoneColors` — headset zone colors.
- `POST /api/headset/sleep` — sleep timeout.
- `POST /api/headset/muteIndicator` — mute indicator.
- `POST /api/headset/anc` — active noise cancellation/transparency.
- `POST /api/headset/sidetone` — sidetone enable/mode.
- `POST /api/headset/sidetoneValue` — sidetone level.
- `POST /api/headset/wheelOption` — wheel behavior.
- `POST /api/headset/equalizer` — equalizer bands.
- `POST /api/audio/update` — virtual/session audio settings.
- `POST /api/audio/outputDevice` — output-device selection.
- `GET /api/media/playback` — current media state.
- `GET /api/media/` — media playback command through a dynamic suffix.

## LCD and displays

- `POST /api/lcd` — LCD assignment/mode.
- `POST /api/lcd/device` — LCD device binding.
- `POST /api/lcd/rotation` — rotation.
- `POST /api/lcd/brightness` — brightness.
- `POST /api/lcd/profile` — profile assignment.
- `POST /api/lcd/image` — image selection.
- `POST /api/lcd/upload` — image/animation upload.
- `PUT /api/lcd/modes` — update custom LCD mode/profile.
- `POST /api/display/update` — display geometry/placement.

## Dashboard compatibility

- `GET /api/dashboard` — dashboard preferences.
- `GET /api/dashboard/devices/get` — selected dashboard devices.
- `POST /api/dashboard/update` — dashboard preferences.
- `POST /api/dashboard/sidebar` — sidebar collapse state.
- `POST /api/dashboard/devices/add` — add dashboard device.
- `DELETE /api/dashboard/devices/delete` — remove dashboard device.

## Per-device snapshots

- `POST /api/userProfile/change` — activate a device-local snapshot.
- `PUT /api/userProfile` — save a device-local snapshot.
- `DELETE /api/userProfile/delete` — delete a device-local snapshot.

## Backend features without complete native-consumable routes

These are part of capability coverage even though they are not additional
registered API routes:

- service build/version and system information are rendered into HTML, but lack
  normalized JSON reads;
- current scheduler state is rendered into HTML, while JSON exposes only its
  write;
- custom LCD profile inventory is rendered into HTML, while JSON exposes upload
  and mutation;
- configuration controls include sensor sources, resume delay, memory/SMBus,
  GPU selection, logging, graph profiles, OpenRGB target server, virtual
  gamepad, motherboard PWM, metrics, frontend, and listener settings, but there
  is no safe general configuration API;
- memory, motherboard, PipeWire/media, virtual gamepad, OpenRGB, metrics, and
  display behavior are environment/configuration dependent;
- device hotplug and sleep/resume reinitialization exist but have no event feed;
- global cross-device profiles, process activation rules, apply transactions,
  revisions, dry-run validation, and rollback reports do not yet exist;
- native Plasma System Monitor publication does not yet exist; Prometheus is the
  current monitoring export.
