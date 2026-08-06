# Lighting controller ownership checkpoint

This checkpoint connects the previously reviewed ownership model to a guarded
versioned route and Plasma client. The source remains undeployed in this
checkpoint, so no hardware transition occurs during development or review.

## Published state

Every lighting catalog publishes an `ownership` object with the active
controller (`individual`, `rgb-cluster`, or `openrgb`), presentation mode,
affected target count, allowed operations, and a summary of the saved
individual effects. A client can therefore explain both what currently owns
the LEDs and what would reappear when synchronized control is released.

Catalogs advertise `change-controller` only for the explicitly reviewed LINK
Hub, K100 AIR wireless, and Scimitar wireless product families when the live
driver implements the exact whole-device RGB Cluster method. OpenRGB-owned
devices remain observable but cannot publish or receive this command.

## Review interaction

The device Lighting tab contains a persistent controller card. “Change control
mode…” opens a review dialog that names the current and requested controllers,
affected targets, and the saved individual state. Confirmation is enabled only
in Live contract-1.0 mode when the selected device publishes the operation.
Global profiles must not switch ownership implicitly; ownership is an explicit
device-level decision.

When RGB Cluster owns the device, “Open Cluster editor” reveals a workspace for
the synchronized scene and its members. Cluster membership
is modeled at the top-level device boundary used by the backend: attached LINK
Hub channels follow their parent Hub rather than appearing as independently
selectable members. “Edit members…” opens a local draft checklist of all
published lighting-capable devices. OpenRGB-owned devices are disclosed and
locked. The editor accepts exactly one changed device per Apply so every
transition receives its own revision check, read-back, and recovery outcome.

## Guarded transaction

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
and unpublished operations before dispatch. The narrow adapter dispatches the
existing whole-device driver method under the shared mutation lock, rebuilds
ownership state, and reports success only after read-back. A mismatch triggers
restoration and produces either `failed-restored` or
`failed-restore-unverified`. Deployment and the first real transition remain a
separate, explicitly authorized checkpoint because the legacy implementation
restarts the lighting renderer and changes whole-device control.
