import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

AbstractButton {
    id: button

    required property var shell
    required property string itemKey
    required property string label
    required property string iconName
    property bool selected: false

    implicitHeight: shell.compactMode ? 42 : 48
    hoverEnabled: true

    background: Rectangle {
        radius: Math.max(6, shell.cornerRadius - 3)
        color: button.selected
            ? Qt.rgba(shell.accentColor.r, shell.accentColor.g, shell.accentColor.b, 0.18)
            : button.hovered
                ? shell.surfaceHover
                : "transparent"

        Rectangle {
            visible: button.selected
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: parent.height - 14
            radius: 2
            color: shell.accentColor
        }
    }

    contentItem: RowLayout {
        spacing: 12

        Item {
            Layout.preferredWidth: 7
        }

        Kirigami.Icon {
                            source: button.iconName
            color: button.selected ? shell.accentColor : shell.mutedText
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
        }

        Label {
            visible: shell.sidebarLabels
            text: button.label
            color: button.selected ? shell.primaryText : shell.secondaryText
            font.weight: button.selected ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    ToolTip.visible: hovered && !shell.sidebarLabels
    ToolTip.text: label
}
