import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Dialog {
    id: dialog

    required property var shell
    required property var availableDevices
    property var draftMembers: []
    readonly property int selectedCount: draftMembers.filter(member => member.selected).length
    readonly property int changedCount: draftMembers.filter(member => member.selected !== member.initialSelected).length

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(780, parent.width - 60)
    height: Math.min(720, parent.height - 60)
    modal: true
    title: "Edit RGB Cluster members"
    standardButtons: Dialog.Cancel

    function lightingEditorFor(device) {
        const tabs = device.tabs || []
        for (let index = 0; index < tabs.length; ++index) {
            if (tabs[index].name === "Lighting" && tabs[index].lightingEditor !== undefined) {
                return tabs[index].lightingEditor
            }
        }
        return null
    }

    function rebuildDraft() {
        const candidates = []
        const devices = availableDevices || []
        for (let index = 0; index < devices.length; ++index) {
            const device = devices[index]
            const lighting = lightingEditorFor(device)
            if (!lighting) continue
            const ownership = lighting.ownership || ({ controller: "individual" })
            const selected = ownership.controller === "rgb-cluster"
            candidates.push({
                key: device.id || device.name,
                name: device.name,
                icon: device.icon || "preferences-desktop-color",
                description: (lighting.targets || []).length + " lighting targets",
                controller: ownership.label || "Individual devices",
                selected: selected,
                initialSelected: selected,
                locked: ownership.controller === "openrgb"
            })
        }
        draftMembers = candidates
    }

    function setMemberSelected(index, selected) {
        if (index < 0 || index >= draftMembers.length || draftMembers[index].locked) return
        const updated = draftMembers.slice()
        const member = updated[index]
        updated[index] = {
            key: member.key,
            name: member.name,
            icon: member.icon,
            description: member.description,
            controller: member.controller,
            selected: selected,
            initialSelected: member.initialSelected,
            locked: member.locked
        }
        draftMembers = updated
    }

    function resetDraft() {
        const updated = []
        for (let index = 0; index < draftMembers.length; ++index) {
            const member = draftMembers[index]
            updated.push({
                key: member.key,
                name: member.name,
                icon: member.icon,
                description: member.description,
                controller: member.controller,
                selected: member.initialSelected,
                initialSelected: member.initialSelected,
                locked: member.locked
            })
        }
        draftMembers = updated
    }

    function openEditor() {
        rebuildDraft()
        open()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: shell.cardSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "view-grid"
                color: shell.accentColor
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: "Choose whole devices for synchronized lighting"
                    color: shell.primaryText
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Label {
                    text: "Attached channels follow their parent device; they are not separate Cluster members."
                    color: shell.mutedText
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            StatusBadge {
                shell: dialog.shell
                text: dialog.selectedCount + " selected"
                badgeColor: shell.accentColor
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: shell.outline }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: 8

                Repeater {
                    model: dialog.draftMembers
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: memberRow.implicitHeight + 24
                        radius: shell.cornerRadius
                        color: modelData.selected ? shell.surfaceAlt : "transparent"
                        border.color: modelData.selected ? shell.accentColor : shell.outline

                        RowLayout {
                            id: memberRow
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Kirigami.Icon {
                                source: modelData.icon
                                color: modelData.locked ? shell.mutedText : shell.accentColor
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label {
                                    text: modelData.name
                                    color: shell.primaryText
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    text: modelData.description + " · Current: " + modelData.controller
                                    color: shell.mutedText
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                            StatusBadge {
                                visible: modelData.locked
                                shell: dialog.shell
                                text: "Owned by OpenRGB"
                                badgeColor: shell.warningColor
                            }
                            CheckBox {
                                checked: modelData.selected
                                enabled: !modelData.locked
                                Accessible.name: "Include " + modelData.name + " in RGB Cluster"
                                onToggled: dialog.setMemberSelected(index, checked)
                            }
                        }
                    }
                }

                Label {
                    visible: dialog.draftMembers.length === 0
                    Layout.fillWidth: true
                    text: "No lighting-capable devices are currently published."
                    color: shell.mutedText
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: shell.outline }

        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: dialog.changedCount === 0
                    ? "No membership changes drafted."
                    : dialog.changedCount + " membership changes drafted locally."
                color: shell.mutedText
            }
            Button {
                text: "Reset draft"
                icon.name: "edit-undo"
                enabled: dialog.changedCount > 0
                onClicked: dialog.resetDraft()
            }
            Button {
                text: "Apply membership"
                icon.name: "dialog-ok-apply"
                enabled: false
                ToolTip.visible: hovered
                ToolTip.text: "No Cluster membership command is connected in this checkpoint."
            }
        }
    }
}
