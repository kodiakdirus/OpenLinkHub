"""Exercise actual launcher shutdown with no service, without opening sockets."""
import os
from pathlib import Path
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from PyQt6.QtCore import QTimer
from backend import BackendController
from main import main


def unavailable(self, path, callback, **kwargs):
    QTimer.singleShot(0, lambda: callback(None, "Connection refused (fixture)"))


BackendController._get_document = unavailable
with tempfile.TemporaryDirectory(prefix="openlinkhub-offline-check-") as directory:
    screenshot = Path(directory) / "offline.png"
    sys.argv = ["openlinkhub-plasma", "--live", "--page", "service", "--screenshot", str(screenshot)]
    assert main() == 0
    assert screenshot.is_file()
