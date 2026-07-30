from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
import unittest


CHECK = Path(__file__).resolve().parent / "qml_tab_persistence_check.py"
QML_ROOT = Path(__file__).resolve().parents[1] / "qml"


class QmlStateTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
