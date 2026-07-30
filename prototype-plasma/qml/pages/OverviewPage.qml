import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page
    objectName: "overviewPage"

    required property var shell
    property var metricKeys: []
    property var zoneKeys: []
    property var deviceKeys: []
    property string metricKeySignature: ""
    property string zoneKeySignature: ""
    property string deviceKeySignature: ""
    property int presentationRevision: 0

    function metricForKey(key) {
        const metrics = shell.overviewMetrics || []
        for (let index = 0; index < metrics.length; ++index) {
            if (metrics[index].key === key) return metrics[index]
        }
        return ({
            key: key,
            label: key,
            detail: "Unavailable",
            icon: "dialog-warning",
            state: "Unavailable",
            warning: true
        })
    }

    function zoneForKey(key) {
        const zones = shell.coolingZones || []
        for (let index = 0; index < zones.length; ++index) {
            if (zones[index].key === key) return zones[index]
        }
        return ({
            key: key,
            name: key,
            icon: "temperature-normal",
            source: "Unavailable",
            profile: "Not reported"
        })
    }

    function deviceForKey(key) {
        const devices = shell.devices || []
        for (let index = 0; index < devices.length; ++index) {
            if (devices[index].id === key) return devices[index]
        }
        return ({
            id: key,
            name: "Unavailable device",
            icon: "network-disconnect",
            subtitle: "No current service data",
            connected: false
        })
    }

    function reconcileMetricKeys() {
        const metrics = shell.overviewMetrics || []
        const nextKeys = []
        for (let index = 0; index < metrics.length; ++index)
            nextKeys.push(metrics[index].key)
        const nextSignature = JSON.stringify(nextKeys)
        if (nextSignature === metricKeySignature) return
        metricKeySignature = nextSignature
        metricKeys = nextKeys
        presentationRevision += 1
    }

    function reconcileZoneKeys() {
        const zones = shell.coolingZones || []
        const nextKeys = []
        for (let index = 0; index < zones.length; ++index)
            nextKeys.push(zones[index].key)
        const nextSignature = JSON.stringify(nextKeys)
        if (nextSignature === zoneKeySignature) return
        zoneKeySignature = nextSignature
        zoneKeys = nextKeys
        presentationRevision += 1
    }

    function reconcileDeviceKeys() {
        const devices = shell.devices || []
        const nextKeys = []
        for (let index = 0; index < Math.min(devices.length, 4); ++index)
            nextKeys.push(devices[index].id)
        const nextSignature = JSON.stringify(nextKeys)
        if (nextSignature === deviceKeySignature) return
        deviceKeySignature = nextSignature
        deviceKeys = nextKeys
        presentationRevision += 1
    }

    function reconcilePresentationKeys() {
        reconcileMetricKeys()
        reconcileZoneKeys()
        reconcileDeviceKeys()
    }

    Connections {
        target: page.shell
        function onOverviewMetricsChanged() {
            Qt.callLater(page.reconcileMetricKeys)
        }
        function onCoolingZonesChanged() {
            Qt.callLater(page.reconcileZoneKeys)
        }
        function onDevicesChanged() {
            Qt.callLater(page.reconcileDeviceKeys)
        }
    }

    Component.onCompleted: reconcilePresentationKeys()

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: page.shell.sectionSpacing

            GridLayout {
                Layout.fillWidth: true
                columns: width > 1000 ? 4 : 2
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Repeater {
                    model: page.metricKeys.length

                    delegate: Panel {
                        id: metricCard
                        required property int index
                        readonly property var metric: page.metricForKey(String(page.metricKeys[index]))
                        shell: page.shell
                        Layout.fillWidth: true
                        Layout.preferredHeight: page.shell.compactMode ? 126 : 142

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: 12
                                color: Qt.rgba(page.shell.accentColor.r, page.shell.accentColor.g, page.shell.accentColor.b, 0.12)

                                Kirigami.Icon {
                            anchors.centerIn: parent
                                    width: 25
                                    height: 25
                                    source: metricCard.metric.icon
                                    color: page.shell.accentColor
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: metricCard.metric.label
                                    color: page.shell.mutedText
                                    font.pixelSize: 12
                                }

                                Label {
                                    text: page.shell.metricValue(metricCard.metric.key)
                                    color: page.shell.primaryText
                                    font.pixelSize: 25
                                    font.weight: Font.DemiBold
                                }

                                Label {
                                    text: metricCard.metric.detail
                                    color: page.shell.mutedText
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        StatusBadge {
                            shell: page.shell
                            text: metricCard.metric.state
                            badgeColor: metricCard.metric.warning
                                ? page.shell.warningColor
                                : page.shell.successColor
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 980 ? 2 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.shell.compactMode ? 380 : 410

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 1
                            Label {
                                text: "Cooling at a glance"
                                color: page.shell.primaryText
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: page.shell.liveMode
                                    ? "Grouped read-only RPM from the service"
                                    : "Mock values follow the active global profile"
                                color: page.shell.mutedText
                                font.pixelSize: 12
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "Open cooling"
                            icon.name: "go-next"
                            onClicked: page.shell.navigate("cooling")
                        }
                    }

                    Repeater {
                        model: page.zoneKeys.length

                        delegate: AbstractButton {
                            id: zoneButton
                            required property int index
                            readonly property var zone: page.zoneForKey(String(page.zoneKeys[index]))
                            Layout.fillWidth: true
                            implicitHeight: page.shell.compactMode ? 62 : 70
                            leftPadding: page.shell.compactMode ? 12 : 16
                            rightPadding: page.shell.compactMode ? 12 : 16
                            topPadding: page.shell.compactMode ? 8 : 10
                            bottomPadding: page.shell.compactMode ? 8 : 10
                            hoverEnabled: true
                            onClicked: page.shell.navigate("cooling")

                            background: Rectangle {
                                radius: Math.max(6, page.shell.cornerRadius - 4)
                                color: parent.hovered ? page.shell.surfaceHover : page.shell.surfaceAlt
                                border.color: page.shell.outline
                            }

                            contentItem: RowLayout {
                                spacing: 12

                                IconSlot {
                                    source: zoneButton.zone.icon
                                    color: page.shell.accentColor
                                    iconSize: 24
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignLeft
                                        text: zoneButton.zone.name
                                        color: page.shell.primaryText
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignLeft
                                        text: zoneButton.zone.source
                                            + " source · " + zoneButton.zone.profile
                                        color: page.shell.mutedText
                                        font.pixelSize: 11
                                    }
                                }

                                Label {
                                    text: page.shell.zoneRpm(zoneButton.zone.key)
                                    color: zoneButton.zone.key === "case"
                                        && page.shell.activeGlobalProfile !== "gaming"
                                        ? page.shell.accentColor
                                        : page.shell.primaryText
                                    font.weight: Font.DemiBold
                                }

                                Kirigami.Icon {
                                    source: "go-next"
                                    color: page.shell.mutedText
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                }
                            }
                        }
                    }
                }

                Panel {
                    shell: page.shell
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.shell.compactMode ? 380 : 410

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 1
                            Label {
                                text: "Devices"
                                color: page.shell.primaryText
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: page.shell.liveMode
                                    ? page.shell.devices.length + " live devices · read only"
                                    : page.shell.devices.length + " demo devices · all available"
                                color: page.shell.mutedText
                                font.pixelSize: 12
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "View all"
                            icon.name: "go-next"
                            onClicked: page.shell.navigate("devices")
                        }
                    }

                    Repeater {
                        model: page.deviceKeys.length

                        delegate: AbstractButton {
                            id: deviceButton
                            required property int index
                            readonly property var device: page.deviceForKey(String(page.deviceKeys[index]))
                            Layout.fillWidth: true
                            implicitHeight: page.shell.compactMode ? 62 : 70
                            leftPadding: page.shell.compactMode ? 12 : 16
                            rightPadding: page.shell.compactMode ? 12 : 16
                            topPadding: page.shell.compactMode ? 8 : 10
                            bottomPadding: page.shell.compactMode ? 8 : 10
                            hoverEnabled: true
                            onClicked: page.shell.selectDevice(device.id)

                            background: Rectangle {
                                radius: Math.max(6, page.shell.cornerRadius - 4)
                                color: parent.hovered ? page.shell.surfaceHover : page.shell.surfaceAlt
                                border.color: page.shell.outline
                            }

                            contentItem: RowLayout {
                                spacing: 12

                                IconSlot {
                                    source: deviceButton.device.icon
                                    color: page.shell.secondaryText
                                    iconSize: 27
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignLeft
                                        text: deviceButton.device.name
                                        color: page.shell.primaryText
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignLeft
                                        text: deviceButton.device.subtitle
                                        color: page.shell.mutedText
                                        font.pixelSize: 11
                                    }
                                }

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: deviceButton.device.connected === false
                                        ? page.shell.warningColor
                                        : page.shell.successColor
                                }
                            }
                        }
                    }
                }
            }

            Panel {
                shell: page.shell
                Layout.fillWidth: true

                Label {
                    text: page.shell.liveMode ? "Local previews" : "Quick actions"
                    color: page.shell.primaryText
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width > 900 ? 4 : 2
                    columnSpacing: page.shell.cardSpacing
                    rowSpacing: page.shell.cardSpacing

                    Repeater {
                        model: [
                            { label: "Quiet Focus", detail: "Activate the complete quiet global profile", icon: "weather-clear-night", action: "quiet" },
                            { label: "Lights out", detail: "Toggle the mock lighting state", icon: "brightness-low", action: "lights" },
                            { label: "Manage profiles", detail: "Coordinate settings and launch rules", icon: "document-multiple", action: "profiles" },
                            { label: "Review alerts", detail: "No current mock warnings", icon: "notifications", action: "alerts" }
                        ]

                        delegate: Button {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 78
                            text: modelData.label
                            icon.name: modelData.icon
                            onClicked: {
                                if (modelData.action === "quiet") page.shell.previewGlobalProfile("quiet")
                                else if (modelData.action === "devices") page.shell.navigate("devices")
                                else if (modelData.action === "profiles") page.shell.navigate("profiles")
                                else if (modelData.action === "lights") {
                                    page.shell.lightsEnabled = !page.shell.lightsEnabled
                                    page.shell.showToast(
                                        page.shell.lightsEnabled ? "Lighting preview restored" : "Lighting preview disabled",
                                        "Only the mock interface changed."
                                    )
                                } else {
                                    page.shell.showToast(
                                        page.shell.backendClient.errorMessage.length > 0
                                            ? "Some live data is unavailable"
                                            : "No connection alerts",
                                        page.shell.backendClient.errorMessage.length > 0
                                            ? page.shell.backendClient.errorMessage
                                            : "The read-only service connection reports normally."
                                    )
                                }
                            }

                            ToolTip.visible: hovered
                            ToolTip.text: modelData.detail
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 1 }
        }
    }
}
