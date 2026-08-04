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
                        source: page.shell.liveMode ? "network-connect" : "network-disconnect"
                        color: page.shell.connectionBadgeColor()
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: page.shell.liveMode
                                ? page.shell.backendClient.contractVersion === "1.0"
                                    ? "Phase 3 — guarded label write checkpoint"
                                    : "Phase 2 — legacy read-only compatibility"
                                : "Demo mode — no backend connection"
                            color: page.shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: page.shell.liveMode
                                ? page.shell.backendClient.contractVersion === "1.0"
                                    ? "The versioned client can update published labels with stale-state rejection and read-back verification; every other mutation remains a local preview."
                                    : "The installed service uses the legacy GET adapter, so every control mutation remains a local preview."
                                : "Controls use local demo state and reset when the window closes."
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
                        text: page.shell.backendClient.apiCallCount + " API calls"
                        badgeColor: page.shell.connectionBadgeColor()
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

                    PanelHeader {
                        shell: page.shell
                        iconName: "preferences-desktop-theme"
                        title: "Appearance"
                        subtitle: "Constrained customization preserves navigation"
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
                            model: ["Dark Modern", "Midnight", "Dim", "Light"]
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
                            model: ["#0078d4", "#66d7c5", "#7aa8ff", "#a98cf5", "#ee876f", "#e8bd57"]
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

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Show sidebar labels"
                            color: page.shell.primaryText
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        Switch {
                            checked: page.shell.sidebarLabels
                            Accessible.name: "Show sidebar labels"
                            onToggled: page.shell.sidebarLabels = checked
                        }
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: page.cellRow("layout", serviceGrid.columns)
                    Layout.column: page.cellColumn("layout", serviceGrid.columns)

                    PanelHeader {
                        shell: page.shell
                        iconName: "view-grid"
                        title: "Layout"
                        subtitle: "Customize presentation without losing hierarchy"
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

                    PanelHeader {
                        shell: page.shell
                        iconName: "network-connect"
                        title: "Client connection"
                        subtitle: page.shell.liveMode
                            ? "The client prefers one versioned snapshot request, exposes one narrow guarded label command, and retains an explicit legacy read-only fallback."
                            : "Choose Live in the top bar to use the loopback transport. Demo mode opens no socket."
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
                            title: "Contract source",
                            description: page.shell.backendClient.contractVersion.length > 0
                                ? "OpenLinkHub contract " + page.shell.backendClient.contractVersion
                                    + " · state " + page.shell.backendClient.contractRevision
                                    + " · telemetry " + page.shell.backendClient.telemetryRevision
                                : "The installed service does not publish contract 1.0",
                            kind: "stat",
                            value: page.shell.backendClient.contractSource
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Read path",
                            description: "Inventory, capabilities, profiles, and telemetry",
                            kind: "stat",
                            value: page.shell.backendClient.contractVersion.length > 0
                                ? "GET /api/v1/snapshot"
                                : "Legacy GET set"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Write path",
                            description: page.shell.backendClient.contractVersion.length > 0
                                ? "Typed command with expected state revision and verification"
                                : "Unavailable on the installed legacy service",
                            kind: "stat",
                            value: page.shell.backendClient.contractVersion.length > 0
                                ? "PUT /api/v1/devices/label"
                                : "Unavailable"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Last command",
                            description: page.shell.backendClient.commandMessage.length > 0
                                ? page.shell.backendClient.commandMessage
                                : "No guarded command has been submitted this session",
                            kind: "stat",
                            value: page.shell.backendClient.commandBusy
                                ? "Working"
                                : page.shell.backendClient.commandStatus
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Connection",
                            description: page.shell.backendClient.errorMessage.length > 0
                                ? page.shell.backendClient.errorMessage
                                : "Current client state",
                            kind: "stat",
                            value: page.shell.backendClient.statusText
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        showDivider: false
                        feature: ({
                            title: "API operations",
                            description: "Lifetime of this process",
                            kind: "stat",
                            value: page.shell.backendClient.apiCallCount + " GET"
                        })
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: page.cellRow("features", serviceGrid.columns)
                    Layout.column: page.cellColumn("features", serviceGrid.columns)

                    PanelHeader {
                        shell: page.shell
                        iconName: "preferences-system"
                        title: "Service feature map"
                        subtitle: "These administration areas remain visible in the information architecture even though this prototype cannot execute them."
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
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
