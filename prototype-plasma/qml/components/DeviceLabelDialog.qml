import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Dialog {
    id: dialog

    required property var shell
    property var device: ({ id: "", name: "", labelTargets: [] })
    property int selectedTargetIndex: 0
    property string errorMessage: ""
    readonly property var targets: device.labelTargets || []
    readonly property var selectedTarget: targets.length > 0
        ? targets[Math.max(0, Math.min(selectedTargetIndex, targets.length - 1))]
        : ({ id: "", name: "", label: "" })

    title: "Edit device labels"
    modal: true
    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: 560

    function openForDevice(value) {
        device = value || ({ id: "", name: "", labelTargets: [] })
        selectedTargetIndex = 0
        errorMessage = ""
        labelField.text = targets.length > 0 ? (targets[0].label || "") : ""
        open()
        labelField.forceActiveFocus()
        labelField.selectAll()
    }

    onSelectedTargetIndexChanged: {
        if (opened && targets.length > 0) {
            labelField.text = selectedTarget.label || ""
            errorMessage = ""
        }
    }

    Connections {
        target: dialog.shell.backendClient

        function onCommandChanged() {
            if (!dialog.opened || dialog.shell.backendClient.commandBusy) return
            if (dialog.shell.backendClient.commandStatus === "succeeded") {
                dialog.shell.showToast(
                    "Label updated",
                    dialog.shell.backendClient.commandMessage
                )
                dialog.close()
            } else if (dialog.shell.backendClient.commandStatus === "rejected") {
                dialog.errorMessage = dialog.shell.backendClient.commandMessage
            }
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Kirigami.Icon {
                source: dialog.device.icon || "edit-rename"
                color: dialog.shell.accentColor
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: dialog.device.name || "Device"
                    color: dialog.shell.primaryText
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Label {
                    Layout.fillWidth: true
                    text: dialog.shell.liveMode
                        ? "The service validates, persists, and reads this label back before reporting success."
                        : "Demo mode previews this editor without contacting the service."
                    color: dialog.shell.mutedText
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: dialog.shell.outline
        }

        Label {
            text: "Label target"
            color: dialog.shell.primaryText
            font.weight: Font.DemiBold
        }

        ComboBox {
            id: targetChoice
            Layout.fillWidth: true
            model: dialog.targets
            textRole: "name"
            currentIndex: dialog.selectedTargetIndex
            onActivated: index => dialog.selectedTargetIndex = index
        }

        Label {
            text: "New label"
            color: dialog.shell.primaryText
            font.weight: Font.DemiBold
        }

        TextField {
            id: labelField
            Layout.fillWidth: true
            placeholderText: "Enter a descriptive label"
            maximumLength: 64
            validator: RegularExpressionValidator {
                regularExpression: /^[A-Za-z0-9#.:_ -]{1,64}$/
            }
            Accessible.name: "New device label"
            onTextEdited: dialog.errorMessage = ""
        }

        Label {
            Layout.fillWidth: true
            text: dialog.errorMessage.length > 0
                ? dialog.errorMessage
                : "Allowed: letters, numbers, spaces, and # . : _ -"
            color: dialog.errorMessage.length > 0
                ? dialog.shell.dangerColor
                : dialog.shell.mutedText
            wrapMode: Text.WordWrap
        }

        Rectangle {
            visible: dialog.shell.liveMode
            Layout.fillWidth: true
            implicitHeight: revisionRow.implicitHeight + 20
            radius: Math.max(6, dialog.shell.cornerRadius - 2)
            color: dialog.shell.surfaceAlt
            border.color: dialog.shell.outline

            RowLayout {
                id: revisionRow
                anchors.fill: parent
                anchors.margins: 10
                Label {
                    Layout.fillWidth: true
                    text: "Expected state revision"
                    color: dialog.shell.secondaryText
                }
                Label {
                    text: String(dialog.shell.backendClient.contractRevision)
                    color: dialog.shell.primaryText
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    footer: DialogButtonBox {
        Button {
            text: "Cancel"
            onClicked: dialog.reject()
        }
        Button {
            text: dialog.shell.backendClient.commandBusy ? "Applying…" : "Apply label"
            icon.name: "dialog-ok-apply"
            highlighted: true
            enabled: dialog.targets.length > 0
                && labelField.acceptableInput
                && !dialog.shell.backendClient.commandBusy
            onClicked: {
                dialog.errorMessage = ""
                if (!dialog.shell.liveMode) {
                    dialog.shell.showToast(
                        "Label previewed locally",
                        dialog.selectedTarget.name + " → " + labelField.text.trim()
                    )
                    dialog.close()
                    return
                }
                dialog.shell.backendClient.updateLabel(
                    dialog.device.id,
                    dialog.selectedTarget.id,
                    labelField.text
                )
            }
        }
    }
}
