"""Host-side, unprivileged PipeWire EQ helper. No USB or system-service access.

Run with python3 -m backend.audio_session from prototype-plasma. The private
Unix socket accepts only state, apply and disable, with a revision baseline.
"""
from __future__ import annotations
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import socketserver
import subprocess
import tempfile
import time

FREQUENCIES = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
SINK = "openlinkhub.headset.eq"


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=5).stdout


def validate_bands(value):
    if (not isinstance(value, list) or len(value) != 10
            or any(type(v) not in (int, float) or not math.isfinite(v)
                   or not -12 <= v <= 12 for v in value)):
        raise ValueError("Expected ten finite EQ gains between -12 and 12 dB")
    return [float(v) for v in value]


def filter_config(target, bands):
    bands = validate_bands(bands)
    # Compensate the largest positive gain to leave headroom.
    preamp = -sum(max(0, gain) for gain in bands)
    nodes = [{"type": "builtin", "name": "preamp", "label": "linear",
              "control": {"Mult": 10 ** (preamp / 20), "Add": 0}}]
    nodes += [{"type": "builtin", "name": f"eq{i}", "label": "bq_peaking",
               "control": {"Freq": f, "Q": 1.4, "Gain": bands[i]}}
              for i, f in enumerate(FREQUENCIES)]
    names = [n["name"] for n in nodes]
    graph = {"nodes": nodes,
             "links": [{"output": a + ":Out", "input": b + ":In"}
                       for a, b in zip(names, names[1:])],
             "inputs": ["preamp:In"], "outputs": ["eq9:Out"]}
    return spa({
        "context.spa-libs": {"audio.convert.*": "audioconvert/libspa-audioconvert",
                             "support.*": "support/libspa-support"},
        "context.modules": [
            {"name": "libpipewire-module-protocol-native"},
            {"name": "libpipewire-module-client-node"},
            {"name": "libpipewire-module-adapter"},
            {"name": "libpipewire-module-filter-chain", "args": {
                "node.description": "OpenLinkHub Headset EQ", "filter.graph": graph,
                "audio.channels": 2, "audio.position": ["FL", "FR"],
                "capture.props": {"node.name": SINK, "media.class": "Audio/Sink",
                                  "node.description": "OpenLinkHub Headset EQ",
                                  "node.virtual": True},
                "playback.props": {"node.name": SINK + ".output", "node.passive": True,
                                   "target.object": target, "node.dont-fallback": True}}}]})


def spa(value):
    """Serialize the documented SPA config syntax, without JSON array commas."""
    if isinstance(value, dict):
        return "{ " + " ".join(json.dumps(k) + " = " + spa(v) for k, v in value.items()) + " }"
    if isinstance(value, list): return "[ " + " ".join(spa(v) for v in value) + " ]"
    return json.dumps(value)


class SessionEQ:
    def __init__(self, directory):
        self.directory = directory
        self.process = None
        self.target = ""
        self.previous_default = ""
        self.bands = [0.] * 10
        self.storage = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "openlinkhub-plasma/session-eq.json"
        if self.storage.exists():
            self.bands = validate_bands(json.loads(self.storage.read_text())["bands"])

    def sinks(self):
        return json.loads(run("pactl", "-f", "json", "list", "sinks"))

    def headset(self):
        matches = [s for s in self.sinks() if
                   str(s.get("properties", {}).get("device.vendor.id", "")).lower() in ("1b1c", "0x1b1c", "6940")
                   and str(s.get("properties", {}).get("device.product.id", "")).lower() in ("0a55", "0x0a55", "2645")]
        if len(matches) != 1:
            raise ValueError("Expected one supported VOID ELITE output; reconnect the dongle")
        return matches[0]

    def state(self):
        running = self.process is not None and self.process.poll() is None
        settings = {"bands": self.bands, "enabled": running}
        revision = hashlib.sha256(json.dumps(settings, sort_keys=True).encode()).hexdigest()
        return dict(settings, revision=revision, frequencies=FREQUENCIES,
                    target=self.target, headroomDb=-sum(max(0, g) for g in self.bands))

    def move_streams(self, source, destination):
        source_sink = next((s for s in self.sinks() if s["name"] == source), None)
        if source_sink is None: return
        for stream in json.loads(run("pactl", "-f", "json", "list", "sink-inputs")):
            # The filter's playback stream must stay pinned to the hardware;
            # moving it into its own capture sink would create a feedback loop.
            if stream.get("properties", {}).get("node.name") == SINK + ".output": continue
            if stream.get("sink") == source_sink["index"]:
                run("pactl", "move-sink-input", str(stream["index"]), destination)

    def disable(self):
        if self.process is None: return
        try:
            # Restore only our route; preserve an independently selected default.
            sinks = self.sinks()
            restore = self.previous_default if any(s["name"] == self.previous_default for s in sinks) else self.target
            if any(s["name"] == restore for s in sinks):
                if run("pactl", "get-default-sink").strip() == SINK:
                    run("pactl", "set-default-sink", restore)
                self.move_streams(SINK, restore)
        finally:
            self.process.terminate()
            try: self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.process.kill(); self.process.wait(timeout=3)
            self.process = None

    def apply(self, bands):
        bands = validate_bands(bands)
        headset = self.headset()
        self.target = headset["name"]
        if self.process is not None and self.process.poll() is None:
            props = {"params": ["preamp:Mult", 10 ** (-sum(max(0, g) for g in bands) / 20)] +
                     [v for i, gain in enumerate(bands) for v in (f"eq{i}:Gain", gain)]}
            nodes = json.loads(run("pw-dump"))
            node = next(n for n in nodes if n.get("info", {}).get("props", {}).get("node.name") == SINK)
            run("pw-cli", "set-param", str(node["id"]), "Props", json.dumps(props))
        else:
            self.previous_default = run("pactl", "get-default-sink").strip()
            config = self.directory / "filter.conf"
            config.write_text(filter_config(self.target, bands))
            log = open(self.directory / "filter.log", "w")
            self.process = subprocess.Popen(["pipewire", "-c", str(config)], stdout=log, stderr=log)
            log.close()
            for _ in range(30):
                if self.process.poll() is not None: raise RuntimeError("PipeWire EQ failed; inspect filter.log")
                if any(s["name"] == SINK for s in self.sinks()): break
                time.sleep(.1)
            else: raise RuntimeError("EQ output did not appear")
            # Keep physical volume unchanged; the virtual sink starts at unity.
            run("pactl", "set-sink-volume", SINK, "100%")
            run("pactl", "set-default-sink", SINK)
            self.move_streams(self.target, SINK)
        # Verify the actual filter control values, not just our saved draft.
        expected = {f"eq{i}:Gain": gain for i, gain in enumerate(bands)}
        expected["preamp:Mult"] = 10 ** (-sum(max(0, g) for g in bands) / 20)
        for _ in range(20):
            node = next((n for n in json.loads(run("pw-dump"))
                         if n.get("info", {}).get("props", {}).get("node.name") == SINK), {})
            params = node.get("info", {}).get("params", {}).get("Props", [])
            values = {}
            for prop in params:
                pairs = prop.get("params", [])
                if isinstance(pairs, list): values.update(zip(pairs[::2], pairs[1::2]))
            if all(isinstance(values.get(k), (int, float)) and abs(values[k] - v) < .001 for k, v in expected.items()): break
            time.sleep(.05)
        else: raise RuntimeError("Live EQ controls could not be verified")
        self.bands = bands
        self.storage.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", dir=self.storage.parent, delete=False) as saved:
            json.dump({"bands": bands}, saved); temporary = saved.name
        os.replace(temporary, self.storage)

    def command(self, request):
        if not isinstance(request, dict): raise ValueError("Expected command object")
        op = request.get("operation")
        if op == "state" and set(request) == {"operation"}: return self.state()
        if request.get("expectedRevision") != self.state()["revision"]: raise ValueError("Settings changed; refresh")
        if op == "apply" and set(request) == {"operation", "expectedRevision", "bands"}:
            try: self.apply(request["bands"])
            except Exception:
                self.disable(); raise
        elif op == "disable" and set(request) == {"operation", "expectedRevision"}: self.disable()
        else: raise ValueError("Unsupported command")
        return self.state()


def main():
    if os.getuid() == 0: raise SystemExit("Run the EQ helper in your desktop user session")
    directory = Path(os.environ["XDG_RUNTIME_DIR"]) / "openlinkhub-plasma"
    directory.mkdir(mode=0o700, exist_ok=True)
    if directory.stat().st_uid != os.getuid(): raise SystemExit("Runtime directory owner mismatch")
    os.chmod(directory, 0o700)
    path = directory / "audio.sock"
    # An active helper owns the socket; a stale one may be removed only after
    # the user service manager has stopped its previous instance.
    if path.exists(): raise SystemExit("Audio socket already exists; stop the previous helper")
    eq = SessionEQ(directory)
    class Handler(socketserver.StreamRequestHandler):
        def handle(self):
            self.connection.settimeout(5)
            try:
                raw = self.rfile.readline(4097)
                if len(raw) > 4096: raise ValueError("Command too large")
                result = {"ok": True, "state": eq.command(json.loads(raw))}
            except Exception as error: result = {"ok": False, "error": str(error), "state": eq.state()}
            self.wfile.write(json.dumps(result).encode() + b"\n")
    class Server(socketserver.UnixStreamServer):
        last_check = 0
        def service_actions(self):
            if time.monotonic() - self.last_check < 1: return
            self.last_check = time.monotonic()
            if eq.process is not None:
                try:
                    if eq.process.poll() is not None or not any(s["name"] == eq.target for s in eq.sinks()):
                        eq.disable()
                except (OSError, ValueError, subprocess.SubprocessError):
                    # Removing our graph still happens if the audio server failed.
                    if eq.process is not None:
                        try: eq.disable()
                        except (OSError, subprocess.SubprocessError): pass
    server = Server(str(path), Handler)
    os.chmod(path, 0o600)
    def stop(*_): raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, stop)
    try: server.serve_forever(poll_interval=.25)
    except KeyboardInterrupt: pass
    finally:
        try: eq.disable()
        finally: server.server_close(); path.unlink(missing_ok=True)


if __name__ == "__main__": main()
