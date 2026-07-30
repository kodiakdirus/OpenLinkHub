#!/usr/bin/env python3
"""Launch the backend-free OpenLinkHub Plasma interaction prototype."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the backend-free OpenLinkHub Plasma prototype."
    )
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
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.screenshot or args.smoke_test:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

    from PyQt6.QtCore import QCoreApplication, QTimer, QUrl
    from PyQt6.QtGui import QGuiApplication, QIcon
    from PyQt6.QtQml import QQmlApplicationEngine

    QCoreApplication.setOrganizationName("OpenLinkHub")
    QCoreApplication.setApplicationName("OpenLinkHub Plasma Prototype")
    QCoreApplication.setApplicationVersion("0.1")

    app = QGuiApplication(sys.argv[:1])
    QIcon.setThemeSearchPaths(QIcon.themeSearchPaths() + ["/usr/share/icons"])
    QIcon.setFallbackThemeName("breeze")
    if not QIcon.themeName():
        QIcon.setThemeName("breeze")

    engine = QQmlApplicationEngine()
    qml_file = Path(__file__).resolve().parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Failed to create the QML application window.", file=sys.stderr)
        return 1

    if args.page:
        engine.rootObjects()[0].setProperty("activeSection", args.page)
    if args.dialog:
        engine.rootObjects()[0].setProperty("demoDialog", True)
    if args.arrange:
        engine.rootObjects()[0].setProperty("demoArrange", True)

    if args.screenshot:
        destination = Path(args.screenshot).expanduser().resolve()

        def capture() -> None:
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

        QTimer.singleShot(1200, capture)

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
        checks = [("activeSection", section) for section in sections]
        checks.extend(
            ("selectedDeviceIndex", index)
            for index in range(7)
        )

        def advance() -> None:
            if not checks:
                print("All workspaces and device shells instantiated.")
                app.quit()
                return

            property_name, value = checks.pop(0)
            if property_name == "selectedDeviceIndex":
                window.setProperty("activeSection", "device")
            window.setProperty(property_name, value)
            QTimer.singleShot(120, advance)

        QTimer.singleShot(250, advance)

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
