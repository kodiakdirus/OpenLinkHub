import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: editor

    required property var shell
    required property var device
    required property var modelData

    property string loadedDeviceId: ""
    property string selectedTargetKey: ""
    property string selectedProfileKey: ""
    property string loadedProfileKey: ""
    property real draftSpeed: 1
    property real draftBrightness: 100
    property int draftDirection: 0
    property string draftStartColor: "#000000"
    property string draftMiddleColor: "#000000"
    property string draftEndColor: "#000000"
    property real draftMinTemperature: 0
    property real draftMaxTemperature: 0

    property var targets: []
    property var profiles: []
    property var ownership: ({
        controller: "individual",
        mode: "individual",
        label: "Individual devices",
        description: "Each published target uses its own saved lighting effect.",
        operations: ["read"],
        affectedTargetCount: 0,
        savedIndividualSummary: "No individual lighting targets"
    })
    property string ownershipSignature: ""
    property bool clusterEditorOpen: false
    property bool showIndividualSettings: false
    readonly property bool individualSettingsInactive: ownership.controller === "rgb-cluster"
        || ownership.controller === "openrgb"
    readonly property var clusterRuntime: shell.backendClient.lightingRuntime || ({})
    readonly property bool reportedClusterMember: ownership.controller === "rgb-cluster"
        && (clusterRuntime.members || []).indexOf(device.id || "") >= 0
    readonly property string clusterProfile: reportedClusterMember && typeof clusterRuntime.profile === "string"
        ? clusterRuntime.profile.trim() : ""
    readonly property string clusterScene: clusterProfile
        ? clusterProfile.replace(/[-_]+/g, " ").replace(/\b\w/g, letter => letter.toUpperCase())
        : "Not reported"
    readonly property string clusterRenderer: reportedClusterMember ? clusterRuntime.renderer || "unavailable" : "unavailable"
    property string targetModelSignature: ""
    property string profileModelSignature: ""
    property string profileSource: ""
    property bool commandFeedbackVisible: false
    property bool commandFeedbackListening: false
    property string commandFeedbackStatus: "idle"
    property string commandFeedbackMessage: ""
    readonly property var selectedTarget: targetForKey(selectedTargetKey)
    readonly property var selectedProfile: profileForKey(selectedProfileKey)
    readonly property var selectedOperations: selectedTarget.operations || []
    readonly property var selectedSupportedProfiles: selectedTarget.supportedProfileIds || []
    readonly property bool canAssignSelected: shell.liveMode
        && shell.backendClient.contractVersion === "1.0"
        && selectedOperations.indexOf("assign-profile") >= 0
        && selectedSupportedProfiles.indexOf(selectedProfileKey) >= 0

    spacing: shell.sectionSpacing

    function indexForKey(collection, key) {
        for (let index = 0; index < collection.length; ++index) {
            if (collection[index].key === key) return index
        }
        return -1
    }

    function targetForKey(key) {
        const index = indexForKey(targets, key)
        return index >= 0 ? targets[index] : ({})
    }

    function profileForKey(key) {
        const index = indexForKey(profiles, key)
        return index >= 0 ? profiles[index] : ({})
    }

    function selectProfile(key) {
        if (indexForKey(profiles, key) < 0) return
        selectedProfileKey = key
        loadDraft()
    }

    function selectTarget(index) {
        if (index < 0 || index >= targets.length) return
        selectedTargetKey = targets[index].key
        const active = targets[index].activeProfile || ""
        if (indexForKey(profiles, active) >= 0) selectProfile(active)
    }

    function loadDraft() {
        const profile = profileForKey(selectedProfileKey)
        if (!profile.key) return
        loadedProfileKey = profile.key
        draftSpeed = profile.speed
        draftBrightness = profile.brightness
        draftDirection = profile.direction
        draftStartColor = profile.startColor
        draftMiddleColor = profile.middleColor
        draftEndColor = profile.endColor
        draftMinTemperature = profile.minTemperature
        draftMaxTemperature = profile.maxTemperature
    }

    function reconcileModel() {
        const incomingTargets = modelData.targets || []
        const incomingProfiles = modelData.profiles || []
        const incomingOwnership = modelData.ownership || editor.ownership
        const nextTargetSignature = JSON.stringify(incomingTargets.map(target => [
            target.key,
            target.name,
            target.description,
            target.activeProfile,
            target.supportedProfileIds,
            target.operations
        ]))
        const nextProfileSignature = JSON.stringify(incomingProfiles.map(profile => [
            profile.key,
            profile.name,
            profile.speed,
            profile.brightness,
            profile.smoothness,
            profile.startColor,
            profile.middleColor,
            profile.endColor,
            profile.gradientColors,
            profile.minTemperature,
            profile.maxTemperature,
            profile.direction,
            profile.alternateColors,
            profile.perLed,
            profile.temperatureReactive
        ]))
        const nextOwnershipSignature = JSON.stringify(incomingOwnership)

        if (nextTargetSignature !== targetModelSignature) {
            targetModelSignature = nextTargetSignature
            targets = incomingTargets
        }
        if (nextProfileSignature !== profileModelSignature) {
            profileModelSignature = nextProfileSignature
            profiles = incomingProfiles
        }
        if (nextOwnershipSignature !== ownershipSignature) {
            ownershipSignature = nextOwnershipSignature
            ownership = incomingOwnership
        }
        profileSource = modelData.source || "Device-filtered OpenLinkHub profile library"

        const nextDeviceId = device.id || ""
        if (loadedDeviceId !== nextDeviceId) {
            loadedDeviceId = nextDeviceId
            showIndividualSettings = false
            selectedTargetKey = ""
            selectedProfileKey = ""
            loadedProfileKey = ""
        }

        if (indexForKey(targets, selectedTargetKey) < 0 && targets.length > 0) {
            selectedTargetKey = targets[0].key
        }

        const target = targetForKey(selectedTargetKey)
        if (indexForKey(profiles, selectedProfileKey) < 0) {
            selectedProfileKey = indexForKey(profiles, target.activeProfile) >= 0
                ? target.activeProfile
                : profiles.length > 0 ? profiles[0].key : ""
        }

        if (loadedProfileKey !== selectedProfileKey) loadDraft()
    }

    onModelDataChanged: Qt.callLater(reconcileModel)
    onDeviceChanged: Qt.callLater(reconcileModel)
    Component.onCompleted: reconcileModel()

    Connections {
        target: editor.shell.backendClient

        function onCommandChanged() {
            if (!editor.commandFeedbackListening) return
            editor.commandFeedbackStatus = editor.shell.backendClient.commandStatus
            editor.commandFeedbackMessage = editor.shell.backendClient.commandMessage
            if (!editor.shell.backendClient.commandBusy
                    && editor.commandFeedbackStatus !== "working") {
                editor.commandFeedbackListening = false
            }
        }
    }

    LightingRuntimeCard {
        shell: editor.shell
        deviceId: editor.device.id || ""
        visible: editor.shell.liveMode
    }

    LightingOwnershipCard {
        shell: editor.shell
        ownership: editor.ownership
        targets: editor.targets
        clusterScene: editor.clusterScene
        clusterRenderer: editor.clusterRenderer
        onReviewRequested: ownershipDialog.open()
        onClusterEditorRequested: editor.clusterEditorOpen = true
    }

    LightingClusterEditor {
        visible: editor.clusterEditorOpen && editor.ownership.controller === "rgb-cluster"
        shell: editor.shell
        ownership: editor.ownership
        targets: editor.targets
        availableDevices: editor.shell.devices
        clusterScene: editor.clusterScene
        clusterRenderer: editor.clusterRenderer
        onEditMembersRequested: clusterMembersDialog.openEditor()
        onCloseRequested: editor.clusterEditorOpen = false
    }

    LightingOwnershipDialog {
        id: ownershipDialog
        shell: editor.shell
        device: editor.device
        ownership: editor.ownership
        targets: editor.targets
    }

    LightingClusterMembersDialog {
        id: clusterMembersDialog
        shell: editor.shell
        availableDevices: editor.shell.devices
    }

    Button {
        visible: editor.individualSettingsInactive
        text: editor.showIndividualSettings ? "Hide saved individual effects" : "Show saved individual effects (inactive)"
        icon.name: editor.showIndividualSettings ? "arrow-up" : "arrow-down"
        onClicked: editor.showIndividualSettings = !editor.showIndividualSettings
    }

    GridLayout {
        objectName: "individualLightingSettings"
        visible: !editor.individualSettingsInactive || editor.showIndividualSettings
        Layout.fillWidth: true
        columns: width > 960 ? 2 : 1
        columnSpacing: editor.shell.cardSpacing
        rowSpacing: editor.shell.cardSpacing

        Panel {
            shell: editor.shell
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: "preferences-desktop-color"
                    color: editor.shell.accentColor
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label {
                        text: editor.individualSettingsInactive ? "Saved individual lighting" : "Lighting assignment"
                        color: editor.shell.primaryText
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: editor.individualSettingsInactive
                            ? "These effects are inactive while " + (editor.ownership.label || "another controller") + " controls this device."
                            : "Choose a physical target and one effect supported by this device."
                        color: editor.shell.mutedText
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
                StatusBadge {
                    shell: editor.shell
                    text: editor.canAssignSelected ? "Assignment available" : "Read only"
                    badgeColor: editor.canAssignSelected
                        ? editor.shell.successColor
                        : editor.shell.warningColor
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: editor.shell.outline
            }

            Label {
                text: "Target"
                color: editor.shell.secondaryText
                font.weight: Font.DemiBold
            }
            ComboBox {
                Layout.fillWidth: true
                model: editor.targets
                textRole: "name"
                currentIndex: Math.max(0, editor.indexForKey(editor.targets, editor.selectedTargetKey))
                onActivated: editor.selectTarget(currentIndex)
            }
            Label {
                text: editor.selectedTarget.description || "No lighting target reported"
                color: editor.shell.mutedText
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                text: editor.individualSettingsInactive ? "Individual effect (inactive)" : "Effect"
                color: editor.shell.secondaryText
                font.weight: Font.DemiBold
            }
            ComboBox {
                Layout.fillWidth: true
                model: editor.profiles
                textRole: "name"
                currentIndex: Math.max(0, editor.indexForKey(editor.profiles, editor.selectedProfileKey))
                onActivated: {
                    if (currentIndex >= 0 && currentIndex < editor.profiles.length) {
                        editor.selectProfile(editor.profiles[currentIndex].key)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StatusBadge {
                    shell: editor.shell
                    text: editor.profiles.length + " supported effects"
                    badgeColor: editor.shell.accentColor
                }
                StatusBadge {
                    visible: Boolean(editor.selectedProfile.temperatureReactive)
                    shell: editor.shell
                    text: "Sensor reactive"
                    badgeColor: editor.shell.warningColor
                }
                StatusBadge {
                    visible: Boolean(editor.selectedProfile.perLed)
                    shell: editor.shell
                    text: "Per LED"
                    badgeColor: editor.shell.accentColor
                }
                Item { Layout.fillWidth: true }
            }
        }

        Panel {
            shell: editor.shell
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: "document-edit"
                    color: editor.shell.accentColor
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label {
                        text: "Effect controls"
                        color: editor.shell.primaryText
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: "Explore the parameters returned by OpenLinkHub without writing them."
                        color: editor.shell.mutedText
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: editor.shell.outline
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 520 ? 2 : 1
                columnSpacing: 16
                rowSpacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Animation speed · " + (Math.round(editor.draftSpeed * 10) / 10)
                        color: editor.shell.secondaryText
                        font.weight: Font.DemiBold
                    }
                    Slider {
                        from: 0
                        to: 10
                        stepSize: 0.1
                        value: editor.draftSpeed
                        Layout.fillWidth: true
                        onMoved: editor.draftSpeed = value
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Brightness · " + Math.round(editor.draftBrightness) + "%"
                        color: editor.shell.secondaryText
                        font.weight: Font.DemiBold
                    }
                    Slider {
                        from: 0
                        to: 100
                        stepSize: 1
                        value: editor.draftBrightness
                        Layout.fillWidth: true
                        onMoved: editor.draftBrightness = value
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Direction"
                        color: editor.shell.secondaryText
                        font.weight: Font.DemiBold
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["Forward", "Reverse"]
                        currentIndex: Math.max(0, Math.min(1, editor.draftDirection))
                        onActivated: editor.draftDirection = currentIndex
                    }
                }

                ColumnLayout {
                    visible: Boolean(editor.selectedProfile.temperatureReactive)
                    Layout.fillWidth: true
                    Label {
                        text: "Temperature range"
                        color: editor.shell.secondaryText
                        font.weight: Font.DemiBold
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        SpinBox {
                            from: 0
                            to: 100
                            value: Math.round(editor.draftMinTemperature)
                            onValueModified: editor.draftMinTemperature = value
                        }
                        Label {
                            text: "to"
                            color: editor.shell.mutedText
                        }
                        SpinBox {
                            from: 0
                            to: 100
                            value: Math.round(editor.draftMaxTemperature)
                            onValueModified: editor.draftMaxTemperature = value
                        }
                        Label {
                            text: "°C"
                            color: editor.shell.mutedText
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8

                Repeater {
                    model: [
                        { label: "Start", propertyName: "draftStartColor" },
                        { label: "Middle", propertyName: "draftMiddleColor" },
                        { label: "End", propertyName: "draftEndColor" }
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Label {
                            text: modelData.label
                            color: editor.shell.mutedText
                            font.pixelSize: 12
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 6
                            color: editor[modelData.propertyName]
                            border.color: editor.shell.outline
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: editor[modelData.propertyName]
                            selectByMouse: true
                            onTextEdited: editor[modelData.propertyName] = text
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: editor.canAssignSelected
                        ? "Apply assigns the selected stored effect to this target. Parameter edits remain a local preview until profile-definition writes are implemented."
                        : "This target does not publish a guarded lighting assignment operation. Draft parameter edits remain local."
                    color: editor.shell.mutedText
                    wrapMode: Text.WordWrap
                }
                Button {
                    text: "Reset draft"
                    icon.name: "edit-undo"
                    onClicked: editor.loadDraft()
                }
                Button {
                    text: editor.shell.backendClient.commandBusy ? "Applying…" : "Apply effect"
                    icon.name: "dialog-ok-apply"
                    enabled: editor.canAssignSelected
                        && !editor.shell.backendClient.commandBusy
                        && editor.selectedProfileKey !== editor.selectedTarget.activeProfile
                    onClicked: {
                        editor.commandFeedbackVisible = true
                        editor.commandFeedbackListening = true
                        editor.commandFeedbackStatus = "working"
                        editor.commandFeedbackMessage = "Applying lighting effect…"
                        editor.shell.backendClient.assignLightingProfile(
                            editor.device.id,
                            editor.selectedTargetKey,
                            editor.selectedProfileKey
                        )
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: editor.canAssignSelected
                        ? "Assign this existing OpenLinkHub effect and verify it by read-back."
                        : "The backend has not authorized assignment for this target."
                }
            }

            RowLayout {
                visible: editor.commandFeedbackVisible
                Layout.fillWidth: true

                StatusBadge {
                    shell: editor.shell
                    text: editor.commandFeedbackStatus === "working"
                        ? "Applying"
                        : editor.commandFeedbackStatus === "succeeded"
                            ? "Applied"
                            : "Not applied"
                    badgeColor: editor.commandFeedbackStatus === "succeeded"
                        ? editor.shell.successColor
                        : editor.commandFeedbackStatus === "working"
                            ? editor.shell.accentColor
                            : editor.shell.warningColor
                }
                Label {
                    Layout.fillWidth: true
                    text: editor.commandFeedbackMessage
                    color: editor.shell.mutedText
                    wrapMode: Text.WordWrap
                }
            }
        }

        Panel {
            shell: editor.shell
            Layout.fillWidth: true
            Layout.columnSpan: parent.columns

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: "view-list-icons"
                    color: editor.shell.accentColor
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label {
                        text: "Supported effect library"
                        color: editor.shell.primaryText
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: editor.profileSource
                        color: editor.shell.mutedText
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: editor.shell.outline
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 960 ? 4 : width > 620 ? 3 : 2
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: editor.profiles
                    delegate: Button {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.name
                        highlighted: modelData.key === editor.selectedProfileKey
                        onClicked: editor.selectProfile(modelData.key)
                        ToolTip.visible: hovered
                        ToolTip.text: modelData.key
                    }
                }
            }
        }
    }
}
