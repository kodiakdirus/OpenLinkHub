from __future__ import annotations

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sys
from threading import Thread
import time
import unittest

from PyQt6.QtCore import QCoreApplication


PROTOTYPE_ROOT = Path(__file__).resolve().parents[1]
if str(PROTOTYPE_ROOT) not in sys.path:
    sys.path.insert(0, str(PROTOTYPE_ROOT))

from backend.controller import BackendController  # noqa: E402


FIXTURE = Path(__file__).resolve().parent / "fixtures" / "legacy_snapshot.json"


class FixtureHandler(BaseHTTPRequestHandler):
    fixture: dict = {}
    requests: list[str] = []
    fail_inventory = False
    support_contract = False
    contract_payload: dict = {}
    contract_etag = '"fixture-s7-t11"'
    label_commands: list[dict] = []

    def do_GET(self) -> None:
        type(self).requests.append(f"GET {self.path}")
        if self.path == "/api/v1/snapshot":
            if (
                type(self).support_contract
                and self.headers.get("If-None-Match")
                == type(self).contract_etag
            ):
                self.send_response(304)
                self.send_header("ETag", type(self).contract_etag)
                self.end_headers()
                return
            payload = (
                type(self).contract_payload
                if type(self).support_contract
                else type(self).fixture["inventory"]
            )
        elif self.path == "/api/devices/" and type(self).fail_inventory:
            self.send_response(503)
            self.end_headers()
            return
        elif self.path == "/api/devices/":
            payload = type(self).fixture["inventory"]
        elif self.path == "/api/batteryStats":
            payload = type(self).fixture["battery"]
        elif self.path == "/api/cpuTemp/clean":
            payload = type(self).fixture["cpu"]
        elif self.path == "/api/gpuTemp/clean":
            payload = type(self).fixture["gpu"]
        elif self.path == "/api/color/":
            payload = type(self).fixture["lighting"]
        elif self.path.startswith("/api/devices/"):
            device_id = self.path.rsplit("/", 1)[-1]
            payload = {
                "code": 200,
                "status": 0,
                "device": type(self).fixture["details"].get(device_id),
            }
        else:
            self.send_response(404)
            self.end_headers()
            return

        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        if self.path == "/api/v1/snapshot" and type(self).support_contract:
            self.send_header("ETag", type(self).contract_etag)
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_POST(self) -> None:
        type(self).requests.append(f"POST {self.path}")
        self.send_response(405)
        self.end_headers()

    def do_PUT(self) -> None:
        type(self).requests.append(f"PUT {self.path}")
        if self.path != "/api/v1/devices/label" or not type(self).support_contract:
            self.send_response(405)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0"))
        command = json.loads(self.rfile.read(length))
        type(self).label_commands.append(command)
        current_revision = type(self).contract_payload["revision"]
        if command.get("expectedRevision") != current_revision:
            status = 409
            result_status = "rejected"
            message = "State changed; refresh before applying."
            changed = False
        else:
            status = 200
            result_status = "succeeded"
            message = "Label applied and verified from refreshed service state."
            changed = True
            type(self).contract_payload["revision"] += 1
            current_revision += 1
            target = type(self).contract_payload["data"]["devices"][0]["labelTargets"][0]
            target["label"] = command["label"]
            type(self).contract_etag = f'"fixture-s{current_revision}-t11"'

        payload = {
            "apiVersion": "1.0",
            "kind": "command-result",
            "revision": current_revision,
            "data": {
                "operation": "device-label.update",
                "status": result_status,
                "message": message,
                "changed": changed,
                "refreshRequired": status == 409,
                "issues": [],
            },
        }
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_DELETE(self) -> None:
        type(self).requests.append(f"DELETE {self.path}")
        self.send_response(405)
        self.end_headers()

    def log_message(self, _format: str, *args: object) -> None:
        return


class BackendControllerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QCoreApplication.instance() or QCoreApplication([])
        FixtureHandler.fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
        FixtureHandler.contract_payload = {
            "apiVersion": "1.0",
            "kind": "snapshot",
            "revision": 7,
            "telemetryRevision": 11,
            "data": {
                "service": {"contract": "1.0"},
                "system": {
                    "cpu": {"value": 50.5, "unit": "celsius"},
                    "gpu": {"value": 45.0, "unit": "celsius"},
                },
                "devices": [
                    {
                        "id": "mouse-1",
                        "product": "SCIMITAR ELITE",
                        "productId": 1,
                        "productType": 1,
                        "deviceType": "mouse",
                        "firmware": "5.6.28",
                        "online": True,
                        "hidden": False,
                        "transport": "usb",
                        "profile": {"active": "Desktop", "savedCount": 1},
                        "capabilities": [
                            {
                                "id": "overview",
                                "label": "Overview",
                                "available": True,
                                "access": "read-write",
                                "operations": ["read", "update-label"],
                                "options": {"labelTargetCount": 1},
                            },
                            {
                                "id": "dpi",
                                "label": "DPI",
                                "available": True,
                                "access": "read",
                                "operations": ["read"],
                                "options": {
                                    "stageCount": 5,
                                    "minimum": 100,
                                    "maximum": 26000,
                                },
                            },
                        ],
                        "channels": [],
                        "labelTargets": [
                            {
                                "id": "device",
                                "scope": "device",
                                "name": "Whole device",
                                "label": "Mouse",
                            }
                        ],
                    }
                ],
                "coolingProfiles": [],
                "scheduler": {},
                "displays": [],
                "dashboard": {},
                "lcdAssets": [],
                "lcdProfiles": [],
            },
        }
        FixtureHandler.requests = []
        FixtureHandler.label_commands = []
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), FixtureHandler)
        cls.thread = Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def setUp(self) -> None:
        FixtureHandler.requests = []
        FixtureHandler.label_commands = []
        FixtureHandler.fail_inventory = False
        FixtureHandler.support_contract = False
        FixtureHandler.contract_payload["revision"] = 7
        FixtureHandler.contract_payload["data"]["devices"][0]["labelTargets"][0]["label"] = "Mouse"
        FixtureHandler.contract_etag = '"fixture-s7-t11"'
        endpoint = f"http://127.0.0.1:{self.server.server_port}"
        self.controller = BackendController(
            endpoint=endpoint,
            refresh_interval_ms=60_000,
        )

    def tearDown(self) -> None:
        self.controller.setMode("demo")
        self.controller.deleteLater()
        self.app.processEvents()

    def wait_until(self, predicate, timeout: float = 3.0) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.app.processEvents()
            if predicate():
                return
            time.sleep(0.01)
        self.fail("Timed out waiting for asynchronous controller state.")

    def test_refuses_non_loopback_endpoint(self) -> None:
        with self.assertRaises(ValueError):
            BackendController(endpoint="http://192.0.2.10:27003")

    def test_demo_mode_opens_no_connection(self) -> None:
        self.app.processEvents()
        self.assertEqual(self.controller.mode, "demo")
        self.assertEqual(self.controller.apiCallCount, 0)
        self.assertEqual(FixtureHandler.requests, [])

    def test_live_refresh_is_get_only_and_normalized(self) -> None:
        self.controller.setMode("live")
        self.wait_until(
            lambda: not self.controller.refreshing
            and self.controller.connectionState == "connected"
        )

        self.assertEqual(len(self.controller.devices), 4)
        self.assertEqual(self.controller.telemetry["coolant"], "38.5°C")
        hub = next(
            device
            for device in self.controller.devices
            if device["name"] == "iCUE LINK System Hub"
        )
        lighting = next(tab for tab in hub["tabs"] if tab["name"] == "Lighting")
        self.assertEqual(lighting["lightingEditor"]["profileCount"], 3)
        self.assertTrue(FixtureHandler.requests)
        self.assertTrue(
            all(request.startswith("GET ") for request in FixtureHandler.requests)
        )
        self.assertIn("GET /api/color/", FixtureHandler.requests)
        self.assertEqual(
            self.controller.contractSource,
            "Legacy compatibility adapter",
        )

    def test_legacy_mode_refuses_label_write_without_sending_request(self) -> None:
        self.controller.setMode("live")
        self.wait_until(
            lambda: not self.controller.refreshing
            and self.controller.connectionState == "connected"
        )
        before = list(FixtureHandler.requests)

        self.controller.updateLabel("mouse-1", "device", "Desk Mouse")

        self.assertEqual(self.controller.commandStatus, "rejected")
        self.assertEqual(FixtureHandler.requests, before)
        self.assertNotIn("PUT /api/v1/devices/label", FixtureHandler.requests)

    def test_versioned_snapshot_uses_one_request_and_skips_legacy_fanout(self) -> None:
        FixtureHandler.support_contract = True
        self.controller.setMode("live")
        self.wait_until(
            lambda: not self.controller.refreshing
            and self.controller.connectionState == "connected"
        )

        self.assertEqual(FixtureHandler.requests, ["GET /api/v1/snapshot"])
        self.assertEqual(self.controller.contractVersion, "1.0")
        self.assertEqual(self.controller.contractRevision, 7)
        self.assertEqual(self.controller.telemetryRevision, 11)
        self.assertEqual(
            self.controller.contractSource,
            "Versioned service contract",
        )
        self.assertEqual(self.controller.devices[0]["capabilities"], ["DPI"])

        changes = 0

        def record_change() -> None:
            nonlocal changes
            changes += 1

        self.controller.dataChanged.connect(record_change)
        self.controller.refresh()
        self.wait_until(lambda: not self.controller.refreshing)
        self.assertEqual(changes, 0)
        self.assertEqual(
            FixtureHandler.requests,
            ["GET /api/v1/snapshot", "GET /api/v1/snapshot"],
        )

    def test_versioned_label_command_uses_revision_and_refreshes_verified_state(self) -> None:
        FixtureHandler.support_contract = True
        self.controller.setMode("live")
        self.wait_until(
            lambda: not self.controller.refreshing
            and self.controller.connectionState == "connected"
        )

        self.assertTrue(self.controller.devices[0]["canEditLabels"])
        self.controller.updateLabel("mouse-1", "device", "Desk Mouse")
        self.wait_until(
            lambda: not self.controller.commandBusy
            and self.controller.commandStatus == "succeeded"
            and not self.controller.refreshing
            and self.controller.devices[0]["labelTargets"][0]["label"]
            == "Desk Mouse"
        )

        self.assertEqual(
            FixtureHandler.label_commands,
            [{
                "expectedRevision": 7,
                "deviceId": "mouse-1",
                "targetId": "device",
                "label": "Desk Mouse",
            }],
        )
        self.assertIn("PUT /api/v1/devices/label", FixtureHandler.requests)
        self.assertEqual(self.controller.contractRevision, 8)
        self.assertEqual(
            self.controller.devices[0]["labelTargets"][0]["label"],
            "Desk Mouse",
        )

        self.controller.updateLabel("mouse-1", "device", "")
        self.wait_until(
            lambda: not self.controller.commandBusy
            and self.controller.commandStatus == "succeeded"
            and not self.controller.refreshing
            and self.controller.devices[0]["labelTargets"][0]["label"] == ""
        )
        self.assertEqual(
            FixtureHandler.label_commands[-1],
            {
                "expectedRevision": 8,
                "deviceId": "mouse-1",
                "targetId": "device",
                "label": "",
            },
        )
        self.assertEqual(self.controller.contractRevision, 9)

    def test_failed_refresh_preserves_last_good_snapshot(self) -> None:
        self.controller.setMode("live")
        self.wait_until(lambda: self.controller.connectionState == "connected")
        original_devices = list(self.controller.devices)

        FixtureHandler.fail_inventory = True
        self.controller.refresh()
        self.wait_until(
            lambda: not self.controller.refreshing
            and self.controller.connectionState == "degraded"
        )

        self.assertEqual(self.controller.devices, original_devices)
        self.assertIn("inventory:", self.controller.errorMessage)

        FixtureHandler.fail_inventory = False
        self.controller.refresh()
        self.wait_until(
            lambda: not self.controller.refreshing
            and self.controller.connectionState == "connected"
        )
        self.assertEqual(self.controller.devices, original_devices)
        self.assertEqual(self.controller.errorMessage, "")

    def test_background_refresh_does_not_reenter_connecting(self) -> None:
        self.controller.setMode("live")
        self.wait_until(
            lambda: not self.controller.refreshing
            and self.controller.connectionState == "connected"
        )
        observed_states: list[str] = []
        self.controller.connectionChanged.connect(
            lambda: observed_states.append(self.controller.connectionState)
        )

        self.controller.refresh()
        self.assertNotEqual(self.controller.connectionState, "connecting")
        self.wait_until(lambda: not self.controller.refreshing)

        self.assertNotIn("connecting", observed_states)
        self.assertEqual(self.controller.connectionState, "connected")


if __name__ == "__main__":
    unittest.main()
