"""Allowlisted diagnostics: never export raw service payloads or user strings."""

import platform
import re
from collections import Counter

from PyQt6.QtCore import PYQT_VERSION_STR, QT_VERSION_STR

from .application import APP_ID, VERSION


TAB_NAMES = {"Overview", "Cooling", "Sensors", "Lighting", "Topology", "Display",
             "Keys", "DPI", "Buttons", "Controls", "Analog", "Actuation", "Vibration",
             "Performance", "Pairing", "Audio", "Profiles", "Power"}


def report(client):
    """Return aggregate capabilities, with no identifiers, names, paths or logs."""
    tabs = Counter(tab["name"] for device in client.devices
                   for tab in device.get("tabs", []) if tab.get("name") in TAB_NAMES)
    version = re.match(r"^v?(\d+\.\d+(?:\.\d+)?)\b", str(client.serviceInfo.get("version", "")))
    runtime = client.lightingRuntime
    return {
        "schemaVersion": 1,
        "application": {"id": APP_ID, "version": VERSION, "channel": "alpha"},
        "environment": {"python": platform.python_version(), "qt": QT_VERSION_STR,
                        "pyqt": PYQT_VERSION_STR, "system": platform.system(),
                        "architecture": platform.machine()},
        "connection": {
            "mode": client.mode if client.mode in {"demo", "live"} else "unknown",
            "state": client.connectionState if client.connectionState in {
                "demo", "connecting", "connected", "degraded", "disconnected", "offline", "error"
            } else "unknown",
            "contract": "1.0" if client.contractVersion == "1.0" else "unavailable",
            "serviceVersion": version[1] if version else "not reported",
        },
        "inventory": {"deviceCount": len(client.devices), "tabs": dict(sorted(tabs.items()))},
        "operations": {"lightingAssignment": client.lightingAssignmentAvailable,
                       "lightingOwnership": client.lightingOwnershipAvailable,
                       "runtime": [op for op in ("recover", "identify") if op in (runtime.get("operations") or [])]},
        "lighting": {"renderer": runtime.get("renderer") if runtime.get("renderer") in {
            "running", "stalled", "stopped", "unavailable"} else "unavailable"},
    }
