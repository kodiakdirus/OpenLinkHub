"""Typed headset commands plus private IPC to the desktop EQ helper."""
import json
import os
from pathlib import Path
from PyQt6.QtCore import QObject, QTimer, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtNetwork import QLocalSocket


class HeadsetAudioController(QObject):
    changed = pyqtSignal()

    def __init__(self, backend):
        super().__init__(backend)
        self.backend = backend
        self._devices = []
        self._selected = ""
        self._state = {}
        self._draft = (False, 25)
        self._baseline = self._draft
        self._revision = ""
        self._reading = self._busy = False
        self._epoch = 0
        self._message = "A compatible headset backend is required."
        self._eq = {}
        self._eq_draft = [0.] * 10
        self._eq_baseline = self._eq_draft[:]
        self._eq_revision = ""
        self._eq_busy = self._eq_reading = False
        self._eq_message = "Start the user-session EQ helper to enable equalization."

    @pyqtProperty("QVariantList", notify=changed)
    def devices(self): return self._devices
    @pyqtProperty(str, notify=changed)
    def selectedId(self): return self._selected
    @pyqtProperty("QVariantMap", notify=changed)
    def state(self): return self._state
    @pyqtProperty(bool, notify=changed)
    def enabled(self): return self._draft[0]
    @pyqtProperty(int, notify=changed)
    def level(self): return self._draft[1]
    @pyqtProperty(bool, notify=changed)
    def dirty(self): return self._draft != self._baseline or self.eqDirty
    @pyqtProperty(bool, notify=changed)
    def sidetoneDirty(self): return self._draft != self._baseline
    @pyqtProperty(bool, notify=changed)
    def busy(self): return self._busy or self._eq_busy
    @pyqtProperty(str, notify=changed)
    def message(self): return self._message
    @pyqtProperty(bool, notify=changed)
    def stale(self): return self.sidetoneDirty and self._revision != self._state.get("revision")
    @pyqtProperty(bool, notify=changed)
    def canApply(self):
        return (self.backend.mode == "live" and self._state.get("connected") is True
                and self.sidetoneDirty and not self.stale and not self.busy
                and not self.backend.commandBusy and not self.backend.coolingBusy)
    @pyqtProperty("QVariantMap", notify=changed)
    def eqState(self): return self._eq
    @pyqtProperty("QVariantList", notify=changed)
    def bands(self): return self._eq_draft
    @pyqtProperty(bool, notify=changed)
    def eqDirty(self): return self._eq_draft != self._eq_baseline
    @pyqtProperty(str, notify=changed)
    def eqMessage(self): return self._eq_message
    @pyqtProperty(bool, notify=changed)
    def canApplyEQ(self):
        return (self.backend.mode == "live" and bool(self._eq) and not self.busy
                and self._eq_revision == self._eq.get("revision")
                and not self.backend.commandBusy and not self.backend.coolingBusy)

    def reset(self):
        self._epoch += 1
        self._devices, self._state, self._eq = [], {}, {}
        self._selected = ""
        self._reading = self._busy = self._eq_busy = self._eq_reading = False
        self.changed.emit()

    @staticmethod
    def valid(state):
        return (isinstance(state, dict) and isinstance(state.get("revision"), str)
                and len(state["revision"]) == 64 and type(state.get("connected")) is bool
                and type(state.get("enabled")) is bool and type(state.get("level")) is int
                and 1 <= state["level"] <= 100 and type(state.get("battery")) is int
                and 0 <= state["battery"] <= 100)

    def accept(self, state):
        if not self.sidetoneDirty:
            self._draft = self._baseline = (state["enabled"], state["level"])
            self._revision = state["revision"]
        self._state = state

    @pyqtSlot(str)
    def select(self, value):
        if self.busy or self.sidetoneDirty or value == self._selected: return
        self._selected = value
        item = next((d for d in self._devices if d["deviceId"] == value), None)
        self._state = {}
        if item: self.accept(item["settings"])
        self.changed.emit()

    @pyqtSlot(bool)
    def setEnabled(self, value):
        if not self.busy: self._draft = (value, self.level); self.changed.emit()

    @pyqtSlot(int)
    def setLevel(self, value):
        if not self.busy and 1 <= value <= 100: self._draft = (self.enabled, value); self.changed.emit()

    @pyqtSlot(int, float)
    def setBand(self, index, value):
        if not self.busy and 0 <= index < 10 and -12 <= value <= 12:
            self._eq_draft = self._eq_draft[:]
            self._eq_draft[index] = value
            self.changed.emit()

    @pyqtSlot()
    def revert(self):
        if self.busy: return
        if self.valid(self._state):
            self._draft = self._baseline = (self._state["enabled"], self._state["level"])
            self._revision = self._state["revision"]
        else: self._draft = self._baseline
        if self._eq:
            self._eq_draft = self._eq_baseline = self._eq["bands"][:]
            self._eq_revision = self._eq["revision"]
        else: self._eq_draft = self._eq_baseline[:]
        self.changed.emit()

    @pyqtSlot()
    def refresh(self):
        if self.backend.mode != "live" or self.busy or self._reading: return
        self._reading = True
        epoch = self._epoch
        def accepted(payload, error):
            if epoch != self._epoch: return
            self._reading = False
            items = payload.get("data") if isinstance(payload, dict) else None
            if (error or not isinstance(payload, dict) or payload.get("apiVersion") != "1.0" or payload.get("kind") != "headset-audio"
                    or not isinstance(items, list) or any(not isinstance(d, dict)
                       or not isinstance(d.get("deviceId"), str) or not self.valid(d.get("settings")) for d in items)):
                self._state = {}
                self._message = "Headset settings unavailable. The service needs a compatible audio update."
            else:
                if self._devices != items: self._devices = items
                if not self._selected and items: self._selected = items[0]["deviceId"]
                item = next((d for d in items if d["deviceId"] == self._selected), None)
                if item: self.accept(item["settings"])
                else: self._state = {}
                self._message = ("Change sidetone, then Apply. Audible confirmation is required."
                                 if item else "No supported headset detected. Check power and dongle connection.")
            self.changed.emit()
        self.backend._get_document("/api/v1/audio/headsets", accepted)
        self.refreshEQ()

    @pyqtSlot()
    def apply(self):
        if not self.canApply: return
        self._epoch += 1
        self._reading = self._eq_reading = False
        epoch = self._epoch
        requested = self._draft
        device = self._selected
        self._busy = True
        self.backend._set_command(True, "pending", "Saving sidetone…")
        self.changed.emit()
        def accepted(payload, error):
            if epoch != self._epoch: return
            self._busy = False
            data = payload.get("data", {}) if isinstance(payload, dict) else {}
            state = data.get("settings")
            verified = (not error and isinstance(payload, dict) and payload.get("apiVersion") == "1.0"
                        and payload.get("kind") == "headset-audio-result" and data.get("deviceId") == device
                        and data.get("persistence") == "verified" and self.valid(state)
                        and state["connected"] and (state["enabled"],state["level"]) == requested)
            if verified:
                self._state = state
                self._baseline = requested
                self._revision = state["revision"]
                self._message = "Sidetone saved and sent. Check the sound on your headset."
            else:
                self._state = {}
                self._message = "Sidetone outcome unverified. Refresh and review before retrying."
            self.backend._set_command(False, "succeeded" if verified else "unverified", self._message)
            self.changed.emit()
            self.refresh()
        self.backend._put_document("/api/v1/audio/headsets", {
            "deviceId": device, "expectedRevision": self._revision,
            "enabled": requested[0], "level": requested[1]}, accepted)

    def ipc(self, request, callback):
        sock = QLocalSocket(self)
        timer = QTimer(sock); timer.setSingleShot(True)
        buffer = bytearray()
        complete = False
        def finish(payload=None, error=None):
            nonlocal complete
            if complete: return
            complete = True; timer.stop(); sock.abort(); sock.deleteLater()
            callback(payload, error)
        def ready():
            buffer.extend(bytes(sock.readAll()))
            if len(buffer) > 16384: finish(error="Helper response too large")
            elif b"\n" in buffer:
                try: payload = json.loads(bytes(buffer).split(b"\n",1)[0])
                except ValueError: finish(error="Invalid helper response"); return
                finish(payload=payload)
        sock.connected.connect(lambda: sock.write(json.dumps(request).encode()+b"\n"))
        sock.readyRead.connect(ready)
        sock.errorOccurred.connect(lambda _: finish(error=sock.errorString()))
        timer.timeout.connect(lambda: finish(error="EQ helper timed out"))
        timer.start(15000)
        sock.connectToServer(str(Path(os.environ.get("XDG_RUNTIME_DIR", "/nonexistent")) / "openlinkhub-plasma/audio.sock"))

    def acceptEQ(self, payload, error):
        from .audio_session import validate_bands
        state = payload.get("state") if isinstance(payload, dict) else None
        try:
            if error or not isinstance(state, dict) or payload.get("ok") is not True: raise ValueError()
            validate_bands(state["bands"])
            if type(state.get("enabled")) is not bool or not isinstance(state.get("revision"),str): raise ValueError()
        except (ValueError, KeyError):
            self._eq = {}
            self._eq_message = "EQ helper unavailable or outcome unverified. Start the user-session helper, then refresh."
            return False
        if not self.eqDirty:
            self._eq_draft = self._eq_baseline = state["bands"][:]
            self._eq_revision = state["revision"]
        self._eq = state
        self._eq_message = "EQ active; live filter gains verified." if state["enabled"] else "EQ bypassed. Apply enables it for the VOID ELITE output."
        return True

    @pyqtSlot()
    def refreshEQ(self):
        if self.backend.mode != "live" or self._eq_reading or self._eq_busy: return
        self._eq_reading = True
        epoch = self._epoch
        def accepted(payload, error):
            if epoch != self._epoch: return
            self._eq_reading = False
            self.acceptEQ(payload, error); self.changed.emit()
        self.ipc({"operation": "state"}, accepted)

    def commandEQ(self, operation):
        if not self.canApplyEQ: return
        self._eq_busy = True
        requested = self._eq_draft[:]
        command = {"operation": operation, "expectedRevision": self._eq_revision}
        if operation == "apply": command["bands"] = requested
        self.backend._set_command(True, "pending", "Updating session EQ…")
        self.changed.emit()
        def accepted(payload, error):
            self._eq_busy = False
            verified = self.acceptEQ(payload, error)
            if verified:
                verified = ((operation == "disable" and not self._eq["enabled"])
                            or (operation == "apply" and self._eq["enabled"] and self._eq["bands"] == requested))
            if verified:
                self._eq_baseline = self._eq["bands"][:]
                self._eq_revision = self._eq["revision"]
            else:
                self._eq = {}
                self._eq_message = "EQ outcome unverified. Refresh before retrying; the draft is retained."
            self.backend._set_command(False, "succeeded" if verified else "unverified", self._eq_message)
            self.changed.emit()
        self.ipc(command, accepted)

    @pyqtSlot()
    def applyEQ(self): self.commandEQ("apply")
    @pyqtSlot()
    def disableEQ(self): self.commandEQ("disable")
