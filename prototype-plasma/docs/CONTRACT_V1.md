# OpenLinkHub contract 1.0

Contract 1.0 is additive. It does not remove or alter the existing Web UI or
legacy `/api/...` routes.

## Documents

| Route | Kind | Purpose |
|---|---|---|
| `GET /api/v1/service` | `service` | Safe build, listener, feature, and warning summary |
| `GET /api/v1/capabilities` | `capabilities` | Semantic device/environment capability manifest |
| `GET /api/v1/snapshot` | `snapshot` | Normalized state plus current measurements |
| `PUT /api/v1/devices/label` | `command-result` | Guarded device/channel label update |

Every successful response contains `apiVersion`, `kind`, a positive
`revision`, and object `data`. Snapshot documents also contain a positive
`telemetryRevision`.

## Guarded label command

The first Phase 3 mutation is deliberately narrow. A client submits a label
only for a `labelTargets` entry published on the selected device:

```json
{
  "expectedRevision": 12,
  "deviceId": "device-serial",
  "targetId": "channel:13",
  "label": "Top radiator"
}
```

The service rejects unknown fields and malformed, empty, overlong, or
unsupported labels. `expectedRevision` must equal the current state revision;
otherwise the command returns HTTP `409` and never reaches a device driver.
Supported targets use `device` or `channel:<id>` stable IDs.

A successful driver return is not sufficient. The service rebuilds the
normalized snapshot and confirms that the requested label appears on the same
target before returning `status: succeeded`. Responses use the common
`command-result` kind with `changed`, a user-safe message, validation issues,
the resulting revision, and the verified target. Command responses are
`Cache-Control: no-store`.

## Revision semantics

- `revision` changes when user/configuration state changes: inventory,
  capabilities, labels/topology, assigned profiles/effects, service flags,
  scheduler, display/dashboard preferences, or LCD/profile inventory.
- `telemetryRevision` changes for availability and live measurements such as
  CPU/GPU/coolant temperature, battery, and channel RPM.
- A measurement change must not invalidate the state revision used by future
  optimistic write commands.
- Revisions are monotonic for one service process and restart from 1 when that
  process restarts. Clients must not compare revisions across service restarts
  without a future instance identifier.

## Conditional requests

All three routes return a strong `ETag`, `Cache-Control: private, no-cache`,
and `Vary: Accept`. Clients should send `If-None-Match`; an identical document
returns `304 Not Modified` with no body. The native client retains its current
presentation model on 304, avoiding unnecessary JSON conversion and QML model
replacement.

The service still gathers current telemetry before deciding whether a snapshot
is unchanged. Device-filtered RGB libraries are cached for 30 seconds because
they are comparatively expensive and mostly static. Phase 3 mutations that
change RGB definitions must invalidate this cache before verification reads.

## Compatibility and safety

Older services may route an unknown `/api/v1/...` read through their generic
`/api/` handler and return HTTP 200 with a legacy document. Clients must require
the exact version, kind, revision, and data shape before selecting contract
mode. An incompatible successful document selects the explicit legacy adapter;
network, HTTP, or malformed-data failures remain errors.

The contract excludes raw configuration paths, sensor file paths, log content,
HID handles/instances, secrets, and the legacy catch-all mutation payload. An
unavailable capability includes an explicit reason and an empty operation set.
Mutation authorization is capability-scoped: only an `overview` capability
with `access: read-write`, operation `update-label`, and a matching published
`labelTargets` entry enables this command. No generic mutation transport exists.
Cooling, lighting, input, display, automation, and administration remain
read-only through contract 1.0. `persistence` is still reported as `unknown`
because the existing device save methods do not return independent durable-file
confirmation; the command proves normalized service read-back, not storage
media durability.

The machine-readable structural baseline is
[`contract-v1.schema.json`](contract-v1.schema.json). Sanitized golden fixture
[`v1_snapshot_families.json`](../tests/fixtures/v1_snapshot_families.json)
covers the connected hub, keyboard, mouse, and receiver presentation families.
