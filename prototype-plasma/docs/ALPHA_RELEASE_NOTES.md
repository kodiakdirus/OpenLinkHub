# OpenLinkHub Plasma 0.1.0a2 — community alpha

An independently installable Qt/Kirigami desktop client for OpenLinkHub.

This alpha adds optional backend setup under Service and a quiet, dismissible
startup reminder. Dismissal persists across restarts and appearance resets.
Setup remains available later, and connected versioned services do not receive
upgrade reminders for device-specific limitations. The setup panel links to
installation guidance; a compatible backend package/in-app installer is still
unavailable.

- Demo exploration without hardware; live telemetry from a local service.
- Focused Cooling, Lighting, Input, Audio and Display workspaces.
- Capability-gated lighting/label operations and existing fan-curve editing.
- Persistent appearance/layouts and protection for unsaved curve drafts.
- Configured Cluster scene display with inactive individual effects separated.
- Backend compatibility guidance and an identifier-free diagnostic export.

The GUI requires a separately installed OpenLinkHub service for Live mode.
Some controls require this branch's versioned API additions and will be
unavailable on older installations. Input/audio/display configuration, global
profiles, automations and effect-definition writes remain unavailable in Live.

See the accompanying `PUBLIC_TESTING.md` for installation,
compatibility, known limitations and reporting problems. Standalone alpha
bundles are updated by installing a newer bundle; there is no update feed yet.

Maintainer: record the exact tested backend build/commit and any physical
hardware acceptance results in the draft release before publication.
