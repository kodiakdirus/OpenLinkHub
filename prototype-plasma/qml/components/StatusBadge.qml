import QtQuick
import QtQuick.Controls

Rectangle {
    id: badge

    required property var shell
    property string text: ""
    property color badgeColor: shell.accentColor
    property bool filled: false

    implicitWidth: label.implicitWidth + 18
    implicitHeight: label.implicitHeight + 8
    radius: height / 2
    color: filled ? Qt.rgba(badgeColor.r, badgeColor.g, badgeColor.b, 0.18) : "transparent"
    border.color: Qt.rgba(badgeColor.r, badgeColor.g, badgeColor.b, 0.65)
    border.width: 1

    Label {
        id: label
        anchors.centerIn: parent
        text: badge.text
        color: badge.badgeColor
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }
}
