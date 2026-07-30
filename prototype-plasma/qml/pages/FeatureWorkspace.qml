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

                    StatusBadge {
                        shell: page.shell
                        text: "Interactive mock"
                        badgeColor: page.shell.accentColor
                        filled: true
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 1020 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Repeater {
                    model: page.groups

                    delegate: Panel {
                        required property var modelData
                        shell: page.shell
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop

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
