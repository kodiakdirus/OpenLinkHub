"""Exercise real QML navigation, persistence, and guarded curve drafts offscreen."""

from copy import deepcopy
import json
import os
from pathlib import Path
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from PyQt6.QtCore import Q_ARG, QCoreApplication, QEvent, QMetaObject, QObject, Qt, QUrl
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtQuick import QQuickItem
from PyQt6.QtTest import QTest
from backend import BackendController
from backend.models import ContractSnapshot, VersionedDocument
from backend.preferences import Preferences


def variant(value):
    return value.toVariant() if hasattr(value, "toVariant") else value


def invoke(obj, name, *args):
    QMetaObject.invokeMethod(obj, name, Qt.ConnectionType.DirectConnection,
                             *(Q_ARG("QVariant", value) for value in args))


def visual_items(item):
    yield item
    for child in item.childItems():
        yield from visual_items(child)


def main():
    app = QGuiApplication([])
    app.setQuitOnLastWindowClosed(False)
    directory = tempfile.TemporaryDirectory(prefix="openlinkhub-daily-test-")
    path = Path(directory.name) / "preferences.json"
    saved = Preferences(path)
    saved.setValue("themeMode", "Light")
    saved.setValue("compactMode", True)
    engine = QQmlApplicationEngine()
    errors = []
    engine.warnings.connect(lambda warnings: errors.extend(w.toString() for w in warnings))
    client = BackendController(parent=engine, preferences_path=str(path))
    # Supply fixture state without starting any transport or hardware operation.
    client._mode = "live"
    fixture = json.loads((ROOT / "tests/fixtures/v1_snapshot_families.json").read_text())
    lighting = fixture["data"]["devices"][0]["lighting"]
    lighting["ownership"]["savedIndividualSummary"] = "Off on 2 targets"
    off = dict(lighting["profiles"][0], id="off", name="Off", brightness=0)
    lighting["profiles"].append(off)
    for target in lighting["targets"]:
        target["activeProfile"] = "off"
        target["supportedProfileIds"].append("off")
    fixture["data"]["devices"][0]["capabilities"].append({
        "id": "display", "label": "Display", "available": True,
        "access": "read", "operations": ["read"], "options": {"brightnessModeCount": 4},
    })
    document = VersionedDocument.from_mapping(fixture, kind="snapshot")
    snapshot = ContractSnapshot(document.data).build()
    client._finish_contract(snapshot, document)
    writes = []
    client._put_document = lambda *args: writes.append(args)
    client.refreshLightingRuntime = lambda: None
    profile = {"sensorString": "Coolant", "zeroRpm": False, "points": {
        "0": [{"x": 0, "y": 70}, {"x": 100, "y": 100}],
        "1": [{"x": 0, "y": 20}, {"x": 40.5, "y": 65.5}, {"x": 60, "y": 100}]
    }}
    def read(path, callback, **kwargs):
        if path == "/api/temperatures/":
            callback({"code": 200, "data": {"Radiator20": deepcopy(profile)}}, None)
        else:
            callback(None, "Unavailable fixture")
    client._get_document = read
    engine.rootContext().setContextProperty("backend", client)
    engine.load(QUrl.fromLocalFile(str(ROOT / "qml/Main.qml")))
    assert engine.rootObjects(), errors
    root = engine.rootObjects()[0]

    def settle():
        for _ in range(5):
            app.processEvents()
            QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)

    def wait_for(predicate):
        # Native styles animate Dialog.open(); onOpened runs after transition.
        for _ in range(200):
            settle()
            if predicate():
                return
            QTest.qWait(10)
        raise AssertionError("Timed out waiting for the dialog transition")

    settle()
    assert root.property("themeMode") == "Light", "Saved theme was overwritten during QML startup"
    assert root.property("compactMode") is True
    root.setProperty("cornerRadius", 16)
    assert Preferences(path).values["cornerRadius"] == 16, "Appearance did not save"

    root.setProperty("activeSection", "lighting")
    settle()
    workspace = root.findChild(QObject, "liveDeviceWorkspace")
    assert workspace is not None, "Live Lighting still opens demo scenes"
    choices = variant(workspace.property("choices"))
    assert choices, "Lighting devices were not discovered"
    assert workspace.findChild(QObject, "devicePage") is None, "Workspace embeds the complete device page"
    assert workspace.findChild(QObject, "deviceTabBar") is None, "Workspace exposes unrelated device tabs"
    editor = workspace.findChild(QObject, "workspaceLightingEditor")
    assert editor is not None, "Lighting workspace did not open its focused editor"
    runtime_card = root.findChild(QObject, "lightingRuntimeCard")
    assert runtime_card.property("width") > 600, "Lighting health card does not fill available width"
    selected_id = workspace.property("selectedId")
    selected_target = editor.property("selectedTargetKey")
    editor.setProperty("draftBrightness", 37)
    client._devices = deepcopy(client._devices)
    client._devices.reverse()
    client.dataChanged.emit()
    settle()
    assert workspace.property("selectedId") == selected_id, "Telemetry changed the selected device"
    assert editor.property("selectedTargetKey") == selected_target, "Telemetry changed the lighting target"
    assert editor.property("draftBrightness") == 37, "Telemetry replaced the lighting draft"

    # Cluster runtime is independent of saved individual effects and snapshot polls.
    def runtime(**overrides):
        client._lighting_runtime = dict(revision=7, mode="unknown", renderer="running",
                                        profile="nebula", members=[selected_id], operations=[])
        client._lighting_runtime.update(overrides)
        client.lightingRuntimeChanged.emit()
        settle()

    runtime()
    scene = editor.findChild(QObject, "clusterSceneName")
    renderer = editor.findChild(QObject, "clusterSceneRenderer")
    individual = editor.findChild(QObject, "individualLightingSettings")
    assert editor.property("selectedProfileKey") == "off"
    assert scene.property("text") == "Nebula" and scene.property("visible")
    assert renderer.property("text") == "Renderer running"
    assert not individual.property("visible"), "Inactive Off controls look like the Cluster scene"
    editor.setProperty("clusterEditorOpen", True)
    settle()
    assert editor.findChild(QObject, "clusterEditorSceneName").property("text") == "Nebula"
    runtime(profile="color-pulse", renderer="stalled")
    assert scene.property("text") == "Color Pulse"
    assert renderer.property("text") == "Renderer stalled"
    assert editor.findChild(QObject, "clusterEditorSceneName").property("text") == "Color Pulse"
    assert editor.property("draftBrightness") == 37
    assert editor.property("selectedTargetKey") == selected_target
    editor.setProperty("clusterEditorOpen", False)
    editor.setProperty("showIndividualSettings", True)
    settle()
    assert individual.property("visible") and editor.property("individualSettingsInactive")
    runtime(members=[])
    assert scene.property("text") == "Not reported"
    assert renderer.property("text") == "Renderer unavailable"
    runtime(profile=None)
    assert scene.property("text") == "Not reported", "Missing Cluster scene fell back to individual Off"
    client._lighting_runtime = {"mode": "unknown", "renderer": "unavailable", "operations": []}
    client.lightingRuntimeChanged.emit()
    settle()
    assert scene.property("text") == "Not reported"
    assert renderer.property("text") == "Renderer unavailable"
    individual_id = next(device["id"] for device in client.devices if device["id"] == "keyboard-1")
    workspace.setProperty("selectedId", individual_id)
    settle()
    assert not editor.property("individualSettingsInactive") and individual.property("visible")
    assert not scene.property("visible"), "Individual device shows another device's Cluster scene"

    # Each workspace exposes only its domain, even for multi-function devices.
    root.setProperty("activeSection", "input")
    settle()
    workspace = root.findChild(QObject, "liveDeviceWorkspace")
    input_id = next(device["id"] for device in client.devices if any(tab["name"] == "DPI" for tab in device["tabs"]))
    workspace.setProperty("selectedId", input_id)
    settle()
    input_cards = [card["key"] for card in variant(workspace.property("capabilityCards"))]
    assert "DPI" in input_cards and set(input_cards) <= {"Keys", "DPI", "Buttons", "Controls", "Analog", "Actuation", "Vibration", "Performance", "Pairing"}
    assert workspace.findChild(QObject, "workspaceLightingEditor") is None, "Input exposes lighting controls"
    assert workspace.findChild(QObject, "deviceTabBar") is None
    dpi_card = next(card for card in visual_items(workspace)
                    if card.objectName() == "workspaceCapabilityCard" and variant(card.property("capability")).get("name") == "DPI")
    assert variant(dpi_card.property("reportedItems")), "Reported DPI settings disappeared"
    # Missing values consolidate into one explanation instead of empty rows.
    for device in client._devices:
        if device["id"] == input_id:
            for tab in device["tabs"]:
                if tab["name"] == "DPI":
                    tab["groups"][0]["items"][0]["value"] = "Not reported"
                    tab["groups"][0]["items"][1]["value"] = "—–—"
    client.dataChanged.emit()
    settle()
    assert workspace.property("selectedId") == input_id
    assert variant(dpi_card.property("reportedItems")) == []
    root.setProperty("activeSection", "displays")
    settle()
    workspace = root.findChild(QObject, "liveDeviceWorkspace")
    assert [card["key"] for card in variant(workspace.property("capabilityCards"))] == ["Display"]
    assert workspace.findChild(QObject, "workspaceLightingEditor") is None, "Displays exposes lighting controls"
    assert workspace.findChild(QObject, "deviceTabBar") is None

    # The complete device page and its saved layouts remain under Devices.
    invoke(root, "selectDevice", selected_id)
    settle()
    device_page = root.findChild(QObject, "devicePage")
    assert device_page is not None and device_page.findChild(QObject, "deviceTabBar") is not None
    assert any(tab["name"] == "Lighting" for tab in variant(device_page.property("navigationTabs")))
    original = variant(device_page.property("arrangedGroups"))
    invoke(device_page, "moveGroup", 0, 1)
    settle()
    arranged = variant(device_page.property("arrangedGroups"))
    assert arranged[0]["key"] == original[1]["key"]
    root.setProperty("activeSection", "overview")
    settle()
    invoke(root, "selectDevice", selected_id)
    settle()
    device_page = root.findChild(QObject, "devicePage")
    device_page.setProperty("selectedTabKey", "Overview")
    settle()
    assert variant(device_page.property("arrangedGroups"))[0]["key"] == original[1]["key"]
    root.setProperty("activeSection", "audio")
    settle()
    workspace = root.findChild(QObject, "liveDeviceWorkspace")
    assert variant(workspace.property("choices")) == [], "Unsupported audio device was fabricated"

    root.setProperty("activeSection", "cooling")
    settle()
    dialog = root.findChild(QObject, "liveCoolingProfilesDialog")
    invoke(dialog, "open")
    wait_for(lambda: dialog.property("selectedName") == "Radiator20")
    assert dialog.property("selectedName") == "Radiator20"
    assert variant(dialog.property("points"))[1]["x"] == 40.5
    assert not dialog.property("dirty")
    invoke(dialog, "editPoint", 1, "y", 10)
    settle()
    assert dialog.property("validationError") and not dialog.property("canSave")
    invoke(dialog, "editPoint", 1, "y", 65.5)
    settle()
    assert not dialog.property("dirty"), "Restoring original values should clear the dirty state"
    invoke(dialog, "editPoint", 1, "y", 70)
    settle()
    assert dialog.property("canSave")
    invoke(root, "navigate", "overview")
    settle()
    assert root.property("activeSection") == "cooling", "Navigation bypassed the modal draft editor"
    client.dataChanged.emit()
    settle()
    assert variant(dialog.property("points"))[1]["y"] == 70, "Polling replaced the curve draft"
    invoke(dialog, "requestClose", False)
    settle()
    discard = root.findChild(QObject, "discardFanCurveDialog")
    wait_for(lambda: discard.property("opened"))
    assert discard.property("visible"), "Closing discarded a dirty draft without a choice"
    # Wrapped confirmation text must reflow without clipping or a sizing loop.
    initial_height = discard.property("height")
    discard.setProperty("width", 320)
    settle()
    content = discard.property("contentItem")
    assert discard.property("height") >= initial_height
    assert content.property("height") >= content.property("implicitHeight") - 1
    discard.setProperty("width", 440)
    settle()
    invoke(discard, "reject")
    wait_for(lambda: not discard.property("visible"))
    assert dialog.property("visible") and dialog.property("dirty")
    client._set_command(True, "pending", "Verifying")
    invoke(dialog, "requestClose", False)
    invoke(root, "close")
    settle()
    assert root.property("visible") and dialog.property("visible"), "Window closed during a command"
    client._set_command(False, "verified", "Saved")
    # Emulate verified read-back and ensure Reset draft uses the new baseline.
    client._cooling_profiles["Radiator20"]["points"]["1"][1]["y"] = 70
    client.fanCurveSaved.emit("Radiator20")
    settle()
    assert not dialog.property("dirty")
    invoke(dialog, "editPoint", 1, "y", 80)
    invoke(dialog, "selectProfile", "Radiator20")
    settle()
    assert variant(dialog.property("points"))[1]["y"] == 70
    invoke(dialog, "editPoint", 1, "y", 80)
    invoke(root, "close")
    settle()
    assert root.property("visible") and discard.property("visible"), "Window close lost unsaved changes"
    invoke(discard, "discarded")
    settle()
    assert not root.property("visible")
    assert not writes, "Navigation or draft changes issued a hardware command"
    assert not errors, "\n".join(errors)
    print("Daily-use QML checks passed: saved preferences, live workspaces, layouts, drafts and close protection.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
