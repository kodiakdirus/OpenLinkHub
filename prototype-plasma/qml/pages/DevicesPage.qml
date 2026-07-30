import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page
    objectName: "devicesPage"

    required property var shell
    property string query: ""
    property var cardDevices: []
    property var filteredCardDevices: []
    property string cardDeviceSignature: ""
    property int presentationRevision: 0

    function reconcileDevices() {
        const sourceDevices = shell.devices || []
        const nextSignature = JSON.stringify(sourceDevices.map(device => [
            device.id,
            device.name,
            device.icon,
            device.subtitle,
            device.connected,
            device.capabilities,
            (device.tabs || []).map(tab => [tab.name, tab.icon])
        ]))
        if (nextSignature !== cardDeviceSignature) {
            cardDeviceSignature = nextSignature
            cardDevices = sourceDevices
            presentationRevision += 1
            applyFilter()
        }
    }

    function applyFilter() {
        const needle = query.trim().toLowerCase()
        if (!needle) {
            filteredCardDevices = cardDevices
            return
        }
        filteredCardDevices = cardDevices.filter(device => {
            const haystack = [
                device.name,
                device.subtitle,
                (device.capabilities || []).join(" "),
                (device.tabs || []).map(tab => tab.name).join(" ")
            ].join(" ").toLowerCase()
            return haystack.indexOf(needle) >= 0
        })
    }

    onQueryChanged: applyFilter()
    Component.onCompleted: reconcileDevices()

    Connections {
        target: page.shell

        function onDevicesChanged() {
            Qt.callLater(page.reconcileDevices)
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: page.shell.sectionSpacing

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Connected hardware"
                    color: page.shell.primaryText
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                TextField {
                    objectName: "deviceFilterField"
                    Layout.preferredWidth: 310
                    placeholderText: "Filter devices or capabilities…"
                    onTextChanged: page.query = text
                }

                Button {
                    visible: page.shell.liveMode
                    text: "Refresh"
                    icon.name: "view-refresh"
                    onClicked: {
                        if (!page.shell.backendClient.refreshing) {
                            page.shell.backendClient.refresh()
                        }
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: page.shell.backendClient.refreshing
                        ? "A telemetry refresh is already in progress"
                        : "Refresh live device data"
                }
            }

            Panel {
                shell: page.shell
                Layout.fillWidth: true
                color: Qt.rgba(page.shell.accentColor.r, page.shell.accentColor.g, page.shell.accentColor.b, 0.08)

                RowLayout {
                    Layout.fillWidth: true
                    Kirigami.Icon {
                            source: "dialog-information"
                        color: page.shell.accentColor
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                    }
                    Label {
                        Layout.fillWidth: true
                        text: page.shell.liveMode
                            ? "Live cards and read-only tabs are normalized from legacy service payloads. Capability inference remains provisional until the versioned manifest exists."
                            : "Capability-aware navigation is active. Device tabs below are generated from the demo hardware capabilities."
                        color: page.shell.secondaryText
                        wrapMode: Text.WordWrap
                    }
                    StatusBadge {
                        shell: page.shell
                        text: page.shell.backendClient.statusText
                        badgeColor: page.shell.connectionBadgeColor()
                        filled: true
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 1050 ? 3 : width > 700 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Repeater {
                    model: page.filteredCardDevices

                    delegate: Panel {
                        required property var modelData
                        shell: page.shell
                        Layout.fillWidth: true
                        Layout.preferredHeight: page.shell.compactMode ? 270 : 300

                        RowLayout {
                            Layout.fillWidth: true

                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                radius: 13
                                color: page.shell.surfaceAlt
                                border.color: page.shell.outline

                                Kirigami.Icon {
                            anchors.centerIn: parent
                                    width: 29
                                    height: 29
                                    source: modelData.icon
                                    color: page.shell.accentColor
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    text: modelData.name
                                    color: page.shell.primaryText
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: modelData.subtitle
                                    color: page.shell.mutedText
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                width: 9
                                height: 9
                                radius: 5
                                color: modelData.connected === false
                                    ? page.shell.warningColor
                                    : page.shell.successColor
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: modelData.capabilities
                                delegate: StatusBadge {
                                    required property var modelData
                                    shell: page.shell
                                    text: modelData
                                    badgeColor: page.shell.mutedText
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: page.shell.outline
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: modelData.tabs.length + " relevant tabs"
                                color: page.shell.mutedText
                                font.pixelSize: 12
                            }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "Open device"
                                icon.name: "go-next"
                                onClicked: page.shell.selectDevice(modelData.id)
                            }
                        }
                    }
                }
            }

            Label {
                visible: page.filteredCardDevices.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 60
                text: page.shell.liveMode
                    ? (page.query.length > 0
                        ? "No live device matches “" + page.query + "”."
                        : "No live devices are available.")
                    : "No demo device matches “" + page.query + "”."
                color: page.shell.mutedText
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 16
            }

            Item { Layout.preferredHeight: 1 }
        }
    }
}
