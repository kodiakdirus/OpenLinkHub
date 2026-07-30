import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page

    required property var shell
    property int selectedScene: 0
    property int brightnessValue: 70

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: page.shell.sectionSpacing

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 2
                    Label {
                        text: "Lighting scenes"
                        color: page.shell.primaryText
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: "Coordinate compatible devices without hiding device-specific zones"
                        color: page.shell.mutedText
                    }
                }

                Item { Layout.fillWidth: true }

                Switch {
                    text: page.shell.lightsEnabled ? "Lighting on" : "Lighting off"
                    checked: page.shell.lightsEnabled
                    onToggled: {
                        page.shell.lightsEnabled = checked
                        page.shell.markDirty("Global lighting")
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 1000 ? 4 : width > 620 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Repeater {
                    model: [
                        { name: "Aurora", colors: ["#36d6c7", "#766bf0", "#274d9a"], detail: "Slow gradient" },
                        { name: "Static cyan", colors: ["#66d7c5", "#66d7c5", "#66d7c5"], detail: "Single color" },
                        { name: "Temperature", colors: ["#3fd076", "#f1c453", "#e45d64"], detail: "Sensor reactive" },
                        { name: "Lights out", colors: ["#1d252b", "#12181d", "#090d10"], detail: "All zones off" }
                    ]

                    delegate: AbstractButton {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        hoverEnabled: true
                        onClicked: {
                            page.selectedScene = index
                            page.shell.markDirty("Lighting scene")
                        }

                        background: Rectangle {
                            radius: page.shell.cornerRadius
                            color: page.selectedScene === index ? page.shell.surfaceHover : page.shell.surface
                            border.width: page.selectedScene === index ? 2 : 1
                            border.color: page.selectedScene === index ? page.shell.accentColor : page.shell.outline
                        }

                        contentItem: ColumnLayout {
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: Math.max(6, page.shell.cornerRadius - 4)
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: modelData.colors[0] }
                                    GradientStop { position: 0.5; color: modelData.colors[1] }
                                    GradientStop { position: 1.0; color: modelData.colors[2] }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label {
                                        text: modelData.name
                                        color: page.shell.primaryText
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        text: modelData.detail
                                        color: page.shell.mutedText
                                        font.pixelSize: 11
                                    }
                                }
                                Kirigami.Icon {
                            visible: page.selectedScene === index
                                    source: "dialog-ok"
                                    color: page.shell.accentColor
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                }
                            }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 920 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true

                    Label {
                        text: "Scene controls"
                        color: page.shell.primaryText
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Brightness",
                            description: "All selected targets",
                            kind: "slider",
                            value: page.brightnessValue,
                            from: 0,
                            to: 100,
                            unit: "%"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Animation speed",
                            description: "Scene-wide timing",
                            kind: "slider",
                            value: 42,
                            from: 0,
                            to: 100,
                            unit: "%"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        showDivider: false
                        feature: ({
                            title: "Primary colors",
                            description: "Select a mock palette",
                            kind: "color",
                            choices: ["#66d7c5", "#8b7cf6", "#ef8b6b", "#f0c75e"]
                        })
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true

                    Label {
                        text: "Targets"
                        color: page.shell.primaryText
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    Repeater {
                        model: [
                            { title: "iCUE LINK System Hub", description: "6 fan zones + pump", kind: "toggle", value: true },
                            { title: "K100 AIR RGB", description: "Per-key surface", kind: "toggle", value: true },
                            { title: "Scimitar RGB Elite", description: "4 lighting zones", kind: "toggle", value: true },
                            { title: "Hardware lighting", description: "Used when the service is unavailable", kind: "toggle", value: false }
                        ]

                        delegate: ControlRow {
                            required property var modelData
                            required property int index
                            shell: page.shell
                            feature: modelData
                            showDivider: index < 3
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Panel {
                shell: page.shell
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    Kirigami.Icon {
                            source: "applications-engineering"
                        color: page.shell.accentColor
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Advanced lighting remains discoverable"
                            color: page.shell.primaryText
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: "Per-LED editing, RGB clusters, temperature thresholds, gradients, strips, adapters, and OpenRGB appear here rather than in a hidden miscellaneous page."
                            color: page.shell.mutedText
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    Button {
                        text: "Explore advanced"
                        onClicked: page.shell.showToast(
                            "Advanced lighting",
                            "The prototype would open the complete source-derived lighting inventory."
                        )
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Revert"
                    enabled: page.shell.pendingChanges
                    onClicked: page.shell.revertChanges()
                }
                Button {
                    text: page.shell.pendingChanges ? "Apply scene" : "No pending changes"
                    icon.name: "dialog-ok-apply"
                    highlighted: true
                    enabled: page.shell.pendingChanges
                    onClicked: page.shell.applyChanges()
                }
            }

            Item { Layout.preferredHeight: 1 }
        }
    }
}
