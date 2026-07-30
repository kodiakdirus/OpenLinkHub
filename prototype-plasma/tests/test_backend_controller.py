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

    def do_GET(self) -> None:
        type(self).requests.append(f"GET {self.path}")
        if self.path == "/api/devices/" and type(self).fail_inventory:
            self.send_response(503)
            self.end_headers()
            return

        if self.path == "/api/devices/":
            payload = type(self).fixture["inventory"]
        elif self.path == "/api/batteryStats":
            payload = type(self).fixture["battery"]
        elif self.path == "/api/cpuTemp/clean":
            payload = type(self).fixture["cpu"]
        elif self.path == "/api/gpuTemp/clean":
            payload = type(self).fixture["gpu"]
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
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_POST(self) -> None:
        type(self).requests.append(f"POST {self.path}")
        self.send_response(405)
        self.end_headers()

    def do_PUT(self) -> None:
        type(self).requests.append(f"PUT {self.path}")
        self.send_response(405)
        self.end_headers()

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
        FixtureHandler.requests = []
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
        FixtureHandler.fail_inventory = False
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

        self.assertEqual(len(self.controller.devices), 3)
        self.assertEqual(self.controller.telemetry["coolant"], "38.5°C")
        self.assertTrue(FixtureHandler.requests)
        self.assertTrue(
            all(request.startswith("GET ") for request in FixtureHandler.requests)
        )

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


if __name__ == "__main__":
    unittest.main()
