#!/usr/bin/env python3
"""Install a wheel into a temporary venv and launch it outside the checkout.

Uses system Qt/Kirigami dependencies; does not install or change host packages.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import venv


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("wheel", type=Path)
args = parser.parse_args()
wheel = args.wheel.resolve()
with tempfile.TemporaryDirectory(prefix="openlinkhub-install-check-") as directory:
    root = Path(directory)
    venv.EnvBuilder(with_pip=True, system_site_packages=True).create(root / "venv")
    python = root / "venv/bin/python"
    subprocess.run([str(python), "-m", "pip", "install", "--no-deps", "--no-index", str(wheel)], check=True, cwd=root)
    environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
    environment.pop("PYTHONPATH", None)
    command = str(root / "venv/bin/openlinkhub-plasma")
    subprocess.run([command, "--version"], check=True, cwd=root, env=environment, timeout=15)
    subprocess.run([command, "--demo", "--smoke-test"], check=True, cwd=root, env=environment, timeout=60)
    print("Installed wheel launches outside the checkout and passes Demo smoke checks.")
