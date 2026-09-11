import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Panel {
    id: card

    required property var ownership
    required property var targets

    signal reviewRequested()
    signal clusterEditorRequested()

    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: shell.cardSpacing

        Kirigami.Icon {
            source: "network-connect"
            color: shell.accentColor
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label {
                text: "Lighting control"
                color: shell.primaryText
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Label {
                text: ownership.description || "Lighting controller state is unavailable."
                color: shell.mutedText
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
        StatusBadge {
            shell: card.shell
            text: (ownership.mode === "synchronized" ? "Synchronized · " : ownership.mode === "external" ? "External · " : "Individual · ")
                + (ownership.label || "Unknown")
            badgeColor: ownership.controller === "openrgb" ? shell.warningColor : shell.accentColor
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: shell.outline
    }

    GridLayout {
        Layout.fillWidth: true
        columns: width > 760 ? 3 : 1
        columnSpacing: shell.cardSpacing
        rowSpacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            Label { text: "Active controller"; color: shell.mutedText; font.pixelSize: 12 }
            Label {
                text: ownership.label || "Unknown"
                color: shell.primaryText
                font.weight: Font.DemiBold
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Label { text: "Affected targets"; color: shell.mutedText; font.pixelSize: 12 }
            Label {
                text: (ownership.affectedTargetCount === undefined ? targets.length : ownership.affectedTargetCount) + " lighting targets"
                color: shell.primaryText
                font.weight: Font.DemiBold
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Label { text: "Saved individual state"; color: shell.mutedText; font.pixelSize: 12 }
            Label {
                text: ownership.savedIndividualSummary || "Not reported"
                color: shell.primaryText
                font.weight: Font.DemiBold
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            text: "Review the affected device before applying a controller change. Published operations verify the resulting ownership."
            color: shell.mutedText
            wrapMode: Text.WordWrap
        }
        Button {
            visible: ownership.controller === "rgb-cluster"
            text: "Open Cluster editor"
            icon.name: "view-grid"
            onClicked: card.clusterEditorRequested()
        }
        Button {
            text: "Change control mode…"
            icon.name: "system-switch-user"
            onClicked: card.reviewRequested()
        }
    }
}
