import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Panel {
    id: panel
    readonly property var audio: shell.backendClient.headsetAudio
    readonly property var battery: audio.eqState.headsetBattery || ({})
    property var headsetChoices: []
    property string headsetSignature: ""
    function reconcile() {
        const choices = audio.devices.map(item => ({id: item.deviceId, name: "VOID ELITE · " + item.deviceId}))
        const signature = JSON.stringify(choices)
        if (signature !== headsetSignature) { headsetSignature = signature; headsetChoices = choices }
    }
    Component.onCompleted: { reconcile(); if (visible) audio.refresh() }
    onVisibleChanged: if (visible) audio.refresh()
    Connections { target: panel.audio; function onChanged() { panel.reconcile() } }
    Timer { interval: 3000; repeat: true; running: panel.visible && panel.shell.liveMode; onTriggered: panel.audio.refresh() }

    PanelHeader { shell: panel.shell; title: "Headset audio"; subtitle: "Sidetone, wireless battery, and session equalizer"; iconName: "audio-headphones" }
    ComboBox {
        Layout.fillWidth: true
        model: panel.headsetChoices; textRole: "name"; valueRole: "id"
        currentIndex: panel.headsetChoices.findIndex(item => item.id === panel.audio.selectedId)
        enabled: !panel.audio.busy && !panel.audio.sidetoneDirty
        onActivated: panel.audio.select(currentValue)
        Accessible.name: "Headset"
    }
    Label {
        Layout.fillWidth: true
        text: panel.audio.state.connected ? "Connected · " + (panel.battery.percent !== undefined
            ? "Battery " + panel.battery.percent + "% · " + panel.battery.status
            : panel.audio.state.battery > 0 ? "Battery " + panel.audio.state.battery + "%" : "Waiting for battery report") : "Headset unavailable"
        color: panel.shell.secondaryText
    }
    CheckBox {
        text: "Sidetone (hear your microphone)"; checked: panel.audio.enabled
        enabled: panel.audio.state.connected === true && !panel.audio.busy
        onToggled: panel.audio.setEnabled(checked)
    }
    Label { text: "Sidetone level · " + panel.audio.level + "%"; color: panel.shell.primaryText }
    Slider {
        Layout.fillWidth: true; from: 1; to: 100; stepSize: 1; value: panel.audio.level
        enabled: panel.audio.state.connected === true && panel.audio.enabled && !panel.audio.busy
        onMoved: panel.audio.setLevel(Math.round(value))
        Accessible.name: "Sidetone level"
    }
    Label {
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: panel.audio.stale ? "Settings changed while editing. Revert to load the current state." : panel.audio.message
        color: panel.audio.stale ? panel.shell.warningColor : panel.shell.secondaryText
    }
    RowLayout {
        Layout.fillWidth: true
        Button { text: "Refresh"; enabled: !panel.audio.busy; onClicked: panel.audio.refresh() }
        Item { Layout.fillWidth: true }
        Button { text: "Revert drafts"; enabled: panel.audio.dirty && !panel.audio.busy; onClicked: panel.audio.revert() }
        Button { text: "Apply sidetone"; enabled: panel.audio.canApply; onClicked: panel.audio.apply() }
    }
    Label { text: "Equalizer"; font.pixelSize: 20; color: panel.shell.primaryText }
    Label {
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: "Apply enables a stereo EQ output for this headset and moves its current playback streams through it. Bypass restores direct playback. Preamp controls overall gain separately."
        color: panel.shell.secondaryText
    }
    RowLayout {
        Layout.fillWidth: true
        CheckBox {
            text: "Virtual surround · 7.1"
            checked: panel.audio.surround
            enabled: panel.audio.canApplyEQ && panel.audio.eqState.surroundAvailable === true
            onToggled: panel.audio.setSurround(checked)
        }
        Item { Layout.fillWidth: true }
        Button { text: "Flat EQ"; enabled: panel.audio.canApplyEQ; onClicked: panel.audio.flatEQ() }
    }
    Label {
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: panel.audio.surround ? "Front stereo and dialogue stay natural; side and rear channels use binaural surround. Select 7.1 output in supporting games."
            : "Stereo processing. Choose Virtual surround for a 7.1 input rendered to your headphones."
        color: panel.shell.secondaryText
    }
    Label { text: "EQ band curve · drag a point to adjust"; color: panel.shell.secondaryText }
    Rectangle {
        id: equalizerGraph
        objectName: "equalizerGraph"
        Layout.fillWidth: true
        Layout.preferredHeight: 280
        color: Qt.rgba(0, 0, 0, 0.12)
        radius: 6
        readonly property var frequencies: [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        readonly property real plotTop: 22
        readonly property real plotBottom: height - 38
        function bandX(index) { return 42 + Math.log(frequencies[index] / 32) / Math.log(500) * (width - 66) }
        function gainY(gain) { return plotTop + (12 - gain) / 24 * (plotBottom - plotTop) }
        Canvas {
            id: responseCurve
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.font = "10px sans-serif"
                for (let gain = -12; gain <= 12; gain += 6) {
                    const yy = equalizerGraph.gainY(gain)
                    ctx.strokeStyle = gain === 0 ? "#777777" : "#3c3c3c"
                    ctx.beginPath(); ctx.moveTo(42, yy); ctx.lineTo(width - 24, yy); ctx.stroke()
                    ctx.fillStyle = "#aaaaaa"; ctx.fillText((gain > 0 ? "+" : "") + gain + " dB", 6, yy + 3)
                }
                const points = []
                for (let i = 0; i < 10; ++i)
                    points.push({x: equalizerGraph.bandX(i), y: equalizerGraph.gainY(panel.audio.bands[i])})
                ctx.strokeStyle = panel.shell.accentColor; ctx.lineWidth = 2
                ctx.beginPath(); ctx.moveTo(points[0].x, points[0].y)
                for (let j = 0; j < points.length - 1; ++j) {
                    const p0 = points[Math.max(0, j - 1)], p1 = points[j]
                    const p2 = points[j + 1], p3 = points[Math.min(points.length - 1, j + 2)]
                    function clipY(y) { return Math.max(equalizerGraph.plotTop, Math.min(equalizerGraph.plotBottom, y)) }
                    ctx.bezierCurveTo(p1.x + (p2.x - p0.x) / 6, clipY(p1.y + (p2.y - p0.y) / 6),
                                     p2.x - (p3.x - p1.x) / 6, clipY(p2.y - (p3.y - p1.y) / 6), p2.x, p2.y)
                }
                ctx.stroke()
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: panel.audio; function onChanged() { responseCurve.requestPaint() } }
        }
        Repeater {
            model: ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
            delegate: Item {
                required property string modelData
                required property int index
                x: equalizerGraph.bandX(index) - width / 2
                width: 32
                height: equalizerGraph.height
                Slider {
                    id: bandSlider
                    objectName: "equalizerBand" + index
                    x: 0; y: equalizerGraph.plotTop - 7
                    width: 32; height: equalizerGraph.plotBottom - equalizerGraph.plotTop + 14
                    orientation: Qt.Vertical
                    padding: 0
                    from: -12; to: 12; stepSize: .5
                    value: panel.audio.bands[index]
                    enabled: panel.audio.canApplyEQ
                    onMoved: panel.audio.setBand(index, value)
                    Accessible.name: modelData + " Hz equalizer gain"
                    background: Rectangle {
                        x: (bandSlider.width - width) / 2; y: 7
                        width: 1; height: bandSlider.height - 14
                        color: Qt.rgba(0.65, 0.65, 0.65, bandSlider.hovered ? 0.5 : 0.18)
                    }
                    handle: Rectangle {
                        width: 14; height: 14; radius: 7
                        x: (bandSlider.width - width) / 2
                        y: bandSlider.visualPosition * (bandSlider.height - height)
                        color: panel.shell.accentColor
                        border.color: panel.shell.surface; border.width: 2
                    }
                    ToolTip.visible: hovered || pressed
                    ToolTip.text: modelData + " Hz · " + (value > 0 ? "+" : "") + Number(value).toFixed(1) + " dB"
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: equalizerGraph.plotBottom + 14
                    text: modelData
                    color: panel.shell.secondaryText
                    font.pixelSize: 11
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label { text: "Preamp"; color: panel.shell.primaryText; Layout.preferredWidth: 70 }
        Slider {
            Layout.fillWidth: true; from: -24; to: 0; stepSize: .5
            value: panel.audio.preamp
            enabled: panel.audio.canApplyEQ
            onMoved: panel.audio.setPreamp(value)
            Accessible.name: "EQ preamp"
        }
        Label { text: Number(panel.audio.preamp).toFixed(1) + " dB"; color: panel.shell.secondaryText }
    }
    Label {
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: "Band boosts keep their gain. Preamp is manual; lower it if a boosted curve distorts. Apply to hear draft changes."
        color: panel.shell.mutedText
    }
    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: panel.audio.eqMessage; color: panel.shell.secondaryText }
    RowLayout {
        Layout.fillWidth: true
        Button { text: "Refresh EQ"; enabled: !panel.audio.busy; onClicked: panel.audio.refreshEQ() }
        Item { Layout.fillWidth: true }
        Button { text: "Bypass processing"; enabled: panel.audio.canApplyEQ && panel.audio.eqState.enabled === true; onClicked: panel.audio.disableEQ() }
        Button { text: "Apply audio"; enabled: panel.audio.canApplyEQ; onClicked: panel.audio.applyEQ() }
    }
}
