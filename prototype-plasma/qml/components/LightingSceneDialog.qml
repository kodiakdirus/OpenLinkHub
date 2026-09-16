import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Dialog {
    id: dialog

    required property var shell
    property bool editing: false
    property string initialName: ""
    property color primaryColor: "#66d7c5"
    property color secondaryColor: "#8b7cf6"

    signal sceneSaved(string name, string effect, color primary, color secondary, bool editing)

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(760, parent.width - 60)
    height: Math.min(700, parent.height - 60)
    modal: true
    title: editing ? "Edit lighting scene" : "Create lighting scene"
    standardButtons: Dialog.Save | Dialog.Cancel

    onOpened: {
        sceneName.text = initialName
    }

    onAccepted: {
        const name = sceneName.text.trim().length > 0
            ? sceneName.text.trim()
            : "Untitled lighting scene"
        sceneSaved(name, effect.currentText, primaryColor, secondaryColor, editing)
        shell.markDirty("Lighting scene library")
        shell.showToast(
            editing ? "Lighting scene updated locally" : "Lighting scene created locally",
            "No lighting profile was written to the backend."
        )
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: shell.cardSpacing

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                radius: shell.cornerRadius
                color: shell.surfaceAlt
                border.color: shell.outline
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: dialog.primaryColor }
                    GradientStop { position: 1.0; color: dialog.secondaryColor }
                }

                Label {
                    anchors.centerIn: parent
                    text: sceneName.text.length > 0 ? sceneName.text : "Scene preview"
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    style: Text.Outline
                    styleColor: "#66000000"
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: shell.cardSpacing
                rowSpacing: 10

                Label { text: "Scene name"; color: shell.secondaryText }
                TextField {
                    id: sceneName
                    Layout.fillWidth: true
                    placeholderText: "Example: Cool twilight"
                }

                Label { text: "Base effect"; color: shell.secondaryText }
                ComboBox {
                    id: effect
                    Layout.fillWidth: true
                    model: [
                        "Static",
                        "Gradient",
                        "Rainbow wave",
                        "Color pulse",
                        "Color shift",
                        "Temperature reactive",
                        "Per-LED custom"
                    ]
                }

                Label { text: "Brightness"; color: shell.secondaryText }
                RowLayout {
                    Slider {
                        from: 0
                        to: 100
                        value: 70
                        Layout.fillWidth: true
                    }
                    Label {
                        text: "70%"
                        color: shell.accentColor
                        Layout.preferredWidth: 42
                    }
                }

                Label { text: "Animation speed"; color: shell.secondaryText }
                RowLayout {
                    Slider {
                        from: 0
                        to: 100
                        value: 42
                        enabled: effect.currentText !== "Static"
                        Layout.fillWidth: true
                    }
                    Label {
                        text: effect.currentText === "Static" ? "—" : "42%"
                        color: shell.accentColor
                        Layout.preferredWidth: 42
                    }
                }
            }

            Label {
                text: "Scene colors"
                color: shell.primaryText
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: ["#66d7c5", "#7aa8ff", "#8b7cf6", "#ee876f", "#e8bd57", "#73d575"]
                    delegate: AbstractButton {
                        required property var modelData
                        implicitWidth: 38
                        implicitHeight: 38
                        onClicked: dialog.primaryColor = modelData
                        background: Rectangle {
                            radius: width / 2
                            color: modelData
                            border.width: dialog.primaryColor.toString() === modelData ? 3 : 1
                            border.color: dialog.primaryColor.toString() === modelData
                                ? shell.primaryText
                                : shell.outline
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: "Use as primary color"
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Swap colors"
                    icon.name: "object-flip-horizontal"
                    onClicked: {
                        const oldPrimary = dialog.primaryColor
                        dialog.primaryColor = dialog.secondaryColor
                        dialog.secondaryColor = oldPrimary
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: shell.outline
            }

            Label {
                text: "Targets and behavior"
                color: shell.primaryText
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: shell.cardSpacing

                CheckBox { text: "iCUE LINK devices"; checked: true }
                CheckBox { text: "Keyboard"; checked: true }
                CheckBox { text: "Mouse"; checked: true }
                CheckBox { text: "Headset"; checked: false }
                CheckBox { text: "Use as hardware lighting"; checked: false }
                CheckBox { text: "Include LCD accent colors"; checked: false }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: shell.outline
            }

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: "dialog-information"
                    color: shell.accentColor
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }
                Label {
                    Layout.fillWidth: true
                    text: "A production editor would expose effect-specific fields, gradients, temperature thresholds, zones, per-LED data, and hardware-mode compatibility here."
                    color: shell.mutedText
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
