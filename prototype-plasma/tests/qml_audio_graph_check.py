"""Exercise graph handle dragging and retained drafts without touching audio."""
import copy
import os
from pathlib import Path
import sys
import tempfile
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from PyQt6.QtCore import QCoreApplication, QEvent, QPoint, QPointF, Qt, QUrl
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtQuick import QQuickItem
from PyQt6.QtTest import QTest
from backend.controller import BackendController

app = QGuiApplication([])
with tempfile.TemporaryDirectory() as directory:
    client = BackendController(preferences_path=str(Path(directory) / "preferences.json"))
    client._mode = "live"
    client._connection_state = "connected"
    settings = dict(revision="a"*64, connected=True, battery=97, enabled=False, level=25)
    processing = dict(bands=[0.]*10, preamp=0., surround=False, surroundAvailable=True,
                      processingVersion=3, enabled=False, revision="b"*64)
    writes, warnings = [], []
    def read(path, callback, **_):
        callback({"apiVersion":"1.0", "kind":"headset-audio", "data":[
            {"deviceId":"2645","settings":copy.deepcopy(settings)}]}, None)
    client._get_document = read
    client.headsetAudio.ipc = lambda body, callback: callback({"ok":True,"state":copy.deepcopy(processing)},None) if body["operation"]=="state" else writes.append(body)
    client.refresh = lambda: None
    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda items: warnings.extend(i.toString() for i in items))
    engine.rootContext().setContextProperty("backend",client)
    engine.load(QUrl.fromLocalFile(str(ROOT / "qml/Main.qml")))
    assert engine.rootObjects(), warnings
    window = engine.rootObjects()[0]
    window.setProperty("activeSection","audio")
    QTest.qWait(180)
    graph = window.findChild(QQuickItem,"equalizerGraph")
    def visual_find(item, name):
        if item.objectName()==name:return item
        for child in item.childItems():
            found=visual_find(child,name)
            if found is not None:return found
        return None
    slider = visual_find(graph,"equalizerBand2")
    assert graph and slider and slider.property("enabled"), (graph, slider, client.mode, client.headsetAudio.eqState, client.headsetAudio.eqMessage)
    center = slider.mapToScene(QPointF(slider.width()/2,slider.height()/2))
    start = QPoint(round(center.x()),round(center.y()))
    finish = QPoint(start.x(),start.y()-35)
    QTest.mousePress(window,Qt.MouseButton.LeftButton,Qt.KeyboardModifier.NoModifier,start)
    QTest.mouseMove(window,finish,30)
    QTest.mouseRelease(window,Qt.MouseButton.LeftButton,Qt.KeyboardModifier.NoModifier,finish)
    QTest.qWait(30)
    assert client.headsetAudio.bands[2]>0, "Dragging a graph handle upward must boost its band"
    draft = client.headsetAudio.bands[:]
    client.headsetAudio.refresh()
    assert client.headsetAudio.bands==draft and visual_find(graph,"equalizerBand2")==slider
    client.headsetAudio.setSurround(True)
    client.headsetAudio.applyEQ()
    assert len(writes)==1 and writes[0]["bands"]==draft and writes[0]["preamp"]==0 and writes[0]["surround"]
    assert not warnings,warnings
    engine.deleteLater()
    QCoreApplication.sendPostedEvents(None,QEvent.Type.DeferredDelete)
    print("Graph drag boosts the band; polling preserves handles/draft; Apply includes explicit gain and surround.")
