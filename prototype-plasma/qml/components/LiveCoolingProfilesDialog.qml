import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Dialog {
    id: dialog
    objectName: "liveCoolingProfilesDialog"
    required property var shell
    readonly property var client: shell.backendClient
    property var names: []
    property string selectedName: ""
    property var selectedProfile: ({})
    property var points: []
    property var baselinePoints: []
    property bool dirty: false
    property int draftRevision: 0
    property bool closeWindowAfterDiscard: false
    readonly property string validationError: {
        const revision = draftRevision
        return selectedName ? client.validateFanCurve(JSON.stringify(points)) : ""
    }
    readonly property bool canSave: dirty && !validationError && points.length >= 2
        && !client.coolingBusy && !client.commandBusy
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(850, parent.width - 48)
    height: Math.min(760, parent.height - 48)
    modal: true
    title: "Fan curves"
    closePolicy: Popup.NoAutoClose

    function requestClose(closeWindow) {
        if (client.coolingBusy || client.commandBusy) return
        if (dirty) {
            closeWindowAfterDiscard = Boolean(closeWindow)
            discardDialog.open()
        } else {
            close()
            if (closeWindow) shell.close()
        }
    }

    function updateDraft() {
        dirty = JSON.stringify(points) !== JSON.stringify(baselinePoints)
        draftRevision += 1
        preview.requestPaint()
    }

    function selectProfile(name) {
        selectedName = name
        selectedProfile = client.coolingProfiles[name] || {}
        baselinePoints = JSON.parse(JSON.stringify((selectedProfile.points || {})["1"] || []))
        points = JSON.parse(JSON.stringify(baselinePoints))
        dirty = false
        draftRevision += 1
    }
    function editPoint(index, key, value) {
        points[index][key] = value
        updateDraft()
    }
    onOpened: {
        shell.activeCurveEditor = dialog
        names = []
        selectedName = ""
        points = []
        dirty = false
        client.loadCoolingProfiles()
    }
    onClosed: {
        if (shell.activeCurveEditor === dialog) shell.activeCurveEditor = null
    }
    Component.onDestruction: {
        if (shell.activeCurveEditor === dialog) shell.activeCurveEditor = null
    }
    Shortcut {
        sequence: "Escape"
        enabled: dialog.opened && !discardDialog.opened
        onActivated: dialog.requestClose(false)
    }
    Dialog {
        id: discardDialog
        objectName: "discardFanCurveDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(440, parent.width - 48)
        modal: true
        title: "Discard unsaved fan curve?"
        standardButtons: Dialog.Discard | Dialog.Cancel
        onDiscarded: {
            dialog.dirty = false
            dialog.close()
            close()
            if (dialog.closeWindowAfterDiscard) dialog.shell.close()
        }
        contentItem: Label {
            // Let Dialog size its content directly. A child sized from the
            // default content item's width creates a measurement cycle in Breeze.
            text: "Your edits to " + dialog.selectedName + " have not been saved. Keep editing or discard the draft."
            wrapMode: Text.WordWrap
        }
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
        function onFanCurveSaved(name) {
            if (name !== dialog.selectedName) return
            dialog.selectedProfile = dialog.client.coolingProfiles[name] || {}
            dialog.baselinePoints = JSON.parse(JSON.stringify(dialog.points))
            dialog.updateDraft()
        }
        function onModeChanged() { dialog.close() }
    }
    footer: DialogButtonBox {
        Button {
            objectName: "saveFanCurveButton"
            text: "Save fan curve"
            icon.name: "document-save"
            enabled: dialog.canSave
            onClicked: dialog.client.saveFanCurve(dialog.selectedName, JSON.stringify(dialog.points))
        }
        Button {
            text: "Close"
            enabled: !dialog.client.coolingBusy
            onClicked: dialog.requestClose(false)
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
                + (dialog.selectedProfile.zeroRpm ? " · Zero RPM allowed" : " · Zero RPM disabled")
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
                            id: temperatureInput
                            from: 0; to: 2000; editable: true; stepSize: 10
                            value: Math.round(modelData.x * 10)
                            textFromValue: function(value, locale) { return Number(value / 10).toLocaleString(locale, 'f', 1) }
                            valueFromText: function(text, locale) { return Math.round(Number.fromLocaleString(locale, text) * 10) }
                            validator: DoubleValidator { bottom: 0; top: 200; decimals: 1; locale: temperatureInput.locale.name }
                            onValueModified: dialog.editPoint(index, "x", value / 10)
                            Accessible.name: "Point " + (index + 1) + " temperature in Celsius"
                        }
                        Label { text: "°C" }
                        SpinBox {
                            id: outputInput
                            from: 0; to: 1000; editable: true; stepSize: 10
                            value: Math.round(modelData.y * 10)
                            textFromValue: function(value, locale) { return Number(value / 10).toLocaleString(locale, 'f', 1) }
                            valueFromText: function(text, locale) { return Math.round(Number.fromLocaleString(locale, text) * 10) }
                            validator: DoubleValidator { bottom: 0; top: 100; decimals: 1; locale: outputInput.locale.name }
                            onValueModified: dialog.editPoint(index, "y", value / 10)
                            Accessible.name: "Point " + (index + 1) + " fan output percentage"
                        }
                        Label { text: "%" }
                        ToolButton {
                            icon.name: "edit-delete"
                            enabled: dialog.points.length > 2
                            Accessible.name: "Remove point " + (index + 1)
                            onClicked: {
                                const updated = dialog.points.slice(); updated.splice(index, 1)
                                dialog.points = updated; dialog.updateDraft()
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
                        dialog.updateDraft()
                    }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            visible: dialog.validationError.length > 0
            text: dialog.validationError
            wrapMode: Text.WordWrap
            color: shell.warningColor
        }
        Label {
            Layout.fillWidth: true
            visible: !dialog.client.coolingBusy && dialog.names.length === 0
            text: "No editable graph-based fan curves are available. Check the service connection and its graph-profile configuration, then Reload."
            wrapMode: Text.WordWrap
            color: shell.warningColor
        }
        Label {
            Layout.fillWidth: true
            text: dialog.client.coolingMessage
            wrapMode: Text.WrapAnywhere
            color: shell.secondaryText
        }
    }
}
