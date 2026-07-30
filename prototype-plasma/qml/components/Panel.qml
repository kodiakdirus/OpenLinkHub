import QtQuick
import QtQuick.Layouts

Rectangle {
    id: panel

    required property var shell
    default property alias content: contentColumn.data
    property int padding: shell.contentPadding

    color: shell.surface
    border.color: shell.outline
    border.width: 1
    radius: shell.cornerRadius
    implicitHeight: contentColumn.implicitHeight + padding * 2
    implicitWidth: 320

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: panel.padding
        spacing: shell.compactMode ? 8 : 12
    }
}
