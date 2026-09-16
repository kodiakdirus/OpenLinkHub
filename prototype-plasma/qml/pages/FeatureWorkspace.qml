import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page

    required property var shell
    property string workspaceTitle: ""
    property string workspaceSubtitle: ""
    property string workspaceIcon: "applications-system"
    property var groups: []
    property var arrangedGroups: []
    property bool layoutEditing: false
    readonly property string layoutKey: "workspace:" + workspaceTitle

    function resetLayout() {
        arrangedGroups = shell.arrangeSavedGroups(layoutKey, (groups || []).map(group => ({
            key: group.title,
            title: group.title,
            icon: group.icon,
            description: group.description,
            badge: group.badge,
            experimental: group.experimental,
            items: group.items,
            wide: Boolean(group.wide)
        })))
    }

    function openLayoutEditor() {
        layoutEditing = true
    }

    function moveGroup(index, delta) {
        const destination = index + delta
        if (destination < 0 || destination >= arrangedGroups.length) return
        const updated = arrangedGroups.slice()
        const moved = updated[index]
        updated[index] = updated[destination]
        updated[destination] = moved
        arrangedGroups = updated
        shell.saveGroupLayout(layoutKey, arrangedGroups)
    }

    function toggleGroupWidth(index) {
        const updated = arrangedGroups.slice()
        const current = updated[index]
        updated[index] = {
            key: current.key,
            title: current.title,
            icon: current.icon,
            description: current.description,
            badge: current.badge,
            experimental: current.experimental,
            items: current.items,
            wide: !current.wide
        }
        arrangedGroups = updated
        shell.saveGroupLayout(layoutKey, arrangedGroups)
    }

    onGroupsChanged: resetLayout()
    Component.onCompleted: resetLayout()
    Connections {
        target: page.shell
        function onPresentationReset() { page.resetLayout() }
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
                            source: page.workspaceIcon
                            color: page.shell.accentColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: page.workspaceTitle
                            color: page.shell.primaryText
                            font.pixelSize: 21
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: page.workspaceSubtitle
                            color: page.shell.mutedText
                            wrapMode: Text.WordWrap
                        }
                    }

                    Button {
                        text: page.layoutEditing ? "Done arranging" : "Arrange cells"
                        icon.name: page.layoutEditing ? "dialog-ok" : "transform-move"
                        onClicked: page.layoutEditing = !page.layoutEditing
                    }

                    StatusBadge {
                        shell: page.shell
                        text: "Interactive mock"
                        badgeColor: page.shell.accentColor
                        filled: true
                    }
                }
            }

            Panel {
                visible: page.layoutEditing
                shell: page.shell
                Layout.fillWidth: true
                color: page.shell.surfaceAlt

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Kirigami.Icon {
                        source: "view-grid"
                        color: page.shell.accentColor
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "Layout rule: cells snap to an ordered one- or two-column grid. Half-width neighbors share equal row height; cells may span the full row, but arbitrary placement is not allowed."
                        color: page.shell.secondaryText
                        wrapMode: Text.WordWrap
                    }
                    Button {
                        text: "Reset layout"
                        icon.name: "edit-undo"
                        onClicked: {
                            page.shell.saveLayout(page.layoutKey, {})
                            page.resetLayout()
                        }
                    }
                }
            }

            GridLayout {
                id: workspaceGrid
                Layout.fillWidth: true
                columns: width > 1020 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Repeater {
                    model: page.arrangedGroups

                    delegate: Panel {
                        required property var modelData
                        required property int index
                        shell: page.shell
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.columnSpan: modelData.wide ? workspaceGrid.columns : 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Kirigami.Icon {
                            source: modelData.icon || page.workspaceIcon
                                color: page.shell.accentColor
                                Layout.preferredWidth: 25
                                Layout.preferredHeight: 25
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label {
                                    text: modelData.title
                                    color: page.shell.primaryText
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    visible: text.length > 0
                                    text: modelData.description || ""
                                    color: page.shell.mutedText
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                visible: page.layoutEditing
                                spacing: 2

                                Button {
                                    text: "←"
                                    implicitWidth: 32
                                    enabled: index > 0
                                    onClicked: page.moveGroup(index, -1)
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Move cell earlier"
                                }
                                Button {
                                    text: "→"
                                    implicitWidth: 32
                                    enabled: index < page.arrangedGroups.length - 1
                                    onClicked: page.moveGroup(index, 1)
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Move cell later"
                                }
                                Button {
                                    visible: workspaceGrid.columns > 1
                                    text: modelData.wide ? "Half" : "Full"
                                    onClicked: page.toggleGroupWidth(index)
                                    ToolTip.visible: hovered
                                    ToolTip.text: modelData.wide ? "Use half width" : "Span full row"
                                }
                            }

                            StatusBadge {
                                visible: Boolean(modelData.badge)
                                shell: page.shell
                                text: modelData.badge || ""
                                badgeColor: modelData.experimental ? page.shell.warningColor : page.shell.mutedText
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: page.shell.outline
                        }

                        Repeater {
                            model: modelData.items || []

                            delegate: ControlRow {
                                required property var modelData
                                required property int index
                                shell: page.shell
                                feature: modelData
                                showDivider: index < (parent.parent.modelData.items.length - 1)
                                Layout.fillWidth: true
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
}
