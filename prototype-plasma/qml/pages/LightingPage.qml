import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page

    required property var shell
    property int selectedScene: 0
    property int brightnessValue: 70
    property bool layoutEditing: false
    property bool targetsFirst: false
    property bool stackControlCells: false
    function restoreLayout() {
        const saved = shell.savedLayout("lighting-demo")
        targetsFirst = Boolean(saved.targetsFirst)
        stackControlCells = Boolean(saved.stackControlCells)
    }
    function saveLayout() {
        shell.saveLayout("lighting-demo", {targetsFirst: targetsFirst, stackControlCells: stackControlCells})
    }
    Component.onCompleted: restoreLayout()
    Connections {
        target: page.shell
        function onPresentationReset() { page.restoreLayout() }
    }
    property var scenes: [
        { name: "Aurora", colors: ["#36d6c7", "#766bf0", "#274d9a"], detail: "Slow gradient" },
        { name: "Static cyan", colors: ["#66d7c5", "#66d7c5", "#66d7c5"], detail: "Single color" },
        { name: "Temperature", colors: ["#3fd076", "#f1c453", "#e45d64"], detail: "Sensor reactive" }
    ]

    function openPrimaryDialog() {
        sceneEditor.editing = false
        sceneEditor.initialName = ""
        sceneEditor.open()
    }

    function openLayoutEditor() {
        layoutEditing = true
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
                        text: "Lighting profiles & scenes"
                        color: page.shell.primaryText
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: "Coordinate compatible devices without hiding device-specific zones"
                        color: page.shell.mutedText
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: page.layoutEditing ? "Done arranging" : "Arrange cells"
                    icon.name: page.layoutEditing ? "dialog-ok" : "transform-move"
                    onClicked: page.layoutEditing = !page.layoutEditing
                }

                Button {
                    text: "Edit selected"
                    icon.name: "document-edit"
                    onClicked: {
                        sceneEditor.editing = true
                        sceneEditor.initialName = page.scenes[page.selectedScene].name
                        sceneEditor.primaryColor = page.scenes[page.selectedScene].colors[0]
                        sceneEditor.secondaryColor = page.scenes[page.selectedScene].colors[1]
                        sceneEditor.open()
                    }
                }

                Button {
                    text: "New scene"
                    icon.name: "list-add"
                    highlighted: true
                    onClicked: {
                        sceneEditor.editing = false
                        sceneEditor.initialName = ""
                        sceneEditor.primaryColor = "#66d7c5"
                        sceneEditor.secondaryColor = "#8b7cf6"
                        sceneEditor.open()
                    }
                }

                Switch {
                    text: page.shell.lightsEnabled ? "Lighting on" : "Lighting off"
                    checked: page.shell.lightsEnabled
                    onToggled: {
                        page.shell.lightsEnabled = checked
                        page.shell.markDirty("Global lighting")
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
                        text: "Scene cards remain a uniform library row. Configuration cells may swap order or switch together between equal two-column and full-width stacked layouts."
                        color: page.shell.secondaryText
                        wrapMode: Text.WordWrap
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 920 ? 3 : width > 620 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Repeater {
                    model: page.scenes

                    delegate: AbstractButton {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 174
                        padding: page.shell.contentPadding
                        hoverEnabled: true
                        onClicked: {
                            page.selectedScene = index
                            page.shell.markDirty("Lighting scene")
                        }

                        background: Rectangle {
                            radius: page.shell.cornerRadius
                            color: page.selectedScene === index ? page.shell.surfaceHover : page.shell.surface
                            border.width: page.selectedScene === index ? 2 : 1
                            border.color: page.selectedScene === index ? page.shell.accentColor : page.shell.outline
                        }

                        contentItem: ColumnLayout {
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: Math.max(6, page.shell.cornerRadius - 4)
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: modelData.colors[0] }
                                    GradientStop { position: 0.5; color: modelData.colors[1] }
                                    GradientStop { position: 1.0; color: modelData.colors[2] }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label {
                                        text: modelData.name
                                        color: page.shell.primaryText
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        text: modelData.detail
                                        color: page.shell.mutedText
                                        font.pixelSize: 11
                                    }
                                }
                                Kirigami.Icon {
                                    visible: page.selectedScene === index
                                    source: "dialog-ok"
                                    color: page.shell.accentColor
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                }
                            }
                        }
                    }
                }
            }

            GridLayout {
                id: lightingControlGrid
                Layout.fillWidth: true
                columns: width > 920 && !page.stackControlCells ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: lightingControlGrid.columns === 1
                        ? (page.targetsFirst ? 1 : 0)
                        : 0
                    Layout.column: lightingControlGrid.columns === 1
                        ? 0
                        : (page.targetsFirst ? 1 : 0)

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Scene controls"
                            color: page.shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        Button {
                            visible: page.layoutEditing
                            text: "Swap"
                            onClicked: {
                                page.targetsFirst = !page.targetsFirst
                                page.saveLayout()
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: "Swap configuration cells"
                        }
                        Button {
                            visible: page.layoutEditing
                            text: page.stackControlCells ? "Columns" : "Stack"
                            onClicked: {
                                page.stackControlCells = !page.stackControlCells
                                page.saveLayout()
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: page.stackControlCells
                                ? "Use equal two-column cells"
                                : "Stack both cells full width"
                        }
                    }

                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Brightness",
                            description: "All selected targets",
                            kind: "slider",
                            value: page.brightnessValue,
                            from: 0,
                            to: 100,
                            unit: "%"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        feature: ({
                            title: "Animation speed",
                            description: "Scene-wide timing",
                            kind: "slider",
                            value: 42,
                            from: 0,
                            to: 100,
                            unit: "%"
                        })
                    }
                    ControlRow {
                        shell: page.shell
                        showDivider: false
                        feature: ({
                            title: "Primary colors",
                            description: "Select a mock palette",
                            kind: "color",
                            choices: ["#66d7c5", "#8b7cf6", "#ef8b6b", "#f0c75e"]
                        })
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.row: lightingControlGrid.columns === 1
                        ? (page.targetsFirst ? 0 : 1)
                        : 0
                    Layout.column: lightingControlGrid.columns === 1
                        ? 0
                        : (page.targetsFirst ? 0 : 1)

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Targets"
                            color: page.shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        Button {
                            visible: page.layoutEditing
                            text: "Swap"
                            onClicked: {
                                page.targetsFirst = !page.targetsFirst
                                page.saveLayout()
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: "Swap configuration cells"
                        }
                        Button {
                            visible: page.layoutEditing
                            text: page.stackControlCells ? "Columns" : "Stack"
                            onClicked: {
                                page.stackControlCells = !page.stackControlCells
                                page.saveLayout()
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: page.stackControlCells
                                ? "Use equal two-column cells"
                                : "Stack both cells full width"
                        }
                    }

                    Repeater {
                        model: [
                            { title: "iCUE LINK System Hub", description: "6 fan zones + pump", kind: "toggle", value: true },
                            { title: "K100 AIR RGB", description: "Per-key surface", kind: "toggle", value: true },
                            { title: "Scimitar RGB Elite", description: "4 lighting zones", kind: "toggle", value: true },
                            { title: "Hardware lighting", description: "Used when the service is unavailable", kind: "toggle", value: false }
                        ]

                        delegate: ControlRow {
                            required property var modelData
                            required property int index
                            shell: page.shell
                            feature: modelData
                            showDivider: index < 3
                            Layout.fillWidth: true
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
                            text: "Desktop behavior"
                            color: page.shell.primaryText
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        StatusBadge {
                            shell: page.shell
                            text: "Prototype concept"
                            badgeColor: page.shell.warningColor
                        }
                    }

                    ControlRow {
                        shell: page.shell
                        showDivider: false
                        feature: ({
                            title: "Lights out when displays sleep",
                            description: "Automatically disable decorative lighting when Plasma turns the monitors off after idle; restore the prior scene when they wake.",
                            kind: "toggle",
                            value: false
                        })
                    }
                }
            }

            Panel {
                shell: page.shell
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    Kirigami.Icon {
                            source: "applications-engineering"
                        color: page.shell.accentColor
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Advanced lighting remains discoverable"
                            color: page.shell.primaryText
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: "Per-LED editing, RGB clusters, temperature thresholds, gradients, strips, adapters, and OpenRGB appear here rather than in a hidden miscellaneous page."
                            color: page.shell.mutedText
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    Button {
                        text: "Explore advanced"
                        onClicked: page.shell.showToast(
                            "Advanced lighting",
                            "The prototype would open the complete source-derived lighting inventory."
                        )
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
                    text: page.shell.pendingChanges ? "Apply scene" : "No pending changes"
                    icon.name: "dialog-ok-apply"
                    highlighted: true
                    enabled: page.shell.pendingChanges
                    onClicked: page.shell.applyChanges()
                }
            }

            Item { Layout.preferredHeight: 1 }
        }
    }

    LightingSceneDialog {
        id: sceneEditor
        shell: page.shell

        onSceneSaved: (name, effect, primary, secondary, editing) => {
            const scene = {
                name: name,
                colors: [primary, secondary, primary],
                detail: effect
            }
            if (editing) {
                const updated = page.scenes.slice()
                updated[page.selectedScene] = scene
                page.scenes = updated
            } else {
                page.scenes = page.scenes.concat([scene])
                page.selectedScene = page.scenes.length - 1
            }
        }
    }
}
