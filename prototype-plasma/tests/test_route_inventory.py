from __future__ import annotations

from collections import Counter
from pathlib import Path
import re
import unittest


REPOSITORY = Path(__file__).resolve().parents[2]
SERVER_SOURCE = REPOSITORY / "src" / "server" / "server.go"
INVENTORY = (
    REPOSITORY
    / "prototype-plasma"
    / "docs"
    / "BACKEND_ROUTE_INVENTORY.md"
)


@unittest.skipUnless(SERVER_SOURCE.is_file(), "Service-source audit requires the full OpenLinkHub repository")
class RouteInventoryTests(unittest.TestCase):
    def test_every_registered_api_route_is_documented(self) -> None:
        source = SERVER_SOURCE.read_text(encoding="utf-8")
        documentation = INVENTORY.read_text(encoding="utf-8")
        registered = [
            (method, path)
            for path, method in re.findall(
                r'handleFunc\(r,\s*"(/api[^"]*)",\s*http\.Method'
                r"(Get|Post|Put|Delete)",
                source,
            )
        ]
        registered.extend(
            (method.title(), path)
            for method, path in re.findall(r'r.HandleFunc\("(PUT|DELETE) (/api[^" ]+)"', source)
        )
        documented = set(
            re.findall(r"`(GET|POST|PUT|DELETE) (/api[^` ]*)`", documentation)
        )

        self.assertEqual(len(registered), 172)
        self.assertEqual(
            Counter(method.upper() for method, _path in registered),
            Counter({"GET": 46, "POST": 107, "PUT": 12, "DELETE": 7}),
        )
        missing = {
            (method.upper(), path)
            for method, path in registered
            if (method.upper(), path) not in documented
        }
        self.assertEqual(missing, set())


if __name__ == "__main__":
    unittest.main()
