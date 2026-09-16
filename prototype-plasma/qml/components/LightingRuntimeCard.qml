import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Panel {
    id: card
    objectName: "lightingRuntimeCard"
    Layout.fillWidth: true
    required property string deviceId
    readonly property var runtime: shell.backendClient.lightingRuntime || ({})
    readonly property var operations: runtime.operations || []
    readonly property bool busy: shell.backendClient.commandBusy
    readonly property bool member: (runtime.members || []).indexOf(deviceId) >= 0

    onDeviceIdChanged: if (shell.liveMode) shell.backendClient.cancelLightingIdentification()
    Component.onCompleted: if (shell.liveMode) shell.backendClient.refreshLightingRuntime()
    Component.onDestruction: if (shell.liveMode) shell.backendClient.cancelLightingIdentification()
    Timer {
        interval: 1000
        running: card.visible && card.shell.liveMode
        repeat: true
        onTriggered: card.shell.backendClient.refreshLightingRuntime()
    }

    Label { text: "Live lighting health"; color: shell.primaryText; font.pixelSize: 18; font.weight: Font.DemiBold }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: shell.secondaryText
        text: "Physical mode: " + (card.runtime.mode || "unknown")
            + " · Cluster renderer: " + (card.runtime.renderer || "unavailable")
            + ". Saved ownership does not confirm visible output."
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Button {
            text: "Refresh status"
            enabled: shell.liveMode
            onClicked: shell.backendClient.refreshLightingRuntime()
        }
        Button {
            text: "Recover saved Cluster scene…"
            enabled: shell.liveMode && !card.busy && !card.runtime.lease && card.operations.indexOf("recover") >= 0
            onClicked: recoveryReview.open()
        }
        Button {
            text: "Identify this device"
            enabled: shell.liveMode && !card.busy && card.member && card.runtime.renderer === "running" && card.operations.indexOf("identify") >= 0
            onClicked: shell.backendClient.identifyLighting(card.deviceId)
        }
        Button {
            text: "End identification"
            visible: !!card.runtime.lease
            enabled: !card.busy
            onClicked: shell.backendClient.cancelLightingIdentification()
        }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: shell.mutedText
        text: card.runtime.lease
            ? "Temporary locator: " + card.runtime.lease.status + ". It expires automatically; the saved scene is unchanged."
            : "Identification briefly lights the whole device. Attached Hub channels follow their parent device."
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        visible: shell.backendClient.commandMessage.length > 0
        text: shell.backendClient.commandMessage
        color: shell.secondaryText
    }
    Dialog {
        id: recoveryReview
        parent: Overlay.overlay
        anchors.centerIn: parent
        title: "Restart the saved Cluster scene?"
        width: Math.min(480, parent.width - 48)
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: card.shell.backendClient.recoverLighting()
        contentItem: Label {
            wrapMode: Text.WordWrap
            text: "This restarts the synchronized renderer for all Cluster members using its saved scene. Membership and cooling settings stay unchanged. A blocked writer may prevent recovery; physical output still needs visual confirmation."
        }
    }
}
