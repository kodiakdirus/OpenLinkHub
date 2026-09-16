from pathlib import Path
import json
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend.preferences import Preferences


class PreferencesTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name) / "preferences.json"

    def test_presentation_and_source_survive_restart(self):
        preferences = Preferences(self.path)
        self.assertFalse(self.path.exists())
        self.assertTrue(preferences.setValue("themeMode", "Light"))
        self.assertTrue(preferences.setValue("mode", "live"))
        self.assertTrue(preferences.setValue("backendSetupReminderDismissed", True))
        layout = {"device:hub:Cooling": {"groups": [{"key": "fans", "wide": True}]}}
        self.assertTrue(preferences.setValue("layouts", layout))
        restarted = Preferences(self.path)
        self.assertEqual(restarted.values["themeMode"], "Light")
        self.assertEqual(restarted.values["mode"], "live")
        self.assertTrue(restarted.values["backendSetupReminderDismissed"])
        self.assertEqual(restarted.values["layouts"], layout)
        self.assertTrue(restarted.resetPresentation())
        reset = Preferences(self.path).values
        self.assertEqual(reset["themeMode"], "Dark Modern")
        self.assertEqual(reset["layouts"], {})
        self.assertEqual(reset["mode"], "live")
        self.assertTrue(reset["backendSetupReminderDismissed"], "Appearance reset must not re-enable setup reminders")

    def test_invalid_values_and_hardware_fields_are_rejected(self):
        preferences = Preferences(self.path)
        for key, value in [("fanSpeed", 0), ("compactMode", "false"), ("cornerRadius", 1000),
                           ("themeMode", "missing"), ("accentColor", []),
                           ("backendSetupReminderDismissed", "true"),
                           ("layouts", {"cooling": {"profile": "unsafe"}})]:
            with self.subTest(key=key):
                self.assertFalse(preferences.setValue(key, value))
        self.assertFalse(self.path.exists())

    def test_corrupt_file_uses_defaults_and_reports_problem(self):
        self.path.write_text("{broken", encoding="utf-8")
        preferences = Preferences(self.path)
        self.assertEqual(preferences.values["themeMode"], "Dark Modern")
        self.assertTrue(preferences.error)
        self.assertTrue(preferences.setValue("themeMode", "Light"))
        self.assertFalse(preferences.error)
        self.assertEqual(json.loads(self.path.read_text())["version"], 1)

    def test_write_failure_keeps_last_saved_values(self):
        # Using a directory as the destination fails even when tests run as root.
        self.path.mkdir()
        preferences = Preferences(self.path)
        self.assertFalse(preferences.setValue("themeMode", "Light"))
        self.assertEqual(preferences.values["themeMode"], "Dark Modern")
        self.assertTrue(preferences.error)


if __name__ == "__main__":
    unittest.main()
