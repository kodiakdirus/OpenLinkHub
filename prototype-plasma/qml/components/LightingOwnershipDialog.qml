import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Dialog {
    id: dialog

    required property var shell
    required property var device
    required property var ownership
    required property var targets
    readonly property bool clusterOwned: ownership.controller === "rgb-cluster"
    readonly property string requestedLabel: clusterOwned ? "Individual devices" : "RGB Cluster"
    readonly property string requestedController: clusterOwned ? "individual" : "rgb-cluster"
    readonly property bool canChange: shell.liveMode
        && shell.backendClient.contractVersion === "1.0"
        && (ownership.operations || []).indexOf("change-controller") >= 0
        && !shell.backendClient.commandBusy

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(720, parent.width - 60)
    modal: true
    title: "Review lighting control change"
    standardButtons: Dialog.Cancel

    ColumnLayout {
        width: parent.width
        spacing: shell.cardSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "dialog-warning"
                color: shell.warningColor
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
            }
            Label {
                Layout.fillWidth: true
                text: "This changes who controls every lighting target on this device."
                color: shell.primaryText
                font.pixelSize: 17
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 10
            Label { text: ownership.label || "Current controller"; color: shell.secondaryText; font.weight: Font.DemiBold }
            Kirigami.Icon { source: "go-next"; color: shell.accentColor; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
            Label { text: dialog.requestedLabel; color: shell.primaryText; font.weight: Font.DemiBold }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: shell.outline }

        Label {
            Layout.fillWidth: true
            text: dialog.clusterOwned
                ? "Leaving RGB Cluster restores the saved individual state: " + (ownership.savedIndividualSummary || "not reported") + "."
                : "Joining RGB Cluster preserves the current individual assignments, but the synchronized controller will own live output."
            color: shell.secondaryText
            wrapMode: Text.WordWrap
        }
        Label {
            Layout.fillWidth: true
            text: (ownership.affectedTargetCount === undefined ? targets.length : ownership.affectedTargetCount)
                + " targets are affected. Global profiles will not switch this mode implicitly."
            color: shell.mutedText
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            StatusBadge {
                shell: dialog.shell
                text: dialog.canChange ? "Guarded transition available" : "Read only"
                badgeColor: dialog.canChange ? shell.successColor : shell.warningColor
            }
            Button {
                text: dialog.clusterOwned ? "Switch to individual control" : "Switch to synchronized control"
                icon.name: "dialog-ok-apply"
                enabled: dialog.canChange
                ToolTip.visible: hovered
                ToolTip.text: dialog.canChange
                    ? "Apply one revision-checked transition and verify it from refreshed state."
                    : "This service or device does not publish the guarded ownership operation."
                onClicked: shell.backendClient.changeLightingController(
                    device.id,
                    ownership.controller,
                    dialog.requestedController
                )
            }
        }

        Label {
            Layout.fillWidth: true
            visible: shell.backendClient.commandMessage !== ""
            text: shell.backendClient.commandMessage
            color: shell.backendClient.commandStatus === "succeeded" ? shell.successColor : shell.warningColor
            wrapMode: Text.WordWrap
        }
    }
}
