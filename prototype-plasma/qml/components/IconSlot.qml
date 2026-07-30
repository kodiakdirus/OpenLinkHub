import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: slot

    property alias source: icon.source
    property alias color: icon.color
    property int iconSize: 24
    property int slotSize: 32

    Layout.minimumWidth: slotSize
    Layout.preferredWidth: slotSize
    Layout.maximumWidth: slotSize
    Layout.minimumHeight: slotSize
    Layout.preferredHeight: slotSize
    Layout.maximumHeight: slotSize
    Layout.alignment: Qt.AlignVCenter

    Kirigami.Icon {
        id: icon
        anchors.centerIn: parent
        width: slot.iconSize
        height: slot.iconSize
    }
}
