import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page

    required property var shell

    function openPrimaryDialog() {
        coolingProfiles.open()
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

                ColumnLayout {
                    spacing: 2
                    Label {
                        text: "Cooling channels"
                        color: page.shell.primaryText
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: "iCUE LINK System Hub · values are simulated"
                        color: page.shell.mutedText
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Manage cooling profiles"
                    icon.name: "document-edit"
                    highlighted: true
                    onClicked: coolingProfiles.open()
                }

                ComboBox {
                    model: ["iCUE LINK System Hub", "TITAN 360 LCD"]
                    Layout.preferredWidth: 245
                    onActivated: page.shell.showToast(
                        "Cooling device changed",
                        "The selected mock device is now " + currentText + "."
                    )
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 850 ? 3 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Repeater {
                    model: [
                        { label: "Coolant", value: page.shell.metricValue("coolant"), icon: "temperature-normal" },
                        { label: "Pump", value: page.shell.zoneRpm("pump"), icon: "media-playback-start" },
                        { label: "Fans", value: "6 channels", icon: "temperature-normal" }
                    ]

                    delegate: Panel {
                        required property var modelData
                        shell: page.shell
                        Layout.fillWidth: true

                        RowLayout {
                            Layout.fillWidth: true
                            Kirigami.Icon {
                            source: modelData.icon
                                color: page.shell.accentColor
                                Layout.preferredWidth: 25
                                Layout.preferredHeight: 25
                            }
                            ColumnLayout {
                                spacing: 1
                                Label {
                                    text: modelData.label
                                    color: page.shell.mutedText
                                    font.pixelSize: 12
                                }
                                Label {
                                    text: modelData.value
                                    color: page.shell.primaryText
                                    font.pixelSize: 20
                                    font.weight: Font.DemiBold
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            Panel {
                shell: page.shell
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Kirigami.Icon {
                        source: "office-chart-line"
                        color: page.shell.accentColor
                        Layout.preferredWidth: 27
                        Layout.preferredHeight: 27
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: "Cooling profile library"
                            color: page.shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: "Create reusable fan and pump curves, then assign them to channels below."
                            color: page.shell.mutedText
                            font.pixelSize: 12
                        }
                    }

                    Flow {
                        spacing: 6
                        StatusBadge {
                            shell: page.shell
                            text: "Radiator 20"
                            badgeColor: page.shell.accentColor
                        }
                        StatusBadge {
                            shell: page.shell
                            text: "GPU Quiet"
                            badgeColor: page.shell.accentColor
                        }
                        StatusBadge {
                            shell: page.shell
                            text: "TITAN Balanced"
                            badgeColor: page.shell.accentColor
                        }
                    }

                    Button {
                        text: "Open curve editor"
                        icon.name: "document-edit"
                        onClicked: coolingProfiles.open()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: page.shell.cardSpacing
                Layout.alignment: Qt.AlignTop

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: page.shell.cardSpacing

                    Repeater {
                        model: page.shell.coolingZones

                        delegate: Panel {
                            id: channelCard
                            required property var modelData
                            property bool expanded: false
                            shell: page.shell
                            Layout.fillWidth: true

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Rectangle {
                                    Layout.preferredWidth: 54
                                    Layout.preferredHeight: 54
                                    radius: 14
                                    color: page.shell.surfaceAlt
                                    border.color: page.shell.outline

                                    Kirigami.Icon {
                            anchors.centerIn: parent
                                        width: 30
                                        height: 30
                                        source: modelData.icon
                                        color: page.shell.secondaryText
                                    }
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 150
                                    spacing: 2
                                    Label {
                                        text: modelData.name
                                        color: page.shell.primaryText
                                        font.pixelSize: 17
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        text: modelData.temperature + " · " + modelData.source
                                        color: page.shell.mutedText
                                        font.pixelSize: 12
                                    }
                                    Label {
                                        text: page.shell.zoneRpm(modelData.key)
                                        color: page.shell.accentColor
                                        font.weight: Font.DemiBold
                                    }
                                }

                                ComboBox {
                                    model: modelData.profiles || [modelData.profile]
                                    currentIndex: Math.max(0, model.indexOf(modelData.profile))
                                    Layout.preferredWidth: 160
                                    enabled: !page.shell.liveMode
                                    onActivated: page.shell.markDirty(modelData.name + " profile")
                                    ToolTip.visible: hovered && page.shell.liveMode
                                    ToolTip.text: "Read-only in Phase 1"
                                }

                                CoolingCurve {
                                    visible: channelCard.width > 690
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 150
                                    Layout.maximumWidth: 250
                                    accentColor: page.shell.accentColor
                                    gridColor: page.shell.outline
                                    intensity: modelData.key === "pump" ? 0.9 : modelData.key === "case" ? 0.45 : 0.7
                                }

                                Item { Layout.fillWidth: true }

                                StatusBadge {
                                    visible: modelData.zeroRpm
                                    shell: page.shell
                                    text: "Zero RPM"
                                    badgeColor: page.shell.accentColor
                                }

                                ToolButton {
                                    icon.name: channelCard.expanded ? "arrow-up" : "arrow-down"
                                    onClicked: channelCard.expanded = !channelCard.expanded
                                    ToolTip.visible: hovered
                                    ToolTip.text: channelCard.expanded ? "Hide channel details" : "Show channel details"
                                }
                            }

                            Rectangle {
                                visible: channelCard.expanded
                                Layout.fillWidth: true
                                height: 1
                                color: page.shell.outline
                            }

                            GridLayout {
                                visible: channelCard.expanded
                                Layout.fillWidth: true
                                columns: width > 620 ? 3 : 1
                                columnSpacing: 20

                                ColumnLayout {
                                    Label {
                                        text: "Minimum output"
                                        color: page.shell.mutedText
                                        font.pixelSize: 12
                                    }
                                    Slider {
                                        from: 0
                                        to: 100
                                        value: modelData.minimum
                                        Layout.fillWidth: true
                                        onMoved: page.shell.markDirty(modelData.name + " minimum")
                                    }
                                }

                                ColumnLayout {
                                    Label {
                                        text: "Sensor source"
                                        color: page.shell.mutedText
                                        font.pixelSize: 12
                                    }
                                    ComboBox {
                                        model: ["Coolant temperature", "GPU temperature", "CPU temperature", "Temperature probe"]
                                        currentIndex: modelData.source.indexOf("GPU") >= 0 ? 1 : 0
                                        Layout.fillWidth: true
                                        onActivated: page.shell.markDirty(modelData.name + " sensor")
                                    }
                                }

                                ColumnLayout {
                                    Label {
                                        text: "Channel behavior"
                                        color: page.shell.mutedText
                                        font.pixelSize: 12
                                    }
                                    Switch {
                                        text: "Allow zero RPM"
                                        checked: modelData.zeroRpm
                                        enabled: modelData.key !== "pump"
                                        onToggled: page.shell.markDirty(modelData.name + " zero RPM")
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Revert"
                            enabled: page.shell.pendingChanges
                            onClicked: page.shell.revertChanges()
                        }
                        Button {
                            text: page.shell.pendingChanges ? "Apply changes" : "No pending changes"
                            icon.name: "dialog-ok-apply"
                            enabled: page.shell.pendingChanges
                            highlighted: true
                            onClicked: page.shell.applyChanges()
                        }
                    }
                }

                ColumnLayout {
                    visible: page.width > 970
                    Layout.preferredWidth: 315
                    Layout.alignment: Qt.AlignTop
                    spacing: page.shell.cardSpacing

                    Panel {
                        shell: page.shell
                        Layout.fillWidth: true
                        color: Qt.rgba(page.shell.successColor.r, page.shell.successColor.g, page.shell.successColor.b, 0.10)
                        border.color: Qt.rgba(page.shell.successColor.r, page.shell.successColor.g, page.shell.successColor.b, 0.45)

                        RowLayout {
                            Layout.fillWidth: true
                            Kirigami.Icon {
                            source: "security-high"
                                color: page.shell.successColor
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                            }
                            ColumnLayout {
                                spacing: 1
                                Label {
                                    text: "Coolant protection"
                                    color: page.shell.secondaryText
                                }
                                Label {
                                    text: "Armed"
                                    color: page.shell.successColor
                                    font.pixelSize: 21
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "Independent critical-temperature override"
                            color: page.shell.mutedText
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }

                    Panel {
                        shell: page.shell
                        Layout.fillWidth: true

                        Label {
                            text: "Safety & sources"
                            color: page.shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }

                        ControlRow {
                            shell: page.shell
                            feature: ({
                                title: "Control source",
                                description: "Primary curve input",
                                kind: "choice",
                                value: "Coolant temperature",
                                choices: ["Coolant temperature", "CPU temperature", "GPU temperature"]
                            })
                        }
                        ControlRow {
                            shell: page.shell
                            feature: ({
                                title: "Zero RPM threshold",
                                description: "Case airflow only",
                                kind: "stat",
                                value: "35°C"
                            })
                        }
                        ControlRow {
                            shell: page.shell
                            feature: ({
                                title: "Failsafe",
                                description: "Critical override output",
                                kind: "stat",
                                value: "100%"
                            })
                        }
                        ControlRow {
                            shell: page.shell
                            showDivider: false
                            feature: ({
                                title: "Live graph",
                                description: "Open mock temperature history",
                                kind: "action",
                                value: "Open",
                                icon: "office-chart-line"
                            })
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 1 }
        }
    }

    CoolingProfilesDialog {
        id: coolingProfiles
        shell: page.shell
    }
}
