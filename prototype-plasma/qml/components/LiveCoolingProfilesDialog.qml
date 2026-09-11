import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Dialog {
    id: dialog
    required property var shell
    readonly property var client: shell.backendClient
    property var names: []
    property string selectedName: ""
    property var selectedProfile: ({})
    property var points: []
    property bool dirty: false
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(850, parent.width - 48)
    height: Math.min(760, parent.height - 48)
    modal: true
    title: "Fan curves"
    closePolicy: client.coolingBusy ? Popup.NoAutoClose : Popup.CloseOnEscape

    function selectProfile(name) {
        selectedName = name
        selectedProfile = client.coolingProfiles[name] || {}
        points = JSON.parse(JSON.stringify((selectedProfile.points || {})["1"] || []))
        dirty = false
    }
    function editPoint(index, key, value) {
        points[index][key] = value
        dirty = true
        preview.requestPaint()
    }
    onOpened: {
        names = []
        selectedName = ""
        points = []
        dirty = false
        client.loadCoolingProfiles()
    }
    Connections {
        target: dialog.client
        function onCoolingChanged() {
            // Ordinary telemetry never replaces the curve draft.
            if (dialog.names.length === 0 && !dialog.client.coolingBusy) {
                dialog.names = Object.keys(dialog.client.coolingProfiles).sort()
                const preferred = dialog.names.indexOf("Radiator20")
                profiles.currentIndex = preferred >= 0 ? preferred : 0
                dialog.selectProfile(dialog.names[profiles.currentIndex] || "")
            }
        }
        function onFanCurveSaved(name) { if (name === dialog.selectedName) dialog.dirty = false }
        function onModeChanged() { dialog.close() }
    }
    footer: DialogButtonBox {
        Button {
            text: "Save fan curve"
            icon.name: "document-save"
            enabled: dialog.dirty && dialog.points.length >= 2 && !dialog.client.coolingBusy && !dialog.client.commandBusy
            onClicked: dialog.client.saveFanCurve(dialog.selectedName, JSON.stringify(dialog.points))
        }
        Button {
            text: "Close"
            enabled: !dialog.client.coolingBusy
            onClicked: dialog.close()
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        Label {
            Layout.fillWidth: true
            text: "Saving immediately updates every fan using this profile. Pump curves, sensor selection, and channel assignments stay as they are."
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            ComboBox {
                id: profiles
                Layout.fillWidth: true
                model: dialog.names
                enabled: !dialog.client.coolingBusy && !dialog.dirty
                onActivated: dialog.selectProfile(dialog.names[currentIndex])
            }
            Button {
                text: "Reset draft"
                enabled: dialog.dirty && !dialog.client.coolingBusy
                onClicked: dialog.selectProfile(dialog.selectedName)
            }
            Button {
                text: "Reload"
                enabled: !dialog.dirty && !dialog.client.coolingBusy
                onClicked: { dialog.names = []; dialog.client.loadCoolingProfiles() }
            }
        }
        Label {
            Layout.fillWidth: true
            text: "Sensor: " + (dialog.selectedProfile.sensorString || "—")
                + (dialog.selectedProfile.zeroRpm ? " · Zero RPM allowed" : " · Service enforces a 20% fan minimum")
            color: shell.secondaryText
        }
        Canvas {
            id: preview
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            Connections { target: dialog; function onPointsChanged() { preview.requestPaint() } }
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const pts = dialog.points
                if (pts.length < 2) return
                const xmax = Math.max(60, pts[pts.length - 1].x)
                const left = 36, top = 12, w = width - 52, h = height - 36
                ctx.strokeStyle = dialog.shell.outline
                ctx.fillStyle = dialog.shell.secondaryText
                ctx.font = "11px sans-serif"
                for (let output = 0; output <= 100; output += 25) {
                    const y = top + h * (1 - output / 100)
                    ctx.fillText(output + "%", 0, y + 4)
                    ctx.beginPath(); ctx.moveTo(left, y); ctx.lineTo(left + w, y); ctx.stroke()
                }
                ctx.fillText("0°C", left, height - 2)
                ctx.fillText(xmax + "°C", left + w - 32, height - 2)
                ctx.strokeStyle = dialog.shell.accentColor
                ctx.lineWidth = 2
                ctx.beginPath()
                pts.forEach((p, i) => {
                    const x = left + w * p.x / xmax, y = top + h * (1 - p.y / 100)
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                })
                ctx.stroke()
            }
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                Repeater {
                    model: dialog.points
                    delegate: RowLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        enabled: !dialog.client.coolingBusy
                        Label { text: "Point " + (index + 1); Layout.fillWidth: true }
                        SpinBox {
                            from: 0; to: 200; editable: true
                            value: modelData.x
                            onValueModified: dialog.editPoint(index, "x", value)
                            Accessible.name: "Point " + (index + 1) + " temperature in Celsius"
                        }
                        Label { text: "°C" }
                        SpinBox {
                            from: 0; to: 100; editable: true
                            value: modelData.y
                            onValueModified: dialog.editPoint(index, "y", value)
                            Accessible.name: "Point " + (index + 1) + " fan output percentage"
                        }
                        Label { text: "%" }
                        ToolButton {
                            icon.name: "edit-delete"
                            enabled: dialog.points.length > 2
                            Accessible.name: "Remove point " + (index + 1)
                            onClicked: {
                                const updated = dialog.points.slice(); updated.splice(index, 1)
                                dialog.points = updated; dialog.dirty = true
                            }
                        }
                    }
                }
                Button {
                    text: "Add point"
                    enabled: !dialog.client.coolingBusy && dialog.points.length > 0 && dialog.points.length < 32 && dialog.points[dialog.points.length - 1].x < 200
                    onClicked: {
                        const last = dialog.points[dialog.points.length - 1]
                        dialog.points = dialog.points.concat([{x: Math.min(200, last.x + 5), y: last.y}])
                        dialog.dirty = true
                    }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            text: dialog.client.coolingMessage
            wrapMode: Text.WrapAnywhere
            color: shell.secondaryText
        }
    }
}
