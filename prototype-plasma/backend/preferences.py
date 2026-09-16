"""Small, validated client-only preferences; never stores hardware state."""

from copy import deepcopy
import json
from pathlib import Path

from PyQt6.QtCore import QObject, QSaveFile, QIODevice, QStandardPaths, pyqtProperty, pyqtSignal, pyqtSlot


DEFAULTS = {
    "themeMode": "Dark Modern",
    "accentColor": "#0078d4",
    "compactMode": False,
    "sidebarLabels": True,
    "cornerRadius": 11,
    "mode": "demo",
    "backendSetupReminderDismissed": False,
    "layouts": {},
}
ACCENTS = {"#0078d4", "#66d7c5", "#7aa8ff", "#a98cf5", "#ee876f", "#e8bd57"}


class Preferences(QObject):
    changed = pyqtSignal()
    errorChanged = pyqtSignal()

    def __init__(self, path=None, parent=None):
        super().__init__(parent)
        self.path = Path(path) if path else Path(QStandardPaths.writableLocation(
            QStandardPaths.StandardLocation.GenericConfigLocation
        )) / "openlinkhub-plasma" / "preferences.json"
        self._values = deepcopy(DEFAULTS)
        self._error = ""
        try:
            saved = json.loads(self.path.read_text(encoding="utf-8"))
            if not isinstance(saved, dict) or saved.get("version") != 1:
                raise ValueError("Unsupported preferences format")
            for key, value in saved.get("values", {}).items():
                if self.valid(key, value):
                    self._values[key] = value
        except FileNotFoundError:
            pass
        except (OSError, ValueError, TypeError, AttributeError):
            self._error = "Saved preferences could not be read. Using presentation defaults."

    @staticmethod
    def valid(key, value):
        if key == "themeMode":
            return isinstance(value, str) and value in {"Dark Modern", "Midnight", "Dim", "Light"}
        if key == "accentColor":
            return isinstance(value, str) and value in ACCENTS
        if key in {"compactMode", "sidebarLabels", "backendSetupReminderDismissed"}:
            return type(value) is bool
        if key == "cornerRadius":
            return type(value) is int and 4 <= value <= 18
        if key == "mode":
            return value in ("demo", "live")
        if key == "layouts":
            # Layout payloads contain only cell identities, order and size.
            return isinstance(value, dict) and len(value) <= 256 and all(
                isinstance(name, str) and len(name) <= 256
                and isinstance(layout, dict) and len(layout) <= 64
                and all(isinstance(k, str) and len(k) <= 256 and (
                    type(v) is bool or (isinstance(v, list) and len(v) <= 64
                    and all(isinstance(item, dict) and set(item) == {"key", "wide"}
                            and isinstance(item["key"], str) and len(item["key"]) <= 256
                            and type(item["wide"]) is bool for item in v))
                ) for k, v in layout.items()) for name, layout in value.items()
            )
        return False

    @pyqtProperty("QVariantMap", notify=changed)
    def values(self):
        return deepcopy(self._values)

    @pyqtProperty(str, notify=errorChanged)
    def error(self):
        return self._error

    def _save(self, values):
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            output = QSaveFile(str(self.path))
            data = json.dumps({"version": 1, "values": values}, indent=2).encode()
            if not output.open(QIODevice.OpenModeFlag.WriteOnly):
                raise OSError(output.errorString())
            if output.write(data) != len(data) or not output.commit():
                raise OSError(output.errorString())
        except OSError:
            self._error = "Preferences could not be saved. Check that your configuration folder is writable."
            self.errorChanged.emit()
            return False
        self._error = ""
        self.errorChanged.emit()
        self._values = deepcopy(values)
        self.changed.emit()
        return True

    @pyqtSlot(str, "QVariant", result=bool)
    def setValue(self, key, value):
        if hasattr(value, "toVariant"):
            value = value.toVariant()
        if not self.valid(key, value):
            return False
        if self._values.get(key) == value:
            return True
        return self._save({**self._values, key: value})

    @pyqtSlot(result=bool)
    def resetPresentation(self):
        return self._save({**deepcopy(DEFAULTS), "mode": self._values["mode"],
                           "backendSetupReminderDismissed": self._values["backendSetupReminderDismissed"]})
