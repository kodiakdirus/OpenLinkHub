import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: row

    required property var shell
    required property var feature
    property bool showDivider: true
    Layout.fillWidth: true
    readonly property bool stacked: width < 430
        || ((feature.kind === "slider"
            || feature.kind === "choice"
            || feature.kind === "color")
            && width < 650)

    implicitHeight: stacked
        ? (feature.description ? 108 : 90)
        : (feature.description ? 68 : 52)

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        GridLayout {
            Layout.fillWidth: true
            columns: row.stacked ? 1 : 2
            rowSpacing: 8
            columnSpacing: 16

            ColumnLayout {
                id: copy
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: row.feature.title || ""
                    color: row.shell.primaryText
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Label {
                    visible: text.length > 0
                    text: row.feature.description || ""
                    color: row.shell.mutedText
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Switch {
                visible: row.feature.kind === "toggle"
                checked: Boolean(row.feature.value)
                Layout.alignment: row.stacked ? Qt.AlignLeft : Qt.AlignRight
                onToggled: row.shell.markDirty(row.feature.title)
            }

            ColumnLayout {
                visible: row.feature.kind === "slider"
                Layout.preferredWidth: 240
                Layout.fillWidth: row.stacked
                Layout.alignment: row.stacked ? Qt.AlignLeft : Qt.AlignRight
                spacing: 2

                Label {
                    text: Math.round(slider.value * 10) / 10 + (row.feature.unit || "")
                    color: row.shell.accentColor
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignRight
                }

                Slider {
                    id: slider
                    from: row.feature.from === undefined ? 0 : row.feature.from
                    to: row.feature.to === undefined ? 100 : row.feature.to
                    value: row.feature.value === undefined ? 50 : row.feature.value
                    stepSize: row.feature.step === undefined ? 1 : row.feature.step
                    Layout.fillWidth: true
                    onMoved: row.shell.markDirty(row.feature.title)
                }
            }

            ComboBox {
                visible: row.feature.kind === "choice"
                model: row.feature.choices || []
                currentIndex: Math.max(0, model.indexOf(row.feature.value))
                Layout.preferredWidth: 240
                Layout.fillWidth: row.stacked
                Layout.alignment: row.stacked ? Qt.AlignLeft : Qt.AlignRight
                onActivated: row.shell.markDirty(row.feature.title)
            }

            Button {
                visible: row.feature.kind === "action"
                text: row.feature.value || "Open"
                icon.name: row.feature.icon || ""
                Layout.alignment: row.stacked ? Qt.AlignLeft : Qt.AlignRight
                onClicked: row.shell.showToast(
                    row.feature.title,
                    row.feature.actionText || "Previewed locally; no backend action was sent."
                )
            }

            Label {
                visible: row.feature.kind !== "toggle"
                    && row.feature.kind !== "slider"
                    && row.feature.kind !== "choice"
                    && row.feature.kind !== "action"
                    && row.feature.kind !== "color"
                text: row.feature.value || "—"
                color: row.feature.accent ? row.shell.accentColor : row.shell.primaryText
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                Layout.alignment: row.stacked ? Qt.AlignLeft : Qt.AlignRight
            }

            RowLayout {
                visible: row.feature.kind === "color"
                Layout.alignment: row.stacked ? Qt.AlignLeft : Qt.AlignRight
                spacing: 6

                Repeater {
                    model: row.feature.choices || ["#66d7c5", "#8b7cf6", "#ef8b6b"]
                    delegate: AbstractButton {
                        required property var modelData
                        implicitWidth: 30
                        implicitHeight: 30
                        onClicked: row.shell.markDirty(row.feature.title)
                        background: Rectangle {
                            radius: width / 2
                            color: modelData
                            border.width: 2
                            border.color: parent.hovered ? row.shell.primaryText : row.shell.outline
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: row.showDivider
            Layout.fillWidth: true
            height: 1
            color: row.shell.outline
        }
    }
}
