import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: dialog
    objectName: "backendSetupDialog"
    required property var shell
    readonly property var setup: shell.backendClient.backendSetup
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(680, parent.width - 48)
    height: Math.min(implicitHeight, parent.height - 48)
    title: "Backend setup"
    modal: true
    standardButtons: Dialog.Close

    contentItem: ScrollView {
        id: setupScroll
        implicitHeight: details.implicitHeight
        contentWidth: availableWidth
        ColumnLayout {
            id: details
            width: setupScroll.availableWidth
            spacing: 16
            StatusBadge {
                shell: dialog.shell
                text: dialog.setup.badge
                badgeColor: dialog.setup.key === "ready" ? dialog.shell.successColor : dialog.shell.accentColor
            }
            Label {
                Layout.fillWidth: true
                text: dialog.setup.title
                color: dialog.shell.primaryText
                font.pixelSize: 20
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
            Label {
                Layout.fillWidth: true
                text: dialog.setup.summary
                color: dialog.shell.secondaryText
                wrapMode: Text.WordWrap
            }
            Button {
                objectName: "backendSetupCheckConnection"
                text: dialog.shell.liveMode ? "Check connection again" : "Connect to existing service"
                icon.name: "network-connect"
                enabled: !dialog.shell.backendClient.refreshing && !dialog.shell.backendClient.commandBusy
                    && !dialog.shell.backendClient.coolingBusy
                onClicked: {
                    if (dialog.shell.liveMode) dialog.shell.backendClient.refresh()
                    else {
                        dialog.shell.backendClient.setMode("live")
                        dialog.shell.savePreference("mode", "live")
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: dialog.shell.outline }
            Label {
                text: "Install or update the service"
                color: dialog.shell.primaryText
                font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                text: "OpenLinkHub is installed separately from this desktop app. Use the service's installation instructions for your distribution, then return here to check the connection."
                color: dialog.shell.secondaryText
                wrapMode: Text.WordWrap
            }
            Button {
                text: "Open service installation guide"
                icon.name: "help-browser"
                onClicked: Qt.openUrlExternally(dialog.shell.backendClient.applicationInfo.serviceInstallUrl)
            }
            Label {
                text: "Compatible testing backend"
                color: dialog.shell.primaryText
                font.weight: Font.DemiBold
            }
            Label {
                objectName: "backendSetupPackageAvailability"
                Layout.fillWidth: true
                text: "A compatible testing-backend package and in-app installer are not available in this alpha. Installing the upstream service may still leave some lighting and label controls unavailable."
                color: dialog.shell.secondaryText
                wrapMode: Text.WordWrap
            }
            Label {
                Layout.fillWidth: true
                text: "Input and display editing, global profiles, and automations are still being developed in the GUI. A backend update cannot enable those unfinished features."
                color: dialog.shell.mutedText
                wrapMode: Text.WordWrap
            }
            CheckBox {
                objectName: "backendSetupShowReminder"
                text: "Show the optional backend setup reminder"
                checked: !dialog.shell.backendClient.preferences.values.backendSetupReminderDismissed
                onToggled: dialog.shell.savePreference("backendSetupReminderDismissed", !checked)
            }
        }
    }
}
