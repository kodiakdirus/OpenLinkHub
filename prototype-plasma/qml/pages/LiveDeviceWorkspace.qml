import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: page
    objectName: "liveDeviceWorkspace"
    required property var shell
    required property string section
    property var choices: []
    property string choiceSignature: ""
    property string selectedId: ""
    property var capabilityCards: []
    property string cardSignature: ""
    readonly property var workspace: ({
        lighting: {label: "Lighting device", tabs: ["Lighting"],
            description: "Effects, targets, and synchronized lighting."},
        input: {label: "Input device", tabs: ["Keys", "DPI", "Buttons", "Controls", "Analog", "Actuation", "Vibration", "Performance", "Pairing"],
            description: "Sensitivity, button assignments, and input behavior."},
        audio: {label: "Audio device", tabs: ["Audio"],
            description: "Audio settings reported for your headset."},
        displays: {label: "LCD device", tabs: ["Display"],
            description: "LCD support and display settings."}
    })[section] || ({label: "Device", tabs: [], description: ""})
    readonly property var selectedDevice: {
        const devices = shell.devices || []
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].id === selectedId) return devices[i]
        return null
    }
    readonly property var lightingModel: capabilityForKey("Lighting").lightingEditor || null

    function capabilityForKey(key) {
        return ((selectedDevice || {}).tabs || []).find(tab => tab.name === key && tab.available !== false) || ({})
    }

    function reconcile() {
        const next = (shell.devices || []).filter(device =>
            (device.tabs || []).some(tab => tab.available !== false && workspace.tabs.indexOf(tab.name) >= 0)
        ).map(device => ({key: device.id, name: device.name}))
        const signature = JSON.stringify(next)
        if (signature !== choiceSignature) {
            choices = next
            choiceSignature = signature
        }
        if (!next.some(device => device.key === selectedId))
            selectedId = next.length ? next[0].key : ""
        reconcileCards()
    }

    function reconcileCards() {
        const cards = workspace.tabs.filter(name => capabilityForKey(name).name).map(name => ({key: name}))
        const signature = JSON.stringify([section, selectedId, cards])
        if (signature === cardSignature) return
        cardSignature = signature
        capabilityCards = cards
    }

    onSelectedIdChanged: Qt.callLater(function() { reconcileCards(); workspaceScroll.contentItem.contentY = 0 })
    onSectionChanged: Qt.callLater(function() { reconcile(); workspaceScroll.contentItem.contentY = 0 })
    Component.onCompleted: reconcile()
    Connections {
        target: page.shell
        function onDevicesChanged() { Qt.callLater(page.reconcile) }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: page.shell.cardSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Label {
                text: page.workspace.label
                color: page.shell.secondaryText
            }
            ComboBox {
                objectName: "workspaceDeviceSelector"
                Layout.preferredWidth: 380
                Layout.fillWidth: true
                Layout.maximumWidth: 480
                model: page.choices
                textRole: "name"
                valueRole: "key"
                currentIndex: page.choices.findIndex(device => device.key === page.selectedId)
                enabled: page.choices.length > 0 && !page.shell.backendClient.commandBusy
                onActivated: page.selectedId = currentValue
                Accessible.name: "Select device for " + page.section
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "View device"
                icon.name: "go-next"
                visible: page.selectedDevice !== null
                enabled: !page.shell.backendClient.commandBusy
                onClicked: page.shell.selectDevice(page.selectedId)
                ToolTip.visible: hovered
                ToolTip.text: "Open all capabilities and device details in Devices"
            }
            ToolButton {
                icon.name: "view-refresh"
                enabled: !page.shell.backendClient.refreshing && !page.shell.backendClient.commandBusy
                onClicked: page.shell.backendClient.refresh()
                Accessible.name: "Refresh devices"
                ToolTip.visible: hovered
                ToolTip.text: "Refresh devices"
            }
        }

        ScrollView {
            id: workspaceScroll
            objectName: "workspaceScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth

            ColumnLayout {
                width: workspaceScroll.availableWidth
                spacing: page.shell.cardSpacing

                Panel {
                    shell: page.shell
                    visible: !page.selectedDevice
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: page.shell.backendClient.connectionState === "connecting"
                            ? "Loading devices…" : "No device reports " + page.section + " settings."
                        color: page.shell.primaryText
                        font.pixelSize: 18
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true
                        text: page.shell.backendClient.connectionState === "offline"
                            ? "Start the OpenLinkHub service, then refresh."
                            : "Supported devices will appear here when the service reports their capabilities."
                        color: page.shell.secondaryText
                        wrapMode: Text.WordWrap
                    }
                }

                Loader {
                    id: lightingLoader
                    objectName: "workspaceLightingLoader"
                    Layout.fillWidth: true
                    active: page.section === "lighting" && page.selectedDevice !== null && page.lightingModel !== null
                    visible: active
                    sourceComponent: Component {
                        LightingDeviceEditor {
                            objectName: "workspaceLightingEditor"
                            shell: page.shell
                            device: page.selectedDevice || ({})
                            modelData: page.lightingModel || ({targets: [], profiles: []})
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: page.selectedDevice !== null && (page.section !== "lighting" || !page.lightingModel)
                    text: page.workspace.description + " These settings are currently read-only."
                    color: page.shell.secondaryText
                    wrapMode: Text.WordWrap
                }

                GridLayout {
                    Layout.fillWidth: true
                    visible: page.selectedDevice !== null && (page.section !== "lighting" || !page.lightingModel)
                    columns: width > 820 ? 2 : 1
                    columnSpacing: page.shell.cardSpacing
                    rowSpacing: page.shell.cardSpacing
                    Repeater {
                        model: page.capabilityCards
                        delegate: WorkspaceCapabilityCard {
                            required property var modelData
                            shell: page.shell
                            capability: page.capabilityForKey(modelData.key)
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.columnSpan: page.capabilityCards.length === 1 ? parent.columns : 1
                        }
                    }
                }
                Item { Layout.preferredHeight: 1 }
            }
        }
    }
}
