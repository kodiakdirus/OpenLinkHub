import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page
    objectName: "coolingPage"

    required property var shell
    property var expandedZones: ({})
    property var zoneKeys: []
    property string zoneKeySignature: ""
    property int presentationRevision: 0
    property var firstProfileControl: null
    property bool firstProfilePopupRequested: false
    readonly property bool firstProfilePopupOpened: firstProfileControl
        ? firstProfileControl.popup.opened
        : false
    property var summaryCards: [
        { key: "coolant", label: "Coolant", icon: "temperature-normal" },
        { key: "pump", label: "Pump", icon: "media-playback-start" },
        { key: "fans", label: "Fans", icon: "temperature-normal" }
    ]

    function openPrimaryDialog() {
        shell.liveMode ? liveCoolingProfiles.open() : coolingProfiles.open()
    }

    function openFirstProfilePopup() {
        if (firstProfileControl) firstProfileControl.popup.open()
    }

    function closeFirstProfilePopup() {
        if (firstProfileControl) firstProfileControl.popup.close()
    }

    onFirstProfilePopupRequestedChanged: {
        if (firstProfilePopupRequested)
            openFirstProfilePopup()
        else
            closeFirstProfilePopup()
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
            temperature: "—",
            source: "Unavailable",
            profile: "Not reported",
            profiles: [],
            zeroRpm: false,
            minimum: 0
        })
    }

    function summaryValue(key) {
        if (key === "coolant") return shell.metricValue("coolant")
        if (key === "pump") return shell.zoneRpm("pump")
        if (key === "fans") {
            if (!shell.liveMode) return "6 channels"
            let count = 0
            const zones = shell.coolingZones || []
            for (let index = 0; index < zones.length; ++index) {
                if (zones[index].key === "pump") continue
                const summary = zones[index].channelSummary || ""
                count += summary.length > 0 ? summary.split(",").length : 1
            }
            return count + (count === 1 ? " channel" : " channels")
        }
        return "—"
    }

    function isZoneExpanded(key) {
        return Boolean(expandedZones[key])
    }

    function toggleZone(key) {
        const updated = Object.assign({}, expandedZones)
        updated[key] = !Boolean(updated[key])
        expandedZones = updated
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

    Connections {
        target: page.shell
        function onCoolingZonesChanged() {
            Qt.callLater(page.reconcileZoneKeys)
        }
    }

    Component.onCompleted: reconcileZoneKeys()

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: page.shell.sectionSpacing

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 2
                    Label {
                        text: "Cooling channels"
                        color: page.shell.primaryText
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: "iCUE LINK System Hub · values are simulated"
                        color: page.shell.mutedText
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Manage cooling profiles"
                    icon.name: "document-edit"
                    highlighted: true
                    onClicked: shell.liveMode ? liveCoolingProfiles.open() : coolingProfiles.open()
                }

                ComboBox {
                    model: ["iCUE LINK System Hub", "TITAN 360 LCD"]
                    Layout.preferredWidth: 245
                    onActivated: page.shell.showToast(
                        "Cooling device changed",
                        "The selected mock device is now " + currentText + "."
                    )
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 850 ? 3 : 1
                columnSpacing: page.shell.cardSpacing
                rowSpacing: page.shell.cardSpacing

                Repeater {
                    model: page.summaryCards

                    delegate: Panel {
                        required property var modelData
                        shell: page.shell
                        Layout.fillWidth: true

                        RowLayout {
                            Layout.fillWidth: true
                            Kirigami.Icon {
                            source: modelData.icon
                                color: page.shell.accentColor
                                Layout.preferredWidth: 25
                                Layout.preferredHeight: 25
                            }
                            ColumnLayout {
                                spacing: 1
                                Label {
                                    text: modelData.label
                                    color: page.shell.mutedText
                                    font.pixelSize: 12
                                }
                                Label {
                                    text: page.summaryValue(modelData.key)
                                    color: page.shell.primaryText
                                    font.pixelSize: 20
                                    font.weight: Font.DemiBold
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            Panel {
                shell: page.shell
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Kirigami.Icon {
                        source: "office-chart-line"
                        color: page.shell.accentColor
                        Layout.preferredWidth: 27
                        Layout.preferredHeight: 27
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: "Cooling profile library"
                            color: page.shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: "Create reusable fan and pump curves, then assign them to channels below."
                            color: page.shell.mutedText
                            font.pixelSize: 12
                        }
                    }

                    Flow {
                        spacing: 6
                        StatusBadge {
                            shell: page.shell
                            text: "Radiator 20"
                            badgeColor: page.shell.accentColor
                        }
                        StatusBadge {
                            shell: page.shell
                            text: "GPU Quiet"
                            badgeColor: page.shell.accentColor
                        }
                        StatusBadge {
                            shell: page.shell
                            text: "TITAN Balanced"
                            badgeColor: page.shell.accentColor
                        }
                    }

                    Button {
                        text: "Open curve editor"
                        icon.name: "document-edit"
                        onClicked: shell.liveMode ? liveCoolingProfiles.open() : coolingProfiles.open()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: page.shell.cardSpacing
                Layout.alignment: Qt.AlignTop

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: page.shell.cardSpacing

                    Repeater {
                        model: page.zoneKeys.length

                        delegate: Panel {
                            id: channelCard
                            required property int index
                            readonly property string zoneKey: String(page.zoneKeys[index])
                            readonly property var zone: page.zoneForKey(zoneKey)
                            readonly property bool expanded: page.isZoneExpanded(zoneKey)
                            property var profileChoices: []
                            property string profileSignature: ""
                            shell: page.shell
                            Layout.fillWidth: true

                            function reconcileProfiles() {
                                const choices = zone.profiles || [zone.profile]
                                const nextSignature = JSON.stringify(choices)
                                if (nextSignature === profileSignature) return
                                profileSignature = nextSignature
                                profileChoices = choices
                            }

                            onZoneChanged: reconcileProfiles()
                            Component.onCompleted: reconcileProfiles()

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Rectangle {
                                    Layout.preferredWidth: 54
                                    Layout.preferredHeight: 54
                                    radius: 14
                                    color: page.shell.surfaceAlt
                                    border.color: page.shell.outline

                                    Kirigami.Icon {
                            anchors.centerIn: parent
                                        width: 30
                                        height: 30
                                        source: channelCard.zone.icon
                                        color: page.shell.secondaryText
                                    }
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 150
                                    spacing: 2
                                    Label {
                                        text: channelCard.zone.name
                                        color: page.shell.primaryText
                                        font.pixelSize: 17
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        text: channelCard.zone.temperature + " · " + channelCard.zone.source
                                        color: page.shell.mutedText
                                        font.pixelSize: 12
                                    }
                                    Label {
                                        text: page.shell.zoneRpm(channelCard.zoneKey)
                                        color: page.shell.accentColor
                                        font.weight: Font.DemiBold
                                    }
                                }

                                ComboBox {
                                    model: channelCard.profileChoices
                                    currentIndex: Math.max(0, model.indexOf(channelCard.zone.profile))
                                    Layout.preferredWidth: 160
                                    enabled: !page.shell.liveMode
                                    onActivated: page.shell.markDirty(channelCard.zone.name + " profile")
                                    Component.onCompleted: {
                                        if (channelCard.index === 0)
                                            page.firstProfileControl = this
                                    }
                                    ToolTip.visible: hovered && page.shell.liveMode
                                    ToolTip.text: "Read-only in Phase 1"
                                }

                                CoolingCurve {
                                    visible: channelCard.width > 690
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 150
                                    Layout.maximumWidth: 250
                                    accentColor: page.shell.accentColor
                                    gridColor: page.shell.outline
                                    intensity: channelCard.zoneKey === "pump"
                                        ? 0.9
                                        : channelCard.zoneKey === "case" ? 0.45 : 0.7
                                }

                                Item { Layout.fillWidth: true }

                                StatusBadge {
                                    visible: channelCard.zone.zeroRpm
                                    shell: page.shell
                                    text: "Zero RPM"
                                    badgeColor: page.shell.accentColor
                                }

                                ToolButton {
                                    icon.name: channelCard.expanded ? "arrow-up" : "arrow-down"
                                    onClicked: page.toggleZone(channelCard.zoneKey)
                                    ToolTip.visible: hovered
                                    ToolTip.text: channelCard.expanded ? "Hide channel details" : "Show channel details"
                                }
                            }

                            Rectangle {
                                visible: channelCard.expanded
                                Layout.fillWidth: true
                                height: 1
                                color: page.shell.outline
                            }

                            GridLayout {
                                visible: channelCard.expanded
                                Layout.fillWidth: true
                                columns: width > 620 ? 3 : 1
                                columnSpacing: 20

                                ColumnLayout {
                                    Label {
                                        text: "Minimum output"
                                        color: page.shell.mutedText
                                        font.pixelSize: 12
                                    }
                                    Slider {
                                        from: 0
                                        to: 100
                                        value: channelCard.zone.minimum
                                        Layout.fillWidth: true
                                        onMoved: page.shell.markDirty(channelCard.zone.name + " minimum")
                                    }
                                }

                                ColumnLayout {
                                    Label {
                                        text: "Sensor source"
                                        color: page.shell.mutedText
                                        font.pixelSize: 12
                                    }
                                    ComboBox {
                                        model: ["Coolant temperature", "GPU temperature", "CPU temperature", "Temperature probe"]
                                        currentIndex: channelCard.zone.source.indexOf("GPU") >= 0 ? 1 : 0
                                        Layout.fillWidth: true
                                        onActivated: page.shell.markDirty(channelCard.zone.name + " sensor")
                                    }
                                }

                                ColumnLayout {
                                    Label {
                                        text: "Channel behavior"
                                        color: page.shell.mutedText
                                        font.pixelSize: 12
                                    }
                                    Switch {
                                        text: "Allow zero RPM"
                                        checked: channelCard.zone.zeroRpm
                                        enabled: channelCard.zoneKey !== "pump"
                                        onToggled: page.shell.markDirty(channelCard.zone.name + " zero RPM")
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Revert"
                            enabled: page.shell.pendingChanges
                            onClicked: page.shell.revertChanges()
                        }
                        Button {
                            text: page.shell.pendingChanges ? "Apply changes" : "No pending changes"
                            icon.name: "dialog-ok-apply"
                            enabled: page.shell.pendingChanges
                            highlighted: true
                            onClicked: page.shell.applyChanges()
                        }
                    }
                }

                ColumnLayout {
                    visible: page.width > 970
                    Layout.preferredWidth: 315
                    Layout.alignment: Qt.AlignTop
                    spacing: page.shell.cardSpacing

                    Panel {
                        shell: page.shell
                        Layout.fillWidth: true
                        color: Qt.rgba(page.shell.successColor.r, page.shell.successColor.g, page.shell.successColor.b, 0.10)
                        border.color: Qt.rgba(page.shell.successColor.r, page.shell.successColor.g, page.shell.successColor.b, 0.45)

                        RowLayout {
                            Layout.fillWidth: true
                            Kirigami.Icon {
                            source: "security-high"
                                color: page.shell.successColor
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                            }
                            ColumnLayout {
                                spacing: 1
                                Label {
                                    text: "Coolant protection"
                                    color: page.shell.secondaryText
                                }
                                Label {
                                    text: "Armed"
                                    color: page.shell.successColor
                                    font.pixelSize: 21
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "Independent critical-temperature override"
                            color: page.shell.mutedText
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }

                    Panel {
                        shell: page.shell
                        Layout.fillWidth: true

                        Label {
                            text: "Safety & sources"
                            color: page.shell.primaryText
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }

                        ControlRow {
                            shell: page.shell
                            feature: ({
                                title: "Control source",
                                description: "Primary curve input",
                                kind: "choice",
                                value: "Coolant temperature",
                                choices: ["Coolant temperature", "CPU temperature", "GPU temperature"]
                            })
                        }
                        ControlRow {
                            shell: page.shell
                            feature: ({
                                title: "Zero RPM threshold",
                                description: "Case airflow only",
                                kind: "stat",
                                value: "35°C"
                            })
                        }
                        ControlRow {
                            shell: page.shell
                            feature: ({
                                title: "Failsafe",
                                description: "Critical override output",
                                kind: "stat",
                                value: "100%"
                            })
                        }
                        ControlRow {
                            shell: page.shell
                            showDivider: false
                            feature: ({
                                title: "Live graph",
                                description: "Open mock temperature history",
                                kind: "action",
                                value: "Open",
                                icon: "office-chart-line"
                            })
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 1 }
        }
    }

    CoolingProfilesDialog {
        id: coolingProfiles
        shell: page.shell
    }
    LiveCoolingProfilesDialog {
        id: liveCoolingProfiles
        shell: page.shell
    }

}
