from __future__ import annotations

import json
from pathlib import Path
import sys
import unittest


PROTOTYPE_ROOT = Path(__file__).resolve().parents[1]
if str(PROTOTYPE_ROOT) not in sys.path:
    sys.path.insert(0, str(PROTOTYPE_ROOT))

from backend.models import ApiEnvelope, LegacySnapshot, PayloadError  # noqa: E402


FIXTURE = Path(__file__).resolve().parent / "fixtures" / "legacy_snapshot.json"


class EnvelopeTests(unittest.TestCase):
    def test_parses_legacy_success_envelope(self) -> None:
        envelope = ApiEnvelope.from_bytes(b'{"code":200,"status":1,"data":42}')
        self.assertEqual(envelope.code, 200)
        self.assertEqual(envelope.status, 1)
        self.assertEqual(envelope.data, 42)

    def test_rejects_malformed_or_non_object_payload(self) -> None:
        with self.assertRaises(PayloadError):
            ApiEnvelope.from_bytes(b"not json")
        with self.assertRaises(PayloadError):
            ApiEnvelope.from_bytes(b"[]")


class LegacySnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
        cls.snapshot = LegacySnapshot(
            inventory=cls.fixture["inventory"],
            details=cls.fixture["details"],
            batteries=cls.fixture["battery"]["data"],
            lighting_profiles=cls.fixture["lighting"]["data"],
            cpu_temperature=cls.fixture["cpu"]["data"],
            gpu_temperature=cls.fixture["gpu"]["data"],
        ).build()

    def test_hidden_transports_are_visible_but_cluster_is_not(self) -> None:
        names = [device["name"] for device in self.snapshot["devices"]]
        self.assertEqual(
            names,
            [
                "iCUE LINK System Hub",
                "K100 AIR",
                "SCIMITAR ELITE",
                "Slipstream Receiver",
            ],
        )
        receiver = next(
            device
            for device in self.snapshot["devices"]
            if device["name"] == "Slipstream Receiver"
        )
        self.assertEqual(receiver["capabilities"], ["Wireless", "Pairing"])
        pairing = next(tab for tab in receiver["tabs"] if tab["name"] == "Pairing")
        self.assertEqual(
            pairing["groups"][0]["items"][1]["value"],
            "Not reported",
        )

    def test_capabilities_are_device_relevant(self) -> None:
        devices = {device["name"]: device for device in self.snapshot["devices"]}
        self.assertIn("Cooling", devices["iCUE LINK System Hub"]["capabilities"])
        self.assertNotIn("Cooling", devices["SCIMITAR ELITE"]["capabilities"])
        self.assertNotIn("Power", devices["SCIMITAR ELITE"]["capabilities"])
        self.assertIn("DPI", devices["SCIMITAR ELITE"]["capabilities"])
        self.assertIn("Keys", devices["K100 AIR"]["capabilities"])

    def test_device_card_order_is_stable_and_transports_are_last(self) -> None:
        reversed_inventory = {
            **self.fixture["inventory"],
            "devices": dict(
                reversed(list(self.fixture["inventory"]["devices"].items()))
            ),
        }
        snapshot = LegacySnapshot(
            inventory=reversed_inventory,
            details=self.fixture["details"],
            batteries=self.fixture["battery"]["data"],
            lighting_profiles=self.fixture["lighting"]["data"],
        ).build()
        self.assertEqual(
            [device["name"] for device in snapshot["devices"]],
            [
                "iCUE LINK System Hub",
                "K100 AIR",
                "SCIMITAR ELITE",
                "Slipstream Receiver",
            ],
        )

    def test_live_tabs_contain_read_only_rows_only(self) -> None:
        for device in self.snapshot["devices"]:
            for tab in device["tabs"]:
                self.assertTrue(tab["readOnly"])
                for group in tab["groups"]:
                    for item in group["items"]:
                        self.assertEqual(item["kind"], "stat")

    def test_lighting_library_is_filtered_and_mapped_per_device(self) -> None:
        devices = {device["name"]: device for device in self.snapshot["devices"]}
        hub_lighting = next(
            tab
            for tab in devices["iCUE LINK System Hub"]["tabs"]
            if tab["name"] == "Lighting"
        )["lightingEditor"]
        mouse_lighting = next(
            tab
            for tab in devices["SCIMITAR ELITE"]["tabs"]
            if tab["name"] == "Lighting"
        )["lightingEditor"]

        self.assertEqual(hub_lighting["profileCount"], 3)
        self.assertEqual(
            [profile["key"] for profile in hub_lighting["profiles"]],
            ["colorpulse", "liquid-temperature", "static"],
        )
        self.assertEqual(len(hub_lighting["targets"]), 3)
        self.assertEqual(mouse_lighting["profileCount"], 2)
        self.assertEqual(mouse_lighting["targets"][0]["name"], "Whole device")

    def test_telemetry_and_cooling_groups_are_normalized(self) -> None:
        self.assertEqual(self.snapshot["telemetry"]["cpu"], "52.2°C")
        self.assertEqual(self.snapshot["telemetry"]["gpu"], "47.0°C")
        self.assertEqual(self.snapshot["telemetry"]["coolant"], "38.5°C")
        self.assertEqual(self.snapshot["zoneValues"]["pump"], "1,500 RPM")
        self.assertEqual(self.snapshot["zoneValues"]["radiator"], "600 RPM")
        self.assertEqual(self.snapshot["zoneValues"]["case"], "0 RPM")


if __name__ == "__main__":
    unittest.main()
