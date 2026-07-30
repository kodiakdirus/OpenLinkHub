import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page

    required property var shell

    function openPrimaryDialog() {
        sensorDialog.open()
    }

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
                color: Qt.rgba(page.shell.accentColor.r, page.shell.accentColor.g, page.shell.accentColor.b, 0.07)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 54
                        radius: 15
                        color: Qt.rgba(page.shell.accentColor.r, page.shell.accentColor.g, page.shell.accentColor.b, 0.14)

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 31
                            height: 31
                            source: "network-connect"
                            color: page.shell.accentColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: "Integrations"
                            color: page.shell.primaryText
                            font.pixelSize: 21
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "Make OpenLinkHub telemetry and controls useful elsewhere without hiding ownership boundaries."
                            color: page.shell.mutedText
                            wrapMode: Text.WordWrap
                        }
                    }

                    StatusBadge {
                        shell: page.shell
                        text: "Interactive mock"
                        badgeColor: page.shell.accentColor
                        filled: true
                    }
                }
            }

            GridLayout {
                id: integrationGrid
                Layout.fillWidth: true
                columns: width > 1020 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.columnSpan: integrationGrid.columns

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Kirigami.Icon {
                            source: "utilities-system-monitor"
                            color: page.shell.accentColor
                            Layout.preferredWidth: 29
                            Layout.preferredHeight: 29
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Label {
                                text: "Plasma System Monitor"
                                color: page.shell.primaryText
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "Expose coolant, pump, fan, battery, and other Corsair telemetry as native desktop sensors."
                                color: page.shell.mutedText
                                wrapMode: Text.WordWrap
                            }
                        }

                        StatusBadge {
                            shell: page.shell
                            text: "Prototype concept"
                            badgeColor: page.shell.warningColor
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: page.shell.outline
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width > 760 ? 4 : 2
                        columnSpacing: page.shell.cardSpacing
                        rowSpacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { text: "Provider"; color: page.shell.mutedText; font.pixelSize: 12 }
                            Label { text: "KSystemStats"; color: page.shell.primaryText; font.weight: Font.DemiBold }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { text: "Namespace"; color: page.shell.mutedText; font.pixelSize: 12 }
                            Label { text: "openlinkhub/…"; color: page.shell.primaryText; font.weight: Font.DemiBold }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { text: "Selected"; color: page.shell.mutedText; font.pixelSize: 12 }
                            Label { text: "7 sensors"; color: page.shell.primaryText; font.weight: Font.DemiBold }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { text: "Refresh"; color: page.shell.mutedText; font.pixelSize: 12 }
                            Label { text: "1 second"; color: page.shell.primaryText; font.weight: Font.DemiBold }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Switch {
                            text: "Expose sensors to Plasma"
                            checked: true
                            onToggled: page.shell.markDirty("Plasma sensor provider")
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "Configure sensors"
                            icon.name: "configure"
                            onClicked: sensorDialog.open()
                        }
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Icon {
                            source: "preferences-desktop"
                            color: page.shell.accentColor
                            Layout.preferredWidth: 25
                            Layout.preferredHeight: 25
                        }
                        Label {
                            text: "Desktop integration"
                            color: page.shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                    }

                    ControlRow {
                        shell: page.shell
                        feature: ({ title: "System tray", description: "Profiles and connection status", kind: "toggle", value: true })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({ title: "Notifications", description: "Warnings and state changes", kind: "toggle", value: true })
                    }
                    ControlRow {
                        shell: page.shell
                        showDivider: false
                        feature: ({ title: "Media controls", description: "MPRIS playback integration", kind: "toggle", value: true })
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Icon {
                            source: "network-connect"
                            color: page.shell.accentColor
                            Layout.preferredWidth: 25
                            Layout.preferredHeight: 25
                        }
                        Label {
                            text: "External services"
                            color: page.shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                    }

                    ControlRow {
                        shell: page.shell
                        feature: ({ title: "OpenRGB", description: "External RGB target", kind: "toggle", value: false })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({ title: "Prometheus metrics", description: "Machine-readable telemetry", kind: "toggle", value: false })
                    }
                    ControlRow {
                        shell: page.shell
                        showDivider: false
                        feature: ({ title: "API explorer", description: "Developer-facing endpoint inspector", kind: "action", value: "Explore", icon: "applications-development" })
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.columnSpan: integrationGrid.columns
                    color: page.shell.surfaceAlt

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Kirigami.Icon {
                            source: "security-high"
                            color: page.shell.accentColor
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: "One hardware owner, many read-only consumers"
                                color: page.shell.primaryText
                                font.weight: Font.DemiBold
                            }
                            Label {
                                Layout.fillWidth: true
                                text: "OpenLinkHub remains responsible for devices and validated telemetry. A desktop provider only republishes readings for System Monitor widgets, graphs, and alerts."
                                color: page.shell.mutedText
                                wrapMode: Text.WordWrap
                            }
                        }
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
                    text: page.shell.pendingChanges ? "Apply preview" : "No pending changes"
                    icon.name: "dialog-ok-apply"
                    highlighted: true
                    enabled: page.shell.pendingChanges
                    onClicked: page.shell.applyChanges()
                }
            }

            Item { Layout.preferredHeight: 1 }
        }
    }

    SensorExportDialog {
        id: sensorDialog
        shell: page.shell
    }
}
