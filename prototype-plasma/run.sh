#!/usr/bin/env bash
set -euo pipefail

prototype_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    printf 'OpenLinkHub Plasma prototype requires python3.\n' >&2
    exit 1
fi

if ! python3 -c 'from PyQt6.QtQml import QQmlApplicationEngine' 2>/dev/null; then
    printf 'OpenLinkHub Plasma prototype requires PyQt6 with QtQml support.\n' >&2
    exit 1
fi

exec python3 "$prototype_dir/main.py" "$@"
