import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Panel {
    id: clusterEditor

    required property var ownership
    required property var targets

    signal closeRequested()

    Layout.fillWidth: true

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
            text: "Design shell · no writes"
            badgeColor: shell.warningColor
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
            text: "Cluster members · " + targets.length
            color: shell.secondaryText
            font.weight: Font.DemiBold
        }
        Label {
            text: "Current output: " + (ownership.label || "RGB Cluster")
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
        ComboBox {
            Layout.fillWidth: true
            enabled: false
            model: ["Use current synchronized scene"]
        }
        Button { text: "Edit scene"; icon.name: "document-edit"; enabled: false }
        Button { text: "Apply to cluster"; icon.name: "dialog-ok-apply"; enabled: false }
    }
}
