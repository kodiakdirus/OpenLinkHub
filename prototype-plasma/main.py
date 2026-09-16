#!/usr/bin/env python3
"""Launch the OpenLinkHub Plasma community desktop client."""

from __future__ import annotations

import argparse
import os
import sys
import tempfile
from pathlib import Path

if __package__:
    from .backend.application import APP_ID, APP_NAME, VERSION
else:
    from backend.application import APP_ID, APP_NAME, VERSION


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the OpenLinkHub Plasma community alpha client."
    )
    parser.add_argument("--version", action="version", version=f"{APP_NAME} {VERSION}")
    parser.add_argument(
        "--screenshot",
        metavar="PNG",
        help="render one offscreen frame to PNG and exit",
    )
    parser.add_argument(
        "--smoke-test",
        action="store_true",
        help="instantiate every workspace and device page offscreen, then exit",
    )
    parser.add_argument(
        "--page",
        choices=[
            "overview",
            "profiles",
            "devices",
            "cooling",
            "lighting",
            "input",
            "audio",
            "displays",
            "automations",
            "integrations",
            "service",
            "device",
        ],
        help="open a specific workspace (useful with --screenshot)",
    )
    parser.add_argument(
        "--dialog",
        action="store_true",
        help="open the primary editor dialog for the selected page",
    )
    parser.add_argument(
        "--arrange",
        action="store_true",
        help="open the selected page in cell-arrangement mode",
    )
    parser.add_argument(
        "--live",
        action="store_true",
        help="connect to the local service at 127.0.0.1:27003",
    )
    parser.add_argument("--demo", action="store_true", help="start with demo data, overriding the saved data source")
    parser.add_argument(
        "--device-index",
        type=int,
        default=0,
        help="select a device card by index for device-page inspection",
    )
    parser.add_argument(
        "--device-tab",
        help="select a named device tab for inspection (for example Lighting)",
    )
    args = parser.parse_args()
    if args.demo and args.live:
        parser.error("--demo and --live cannot be used together")
    return args


def main() -> int:
    args = parse_args()

    if args.screenshot or args.smoke_test:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

    from PyQt6.QtCore import QCoreApplication, QEvent, QObject, QTimer, QUrl
    from PyQt6.QtGui import QGuiApplication, QIcon
    from PyQt6.QtQml import QQmlApplicationEngine

    if __package__:
        from .backend import BackendController
    else:
        from backend import BackendController

    QCoreApplication.setOrganizationName("OpenLinkHub")
    QCoreApplication.setApplicationName(APP_NAME)
    QCoreApplication.setApplicationVersion(VERSION)

    app = QGuiApplication(sys.argv[:1])
    app.setDesktopFileName(APP_ID)
    app.setWindowIcon(QIcon(str(Path(__file__).resolve().parent / "packaging" / f"{APP_ID}.svg")))
    QIcon.setThemeSearchPaths(QIcon.themeSearchPaths() + ["/usr/share/icons"])
    QIcon.setFallbackThemeName("breeze")
    if not QIcon.themeName():
        QIcon.setThemeName("breeze")

    # Automated renders must not read or overwrite the user's presentation.
    temporary_preferences = tempfile.TemporaryDirectory(prefix="openlinkhub-render-") if args.screenshot or args.smoke_test else None
    backend = BackendController(preferences_path=(
        str(Path(temporary_preferences.name) / "preferences.json") if temporary_preferences else None
    ))
    engine = QQmlApplicationEngine()
    qml_errors = []
    engine.warnings.connect(lambda warnings: qml_errors.extend(str(warning.toString()) for warning in warnings))
    engine.rootContext().setContextProperty("backend", backend)
    qml_file = Path(__file__).resolve().parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Failed to create the QML application window.", file=sys.stderr)
        return 1

    window = engine.rootObjects()[0]
    use_live = args.live or (not args.demo and not temporary_preferences and backend.preferences.values["mode"] == "live")
    if use_live:
        backend.setMode("live")
        app.processEvents()
    if args.device_index >= 0:
        window.setProperty("selectedDeviceIndex", args.device_index)
    if args.page:
        window.setProperty("activeSection", args.page)
    if args.device_tab:
        device_page = window.findChild(QObject, "devicePage")
        if device_page is not None:
            device_page.setProperty("selectedTabKey", args.device_tab)
    if args.dialog:
        engine.rootObjects()[0].setProperty("demoDialog", True)
    if args.arrange:
        engine.rootObjects()[0].setProperty("demoArrange", True)

    def select_live_device() -> None:
        if not backend.devices:
            return
        backend.dataChanged.disconnect(select_live_device)

        def select() -> None:
            index = min(max(0, args.device_index), len(backend.devices) - 1)
            window.setProperty("selectedDeviceIndex", index)
            window.setProperty("selectedDeviceId", backend.devices[index]["id"])
            if args.device_tab:
                device_page = window.findChild(QObject, "devicePage")
                if device_page is not None:
                    device_page.setProperty("selectedTabKey", args.device_tab)
        QTimer.singleShot(0, select)

    if use_live:
        backend.dataChanged.connect(select_live_device)

    if args.screenshot:
        destination = Path(args.screenshot).expanduser().resolve()

        def capture() -> None:
            if qml_errors:
                print("\n".join(qml_errors), file=sys.stderr)
                app.exit(3)
                return
            destination.parent.mkdir(parents=True, exist_ok=True)
            window = engine.rootObjects()[0]
            screen = window.screen() or app.primaryScreen()
            pixmap = screen.grabWindow(int(window.winId()))
            if pixmap.isNull() or not pixmap.save(str(destination)):
                print(f"Failed to save screenshot to {destination}", file=sys.stderr)
                app.exit(2)
                return
            print(destination)
            app.quit()

        # Live renders intentionally span the first periodic refresh so
        # screenshots also exercise navigation-state persistence.
        QTimer.singleShot(5200 if args.live else 1200, capture)

    if args.smoke_test:
        window = engine.rootObjects()[0]
        sections = [
            "overview",
            "profiles",
            "devices",
            "cooling",
            "lighting",
            "input",
            "audio",
            "displays",
            "automations",
            "integrations",
            "service",
        ]
        checks = []
        device_count = 0
        tab_count = 0

        def advance() -> None:
            if not checks:
                if qml_errors:
                    print("\n".join(qml_errors), file=sys.stderr)
                    app.exit(3)
                    return
                print(f"All {len(sections)} workspaces, {device_count} device shells and {tab_count} tabs instantiated without QML warnings.")
                app.quit()
                return

            property_name, value = checks.pop(0)
            if property_name == "selectedDeviceIndex":
                window.setProperty("selectedDeviceId", "")
                window.setProperty("activeSection", "device")
            if property_name == "selectedTabKey":
                page = window.findChild(QObject, "devicePage")
                if page is None:
                    app.exit(3)
                    return
                page.setProperty(property_name, value)
            else:
                window.setProperty(property_name, value)
            QTimer.singleShot(120, advance)

        attempts = 0

        def start_checks() -> None:
            nonlocal attempts, device_count, tab_count
            if use_live and not backend.connected:
                attempts += 1
                if attempts >= 40:
                    print("Live smoke test could not connect to the service.", file=sys.stderr)
                    app.exit(4)
                else:
                    QTimer.singleShot(250, start_checks)
                return
            devices = backend.devices if use_live else window.property("demoDevices").toVariant()
            device_count = len(devices)
            checks.extend(("activeSection", section) for section in sections)
            for index, device in enumerate(devices):
                checks.append(("selectedDeviceIndex", index))
                for tab in device.get("tabs", []):
                    checks.append(("selectedTabKey", tab["name"]))
                    tab_count += 1
            advance()

        QTimer.singleShot(250, start_checks)

    result = app.exec()
    # QML bindings must disappear while their Python context objects still live.
    # In particular, a failed connection can leave callbacks retaining the engine
    # beyond Python's ordinary local-variable teardown order.
    engine.deleteLater()
    QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
    if temporary_preferences:
        temporary_preferences.cleanup()
    return result


if __name__ == "__main__":
    raise SystemExit(main())
