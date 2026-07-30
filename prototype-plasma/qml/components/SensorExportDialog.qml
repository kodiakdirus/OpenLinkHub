import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Dialog {
    id: dialog

    required property var shell

    property var sensorRows: [
        { name: "Coolant temperature", id: "titan360/coolantTemperature", sample: "38.2 °C", enabled: true },
        { name: "Pump speed", id: "titan360/pumpSpeed", sample: "1,460 RPM", enabled: true },
        { name: "Radiator fan 1", id: "linkhub/radiatorFan1", sample: "718 RPM", enabled: true },
        { name: "Radiator fan 2", id: "linkhub/radiatorFan2", sample: "721 RPM", enabled: true },
        { name: "Radiator fan 3", id: "linkhub/radiatorFan3", sample: "716 RPM", enabled: true },
        { name: "Case fan average", id: "linkhub/caseFanAverage", sample: "0 RPM", enabled: true },
        { name: "K100 AIR battery", id: "k100air/battery", sample: "82%", enabled: true },
        { name: "Virtuoso battery", id: "virtuoso/battery", sample: "68%", enabled: false }
    ]

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(860, parent.width - 60)
    height: Math.min(730, parent.height - 60)
    modal: true
    title: "Configure system sensor export"
    standardButtons: Dialog.Save | Dialog.Cancel

    onAccepted: {
        shell.markDirty("Plasma System Monitor sensor export")
        shell.showToast(
            "Sensor export preview saved",
            "The mock provider changed locally; no KSystemStats plugin or backend connection was created."
        )
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: shell.cardSpacing

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: providerCopy.implicitHeight + shell.contentPadding * 2
                radius: shell.cornerRadius
                color: Qt.rgba(shell.accentColor.r, shell.accentColor.g, shell.accentColor.b, 0.08)
                border.color: shell.accentColor

                RowLayout {
                    id: providerCopy
                    anchors.fill: parent
                    anchors.margins: shell.contentPadding
                    spacing: 14

                    Kirigami.Icon {
                        source: "utilities-system-monitor"
                        color: shell.accentColor
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: "Plasma System Monitor provider"
                            color: shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "Publish read-only Corsair telemetry through a KSystemStats-compatible provider."
                            color: shell.mutedText
                            wrapMode: Text.WordWrap
                        }
                    }

                    Label {
                        text: "Prototype concept"
                        color: shell.warningColor
                        font.weight: Font.DemiBold
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: shell.cardSpacing
                rowSpacing: 10

                Label { text: "Provider"; color: shell.secondaryText }
                ComboBox {
                    Layout.fillWidth: true
                    model: ["Plasma System Monitor (KSystemStats)", "Prometheus metrics"]
                }

                Label { text: "Sensor namespace"; color: shell.secondaryText }
                TextField {
                    Layout.fillWidth: true
                    text: "openlinkhub"
                    placeholderText: "Provider namespace"
                }

                Label { text: "Refresh interval"; color: shell.secondaryText }
                RowLayout {
                    Layout.fillWidth: true
                    Slider {
                        from: 250
                        to: 5000
                        stepSize: 250
                        value: 1000
                        Layout.fillWidth: true
                    }
                    Label {
                        text: "1 s"
                        color: shell.accentColor
                        Layout.preferredWidth: 42
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Available Corsair sensors"
                    color: shell.primaryText
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "7 selected"
                    color: shell.mutedText
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sensorList.implicitHeight + shell.contentPadding * 2
                radius: shell.cornerRadius
                color: shell.surfaceAlt
                border.color: shell.outline

                ColumnLayout {
                    id: sensorList
                    anchors.fill: parent
                    anchors.margins: shell.contentPadding
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8

                        Label {
                            text: "Sensor"
                            color: shell.mutedText
                            font.weight: Font.DemiBold
                            Layout.preferredWidth: 210
                        }
                        Label {
                            text: "System Monitor ID"
                            color: shell.mutedText
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        Label {
                            text: "Preview"
                            color: shell.mutedText
                            font.weight: Font.DemiBold
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignRight
                        }
                        Item { Layout.preferredWidth: 52 }
                    }

                    Repeater {
                        model: dialog.sensorRows

                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: shell.outline
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 47

                                Label {
                                    text: modelData.name
                                    color: shell.primaryText
                                    Layout.preferredWidth: 210
                                }
                                Label {
                                    text: "openlinkhub/" + modelData.id
                                    color: shell.mutedText
                                    font.family: "monospace"
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                }
                                Label {
                                    text: modelData.sample
                                    color: shell.secondaryText
                                    font.weight: Font.DemiBold
                                    Layout.preferredWidth: 100
                                    horizontalAlignment: Text.AlignRight
                                }
                                Switch {
                                    checked: modelData.enabled
                                    Accessible.name: "Export " + modelData.name
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Kirigami.Icon {
                    source: "security-high"
                    color: shell.accentColor
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }

                Label {
                    Layout.fillWidth: true
                    text: "Export is read-only. A production provider would consume validated service telemetry and must never become another hardware-control owner."
                    color: shell.mutedText
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
