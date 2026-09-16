import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: notice
    objectName: "backendSetupNotice"
    required property var shell
    implicitHeight: noticeRow.implicitHeight + 16
    color: shell.surfaceAlt

    RowLayout {
        id: noticeRow
        anchors.fill: parent
        anchors.leftMargin: notice.shell.contentPadding
        anchors.rightMargin: notice.shell.contentPadding
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 12
        Kirigami.Icon {
            source: "dialog-information"
            color: notice.shell.mutedText
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
        }
        Label {
            Layout.fillWidth: true
            text: notice.shell.backendClient.backendSetup.title
            color: notice.shell.secondaryText
            wrapMode: Text.WordWrap
        }
        Button {
            objectName: "backendSetupNoticeAction"
            text: "Backend setup"
            flat: true
            onClicked: notice.shell.openBackendSetup()
        }
        ToolButton {
            objectName: "dismissBackendSetupNotice"
            icon.name: "dialog-close"
            icon.color: notice.shell.secondaryText
            Accessible.name: "Dismiss backend setup reminder"
            ToolTip.visible: hovered
            ToolTip.text: "Hide this reminder. Backend setup stays available under Service."
            onClicked: notice.shell.dismissBackendSetupReminder()
        }
    }
}
