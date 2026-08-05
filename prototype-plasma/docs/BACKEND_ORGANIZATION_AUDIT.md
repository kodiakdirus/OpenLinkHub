# Backend organization audit

**Status:** Source audit completed 2026-08-05. This document changes no
runtime behavior and authorizes no hardware operation.

## Decision

OpenLinkHub is an organically grown but viable hardware service. Its device
packages, single hardware authority, existing Web client, and additive v1
contract are assets worth preserving. The backend is **not** a sensible
rewrite candidate.

One small structural prerequisite should precede guarded lighting writes:
introduce a typed application-service boundary for lighting and keep legacy
reflection behind an adapter. Broader route, persistence, and driver cleanup
belongs on the Horizon and should be migrated feature-by-feature only when
touched.

## Current execution path

The important legacy and versioned paths currently converge like this:

```text
Web UI / legacy client / Plasma client
                 |
       HTTP routes and handlers
       server.go / requests.go / api_v1.go
                 |
      global domain and device registries
                 |
 string-named reflection dispatcher
                 |
       product-specific device package
                 |
  in-memory mutation + profile persistence
        + renderer or hardware action
```

`contractv1` is already a useful exception: it normalizes product-specific
state into typed, testable projections without importing device drivers. That
is the seam to extend, not replace.

## Source inventory

These counts describe the audited branch and are evidence of concentration,
not quality scores:

| Area | Observed shape |
|---|---|
| Route registration | `setRoutes` contains 173 `handleFunc` registrations; the documented public inventory contains 160 `/api` method/path pairs |
| Legacy request layer | `src/server/requests/requests.go` is about 5,420 lines and contains 104 `Process...` functions |
| Server layer | `src/server/server.go` is about 2,760 lines; `api_v1.go` is about 437 lines |
| Device layer | 149 driver source files were matched; many product packages repeat profile, RGB, and persistence lifecycles |
| Reflection boundary | `dispatcher.DeviceDispatcher` accepts a device ID, string method name, and `...interface{}` arguments |
| Tests | Three Go `_test.go` files currently cover the API v1 cache/handlers and contract normalization; the Plasma client adds a larger Python/QML suite |

Device-family packages are not themselves a defect. Hardware variants need
local protocol knowledge. The concern is that transport, validation,
coordination, persistence, and hardware effects often meet in the same call
path.

## Findings

### 1. Dynamic dispatch is the dominant device abstraction — high

`devices.CallDeviceMethod` resolves methods by string through reflection.
Missing methods are discovered at runtime, arguments are not compiler-checked,
and capability truth is partly inferred from payload shape. The versioned API
has begun compensating for this with normalized operations, but its label
mutation still ultimately crosses the reflective boundary.

This does not require immediate conversion of every driver. Each newly guarded
operation should instead receive one narrow typed port and one legacy adapter.
The adapter becomes the only place permitted to translate typed calls into
reflection until individual drivers are migrated.

### 2. Global registry access has unsafe concurrency edges — high

The device registry is mutated under a global mutex, while `GetDevices`
returns the underlying map. Readers such as the v1 snapshot collector can
iterate that map outside the registry lock. This is a source-identified race
risk; it has not been claimed as a reproduced production failure.

The same global mutex is held across reflective device calls, including
operations that can save profiles or touch hardware. A slow operation on one
device can therefore delay unrelated registry work.

The first cleanup should add a locked inventory-snapshot function that returns
a copy. Per-device command serialization can be introduced later behind typed
services, without changing all drivers at once.

### 3. HTTP, orchestration, and device effects are interleaved — high

Legacy request processors commonly decode a large shared payload, validate a
subset of its fields, select a device, dispatch a driver method, and map its
integer result directly to an HTTP response. The v1 label handler is much
safer, but still owns decoding, optimistic revision checks, target resolution,
dispatch, read-back verification, and response mapping.

Lighting adds recovery, cache invalidation, and transient leases. Putting all
of those in another handler would make correctness harder to test and reuse.
They belong in an application service with HTTP acting only as transport.

### 4. Persistence success is not independently observable — high

Many drivers mutate in-memory profile structures, save JSON, and restart a
renderer within the same method. The legacy integer result does not give the
caller a durable persistence receipt. A normalized read-back can prove current
service state, but not by itself prove that bytes reached durable storage.

The first lighting assignment must therefore report persistence as `unknown`
unless the driver adapter gains an explicit, testable persistence result.
Centralized atomic persistence is a useful Horizon project, not a prerequisite
for every first guarded write.

### 5. Transport types and route organization are broad — medium

`requests.Payload` combines fields from unrelated lighting, cooling, input,
LCD, scheduler, and service operations. The legacy response envelope likewise
uses broad `interface{}` fields and sometimes reports validation failure with
HTTP 200. Large route and request files make ownership harder to see.

Compatibility routes should remain intact. New v1 routes should use one typed
request and response per operation, while legacy registrations can later be
split into domain files without changing paths or behavior.

### 6. Product packages repeat cross-cutting lifecycle code — medium

Profile selection, JSON persistence, RGB renderer restart, and common label
flows recur throughout the product packages. Some duplication is justified by
hardware protocol differences; shared lifecycle helpers are appropriate only
after two or more implementations can be proven behaviorally identical.

### 7. Safety-critical behavior has a narrow automated-test base — medium-high

The new contract and client have focused tests, but most legacy handlers and
hardware packages do not have isolated tests. Direct hardware access makes
unit coverage difficult, which is another reason to create typed ports and
fakes around operations as they are exposed.

## Incremental target architecture

```text
HTTP transport (legacy and v1)
             |
thin decoding / response handlers
             |
application services
SnapshotService | LabelService | LightingService
             |
narrow typed ports
InventoryReader | LabelWriter | LightingAssigner | LightingIdentifier
             |
legacy device adapter          future typed drivers
(reflection contained here)    (migrated when touched)
             |
product drivers + persistence + hardware
```

`contractv1` remains the normalized read/domain boundary. Application services
may consume its published target identities and operations, but QML and HTTP
handlers must not supply raw driver method names or guess identifiers.

## Prerequisite for the guarded lighting slice

Before adding `PUT /api/v1/lighting/assignment`:

1. Add a small `LightingService` and inject it into the v1 handler.
2. Define typed `InventoryReader` and `LightingAssigner` ports for only the
   published `device` and `channel:<id>` scopes.
3. Put reflection, legacy integer-result normalization, and panic containment
   in one adapter.
4. Move revision locking, target/profile authorization, no-op detection,
   read-back verification, and recovery orchestration into the service.
5. Add a locked device inventory snapshot that cannot leak the mutable global
   map.
6. Test the service with fakes before connecting the adapter; keep real
   hardware unauthorized during this checkpoint.

The transient identify operation should use a separate typed
`LightingIdentifier` port and lease manager. It must not be simulated by the
persistent legacy RGB assignment method.

## Horizon cleanup program

The following work is sensible but does not block the narrow lighting seam:

- split legacy route registration and request processors by domain without
  changing the public API;
- replace the catch-all payload with route-specific types when a route is
  versioned or materially changed;
- migrate reflection one operation/family at a time behind typed adapters;
- define an atomic persistence result and recovery contract;
- extract shared driver lifecycle helpers only where equivalence is tested;
- add registry race tests, fake-device application tests, and command latency
  observability;
- standardize errors and HTTP status behavior in versioned endpoints while
  retaining legacy compatibility.

## Non-goals

- no backend rewrite;
- no removal or replacement of the current Web UI;
- no direct hardware ownership in the Plasma client;
- no mass driver migration;
- no route renames or legacy compatibility break;
- no live lighting, cooling, input, profile, or service mutation from this
  audit.

## Validation and backout

The audit is based on static source inspection and the already passing v1 and
Plasma test suites. The recommended prerequisite is accepted only when fake
service tests prove stale rejection, target authorization, no-op behavior,
driver rejection, read-back success, recovery success, and unverified recovery
without hardware access.

This document has no runtime backout. A future structural checkpoint must be
one behavior-preserving commit and can be reverted without changing installed
profiles, the Web UI, legacy routes, or the deployed service binary.
