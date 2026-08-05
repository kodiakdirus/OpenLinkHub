from __future__ import annotations

import json
from pathlib import Path
import unittest


PROTOTYPE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PROTOTYPE_ROOT.parent
FIXTURE = Path(__file__).parent / "fixtures" / "lighting_command_design.json"
SCHEMA = PROTOTYPE_ROOT / "docs" / "lighting-command-design.schema.json"
DESIGN = PROTOTYPE_ROOT / "docs" / "LIGHTING_COMMAND_DESIGN.md"
CURRENT_CONTRACT = PROTOTYPE_ROOT / "docs" / "CONTRACT_V1.md"
SERVER = REPOSITORY_ROOT / "src" / "server" / "server.go"


class LightingCommandDesignTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
        cls.schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
        cls.design = DESIGN.read_text(encoding="utf-8")

    def test_design_is_explicitly_non_operational(self) -> None:
        self.assertIn("Design-only checkpoint", self.design)
        current_contract = CURRENT_CONTRACT.read_text(encoding="utf-8")
        server = SERVER.read_text(encoding="utf-8")
        for route in (
            "/api/v1/lighting/assignment",
            "/api/v1/lighting/identify",
        ):
            self.assertNotIn(route, current_contract)
            self.assertNotIn(route, server)

    def test_target_identity_and_authorization_are_bounded(self) -> None:
        target = self.fixture["target"]
        self.assertEqual(target["id"], f"channel:{target['channelId']}")
        self.assertIn(target["activeProfile"], target["supportedProfileIds"])
        self.assertEqual(
            target["operations"], ["read", "assign-profile", "identify"]
        )
        self.assertTrue(target["identifiable"])

        operation_enum = self.schema["$defs"]["lightingTarget"]["properties"][
            "operations"
        ]["items"]["enum"]
        self.assertEqual(operation_enum, ["read", "assign-profile", "identify"])

    def test_assignment_requires_revision_and_verified_readback(self) -> None:
        assignment = self.fixture["assignment"]
        request = assignment["request"]
        response = assignment["response"]
        data = response["data"]

        self.assertGreater(request["expectedRevision"], 0)
        self.assertIn(request["profileId"], self.fixture["target"]["supportedProfileIds"])
        self.assertGreater(response["revision"], request["expectedRevision"])
        self.assertEqual(data["status"], "succeeded")
        self.assertEqual(data["requestedProfile"], data["observedProfile"])
        self.assertEqual(data["recovery"], "not-needed")

        required = self.schema["$defs"]["assignmentCommand"]["required"]
        self.assertEqual(
            required,
            ["expectedRevision", "deviceId", "targetId", "profileId"],
        )

    def test_identification_is_leased_non_persistent_and_server_colored(self) -> None:
        identification = self.fixture["identification"]
        request = identification["startRequest"]
        started = identification["startResponse"]
        cancelled = identification["cancelResponse"]

        self.assertGreaterEqual(request["durationMs"], 1000)
        self.assertLessEqual(request["durationMs"], 5000)
        self.assertNotIn("color", request)
        self.assertEqual(started["revision"], request["expectedRevision"])
        self.assertEqual(cancelled["revision"], started["revision"])
        self.assertEqual(
            identification["cancelRequest"]["leaseId"],
            started["data"]["leaseId"],
        )
        self.assertEqual(cancelled["data"]["restoration"], "verified")

        duration = self.schema["$defs"]["identifyCommand"]["properties"][
            "durationMs"
        ]
        self.assertEqual((duration["minimum"], duration["maximum"]), (1000, 5000))

    def test_recovery_and_non_color_ui_requirements_are_part_of_the_contract(self) -> None:
        normalized_design = " ".join(self.design.split())
        for phrase in (
            "failed-restored",
            "failed-restore-unverified",
            "server-side expiry",
            "selected-row highlight",
            "never saves a profile",
        ):
            self.assertIn(phrase, normalized_design)


if __name__ == "__main__":
    unittest.main()
