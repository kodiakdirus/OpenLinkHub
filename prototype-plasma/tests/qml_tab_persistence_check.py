#!/usr/bin/env python3
"""Exercise GUI-wide presentation stability across telemetry replacement."""

from __future__ import annotations

from copy import deepcopy
import os
from pathlib import Path
import sys


PROTOTYPE_ROOT = Path(__file__).resolve().parents[1]
if str(PROTOTYPE_ROOT) not in sys.path:
    sys.path.insert(0, str(PROTOTYPE_ROOT))

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtCore import QMetaObject, QObject, Qt, QUrl  # noqa: E402
from PyQt6.QtGui import QGuiApplication  # noqa: E402
from PyQt6.QtQml import QQmlApplicationEngine  # noqa: E402

from backend import BackendController  # noqa: E402


def variant(value: object) -> object:
    return value.toVariant() if hasattr(value, "toVariant") else value


def settle(app: QGuiApplication) -> None:
    app.processEvents()
    app.processEvents()


def invoke(target: QObject, method: str) -> None:
    if not QMetaObject.invokeMethod(
        target,
        method,
        Qt.ConnectionType.DirectConnection,
    ):
        raise RuntimeError(f"Could not invoke {method}.")


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

    devices_property = variant(root.property("demoDevices"))
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

    page.setProperty("selectedTabKey", "Overview")
    settle(app)
    device_layout_revision = page.property("layoutPresentationRevision")
    device_telemetry = deepcopy(variant(root.property("demoDevices")))
    device_telemetry[0]["tabs"][0]["groups"][0]["items"][0]["value"] = "Changed"
    root.setProperty("demoDevices", device_telemetry)
    settle(app)
    if page.property("layoutPresentationRevision") != device_layout_revision:
        print("Telemetry-only replacement rebuilt device-tab cells.", file=sys.stderr)
        return 8

    root.setProperty("activeSection", "devices")
    settle(app)
    devices_page = root.findChild(QObject, "devicesPage")
    filter_field = root.findChild(QObject, "deviceFilterField")
    if devices_page is None or filter_field is None:
        print("Devices page presentation controls were not created.", file=sys.stderr)
        return 9
    filter_field.setProperty("text", "mouse")
    app.processEvents()
    original_revision = devices_page.property("presentationRevision")

    devices_property = variant(root.property("demoDevices"))
    telemetry_refresh = deepcopy(devices_property)
    telemetry_refresh[0]["tabs"][0]["groups"][0]["items"][0]["value"] = "Updated"
    root.setProperty("demoDevices", telemetry_refresh)
    app.processEvents()
    app.processEvents()

    if filter_field.property("text") != "mouse":
        print("Telemetry-style model replacement reset the device filter.", file=sys.stderr)
        return 10
    if devices_page.property("presentationRevision") != original_revision:
        print("Telemetry-only replacement rebuilt the device-card presentation.", file=sys.stderr)
        return 11

    card_refresh = deepcopy(telemetry_refresh)
    card_refresh[0]["subtitle"] += " · card changed"
    root.setProperty("demoDevices", card_refresh)
    app.processEvents()
    app.processEvents()
    if devices_page.property("presentationRevision") <= original_revision:
        print("A card-visible model change did not update the presentation.", file=sys.stderr)
        return 12

    search_field = root.findChild(QObject, "globalSearchField")
    search_popup = root.findChild(QObject, "globalSearchPopup")
    if search_field is None or search_popup is None:
        print("Global search controls were not created.", file=sys.stderr)
        return 13
    search_field.setProperty("text", "devices")
    settle(app)
    search_revision = root.property("searchPresentationRevision")
    if not search_popup.property("opened"):
        print("Global search popup did not open.", file=sys.stderr)
        return 14
    search_refresh = deepcopy(variant(root.property("demoDevices")))
    search_refresh[0]["tabs"][0]["groups"][0]["items"][0]["value"] = "Search refresh"
    root.setProperty("demoDevices", search_refresh)
    settle(app)
    if not search_popup.property("opened"):
        print("Telemetry replacement closed the global search popup.", file=sys.stderr)
        return 15
    if root.property("searchPresentationRevision") != search_revision:
        print("Telemetry-only replacement rebuilt global search results.", file=sys.stderr)
        return 16
    search_field.setProperty("text", "")
    settle(app)

    root.setProperty("activeSection", "cooling")
    settle(app)
    cooling_page = root.findChild(QObject, "coolingPage")
    profile_combo = variant(cooling_page.property("firstProfileControl")) if cooling_page else None
    if cooling_page is None or profile_combo is None:
        names = [
            child.objectName()
            for child in root.findChildren(QObject)
            if "cooling" in child.objectName().lower()
        ]
        print(
            "Cooling refresh controls were not created: " + ", ".join(names),
            file=sys.stderr,
        )
        return 17
    cooling_page.setProperty("expandedZones", {"radiator": True})
    settle(app)
    expanded = variant(cooling_page.property("expandedZones"))
    if not expanded.get("radiator", False):
        print("Cooling channel did not expand.", file=sys.stderr)
        return 18
    cooling_page.setProperty("firstProfilePopupRequested", True)
    settle(app)
    if not cooling_page.property("firstProfilePopupOpened"):
        print("Cooling profile popup did not open.", file=sys.stderr)
        return 19
    cooling_revision = cooling_page.property("presentationRevision")
    cooling_refresh = deepcopy(variant(root.property("demoCoolingZones")))
    cooling_refresh[0]["temperature"] = "39.9°C"
    root.setProperty("demoCoolingZones", cooling_refresh)
    settle(app)
    expanded = variant(cooling_page.property("expandedZones"))
    if not expanded.get("radiator", False):
        print("Telemetry replacement collapsed the cooling channel.", file=sys.stderr)
        return 20
    if not cooling_page.property("firstProfilePopupOpened"):
        print("Telemetry replacement closed the cooling profile popup.", file=sys.stderr)
        return 21
    if cooling_page.property("presentationRevision") != cooling_revision:
        print("Telemetry-only replacement rebuilt cooling-channel delegates.", file=sys.stderr)
        return 22
    cooling_page.setProperty("firstProfilePopupRequested", False)
    settle(app)

    root.setProperty("activeSection", "overview")
    settle(app)
    overview_page = root.findChild(QObject, "overviewPage")
    if overview_page is None:
        print("Overview page was not created.", file=sys.stderr)
        return 23
    overview_revision = overview_page.property("presentationRevision")
    overview_metrics = deepcopy(variant(root.property("demoOverviewMetrics")))
    overview_metrics[0]["state"] = "Refreshed"
    root.setProperty("demoOverviewMetrics", overview_metrics)
    overview_zones = deepcopy(variant(root.property("demoCoolingZones")))
    overview_zones[0]["temperature"] = "40.1°C"
    root.setProperty("demoCoolingZones", overview_zones)
    overview_devices = deepcopy(variant(root.property("demoDevices")))
    overview_devices[0]["subtitle"] += " · telemetry"
    root.setProperty("demoDevices", overview_devices)
    settle(app)
    if overview_page.property("presentationRevision") != overview_revision:
        print("Telemetry-only replacement rebuilt Overview delegates.", file=sys.stderr)
        return 24

    print("All audited stateful and live presentation surfaces survived telemetry replacement.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
