# OpenLinkHub Interactive UI Concept

This is a backend-free interaction prototype for exploring a capability-driven
OpenLinkHub interface. It does not call the OpenLinkHub API or control hardware.

## Run

From the OpenLinkHub repository root:

```bash
python3 -m http.server 4173 --bind 127.0.0.1
```

Then open:

```text
http://127.0.0.1:4173/prototype/
```

You can also open `prototype/index.html` directly, although a local server gives
more predictable browser behavior.

## Included interactions

- Capability-driven navigation
- Simulated Quiet, Balanced, Performance, and Custom system modes
- Cooling zones and an interactive curve editor
- Lighting scenes, brightness, and target selection
- Searchable/filterable device cards and capability-aware detail drawer
- Per-device settings tabs generated from supported capabilities (a mouse never
  receives cooling controls)
- Automation concepts with explicit future-feature labeling
- Dark, dim, and light themes
- Accent, density, corner, sidebar, and constrained dashboard-layout controls
- Local browser persistence via `localStorage`

All values and device state in this prototype are mock data.

## Client direction

The OpenLinkHub service and its local API remain the source of truth. The web UI
continues as a first-class client.

A future desktop prototype should be Plasma-first, using Qt 6 and Kirigami for a
native KDE presentation while consuming the same service API. That keeps device
logic out of the desktop shell and leaves room for other desktop environments or
client implementations later.

The intended contribution path is an upstream pull request once the interaction
model, capability mapping, accessibility, and maintainability are polished
enough for the project owner to review.
