# OpenLinkHub read-only contract 1.0

Contract 1.0 is additive. It does not remove or alter the existing Web UI or
legacy `/api/...` routes.

## Documents

| Route | Kind | Purpose |
|---|---|---|
| `GET /api/v1/service` | `service` | Safe build, listener, feature, and warning summary |
| `GET /api/v1/capabilities` | `capabilities` | Semantic device/environment capability manifest |
| `GET /api/v1/snapshot` | `snapshot` | Normalized state plus current measurements |

Every successful response contains `apiVersion`, `kind`, a positive
`revision`, and object `data`. Snapshot documents also contain a positive
`telemetryRevision`.

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

Older services may route an unknown `/api/v1/...` request through their generic
`/api/` handler and return HTTP 200 with a legacy document. Clients must require
the exact version, kind, revision, and data shape before selecting contract
mode. An incompatible successful document selects the explicit legacy adapter;
network, HTTP, or malformed-data failures remain errors.

The contract excludes raw configuration paths, sensor file paths, log content,
HID handles/instances, secrets, and the legacy catch-all mutation payload. An
unavailable capability includes an explicit reason and an empty operation set.
The current contract is GET-only; it grants no mutation authorization.
`persistence` is reported as `unknown` until a versioned durable-write contract
can prove its behavior rather than inheriting an assumption from legacy routes.

The machine-readable structural baseline is
[`contract-v1.schema.json`](contract-v1.schema.json). Sanitized golden fixture
[`v1_snapshot_families.json`](../tests/fixtures/v1_snapshot_families.json)
covers the connected hub, keyboard, mouse, and receiver presentation families.
