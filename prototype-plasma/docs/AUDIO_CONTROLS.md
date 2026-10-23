# VOID ELITE audio controls

Owning work: [audio #4](https://github.com/kodiakdirus/OpenLinkHub/issues/4),
[revision support #6](https://github.com/kodiakdirus/OpenLinkHub/issues/6).

The Audio workspace and device Audio tab share the same retained controller.
It exposes wireless connection/battery and sidetone enable/level (1–100%).
Battery prefers the host helper’s power-supply report, matched by HID vendor/product identity. The legacy driver’s startup zero is shown as awaiting a report, not a confirmed empty battery.
GET/PUT `/api/v1/audio/headsets` is additive: older services show a compatibility
message and cannot receive audio writes. Only the reviewed VOID ELITE driver
implements this first adapter. Other headset families remain unavailable.

PUT requires device identity, the saved-settings SHA-256 baseline, an explicit
boolean and integer level. Unknown fields, stale settings, disconnected devices,
invalid ranges and trailing JSON are rejected before a driver call. The service
verifies HID submission and persisted profile fields. This is not firmware
readback or proof of an audible effect. A lost response is observed, never
automatically retried. Revert reloads the reported baseline; navigation/polling
retains drafts and closing warns before discarding them.

## User-session EQ

The system backend keeps ownership of USB and cooling. EQ is a separate
unprivileged desktop helper using PipeWire's builtin ten-band peaking filters
at 32/64/125/250/500 Hz and 1/2/4/8/16 kHz, ±12 dB. Stereo processing duplicates
the filter graph per channel. Positive gains receive conservative input headroom
equal to their sum, so boosts can reduce overall loudness.

Host dependencies: Python 3, PipeWire/filter-chain, `pw-cli`, `pw-dump`,
`pactl` and a user systemd session. Install as the desktop user:

```bash
bash prototype-plasma/scripts/install-audio-session.sh
```

The installer copies just the stdlib helper into a content-addressed user data
directory and enables `openlinkhub-audio-session.service`. Starting it leaves
EQ bypassed. Apply EQ creates its virtual sink, pins playback to the uniquely
inventoried Corsair `1b1c:0a55` output, selects the EQ sink and moves only streams
currently playing through that physical headset. Other existing streams keep
their routes. Subsequent gain updates use live controls without restarting the
graph. All ten gains and headroom are read back before saving/reporting success.
Failed application bypasses the helper. Saved gains reopen without automatically
enabling processing after login. Bypass restores the previous default when EQ
still owns that selection; an independently changed default is preserved.

The client talks asynchronously over `$XDG_RUNTIME_DIR/openlinkhub-plasma/audio.sock`.
The helper directory is 0700 and socket 0600, with no TCP listener, shell command
interface, device access or privilege escalation. The Flatpak receives only that
runtime directory; it does not gain host execution or general filesystem access.
Helper failure leaves controls unavailable and retains drafts.

Backout:

```bash
systemctl --user disable --now openlinkhub-audio-session.service
```

Normal shutdown removes EQ and restores its route. If the process was killed,
select the physical headset in Plasma's audio panel; restart the helper service
to clear its managed runtime directory. Neither helper nor client changes the
system backend's PipeWire access or service account.

## Validation and applicability

Source tests cover invalid/stale commands, disconnects, exact readback, lost
responses, retained drafts, helper validation and configuration generation.
Live testing must additionally verify sidetone by ear, EQ across both channels,
battery/reconnect behavior, helper stop/start, failed writes and Flatpak IPC.
Do not treat a source test pass as deployed hardware acceptance.

References:

- [Upstream revision implementation, 69873ad8](https://github.com/jurkovic-nikola/OpenLinkHub/commit/69873ad8): adds the `0a55` dongle to the existing driver; `0a54` is not an audio-streaming interface.
- [PipeWire filter-chain](https://docs.pipewire.org/page_module_filter_chain.html): builtin `bq_peaking`, `linear`, stereo graph replication and stream properties; tested with PipeWire 1.6.9.
- [PipeWire pw-cli](https://docs.pipewire.org/page_man_pw-cli_1.html): runtime Props updates.
- [Corsair headset setup](https://help.corsair.com/hc/en-us/articles/360059501391-How-to-Set-up-gaming-headsets-in-iCUE-4-or-newer): vendor context for sidetone/EQ; Windows iCUE procedures do not authorize Linux HID commands.
