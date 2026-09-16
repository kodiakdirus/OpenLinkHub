import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Panel {
    id: clusterEditor

    required property var ownership
    required property var targets
    required property var availableDevices
    property string clusterScene: "Not reported"
    property string clusterRenderer: "unavailable"

    signal closeRequested()
    signal editMembersRequested()

    Layout.fillWidth: true

    function lightingEditorFor(device) {
        const tabs = device.tabs || []
        for (let index = 0; index < tabs.length; ++index) {
            if (tabs[index].name === "Lighting" && tabs[index].lightingEditor !== undefined) {
                return tabs[index].lightingEditor
            }
        }
        return null
    }

    function assignedDeviceCount() {
        let count = 0
        const devices = availableDevices || []
        for (let index = 0; index < devices.length; ++index) {
            const lighting = lightingEditorFor(devices[index])
            if (lighting && lighting.ownership
                    && lighting.ownership.controller === "rgb-cluster") count += 1
        }
        return count
    }

    RowLayout {
        Layout.fillWidth: true
        Kirigami.Icon {
            source: "view-grid"
            color: shell.accentColor
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label {
                text: "RGB Cluster editor"
                color: shell.primaryText
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Label {
                text: "A synchronized scene workspace for every target owned by this controller."
                color: shell.mutedText
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
        StatusBadge {
            shell: clusterEditor.shell
            text: shell.backendClient.lightingOwnershipAvailable
                ? "Guarded membership · one at a time"
                : "Read-only membership"
            badgeColor: shell.backendClient.lightingOwnershipAvailable ? shell.successColor : shell.warningColor
        }
        Button {
            text: "Edit members…"
            icon.name: "list-add"
            onClicked: clusterEditor.editMembersRequested()
        }
        Button {
            text: "Close"
            icon.name: "window-close"
            onClicked: clusterEditor.closeRequested()
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: shell.outline }

    RowLayout {
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            text: "Cluster devices · " + clusterEditor.assignedDeviceCount()
            color: shell.secondaryText
            font.weight: Font.DemiBold
        }
        Label {
            text: "Lighting targets · " + targets.length
            color: shell.mutedText
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: clusterEditor.targets
            delegate: StatusBadge {
                required property var modelData
                shell: clusterEditor.shell
                text: modelData.name
                badgeColor: clusterEditor.shell.accentColor
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            Label { text: "Configured scene"; color: shell.mutedText }
            Label {
                objectName: "clusterEditorSceneName"
                text: clusterEditor.clusterScene
                color: shell.primaryText
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
            Label { text: "Renderer " + clusterEditor.clusterRenderer; color: shell.mutedText }
        }
        Button { text: "Edit scene"; icon.name: "document-edit"; enabled: false }
        Button { text: "Apply to cluster"; icon.name: "dialog-ok-apply"; enabled: false }
    }
}
