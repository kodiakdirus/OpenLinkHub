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
    readonly property var currentTab: device
        && device.tabs
        && selectedTab >= 0
        && selectedTab < device.tabs.length
        ? device.tabs[selectedTab]
        : ({ name: "", icon: "applications-system", groups: [] })

    onDeviceChanged: selectedTab = 0

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

                    StatusBadge {
                        shell: page.shell
                        text: "Connected · mock"
                        badgeColor: page.shell.successColor
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

            GridLayout {
                id: contentGrid
                Layout.fillWidth: true
                columns: width > 960 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Repeater {
                    model: page.currentTab.groups

                    delegate: Panel {
                        required property var modelData
                        shell: page.shell
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop

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
