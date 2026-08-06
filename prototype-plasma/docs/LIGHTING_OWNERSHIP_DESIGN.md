# Lighting controller ownership checkpoint

This checkpoint makes whole-device lighting ownership understandable before it
becomes writable. It is source-only and fake-backed: no HTTP route, controller
callback, product-driver adapter, service deployment, or hardware transition is
included.

## Published state

Every lighting catalog publishes an `ownership` object with the active
controller (`individual`, `rgb-cluster`, or `openrgb`), presentation mode,
affected target count, allowed operations, and a summary of the saved
individual effects. A client can therefore explain both what currently owns
the LEDs and what would reappear when synchronized control is released.

Current catalogs publish only `read`. A later implementation may advertise
`change-controller` only for a device backed by an explicitly reviewed driver
adapter. OpenRGB is observable but cannot be selected through this proposed
command.

## Review interaction

The device Lighting tab contains a persistent controller card. “Change control
mode…” opens a review dialog that names the current and requested controllers,
affected targets, and the saved individual state. The confirmation control is
disabled in this checkpoint. Global profiles must not switch ownership
implicitly; ownership is an explicit device-level decision.

When RGB Cluster owns the device, “Open Cluster editor” reveals a non-writing
workspace shell for the synchronized scene and its members. This establishes
the information hierarchy without inventing a backend capability.

## Future guarded transaction

The transport-neutral application service accepts:

```json
{
  "expectedRevision": 12,
  "deviceId": "device-serial",
  "expectedController": "rgb-cluster",
  "requestedController": "individual"
}
```

It rejects stale revisions, owner changes, unknown devices, unsupported modes,
and unpublished operations before dispatch. A future adapter must capture the
previous controller, dispatch exactly once, rebuild ownership state, and report
success only after read-back. A mismatch triggers restoration and produces
either `failed-restored` or `failed-restore-unverified`.

Connecting a versioned route and a real LINK Hub adapter is a separate review
checkpoint because the legacy implementation restarts the lighting renderer
and changes whole-device control.
