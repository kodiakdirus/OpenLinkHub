from pathlib import Path
import sys
import unittest

from PyQt6.QtCore import QCoreApplication

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend.controller import BackendController


class LightingRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.client = BackendController()
        self.calls = []
        self.client._put_document = lambda path, payload, callback, **kwargs: self.calls.append((path, payload, callback, kwargs))
        self.client._get_document = lambda path, callback: self.calls.append((path, callback))
        self.client._lighting_runtime = {"revision": 7, "operations": ["recover", "identify"], "members": ["hub"]}

    def test_demo_never_sends_runtime_commands(self):
        self.client.refreshLightingRuntime()
        self.client.recoverLighting()
        self.client.identifyLighting("hub")
        self.assertEqual(self.calls, [])

    def test_identify_uses_catalog_revision_and_only_published_member(self):
        self.client._mode = "live"
        self.client.identifyLighting("missing")
        self.assertEqual(self.calls, [])
        self.client.identifyLighting("hub")
        path, body, callback, kwargs = self.calls.pop()
        self.assertEqual(path, "/api/v1/lighting/identify")
        self.assertEqual(body, {"expectedRevision": 7, "deviceId": "hub", "durationMs": 3000})
        callback({"apiVersion": "1.0", "kind": "lighting-runtime-result", "data": {"status": "identifying", "message": "Active", "state": {"lease": {"id": "owned"}}}}, None)
        self.assertEqual(self.client._runtime_lease_id, "owned")
        self.client.cancelLightingIdentification()
        path, body, callback, kwargs = self.calls[-1]
        self.assertEqual(body, {"leaseId": "owned"})
        self.assertEqual(kwargs["method"], b"DELETE")

    def test_failed_or_legacy_runtime_read_disables_controls(self):
        self.client._mode = "live"
        self.client.refreshLightingRuntime()
        _, callback = self.calls.pop()
        callback({"status": 1, "data": {}}, None)
        self.assertEqual(self.client.lightingRuntime["operations"], [])
        self.assertEqual(self.client.lightingRuntime["mode"], "unknown")

    def test_result_after_mode_change_cannot_install_a_lease(self):
        self.client._mode = "live"
        self.client.identifyLighting("hub")
        _, _, callback, _ = self.calls.pop()
        self.client.setMode("demo")
        callback({"apiVersion": "1.0", "kind": "lighting-runtime-result", "data": {"status": "identifying", "state": {"lease": {"id": "stale"}}}}, None)
        self.assertEqual(self.client._runtime_lease_id, "")

    def test_pre_command_poll_cannot_discard_new_lease(self):
        self.client._mode = "live"
        self.client.refreshLightingRuntime()
        _, old_poll = self.calls.pop()
        self.client.identifyLighting("hub")
        _, _, callback, _ = self.calls.pop()
        callback({"apiVersion": "1.0", "kind": "lighting-runtime-result", "data": {"status": "identifying", "state": {"lease": {"id": "new"}}}}, None)
        old_poll({"apiVersion": "1.0", "kind": "lighting-runtime", "data": {"revision": 7}}, None)
        self.assertEqual(self.client._runtime_lease_id, "new")

    def test_editor_close_during_identify_cancels_late_lease(self):
        self.client._mode = "live"
        self.client.identifyLighting("hub")
        _, _, callback, _ = self.calls.pop()
        self.client.cancelLightingIdentification()
        self.assertTrue(self.client._runtime_cancel_pending)
        callback({"apiVersion": "1.0", "kind": "lighting-runtime-result", "data": {"status": "identifying", "state": {"lease": {"id": "late"}}}}, None)
        deletes = [call for call in self.calls if len(call) == 4 and call[3].get("method") == b"DELETE"]
        self.assertEqual(len(deletes), 1)
        self.assertEqual(deletes[0][1], {"leaseId": "late"})

    def test_malformed_runtime_fields_disable_operations(self):
        self.client._mode = "live"
        self.client.refreshLightingRuntime()
        _, callback = self.calls.pop()
        callback({"apiVersion": "1.0", "kind": "lighting-runtime", "data": {"revision": 7, "mode": "unknown", "renderer": "running", "members": ["hub"], "operations": None}}, None)
        self.assertEqual(self.client.lightingRuntime["operations"], [])
