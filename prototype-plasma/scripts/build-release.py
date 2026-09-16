#!/usr/bin/env python3
"""Build client source/wheel artifacts; never bundles service code or local data."""

import argparse
import hashlib
import os
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("dist"))
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[1]
    os.chdir(root)
    from setuptools.build_meta import build_sdist, build_wheel
    archives = [output / build_sdist(str(output)), output / build_wheel(str(output))]
    for archive in archives:
        print(f"Built {archive}")
    sums = "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n" for path in archives)
    (output / "SHA256SUMS").write_text(sums, encoding="utf-8")


if __name__ == "__main__":
    main()
