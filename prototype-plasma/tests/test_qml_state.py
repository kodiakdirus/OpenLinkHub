from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
import unittest


CHECK = Path(__file__).resolve().parent / "qml_tab_persistence_check.py"
QML_ROOT = Path(__file__).resolve().parents[1] / "qml"


class QmlStateTests(unittest.TestCase):
    def test_backend_setup_is_nonintrusive_and_always_accessible(self) -> None:
        for style in ("Basic", "org.kde.breeze"):
            with self.subTest(style=style):
                result = subprocess.run(
                    [sys.executable, str(CHECK.with_name("qml_backend_setup_check.py"))],
                    capture_output=True, text=True, timeout=20,
                    env=dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_CONTROLS_STYLE=style),
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_no_service_launcher_exits_without_dangling_qml_bindings(self) -> None:
        result = subprocess.run(
            [sys.executable, str(CHECK.with_name("launcher_no_service_check.py"))],
            capture_output=True, text=True, timeout=20,
            env=dict(os.environ, QT_QPA_PLATFORM="offscreen"),
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("TypeError", result.stderr)
        self.assertNotIn("Binding loop", result.stderr)

    def test_daily_use_workflows(self) -> None:
        for style in ("Basic", "org.kde.breeze"):
            with self.subTest(style=style):
                environment = dict(os.environ, QT_QUICK_CONTROLS_STYLE=style)
                result = subprocess.run(
                    [sys.executable, str(CHECK.with_name("qml_daily_use_check.py"))],
                    capture_output=True, text=True, timeout=20, env=environment,
                )
                self.assertEqual(result.returncode, 0, result.stdout + "\n" + result.stderr)

    def test_gui_state_survives_model_replacement(self) -> None:
        environment = dict(os.environ)
        environment["QT_QPA_PLATFORM"] = "offscreen"
        result = subprocess.run(
            [sys.executable, str(CHECK)],
            check=False,
            capture_output=True,
            text=True,
            env=environment,
            timeout=15,
        )
        self.assertEqual(
            result.returncode,
            0,
            msg=(result.stdout + "\n" + result.stderr).strip(),
        )

    def test_live_models_do_not_directly_own_stateful_controls(self) -> None:
        sources = {
            path.relative_to(QML_ROOT).as_posix(): path.read_text(encoding="utf-8")
            for path in QML_ROOT.rglob("*.qml")
        }
        combined = "\n".join(sources.values())
        forbidden = {
            "Cooling telemetry as a delegate model": "model: page.shell.coolingZones",
            "Overview telemetry as a delegate model": "model: page.shell.overviewMetrics",
            "Devices telemetry as a delegate model": "model: page.shell.devices",
            "Computed search results as a popup model": "model: root.searchResults(",
            "A changing feature choice array as a popup model": "model: row.feature.choices",
        }
        for description, needle in forbidden.items():
            with self.subTest(description=description):
                self.assertNotIn(needle, combined)

        self.assertIn("model: page.zoneKeys.length", sources["pages/CoolingPage.qml"])
        self.assertIn("model: row.choiceModel", sources["components/ControlRow.qml"])
        self.assertIn("model: root.stableSearchResults", sources["Main.qml"])

    def test_dark_modern_theme_is_the_default(self) -> None:
        main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
        service = (QML_ROOT / "pages" / "ServicePage.qml").read_text(encoding="utf-8")
        self.assertIn('property string themeMode: "Dark Modern"', main)
        self.assertIn('property color accentColor: "#0078d4"', main)
        for color in ("#181818", "#1f1f1f", "#2b2b2b", "#3c3c3c", "#cccccc"):
            with self.subTest(color=color):
                self.assertIn(color, main)
        self.assertIn('model: ["Dark Modern", "Midnight", "Dim", "Light"]', service)

    def test_guarded_label_editor_discloses_revision_and_verification(self) -> None:
        prototype = QML_ROOT.parent
        device_page = (QML_ROOT / "pages" / "DevicePage.qml").read_text(encoding="utf-8")
        dialog = (QML_ROOT / "components" / "DeviceLabelDialog.qml").read_text(encoding="utf-8")
        controller = (prototype / "backend" / "controller.py").read_text(encoding="utf-8")

        self.assertIn('text: "Edit labels"', device_page)
        self.assertIn("expected state revision", dialog.lower())
        self.assertIn("reads this label back", dialog.lower())
        self.assertIn("leave blank to clear", dialog.lower())
        self.assertIn("{0,64}", dialog)
        self.assertIn("backendClient.updateLabel", dialog)
        self.assertIn('"expectedRevision": self._contract_revision', controller)
        self.assertIn('kind="command-result"', controller)

    def test_lighting_assignment_is_capability_gated(self) -> None:
        prototype = QML_ROOT.parent
        editor = (QML_ROOT / "components" / "LightingDeviceEditor.qml").read_text(
            encoding="utf-8"
        )
        controller = (prototype / "backend" / "controller.py").read_text(
            encoding="utf-8"
        )
        main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

        self.assertIn('selectedOperations.indexOf("assign-profile")', editor)
        self.assertIn("backendClient.assignLightingProfile", editor)
        self.assertIn("commandFeedbackMessage", editor)
        self.assertIn("Not applied", editor)
        self.assertIn("Parameter edits remain a local preview", editor)
        self.assertIn('"/api/v1/lighting/assignment"', controller)
        self.assertIn('"expectedRevision": self._contract_revision', controller)
        self.assertIn("lightingAssignmentAvailable", controller)
        self.assertIn("backendClient.lightingAssignmentAvailable", main)

    def test_lighting_ownership_checkpoint_is_guarded_and_capability_gated(self) -> None:
        prototype = QML_ROOT.parent
        editor = (QML_ROOT / "components" / "LightingDeviceEditor.qml").read_text(
            encoding="utf-8"
        )
        card = (QML_ROOT / "components" / "LightingOwnershipCard.qml").read_text(
            encoding="utf-8"
        )
        dialog = (QML_ROOT / "components" / "LightingOwnershipDialog.qml").read_text(
            encoding="utf-8"
        )
        cluster = (QML_ROOT / "components" / "LightingClusterEditor.qml").read_text(
            encoding="utf-8"
        )
        members = (
            QML_ROOT / "components" / "LightingClusterMembersDialog.qml"
        ).read_text(encoding="utf-8")
        controller = (prototype / "backend" / "controller.py").read_text(
            encoding="utf-8"
        )

        self.assertIn("modelData.ownership", editor)
        self.assertIn("LightingOwnershipCard", editor)
        self.assertIn("LightingOwnershipDialog", editor)
        self.assertIn("LightingClusterEditor", editor)
        self.assertIn('text: "Change control mode…"', card)
        self.assertIn('text: "Saved individual state"', card)
        self.assertIn("Global profiles will not switch this mode implicitly", dialog)
        self.assertIn("enabled: dialog.canChange", dialog)
        self.assertIn('text: "RGB Cluster editor"', cluster)
        self.assertIn("Guarded membership · one at a time", cluster)
        self.assertIn('text: "Edit members…"', cluster)
        self.assertIn("availableDevices: editor.shell.devices", editor)
        self.assertIn('title: "Edit RGB Cluster members"', members)
        self.assertIn("Attached channels follow their parent device", members)
        self.assertIn('text: "Apply membership"', members)
        self.assertIn("enabled: dialog.canApply", members)
        self.assertIn("changedCount === 1", members)
        self.assertIn("Apply one device at a time", members)
        self.assertIn("ownership.controller === \"rgb-cluster\"", members)
        self.assertIn("ownership.controller === \"openrgb\"", members)
        self.assertIn('objectName: "clusterMembersDialog"', members)
        self.assertIn("function reconcileDraft()", members)
        self.assertIn("nextSignature === publishedSignature", members)
        self.assertIn("previous.initialSelected === incoming.initialSelected", members)
        self.assertIn("incoming.selected = previous.selected", members)
        self.assertIn("Qt.callLater(reconcileDraft)", members)
        self.assertNotIn("Qt.callLater(rebuildDraft)", members)
        self.assertIn("onClicked: dialog.setMemberSelected", members)
        self.assertIn("changeLightingController", dialog)
        self.assertIn("changeLightingController", members)
        self.assertIn("/api/v1/lighting/ownership", controller)

    def test_overview_and_service_alignment_contracts(self) -> None:
        overview = (QML_ROOT / "pages" / "OverviewPage.qml").read_text(encoding="utf-8")
        service = (QML_ROOT / "pages" / "ServicePage.qml").read_text(encoding="utf-8")
        panel_header = (QML_ROOT / "components" / "PanelHeader.qml").read_text(encoding="utf-8")
        icon_slot = (QML_ROOT / "components" / "IconSlot.qml").read_text(encoding="utf-8")
        self.assertEqual(
            overview.count("leftPadding: page.shell.compactMode ? 12 : 16"),
            2,
        )
        self.assertEqual(
            overview.count("rightPadding: page.shell.compactMode ? 12 : 16"),
            2,
        )
        self.assertEqual(service.count("PanelHeader {"), 5)
        self.assertGreaterEqual(panel_header.count("Layout.alignment: Qt.AlignTop"), 3)
        self.assertEqual(overview.count("IconSlot {"), 2)
        self.assertEqual(overview.count("horizontalAlignment: Text.AlignLeft"), 4)
        self.assertIn("Layout.minimumWidth: slotSize", icon_slot)
        self.assertIn("Layout.maximumWidth: slotSize", icon_slot)
        self.assertIn("Layout.alignment: Qt.AlignVCenter", icon_slot)
        self.assertIn('Accessible.name: "Show sidebar labels"', service)


if __name__ == "__main__":
    unittest.main()
