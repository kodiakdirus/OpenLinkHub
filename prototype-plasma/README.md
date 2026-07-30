# OpenLinkHub Plasma Prototype

This is a backend-free native Qt 6/Kirigami interaction prototype for an
OpenLinkHub desktop client. It is deliberately a presentation-only application:
it does not import an HTTP client, open a socket, read OpenLinkHub configuration,
or control hardware.

## Run

From the OpenLinkHub repository root:

```bash
./prototype-plasma/run.sh
```

The launcher checks for Python 3, PyQt6, and the system Kirigami QML module
before starting. SparkleDog already has those dependencies through its Plasma
installation.

For a deterministic offscreen render:

```bash
./prototype-plasma/run.sh --page cooling \
  --dialog \
  --screenshot /tmp/openlinkhub-plasma.png
```

To instantiate every workspace and device shell without opening a visible
window:

```bash
./prototype-plasma/run.sh --smoke-test
```

## Included interactions

- Native Breeze/Plasma controls and icon theme
- Searchable global workspaces and device commands
- Dedicated global profile library with game/application launch-rule concepts
- Capability-aware device tabs
- Mock Quiet, Balanced, Performance, and Custom operating modes
- Interactive cooling-curve profile manager
- Custom lighting-scene editor, targets, brightness, and hardware-lighting controls
- Display-idle lights-out automation concept
- Configurable Plasma System Monitor sensor-export concept for coolant, pump,
  fan, battery, and other read-only Corsair telemetry
- Keyboard, mouse, audio, display, automation, and integration surfaces
- Theme, accent, density, corner, and sidebar presentation controls
- Local notifications and explicit prototype/offline state

All values reset when the application exits. There is intentionally no
persistence and no backend callback path.

## Architecture boundary

The intended production boundary remains:

```text
OpenLinkHub service/API
        ├── Web client
        └── Native Plasma client
```

Device behavior, validation, safety policy, and persistent state stay in the
service. This prototype explores only the native client's information
architecture and interaction model.
