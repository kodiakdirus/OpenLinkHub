import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page

    required property var shell
    property bool layoutEditing: false
    property bool appearanceFirst: true
    property bool connectionFirst: true
    property bool stackCells: false

    function cellIndex(name) {
        const order = appearanceFirst
            ? ["appearance", "layout"]
            : ["layout", "appearance"]
        if (connectionFirst) {
            order.push("connection")
            order.push("features")
        } else {
            order.push("features")
            order.push("connection")
        }
        return order.indexOf(name)
    }

    function openLayoutEditor() {
        layoutEditing = true
    }

    function cellRow(name, columns) {
        return columns === 1 ? cellIndex(name) : Math.floor(cellIndex(name) / 2)
    }

    function cellColumn(name, columns) {
        return columns === 1 ? 0 : cellIndex(name) % 2
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

                    Button {
                        text: page.layoutEditing ? "Done arranging" : "Arrange cells"
                        icon.name: page.layoutEditing ? "dialog-ok" : "transform-move"
                        onClicked: page.layoutEditing = !page.layoutEditing
                    }

                    StatusBadge {
                        shell: page.shell
                        text: "0 API calls"
                        badgeColor: page.shell.successColor
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
                    spacing: 10
                    Kirigami.Icon {
                        source: "view-grid"
                        color: page.shell.accentColor
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "Service cells use the same constrained grid: paired cells share equal row height, and full-width mode stacks every cell without arbitrary gaps."
                        color: page.shell.secondaryText
                        wrapMode: Text.WordWrap
                    }
                    Button {
                        text: "Swap top pair"
                        icon.name: "object-flip-horizontal"
                        onClicked: {
                            page.appearanceFirst = !page.appearanceFirst
                            page.shell.markDirty("Service cell order")
                        }
                    }
                    Button {
                        text: "Swap bottom pair"
                        icon.name: "object-flip-horizontal"
                        onClicked: {
                            page.connectionFirst = !page.connectionFirst
                            page.shell.markDirty("Service cell order")
                        }
                    }
                    Button {
                        text: page.stackCells ? "Two columns" : "Stack full width"
                        icon.name: page.stackCells ? "view-restore" : "view-fullscreen"
                        onClicked: {
                            page.stackCells = !page.stackCells
                            page.shell.markDirty("Service cell size")
                        }
                    }
                }
            }

            GridLayout {
                id: serviceGrid
                Layout.fillWidth: true
                columns: width > 1000 && !page.stackCells ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: page.cellRow("appearance", serviceGrid.columns)
                    Layout.column: page.cellColumn("appearance", serviceGrid.columns)

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
                    Layout.fillHeight: true
                    Layout.row: page.cellRow("layout", serviceGrid.columns)
                    Layout.column: page.cellColumn("layout", serviceGrid.columns)

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
                    Layout.fillHeight: true
                    Layout.row: page.cellRow("connection", serviceGrid.columns)
                    Layout.column: page.cellColumn("connection", serviceGrid.columns)

                    Label {
                        text: "Future client connection"
                        color: page.shell.primaryText
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "The production native client would use the same loopback HTTP API as the WebUI. This prototype intentionally leaves that transport disabled."
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
                            title: "Transport",
                            description: "Typed client layer over the existing local API",
                            kind: "stat",
                            value: "HTTP + JSON"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Read path",
                            description: "Inventory, capabilities, profiles, and telemetry",
                            kind: "stat",
                            value: "GET"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Write path",
                            description: "Validated profile and device commands",
                            kind: "stat",
                            value: "POST / PUT / DELETE"
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
                    Layout.fillHeight: true
                    Layout.row: page.cellRow("features", serviceGrid.columns)
                    Layout.column: page.cellColumn("features", serviceGrid.columns)

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
