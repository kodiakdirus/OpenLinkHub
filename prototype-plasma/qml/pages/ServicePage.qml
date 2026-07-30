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

            Panel {
                shell: page.shell
                Layout.fillWidth: true
                color: Qt.rgba(page.shell.warningColor.r, page.shell.warningColor.g, page.shell.warningColor.b, 0.08)
                border.color: Qt.rgba(page.shell.warningColor.r, page.shell.warningColor.g, page.shell.warningColor.b, 0.45)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Kirigami.Icon {
                            source: "network-disconnect"
                        color: page.shell.warningColor
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: "Prototype mode — no backend connection"
                            color: page.shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "This process has no networking code. Controls change local QML state only and reset when the window closes."
                            color: page.shell.secondaryText
                            wrapMode: Text.WordWrap
                        }
                    }

                    StatusBadge {
                        shell: page.shell
                        text: "0 API calls"
                        badgeColor: page.shell.successColor
                        filled: true
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 1000 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Icon {
                            source: "preferences-desktop-theme"
                            color: page.shell.accentColor
                            Layout.preferredWidth: 27
                            Layout.preferredHeight: 27
                        }
                        ColumnLayout {
                            spacing: 1
                            Label {
                                text: "Appearance"
                                color: page.shell.primaryText
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: "Constrained customization preserves navigation"
                                color: page.shell.mutedText
                                font.pixelSize: 12
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: page.shell.outline
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Theme"
                            color: page.shell.primaryText
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        ComboBox {
                            model: ["Dark", "Dim", "Light"]
                            currentIndex: model.indexOf(page.shell.themeMode)
                            Layout.preferredWidth: 180
                            onActivated: page.shell.themeMode = currentText
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Accent"
                            color: page.shell.primaryText
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        Repeater {
                            model: ["#66d7c5", "#7aa8ff", "#a98cf5", "#ee876f", "#e8bd57"]
                            delegate: AbstractButton {
                                required property var modelData
                                implicitWidth: 32
                                implicitHeight: 32
                                onClicked: page.shell.accentColor = modelData
                                background: Rectangle {
                                    radius: width / 2
                                    color: modelData
                                    border.width: page.shell.accentColor.toString() === modelData ? 3 : 1
                                    border.color: page.shell.accentColor.toString() === modelData
                                        ? page.shell.primaryText
                                        : page.shell.outline
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Interface density"
                            color: page.shell.primaryText
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        ComboBox {
                            model: ["Comfortable", "Compact"]
                            currentIndex: page.shell.compactMode ? 1 : 0
                            Layout.preferredWidth: 180
                            onActivated: page.shell.compactMode = currentIndex === 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Corner radius"
                            color: page.shell.primaryText
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        Slider {
                            from: 4
                            to: 18
                            stepSize: 1
                            value: page.shell.cornerRadius
                            Layout.preferredWidth: 180
                            onMoved: page.shell.cornerRadius = Math.round(value)
                        }
                        Label {
                            text: page.shell.cornerRadius + " px"
                            color: page.shell.accentColor
                            Layout.preferredWidth: 42
                        }
                    }

                    Switch {
                        text: "Show sidebar labels"
                        checked: page.shell.sidebarLabels
                        onToggled: page.shell.sidebarLabels = checked
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Icon {
                            source: "view-grid"
                            color: page.shell.accentColor
                            Layout.preferredWidth: 27
                            Layout.preferredHeight: 27
                        }
                        ColumnLayout {
                            spacing: 1
                            Label {
                                text: "Layout"
                                color: page.shell.primaryText
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: "Customize presentation without losing hierarchy"
                                color: page.shell.mutedText
                                font.pixelSize: 12
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: page.shell.outline
                    }

                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Overview density",
                            description: "Number of dashboard columns",
                            kind: "choice",
                            value: "Adaptive",
                            choices: ["Adaptive", "Two columns", "Single column"]
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Temperature units",
                            description: "Applied throughout the client",
                            kind: "choice",
                            value: "Celsius",
                            choices: ["Celsius", "Fahrenheit"]
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Dashboard widgets",
                            description: "Reorder approved overview regions",
                            kind: "action",
                            value: "Customize",
                            icon: "configure"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        showDivider: false
                        feature: ({
                            title: "Reset presentation",
                            description: "Restore the prototype defaults",
                            kind: "action",
                            value: "Reset",
                            icon: "edit-undo",
                            actionText: "Close and reopen the prototype to restore all defaults."
                        })
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    Label {
                        text: "Future service connection"
                        color: page.shell.primaryText
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Shown for architecture review only. The controls are intentionally disabled in this build."
                        color: page.shell.mutedText
                        wrapMode: Text.WordWrap
                    }

                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Endpoint",
                            description: "Loopback-only production default",
                            kind: "stat",
                            value: "127.0.0.1:27003"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Connection",
                            description: "No socket is opened",
                            kind: "stat",
                            value: "Disabled"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        showDivider: false
                        feature: ({
                            title: "API operations",
                            description: "Lifetime of this process",
                            kind: "stat",
                            value: "0"
                        })
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    Label {
                        text: "Service feature map"
                        color: page.shell.primaryText
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "These administration areas remain visible in the information architecture even though this prototype cannot execute them."
                        color: page.shell.mutedText
                        wrapMode: Text.WordWrap
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 7
                        Repeater {
                            model: [
                                "Health", "Logs", "Backups", "Updates", "Permissions",
                                "Supported devices", "Language", "Metrics", "Listener", "Sensor sources"
                            ]
                            delegate: StatusBadge {
                                required property var modelData
                                shell: page.shell
                                text: modelData
                                badgeColor: page.shell.mutedText
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 1 }
        }
    }
}
