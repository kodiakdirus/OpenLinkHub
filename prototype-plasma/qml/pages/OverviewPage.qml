import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page

    required property var shell

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: page.shell.sectionSpacing

            GridLayout {
                Layout.fillWidth: true
                columns: width > 1000 ? 4 : 2
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Repeater {
                    model: page.shell.overviewMetrics

                    delegate: Panel {
                        required property var modelData
                        shell: page.shell
                        Layout.fillWidth: true
                        Layout.preferredHeight: page.shell.compactMode ? 126 : 142

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: 12
                                color: Qt.rgba(page.shell.accentColor.r, page.shell.accentColor.g, page.shell.accentColor.b, 0.12)

                                Kirigami.Icon {
                            anchors.centerIn: parent
                                    width: 25
                                    height: 25
                                    source: modelData.icon
                                    color: page.shell.accentColor
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: modelData.label
                                    color: page.shell.mutedText
                                    font.pixelSize: 12
                                }

                                Label {
                                    text: page.shell.metricValue(modelData.key)
                                    color: page.shell.primaryText
                                    font.pixelSize: 25
                                    font.weight: Font.DemiBold
                                }

                                Label {
                                    text: modelData.detail
                                    color: page.shell.mutedText
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        StatusBadge {
                            shell: page.shell
                            text: modelData.state
                            badgeColor: modelData.warning ? page.shell.warningColor : page.shell.successColor
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 980 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.shell.compactMode ? 380 : 410

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 1
                            Label {
                                text: "Cooling at a glance"
                                color: page.shell.primaryText
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: "Mock values follow the selected operating mode"
                                color: page.shell.mutedText
                                font.pixelSize: 12
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "Open cooling"
                            icon.name: "go-next"
                            onClicked: page.shell.navigate("cooling")
                        }
                    }

                    Repeater {
                        model: page.shell.coolingZones

                        delegate: AbstractButton {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: page.shell.compactMode ? 62 : 70
                            hoverEnabled: true
                            onClicked: page.shell.navigate("cooling")

                            background: Rectangle {
                                radius: Math.max(6, page.shell.cornerRadius - 4)
                                color: parent.hovered ? page.shell.surfaceHover : page.shell.surfaceAlt
                                border.color: page.shell.outline
                            }

                            contentItem: RowLayout {
                                spacing: 12

                                Kirigami.Icon {
                            source: modelData.icon
                                    color: page.shell.accentColor
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label {
                                        text: modelData.name
                                        color: page.shell.primaryText
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        text: modelData.source + " source · " + modelData.profile
                                        color: page.shell.mutedText
                                        font.pixelSize: 11
                                    }
                                }

                                Label {
                                    text: page.shell.zoneRpm(modelData.key)
                                    color: modelData.key === "case" && page.shell.activeMode !== "performance"
                                        ? page.shell.accentColor
                                        : page.shell.primaryText
                                    font.weight: Font.DemiBold
                                }

                                Kirigami.Icon {
                            source: "go-next"
                                    color: page.shell.mutedText
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                }
                            }
                        }
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.shell.compactMode ? 380 : 410

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 1
                            Label {
                                text: "Devices"
                                color: page.shell.primaryText
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: page.shell.devices.length + " mock devices · all available"
                                color: page.shell.mutedText
                                font.pixelSize: 12
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "View all"
                            icon.name: "go-next"
                            onClicked: page.shell.navigate("devices")
                        }
                    }

                    Repeater {
                        model: page.shell.devices.slice(0, 4)

                        delegate: AbstractButton {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: page.shell.compactMode ? 62 : 70
                            hoverEnabled: true
                            onClicked: page.shell.selectDevice(modelData.id)

                            background: Rectangle {
                                radius: Math.max(6, page.shell.cornerRadius - 4)
                                color: parent.hovered ? page.shell.surfaceHover : page.shell.surfaceAlt
                                border.color: page.shell.outline
                            }

                            contentItem: RowLayout {
                                spacing: 12

                                Kirigami.Icon {
                            source: modelData.icon
                                    color: page.shell.secondaryText
                                    Layout.preferredWidth: 27
                                    Layout.preferredHeight: 27
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label {
                                        text: modelData.name
                                        color: page.shell.primaryText
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        text: modelData.subtitle
                                        color: page.shell.mutedText
                                        font.pixelSize: 11
                                    }
                                }

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: page.shell.successColor
                                }
                            }
                        }
                    }
                }
            }

            Panel {
                shell: page.shell
                Layout.fillWidth: true

                Label {
                    text: "Quick actions"
                    color: page.shell.primaryText
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width > 900 ? 4 : 2
                    columnSpacing: page.shell.cardSpacing
                    rowSpacing: page.shell.cardSpacing

                    Repeater {
                        model: [
                            { label: "Quiet mode", detail: "Preview lower-noise values", icon: "weather-clear-night", action: "quiet" },
                            { label: "Lights out", detail: "Toggle the mock lighting state", icon: "brightness-low", action: "lights" },
                            { label: "Device inventory", detail: "Browse capability-aware devices", icon: "drive-multidisk", action: "devices" },
                            { label: "Review alerts", detail: "No current mock warnings", icon: "notifications", action: "alerts" }
                        ]

                        delegate: Button {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 78
                            text: modelData.label
                            icon.name: modelData.icon
                            onClicked: {
                                if (modelData.action === "quiet") page.shell.previewMode("quiet")
                                else if (modelData.action === "devices") page.shell.navigate("devices")
                                else if (modelData.action === "lights") {
                                    page.shell.lightsEnabled = !page.shell.lightsEnabled
                                    page.shell.showToast(
                                        page.shell.lightsEnabled ? "Lighting preview restored" : "Lighting preview disabled",
                                        "Only the mock interface changed."
                                    )
                                } else {
                                    page.shell.showToast("No active alerts", "All prototype devices report normal status.")
                                }
                            }

                            ToolTip.visible: hovered
                            ToolTip.text: modelData.detail
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 1 }
        }
    }
}
