import json
from pathlib import Path
import sys
import tempfile
import unittest

from PyQt6.QtCore import QCoreApplication, QUrl

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend import BackendController
from backend.diagnostics import report


class DiagnosticsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.client = BackendController(preferences_path=str(Path(self.directory.name) / "prefs.json"))
        self.client._get_document = lambda *a, **k: self.fail("Export must not contact the service")
        self.client._put_document = lambda *a, **k: self.fail("Export must not mutate hardware")

    def test_only_aggregate_allowlisted_data_is_exported(self):
        secret = "SERIAL-secret-home-kodi-profile-label"
        self.client._devices = [{"id": secret, "name": secret, "firmware": secret,
                                 "tabs": [{"name": "Lighting", "groups": [{"value": secret}]}, {"name": secret}]}]
        self.client._lighting_runtime = {"profile": secret, "members": [secret], "lease": {"id": secret},
                                         "renderer": "running", "operations": ["identify", secret]}
        self.client._service_info = {"version": "0.8.9-" + secret, "features": [{"reason": secret}]}
        self.client._error_message = secret
        data = report(self.client)
        self.assertNotIn(secret, json.dumps(data))
        self.assertEqual(data["inventory"], {"deviceCount": 1, "tabs": {"Lighting": 1}})
        self.assertEqual(data["connection"]["serviceVersion"], "0.8.9")
        self.assertEqual(data["operations"]["runtime"], ["identify"])
        path = Path(self.directory.name) / "diagnostics.json"
        self.assertTrue(self.client.exportDiagnostics(QUrl.fromLocalFile(str(path))))
        self.assertEqual(json.loads(path.read_text()), data)

    def test_export_failure_is_reported_without_exposing_paths(self):
        self.assertFalse(self.client.exportDiagnostics(QUrl("https://example.org/report")))
        self.assertFalse(self.client.exportDiagnostics(QUrl.fromLocalFile(str(Path(self.directory.name) / "missing/report.json"))))
        self.assertIn("Could not save", self.client.diagnosticsMessage)
        self.assertNotIn(self.directory.name, self.client.diagnosticsMessage)

    def test_compatibility_explains_demo_missing_legacy_and_versioned_service(self):
        self.assertIn("simulated", self.client.compatibilityText)
        self.client._mode = "live"
        self.client._connection_state = "offline"
        self.assertIn("Install or start", self.client.compatibilityText)
        self.client._connection_state = "connected"
        self.assertIn("Legacy compatibility", self.client.compatibilityText)
        self.client._contract_version = "1.0"
        self.assertIn("Versioned API connected", self.client.compatibilityText)
