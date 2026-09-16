"""Exercise opt-in setup and durable reminder dismissal with no real transport."""
import os
from pathlib import Path
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from PyQt6.QtCore import QCoreApplication, QEvent, QMetaObject, QObject, Qt, QUrl
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtTest import QTest
from backend import BackendController
from backend.preferences import Preferences


def invoke(obj, name):
    QMetaObject.invokeMethod(obj, name, Qt.ConnectionType.DirectConnection)


app = QGuiApplication([])
app.setQuitOnLastWindowClosed(False)
with tempfile.TemporaryDirectory(prefix="openlinkhub-setup-check-") as folder:
    path = Path(folder) / "preferences.json"
    errors, requests, writes = [], [], []
    engine = QQmlApplicationEngine()
    client = BackendController(preferences_path=str(path))
    client._get_document = lambda *a, **k: requests.append(a)
    client._put_document = lambda *a, **k: writes.append(a)
    engine.warnings.connect(lambda warnings: errors.extend(w.toString() for w in warnings))
    engine.rootContext().setContextProperty("backend", client)
    engine.load(QUrl.fromLocalFile(str(ROOT / "qml/Main.qml")))
    assert engine.rootObjects(), errors
    root = engine.rootObjects()[0]

    def wait_for(predicate):
        for _ in range(200):
            app.processEvents()
            if predicate():
                return
            QTest.qWait(10)
        raise AssertionError("Setup UI did not settle")

    dialog = root.findChild(QObject, "backendSetupDialog")
    notice = root.findChild(QObject, "backendSetupNotice")
    assert not dialog.property("visible"), "Setup opened automatically"
    assert not notice.property("visible"), "Reminder flashes before startup mode settles"
    wait_for(lambda: notice.property("visible"))
    assert not requests and not writes, "Demo setup probed or changed the service"
    invoke(root.findChild(QObject, "dismissBackendSetupNotice"), "clicked")
    wait_for(lambda: not notice.property("visible"))
    assert Preferences(path).values["backendSetupReminderDismissed"]
    client.preferences.resetPresentation()
    assert client.preferences.values["backendSetupReminderDismissed"]
    root.setProperty("activeSection", "service")
    wait_for(lambda: root.findChild(QObject, "serviceBackendSetupAction") is not None)
    invoke(root.findChild(QObject, "serviceBackendSetupAction"), "clicked")
    wait_for(lambda: dialog.property("opened"))
    assert not requests and not writes, "Opening setup started an operation"
    assert "not available" in root.findChild(QObject, "backendSetupPackageAvailability").property("text")
    assert dialog.property("height") <= root.property("height") - 48
    invoke(dialog, "close")
    wait_for(lambda: not dialog.property("visible"))
    client.preferences.setValue("backendSetupReminderDismissed", False)
    root.setProperty("activeSection", "overview")
    wait_for(lambda: notice.property("visible"))
    invoke(root.findChild(QObject, "backendSetupNoticeAction"), "clicked")
    wait_for(lambda: dialog.property("opened"))
    assert not notice.property("visible")
    # Only this explicit action starts reads and saves Live as the startup choice.
    invoke(root.findChild(QObject, "backendSetupCheckConnection"), "clicked")
    assert client.mode == "live" and requests
    assert client.preferences.values["mode"] == "live"
    client._set_refreshing(False)
    client._set_connection("connected", "Live", "")
    invoke(dialog, "close")
    wait_for(lambda: not dialog.property("visible"))
    wait_for(lambda: notice.property("visible"))
    client._set_connection("connecting", "Connecting", "")
    assert notice.property("visible"), "Polling flashes the legacy reminder"
    client._set_contract("1.0", "Versioned", 1, 1)
    client._set_connection("connected", "Live", "")
    wait_for(lambda: not notice.property("visible"))
    assert not writes, "Setup sent a mutation"
    engine.deleteLater()
    QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
    assert not errors, errors
    print("Setup remains opt-in; dismissal persists and compatible services suppress reminders.")
