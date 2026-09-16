#!/usr/bin/env python3
"""Check release identity without importing Qt or requiring the service."""
import argparse
import ast
import json
from pathlib import Path
import xml.etree.ElementTree as ET


root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tag")
args = parser.parse_args()
values = {}
for node in ast.parse((root / "backend/application.py").read_text()).body:
    if isinstance(node, ast.Assign) and isinstance(node.value, ast.Constant):
        values[node.targets[0].id] = node.value.value
app_id, version = values["APP_ID"], values["VERSION"]
manifest = json.loads((root / f"packaging/{app_id}.json").read_text())
metadata = ET.parse(root / f"packaging/{app_id}.metainfo.xml").getroot()
assert manifest["app-id"] == metadata.findtext("id") == app_id
assert metadata.find("releases/release").get("version") == version
assert manifest["base-version"] == manifest["runtime-version"]
assert (root / f"packaging/{app_id}.desktop").is_file()
assert (root / f"packaging/{app_id}.svg").is_file()
if args.tag:
    assert args.tag == f"plasma-v{version}", "Release tag does not match application version"
print(f"Validated {app_id} {version}")
