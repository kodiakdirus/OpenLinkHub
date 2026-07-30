import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: header

    required property var shell
    property string iconName: "applications-system"
    property string title: ""
    property string subtitle: ""
    property color iconColor: shell.accentColor

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignTop
    spacing: 12

    Rectangle {
        Layout.preferredWidth: 38
        Layout.preferredHeight: 38
        Layout.alignment: Qt.AlignTop
        radius: 10
        color: Qt.rgba(
            header.iconColor.r,
            header.iconColor.g,
            header.iconColor.b,
            0.10
        )
        border.color: Qt.rgba(
            header.iconColor.r,
            header.iconColor.g,
            header.iconColor.b,
            0.28
        )

        Kirigami.Icon {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: header.iconName
            color: header.iconColor
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 1

        Label {
            Layout.fillWidth: true
            text: header.title
            color: header.shell.primaryText
            font.pixelSize: 19
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Label {
            visible: header.subtitle.length > 0
            Layout.fillWidth: true
            text: header.subtitle
            color: header.shell.mutedText
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
}
