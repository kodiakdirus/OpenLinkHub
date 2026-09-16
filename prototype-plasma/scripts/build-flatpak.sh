#!/usr/bin/env bash
# Build and test locally; does not publish or install the client.
set -euo pipefail
client_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$client_dir/dist}"
mkdir -p "$output_dir"
output_dir="$(cd -- "$output_dir" && pwd)"
app_id=io.github.kodiakdirus.OpenLinkHubPlasma
manifest="$client_dir/packaging/$app_id.json"
builder="${FLATPAK_BUILDER:-flatpak-builder}"

"$builder" --user --force-clean --install-deps-from=flathub \
    --state-dir="$output_dir/builder-state" --repo="$output_dir/repo" \
    "$output_dir/flatpak-build" "$manifest"
flatpak build --env=QT_QPA_PLATFORM=offscreen --env=QT_QUICK_BACKEND=software \
    "$output_dir/flatpak-build" openlinkhub-plasma --demo --smoke-test
source_dir="$client_dir"
if [ -d "$client_dir/../src/server" ]; then source_dir="$(dirname -- "$client_dir")"; fi
flatpak build --filesystem="$source_dir:ro" --env=QT_QPA_PLATFORM=offscreen \
    --env=QT_QUICK_BACKEND=software "$output_dir/flatpak-build" \
    python3 -m unittest discover -s "$client_dir/tests" -v
version="$(flatpak build "$output_dir/flatpak-build" openlinkhub-plasma --version | awk '{print $NF}')"
architecture="$(flatpak --default-arch)"
bundle="openlinkhub-plasma-$version-$architecture.flatpak"
flatpak build-bundle --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo \
    "$output_dir/repo" "$output_dir/$bundle" "$app_id"
cd -- "$output_dir"
sha256sum "$bundle" > "$bundle.sha256"
