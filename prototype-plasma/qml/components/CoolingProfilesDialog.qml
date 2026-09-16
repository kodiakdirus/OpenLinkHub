import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Dialog {
    id: dialog

    required property var shell
    property int selectedProfile: 0
    property var profileNames: [
        "Radiator 20",
        "GPU Quiet",
        "TITAN Balanced",
        "Quiet",
        "Balanced",
        "Performance"
    ]
    property var points: [
        { temperature: 30, output: 20 },
        { temperature: 38, output: 25 },
        { temperature: 42, output: 45 },
        { temperature: 48, output: 75 },
        { temperature: 55, output: 100 }
    ]

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(940, parent.width - 60)
    height: Math.min(720, parent.height - 60)
    modal: true
    title: "Cooling profile manager"
    standardButtons: Dialog.Save | Dialog.Cancel

    onOpened: {
        editorName.text = profileNames[selectedProfile]
    }

    onAccepted: {
        const name = editorName.text.trim().length > 0
            ? editorName.text.trim()
            : "Untitled cooling profile"
        if (profileNames.indexOf(name) < 0) {
            profileNames = profileNames.concat([name])
            selectedProfile = profileNames.length - 1
        }
        shell.markDirty("Cooling profile library")
        shell.showToast(
            "Cooling profile saved locally",
            "The curve exists only in this prototype and no fan or pump command was sent."
        )
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: shell.cardSpacing

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: shell.cornerRadius
            color: Qt.rgba(shell.accentColor.r, shell.accentColor.g, shell.accentColor.b, 0.08)
            border.color: shell.outline

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14

                Kirigami.Icon {
                    source: "temperature-normal"
                    color: shell.accentColor
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                }
                Label {
                    Layout.fillWidth: true
                    text: "Cooling profiles are reusable temperature-to-output curves. Global profiles reference them; they are not global profiles themselves."
                    color: shell.secondaryText
                    wrapMode: Text.WordWrap
                }
                StatusBadge {
                    shell: dialog.shell
                    text: "Mock editor"
                    badgeColor: shell.warningColor
                    filled: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: shell.cardSpacing

            Rectangle {
                Layout.preferredWidth: 245
                Layout.fillHeight: true
                radius: shell.cornerRadius
                color: shell.surfaceAlt
                border.color: shell.outline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: shell.contentPadding
                    spacing: 10

                    Label {
                        text: "Cooling profiles"
                        color: shell.primaryText
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }

                    ListView {
                        id: profileList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 5
                        clip: true
                        model: dialog.profileNames

                        delegate: ItemDelegate {
                            required property var modelData
                            required property int index
                            width: profileList.width
                            text: modelData
                            highlighted: dialog.selectedProfile === index
                            icon.name: index < 3 ? "favorite" : "document-edit"
                            onClicked: {
                                dialog.selectedProfile = index
                                editorName.text = modelData
                                sourceCombo.currentIndex = index === 1 ? 1 : 0
                                targetCombo.currentIndex = index === 2 ? 1 : 0
                                zeroRpm.checked = index === 1
                            }
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: "New cooling profile"
                        icon.name: "list-add"
                        onClicked: {
                            dialog.selectedProfile = -1
                            editorName.text = "New cooling profile"
                            sourceCombo.currentIndex = 0
                            targetCombo.currentIndex = 0
                            zeroRpm.checked = false
                            editorName.forceActiveFocus()
                            editorName.selectAll()
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: "Duplicate selected"
                        icon.name: "edit-copy"
                        onClicked: {
                            editorName.text = editorName.text + " copy"
                            dialog.selectedProfile = -1
                        }
                    }
                }
            }

            ScrollView {
                id: editorScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: editorScroll.availableWidth
                    spacing: shell.cardSpacing

                    Label {
                        text: "Curve editor"
                        color: shell.primaryText
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: shell.cardSpacing
                        rowSpacing: 8

                        Label { text: "Name"; color: shell.secondaryText }
                        TextField {
                            id: editorName
                            Layout.fillWidth: true
                        }

                        Label { text: "Sensor source"; color: shell.secondaryText }
                        ComboBox {
                            id: sourceCombo
                            Layout.fillWidth: true
                            model: [
                                "Coolant temperature",
                                "GPU temperature",
                                "CPU temperature",
                                "Temperature probe",
                                "Storage temperature",
                                "External hwmon sensor"
                            ]
                        }

                        Label { text: "Target type"; color: shell.secondaryText }
                        ComboBox {
                            id: targetCombo
                            Layout.fillWidth: true
                            model: ["Fan", "Pump"]
                            onActivated: {
                                if (currentIndex === 1) zeroRpm.checked = false
                            }
                        }

                        Label { text: "Curve behavior"; color: shell.secondaryText }
                        RowLayout {
                            Switch {
                                id: zeroRpm
                                text: "Allow zero RPM"
                                enabled: targetCombo.currentIndex === 0
                            }
                            CheckBox {
                                text: "Interpolate points"
                                checked: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 115
                        radius: shell.cornerRadius
                        color: shell.surfaceAlt
                        border.color: shell.outline

                        CoolingCurve {
                            anchors.fill: parent
                            anchors.margins: 18
                            accentColor: shell.accentColor
                            gridColor: shell.outline
                            intensity: 0.72
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Curve points"
                            color: shell.primaryText
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        Label {
                            text: "Temperature"
                            color: shell.mutedText
                            font.pixelSize: 11
                        }
                        Label {
                            text: "Output"
                            color: shell.mutedText
                            font.pixelSize: 11
                            Layout.rightMargin: 44
                        }
                    }

                    Repeater {
                        model: dialog.points

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: Math.max(5, shell.cornerRadius - 4)
                            color: shell.surfaceAlt
                            border.color: shell.outline

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 12

                                Label {
                                    text: "Point " + (index + 1)
                                    color: shell.secondaryText
                                    Layout.fillWidth: true
                                }
                                SpinBox {
                                    from: 0
                                    to: 110
                                    value: modelData.temperature
                                    editable: true
                                    textFromValue: value => value + "°C"
                                    valueFromText: text => parseInt(text)
                                }
                                SpinBox {
                                    from: 0
                                    to: 100
                                    value: modelData.output
                                    editable: true
                                    textFromValue: value => value + "%"
                                    valueFromText: text => parseInt(text)
                                }
                                ToolButton {
                                    icon.name: "edit-delete"
                                    enabled: dialog.points.length > 2
                                    onClicked: shell.showToast(
                                        "Curve point removed",
                                        "The visual preview keeps a fixed five-point sample in this prototype."
                                    )
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "Add curve point"
                            icon.name: "list-add"
                            onClicked: shell.showToast(
                                "Curve point added",
                                "A production editor would insert a draggable point in temperature order."
                            )
                        }
                        Item { Layout.fillWidth: true }
                        StatusBadge {
                            shell: dialog.shell
                            text: zeroRpm.checked ? "Zero RPM allowed" : "Minimum output enforced"
                            badgeColor: zeroRpm.checked ? shell.accentColor : shell.mutedText
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: shell.outline
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Icon {
                            source: "security-high"
                            color: shell.successColor
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "Device minimums and critical-coolant protection remain service-owned constraints in a production client."
                            color: shell.mutedText
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
