from pathlib import Path
import sys
import tempfile
import unittest

from PyQt6.QtCore import QCoreApplication

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend import BackendController


class BackendSetupTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.client = BackendController(preferences_path=str(Path(self.directory.name) / "preferences.json"))
        self.client._get_document = lambda *a, **k: self.fail("Setup assessment must not send requests")
        self.client._put_document = lambda *a, **k: self.fail("Setup must not modify the service")

    def test_demo_does_not_assume_service_is_missing(self):
        setup = self.client.backendSetup
        self.assertEqual(setup["key"], "demo")
        self.assertEqual(setup["badge"], "Not checked")
        self.assertTrue(setup["showReminder"])
        self.assertFalse(setup["installationAvailable"])

    def test_legacy_notice_stays_stable_during_polls(self):
        self.client._mode = "live"
        self.client._set_connection("connecting", "Connecting", "")
        self.assertEqual(self.client.backendSetup["key"], "checking")
        self.assertFalse(self.client.backendSetup["showReminder"])
        self.client._set_connection("connected", "Live", "")
        self.assertEqual(self.client.backendSetup["key"], "legacy")
        self.client._set_connection("connecting", "Connecting", "")
        self.assertEqual(self.client.backendSetup["key"], "legacy")

    def test_read_only_devices_do_not_trigger_upgrade_prompts(self):
        self.client._mode = "live"
        self.client._set_contract("1.0", "Versioned", 1, 1)
        self.client._set_connection("connected", "Live", "")
        self.client._devices = [{"id": "read-only-device", "tabs": []}]
        self.assertEqual(self.client.backendSetup["key"], "ready")
        self.assertFalse(self.client.backendSetup["showReminder"])

    def test_connection_failure_does_not_recommend_reinstallation(self):
        self.client._mode = "live"
        for state in ("degraded", "offline"):
            self.client._set_connection(state, "Unavailable", "")
            self.assertEqual(self.client.backendSetup["key"], "unavailable")
            self.assertIn("Check the existing installation", self.client.backendSetup["summary"])
            self.assertFalse(self.client.backendSetup["showReminder"], "Existing connection banner handles failures")
            self.client._set_connection("connecting", "Retrying", "")
            self.assertEqual(self.client.backendSetup["key"], "unavailable")
