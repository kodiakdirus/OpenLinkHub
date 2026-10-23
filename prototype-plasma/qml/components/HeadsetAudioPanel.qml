import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Panel {
    id: panel
    readonly property var audio: shell.backendClient.headsetAudio
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
        text: panel.audio.state.connected ? "Connected · Battery " + panel.audio.state.battery + "%" : "Headset unavailable"
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
        text: "Apply enables a stereo EQ output for this headset and moves its current playback streams through it. Bypass restores direct playback. Positive gains receive automatic headroom compensation."
        color: panel.shell.secondaryText
    }
    Repeater {
        model: ["32 Hz", "64 Hz", "125 Hz", "250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"]
        delegate: RowLayout {
            required property string modelData
            required property int index
            Layout.fillWidth: true
            Label { text: modelData; Layout.preferredWidth: 60; color: panel.shell.primaryText }
            Slider {
                Layout.fillWidth: true; from: -12; to: 12; stepSize: .5
                value: panel.audio.bands[index]
                enabled: panel.audio.canApplyEQ
                onMoved: panel.audio.setBand(index, value)
                Accessible.name: modelData + " equalizer gain"
            }
            Label { text: Number(panel.audio.bands[index]).toFixed(1) + " dB"; Layout.preferredWidth: 65; color: panel.shell.secondaryText }
        }
    }
    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: panel.audio.eqMessage; color: panel.shell.secondaryText }
    RowLayout {
        Layout.fillWidth: true
        Button { text: "Refresh EQ"; enabled: !panel.audio.busy; onClicked: panel.audio.refreshEQ() }
        Item { Layout.fillWidth: true }
        Button { text: "Bypass EQ"; enabled: panel.audio.canApplyEQ && panel.audio.eqState.enabled === true; onClicked: panel.audio.disableEQ() }
        Button { text: "Apply EQ"; enabled: panel.audio.canApplyEQ; onClicked: panel.audio.applyEQ() }
    }
}
