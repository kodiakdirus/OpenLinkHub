#!/usr/bin/env bash
# Install only the user-session EQ helper; no sudo, USB access or backend restart.
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo 'Run as your desktop user.'; exit 1; }
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for command in python3 pipewire pw-dump pw-cli pactl systemctl; do
    command -v "$command" >/dev/null || { echo "Missing dependency: $command"; exit 1; }
done
helper="$source_dir/backend/audio_session.py"
digest=$(sha256sum "$helper" | cut -d' ' -f1)
destination="${XDG_DATA_HOME:-$HOME/.local/share}/openlinkhub-plasma/audio/$digest"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p -- "$destination" "$unit_dir"
install -m 0644 -- "$helper" "$destination/audio_session.py"
unit="$unit_dir/openlinkhub-audio-session.service"
if [[ -f "$unit" ]]; then cp -p -- "$unit" "$unit.before-audio-update"; fi
python3 - "$destination/audio_session.py" "$unit" <<'PY'
from pathlib import Path
import sys
# Quote systemd specifiers and literal backslashes/quotes in user paths.
helper=sys.argv[1].replace('%','%%').replace('\\','\\\\').replace('"','\\"')
Path(sys.argv[2]).write_text('''[Unit]
Description=OpenLinkHub desktop-session headset equalizer
After=pipewire.service pipewire-pulse.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 "'''+helper+'''"
RuntimeDirectory=openlinkhub-plasma
RuntimeDirectoryMode=0700
UMask=0077
NoNewPrivileges=yes
Restart=on-failure
RestartSec=3
TimeoutStopSec=15

[Install]
WantedBy=default.target
''')
PY
systemctl --user daemon-reload
systemctl --user enable openlinkhub-audio-session.service
systemctl --user restart openlinkhub-audio-session.service
systemctl --user --no-pager status openlinkhub-audio-session.service
echo 'Installed. EQ remains bypassed until Apply EQ is selected in the client.'
echo 'Backout: systemctl --user disable --now openlinkhub-audio-session.service'
