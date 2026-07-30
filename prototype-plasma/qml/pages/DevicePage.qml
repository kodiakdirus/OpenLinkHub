import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page

    required property var shell
    required property var device
    property int selectedTab: 0
    property bool layoutEditing: false
    property var arrangedGroups: []
    readonly property var currentTab: device
        && device.tabs
        && selectedTab >= 0
        && selectedTab < device.tabs.length
        ? device.tabs[selectedTab]
        : ({ name: "", icon: "applications-system", groups: [] })

    function resetLayout() {
        arrangedGroups = (currentTab.groups || []).map(group => ({
            title: group.title,
            icon: group.icon,
            description: group.description,
            items: group.items,
            wide: Boolean(group.wide)
        }))
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
        shell.markDirty(device.name + " · " + currentTab.name + " cell order")
    }

    function toggleGroupWidth(index) {
        const updated = arrangedGroups.slice()
        const current = updated[index]
        updated[index] = {
            title: current.title,
            icon: current.icon,
            description: current.description,
            items: current.items,
            wide: !current.wide
        }
        arrangedGroups = updated
        shell.markDirty(device.name + " · " + currentTab.name + " cell size")
    }

    onDeviceChanged: {
        selectedTab = 0
        resetLayout()
    }
    onSelectedTabChanged: {
        layoutEditing = false
    }
    onCurrentTabChanged: resetLayout()
    Component.onCompleted: resetLayout()

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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 62
                        Layout.preferredHeight: 62
                        radius: 17
                        color: page.shell.surfaceAlt
                        border.color: page.shell.outline

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            source: page.device.icon
                            color: page.shell.accentColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: page.device.name
                            color: page.shell.primaryText
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: page.device.subtitle
                            color: page.shell.mutedText
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: page.device.capabilities
                                delegate: StatusBadge {
                                    required property var modelData
                                    shell: page.shell
                                    text: modelData
                                    badgeColor: page.shell.mutedText
                                }
                            }
                        }
                    }

                    Button {
                        text: page.layoutEditing ? "Done arranging" : "Arrange tab cells"
                        icon.name: page.layoutEditing ? "dialog-ok" : "transform-move"
                        onClicked: page.layoutEditing = !page.layoutEditing
                    }

                    StatusBadge {
                        shell: page.shell
                        text: page.shell.liveMode ? "Connected · read only" : "Connected · demo"
                        badgeColor: page.device.connected === false
                            ? page.shell.warningColor
                            : page.shell.successColor
                        filled: true
                    }
                }
            }

            TabBar {
                id: tabs
                Layout.fillWidth: true
                currentIndex: page.selectedTab
                onCurrentIndexChanged: page.selectedTab = currentIndex

                Repeater {
                    model: page.device.tabs
                    delegate: TabButton {
                        required property var modelData
                        text: modelData.name
                        icon.name: modelData.icon
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
                    Kirigami.Icon {
                        source: "view-grid"
                        color: page.shell.accentColor
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "This layout belongs to " + page.device.name + " · " + page.currentTab.name
                            + ". Cells snap to half or full width, preserve their internal controls, and match the height of a half-width neighbor."
                        color: page.shell.secondaryText
                        wrapMode: Text.WordWrap
                    }
                    Button {
                        text: "Reset tab layout"
                        icon.name: "edit-undo"
                        onClicked: page.resetLayout()
                    }
                }
            }

            GridLayout {
                id: contentGrid
                Layout.fillWidth: true
                columns: width > 960 ? 2 : 1
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
                        Layout.columnSpan: modelData.wide ? contentGrid.columns : 1

                        RowLayout {
                            Layout.fillWidth: true
                            Kirigami.Icon {
                            source: modelData.icon || page.currentTab.icon
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
                                    visible: contentGrid.columns > 1
                                    text: modelData.wide ? "Half" : "Full"
                                    onClicked: page.toggleGroupWidth(index)
                                    ToolTip.visible: hovered
                                    ToolTip.text: modelData.wide ? "Use half width" : "Span full row"
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: page.shell.outline
                        }

                        Repeater {
                            model: modelData.items
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
                Button {
                    text: "Back to devices"
                    icon.name: "go-previous"
                    onClicked: page.shell.navigate("devices")
                }
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
