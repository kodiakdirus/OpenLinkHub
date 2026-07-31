from __future__ import annotations

import json
from pathlib import Path
import sys
import unittest


PROTOTYPE_ROOT = Path(__file__).resolve().parents[1]
if str(PROTOTYPE_ROOT) not in sys.path:
    sys.path.insert(0, str(PROTOTYPE_ROOT))

from backend.models import ContractSnapshot, VersionedDocument  # noqa: E402


FIXTURE = Path(__file__).parent / "fixtures" / "v1_snapshot_families.json"
SCHEMA = PROTOTYPE_ROOT / "docs" / "contract-v1.schema.json"


class ContractSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.document = json.loads(FIXTURE.read_text(encoding="utf-8"))
        cls.schema = json.loads(SCHEMA.read_text(encoding="utf-8"))

    def test_golden_snapshot_has_stable_envelope_and_bounded_size(self) -> None:
        self.assertEqual(self.document["apiVersion"], "1.0")
        self.assertEqual(self.document["kind"], "snapshot")
        self.assertGreaterEqual(self.document["revision"], 1)
        self.assertGreaterEqual(self.document["telemetryRevision"], 1)
        self.assertLess(len(FIXTURE.read_bytes()), 64 * 1024)
        self.assertIn("$defs", self.schema)
        self.assertIn("device", self.schema["$defs"])

    def test_golden_snapshot_covers_representative_device_families(self) -> None:
        devices = self.document["data"]["devices"]
        self.assertEqual(
            {device["deviceType"] for device in devices},
            {"cooler", "keyboard", "mouse", "receiver"},
        )
        self.assertEqual(len({device["id"] for device in devices}), len(devices))

        for device in devices:
            capability_ids = [item["id"] for item in device["capabilities"]]
            self.assertEqual(capability_ids[0], "overview")
            self.assertEqual(len(capability_ids), len(set(capability_ids)))
            for capability in device["capabilities"]:
                if capability["available"]:
                    self.assertEqual(capability["access"], "read")
                    self.assertEqual(capability["operations"], ["read"])
                else:
                    self.assertEqual(capability["access"], "unavailable")
                    self.assertEqual(capability["operations"], [])
                    self.assertTrue(capability.get("reason"))

            for channel in device["channels"]:
                self.assertIn(
                    channel["role"],
                    {"pump", "fan", "probe", "sensor", "channel"},
                )
                if "speed" in channel:
                    self.assertEqual(channel["speed"]["unit"], "rpm")
                if "temperature" in channel:
                    self.assertEqual(
                        channel["temperature"]["unit"], "celsius"
                    )

        mouse = next(item for item in devices if item["deviceType"] == "mouse")
        self.assertNotIn(
            "cooling", {item["id"] for item in mouse["capabilities"]}
        )
        receiver = next(
            item for item in devices if item["deviceType"] == "receiver"
        )
        pairing = next(
            item for item in receiver["capabilities"] if item["id"] == "pairing"
        )
        self.assertFalse(pairing["available"])
        self.assertIn("paired-device inventory", pairing["reason"].lower())

    def test_lighting_references_and_normalized_client_projection(self) -> None:
        devices = self.document["data"]["devices"]
        hub = next(item for item in devices if item["deviceType"] == "cooler")
        lighting = hub["lighting"]
        profile_ids = {item["id"] for item in lighting["profiles"]}
        self.assertEqual(lighting["profileCount"], len(profile_ids))
        for target in lighting["targets"]:
            self.assertIn(target["activeProfile"], profile_ids)

        document = VersionedDocument.from_mapping(
            self.document,
            kind="snapshot",
        )
        snapshot = ContractSnapshot(document.data).build()
        self.assertEqual(len(snapshot["devices"]), 4)
        normalized_mouse = next(
            item for item in snapshot["devices"] if item["id"] == "mouse-1"
        )
        self.assertNotIn("Cooling", normalized_mouse["capabilities"])
        self.assertEqual(document.revision, 7)
        self.assertEqual(document.telemetry_revision, 11)

    def test_fixture_discloses_no_host_configuration_paths(self) -> None:
        encoded = json.dumps(self.document, sort_keys=True)
        for sensitive in (
            "/etc/OpenLinkHub",
            "ConfigPath",
            "CpuTempFile",
            "GpuTempFile",
            "LogFile",
        ):
            self.assertNotIn(sensitive, encoded)


if __name__ == "__main__":
    unittest.main()
