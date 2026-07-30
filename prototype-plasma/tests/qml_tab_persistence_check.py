#!/usr/bin/env python3
"""Exercise the device-tab selection across a same-device model replacement."""

from __future__ import annotations

from copy import deepcopy
import os
from pathlib import Path
import sys


PROTOTYPE_ROOT = Path(__file__).resolve().parents[1]
if str(PROTOTYPE_ROOT) not in sys.path:
    sys.path.insert(0, str(PROTOTYPE_ROOT))

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtCore import QObject, QUrl  # noqa: E402
from PyQt6.QtGui import QGuiApplication  # noqa: E402
from PyQt6.QtQml import QQmlApplicationEngine  # noqa: E402

from backend import BackendController  # noqa: E402


def main() -> int:
    app = QGuiApplication([])
    engine = QQmlApplicationEngine()
    backend = BackendController(parent=engine)
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(PROTOTYPE_ROOT / "qml" / "Main.qml")))
    if not engine.rootObjects():
        print("QML root did not load.", file=sys.stderr)
        return 1

    root = engine.rootObjects()[0]
    root.setProperty("activeSection", "device")
    app.processEvents()
    page = root.findChild(QObject, "devicePage")
    if page is None:
        print("Device page was not created.", file=sys.stderr)
        return 2
    tab_bar = page.findChild(QObject, "deviceTabBar")
    if tab_bar is None:
        print("Device tab bar was not created.", file=sys.stderr)
        return 3

    page.setProperty("selectedTabKey", "Lighting")
    app.processEvents()
    if page.property("selectedTabKey") != "Lighting":
        print("Could not select the Lighting tab.", file=sys.stderr)
        return 4
    selected_index = page.property("selectedTab")
    if selected_index <= 0 or tab_bar.property("currentIndex") != selected_index:
        print("The visible tab indicator did not follow Lighting.", file=sys.stderr)
        return 5

    devices_property = root.property("demoDevices")
    if hasattr(devices_property, "toVariant"):
        devices_property = devices_property.toVariant()
    refreshed_devices = deepcopy(devices_property)
    refreshed_devices[0]["subtitle"] += " · refreshed"
    root.setProperty("demoDevices", refreshed_devices)
    app.processEvents()

    if page.property("selectedTabKey") != "Lighting":
        print("Telemetry-style model replacement reset the selected tab.", file=sys.stderr)
        return 6
    if tab_bar.property("currentIndex") != selected_index:
        print("Telemetry-style model replacement reset the visible tab indicator.", file=sys.stderr)
        return 7
    print("Device tab content and visible indicator survived a same-device model replacement.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
