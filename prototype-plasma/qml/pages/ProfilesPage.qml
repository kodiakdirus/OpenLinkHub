import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../components"

Item {
    id: page

    required property var shell
    property int selectedProfile: 1
    property int activeTab: 0
    property var launchRules: [
        {
            program: "Cyberpunk 2077",
            match: "Cyberpunk2077.exe",
            profile: "Gaming",
            kind: "Game",
            enabled: true
        },
        {
            program: "Steam Big Picture",
            match: "steam -gamepadui",
            profile: "Gaming",
            kind: "Application",
            enabled: true
        },
        {
            program: "Kdenlive",
            match: "kdenlive",
            profile: "Balanced",
            kind: "Application",
            enabled: false
        }
    ]

    function openPrimaryDialog() {
        profileName.text = ""
        profileDialog.open()
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: page.shell.sectionSpacing

            Panel {
                shell: page.shell
                Layout.fillWidth: true
                color: Qt.rgba(page.shell.accentColor.r, page.shell.accentColor.g, page.shell.accentColor.b, 0.07)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 54
                        radius: 15
                        color: Qt.rgba(page.shell.accentColor.r, page.shell.accentColor.g, page.shell.accentColor.b, 0.14)

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 31
                            height: 31
                            source: "document-multiple"
                            color: page.shell.accentColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: "Global profiles"
                            color: page.shell.primaryText
                            font.pixelSize: 21
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "One profile can coordinate cooling, lighting, input, audio, and displays without pretending those are the same kind of setting."
                            color: page.shell.mutedText
                            wrapMode: Text.WordWrap
                        }
                    }

                    StatusBadge {
                        shell: page.shell
                        text: "Prototype concept"
                        badgeColor: page.shell.warningColor
                        filled: true
                    }
                }
            }

            TabBar {
                id: tabs
                Layout.fillWidth: true
                currentIndex: page.activeTab
                onCurrentIndexChanged: page.activeTab = currentIndex

                TabButton {
                    text: "Profiles"
                    icon.name: "document-multiple"
                }
                TabButton {
                    text: "Automatic switching"
                    icon.name: "system-run"
                }
            }

            StackLayout {
                Layout.fillWidth: true
                currentIndex: page.activeTab

                ColumnLayout {
                    spacing: page.shell.sectionSpacing

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            text: "Profile library"
                            color: page.shell.primaryText
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "New global profile"
                            icon.name: "list-add"
                            highlighted: true
                            onClicked: {
                                profileName.text = ""
                                startingPoint.currentIndex = 1
                                profileDialog.open()
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width > 980 ? 2 : 1
                        columnSpacing: page.shell.cardSpacing
                        rowSpacing: page.shell.cardSpacing

                        Repeater {
                            model: page.shell.globalProfiles

                            delegate: AbstractButton {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: page.shell.compactMode ? 210 : 230
                                padding: page.shell.contentPadding
                                hoverEnabled: true
                                onClicked: page.selectedProfile = index

                                background: Rectangle {
                                    radius: page.shell.cornerRadius
                                    color: page.selectedProfile === index
                                        ? page.shell.surfaceHover
                                        : page.shell.surface
                                    border.width: page.selectedProfile === index ? 2 : 1
                                    border.color: page.selectedProfile === index
                                        ? modelData.color
                                        : page.shell.outline
                                }

                                contentItem: ColumnLayout {
                                    spacing: 12

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Rectangle {
                                            Layout.preferredWidth: 12
                                            Layout.preferredHeight: 42
                                            radius: 6
                                            color: modelData.color
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Label {
                                                text: modelData.name
                                                color: page.shell.primaryText
                                                font.pixelSize: 18
                                                font.weight: Font.DemiBold
                                            }
                                            Label {
                                                Layout.fillWidth: true
                                                text: modelData.description
                                                color: page.shell.mutedText
                                                font.pixelSize: 12
                                                wrapMode: Text.WordWrap
                                            }
                                        }

                                        StatusBadge {
                                            visible: modelData.automatic
                                            shell: page.shell
                                            text: "Has launch rule"
                                            badgeColor: page.shell.accentColor
                                        }
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: modelData.sections
                                            delegate: StatusBadge {
                                                required property var modelData
                                                shell: page.shell
                                                text: modelData
                                                badgeColor: page.shell.mutedText
                                            }
                                        }
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.composition
                                        color: page.shell.secondaryText
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Item { Layout.fillHeight: true }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: page.shell.outline
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Button {
                                            text: "Edit"
                                            icon.name: "document-edit"
                                            onClicked: {
                                                profileName.text = modelData.name
                                                profileDialog.open()
                                            }
                                        }
                                        Button {
                                            text: "Duplicate"
                                            icon.name: "edit-copy"
                                            onClicked: {
                                                page.shell.globalProfiles = page.shell.globalProfiles.concat([{
                                                    key: modelData.key + "-copy-" + Date.now(),
                                                    name: modelData.name + " copy",
                                                    description: modelData.description,
                                                    color: modelData.color,
                                                    automatic: false,
                                                    sections: modelData.sections,
                                                    composition: modelData.composition
                                                }])
                                                page.shell.markDirty("Global profile copy")
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Button {
                                            text: page.shell.activeGlobalProfile === modelData.key ? "Active" : "Activate"
                                            icon.name: page.shell.activeGlobalProfile === modelData.key ? "dialog-ok" : "media-playback-start"
                                            highlighted: page.shell.activeGlobalProfile === modelData.key
                                            onClicked: {
                                                page.selectedProfile = index
                                                page.shell.previewGlobalProfile(modelData.key)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    spacing: page.shell.sectionSpacing

                    Panel {
                        shell: page.shell
                        Layout.fillWidth: true

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    text: "Application-aware profile switching"
                                    color: page.shell.primaryText
                                    font.pixelSize: 20
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    text: "Match a running game or program and activate its complete global profile."
                                    color: page.shell.mutedText
                                }
                            }
                            Switch {
                                text: checked ? "Enabled" : "Disabled"
                                checked: true
                                onToggled: page.shell.markDirty("Automatic profile switching")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            StatusBadge {
                                shell: page.shell
                                text: "Future service/client contract"
                                badgeColor: page.shell.warningColor
                                filled: true
                            }
                            Label {
                                Layout.fillWidth: true
                                text: "The prototype can model these rules, but process detection and conflict policy are not verified backend features yet."
                                color: page.shell.mutedText
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Launch rules"
                            color: page.shell.primaryText
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Add game or program"
                            icon.name: "list-add"
                            highlighted: true
                            onClicked: {
                                ruleName.text = ""
                                ruleMatch.text = ""
                                ruleDialog.open()
                            }
                        }
                    }

                    Repeater {
                        model: page.launchRules

                        delegate: Panel {
                            required property var modelData
                            shell: page.shell
                            Layout.fillWidth: true

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Rectangle {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    radius: 13
                                    color: page.shell.surfaceAlt
                                    border.color: page.shell.outline

                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        width: 27
                                        height: 27
                                        source: modelData.kind === "Game" ? "input-gaming" : "application-x-executable"
                                        color: page.shell.accentColor
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Label {
                                        text: modelData.program
                                        color: page.shell.primaryText
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        text: modelData.kind + " · Match: " + modelData.match
                                        color: page.shell.mutedText
                                        font.pixelSize: 12
                                    }
                                }

                                Label {
                                    text: "→"
                                    color: page.shell.mutedText
                                    font.pixelSize: 20
                                }

                                ComboBox {
                                    model: page.shell.globalProfiles.map(profile => profile.name)
                                    currentIndex: Math.max(0, model.indexOf(modelData.profile))
                                    Layout.preferredWidth: 190
                                    onActivated: page.shell.markDirty(modelData.program + " rule")
                                }

                                Switch {
                                    checked: modelData.enabled
                                    onToggled: page.shell.markDirty(modelData.program + " rule")
                                }

                                ToolButton {
                                    icon.name: "document-edit"
                                    onClicked: {
                                        ruleName.text = modelData.program
                                        ruleMatch.text = modelData.match
                                        ruleDialog.open()
                                    }
                                }
                            }
                        }
                    }

                    Panel {
                        shell: page.shell
                        Layout.fillWidth: true

                        RowLayout {
                            Layout.fillWidth: true
                            Kirigami.Icon {
                                source: "dialog-information"
                                color: page.shell.accentColor
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                            }
                            Label {
                                Layout.fillWidth: true
                                text: "Conflict policy preview: the most recently focused matching program wins; when it exits, return to the previous profile."
                                color: page.shell.secondaryText
                                wrapMode: Text.WordWrap
                            }
                            Button {
                                text: "Rule priority"
                                onClicked: page.shell.showToast(
                                    "Rule priority",
                                    "A production manager would support ordering, exclusions, and restoration policy."
                                )
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Revert"
                    enabled: page.shell.pendingChanges
                    onClicked: page.shell.revertChanges()
                }
                Button {
                    text: page.shell.pendingChanges ? "Apply profile changes" : "No pending changes"
                    icon.name: "dialog-ok-apply"
                    highlighted: true
                    enabled: page.shell.pendingChanges
                    onClicked: page.shell.applyChanges()
                }
            }

            Item { Layout.preferredHeight: 1 }
        }
    }

    Dialog {
        id: profileDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(820, parent.width - 60)
        height: Math.min(760, parent.height - 60)
        modal: true
        title: profileName.text.length > 0 ? "Edit global profile" : "New global profile"
        standardButtons: Dialog.Save | Dialog.Cancel

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: page.shell.cardSpacing

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: compositionIntro.implicitHeight + page.shell.contentPadding * 2
                    radius: page.shell.cornerRadius
                    color: Qt.rgba(page.shell.accentColor.r, page.shell.accentColor.g, page.shell.accentColor.b, 0.08)
                    border.color: page.shell.accentColor

                    RowLayout {
                        id: compositionIntro
                        anchors.fill: parent
                        anchors.margins: page.shell.contentPadding
                        spacing: 12

                        Kirigami.Icon {
                            source: "document-multiple"
                            color: page.shell.accentColor
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: "Compose one global profile from saved purpose-specific profiles"
                                color: page.shell.primaryText
                                font.weight: Font.DemiBold
                            }
                            Label {
                                Layout.fillWidth: true
                                text: "The global object references existing cooling, lighting, and per-device profiles; it does not merge them into one ambiguous profile type."
                                color: page.shell.mutedText
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: page.shell.cardSpacing
                    rowSpacing: 10

                    Label { text: "Global profile name"; color: page.shell.secondaryText }
                    TextField {
                        id: profileName
                        Layout.fillWidth: true
                        placeholderText: "Example: Simulation"
                    }

                    Label { text: "Starting point"; color: page.shell.secondaryText }
                    ComboBox {
                        id: startingPoint
                        Layout.fillWidth: true
                        model: page.shell.globalProfiles.map(profile => profile.name).concat(["Blank profile"])
                    }
                }

                Label {
                    text: "Cooling and lighting"
                    color: page.shell.primaryText
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: page.shell.cardSpacing
                    rowSpacing: 10

                    Label { text: "Cooling assignments"; color: page.shell.secondaryText }
                    ComboBox {
                        id: coolingComposition
                        Layout.fillWidth: true
                        model: [
                            "Balanced cooling",
                            "TitanQuiet + Radiator20 + CaseGPU",
                            "Performance cooling",
                            "Keep current assignments"
                        ]
                    }

                    Label { text: "Lighting profile / scene"; color: page.shell.secondaryText }
                    ComboBox {
                        id: lightingComposition
                        Layout.fillWidth: true
                        model: ["Aurora", "Static cyan", "Temperature reactive", "Keep current scene"]
                    }
                }

                Label {
                    text: "Per-device profiles"
                    color: page.shell.primaryText
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: page.shell.cardSpacing
                    rowSpacing: 10

                    Label { text: "K100 AIR RGB"; color: page.shell.secondaryText }
                    ComboBox {
                        id: keyboardComposition
                        Layout.fillWidth: true
                        model: ["Desktop", "Palworld", "Creator", "Keep current"]
                    }

                    Label { text: "Scimitar RGB Elite"; color: page.shell.secondaryText }
                    ComboBox {
                        id: mouseComposition
                        Layout.fillWidth: true
                        model: ["Desktop", "MMO", "Precision", "Keep current"]
                    }

                    Label { text: "Virtuoso Wireless"; color: page.shell.secondaryText }
                    ComboBox {
                        id: audioComposition
                        Layout.fillWidth: true
                        model: ["Pure Direct", "Competitive", "Media", "Keep current"]
                    }

                    Label { text: "SCUF Envision Pro"; color: page.shell.secondaryText }
                    ComboBox {
                        id: controllerComposition
                        Layout.fillWidth: true
                        model: ["Default", "Shooter", "Racing", "Keep current"]
                    }

                    Label { text: "TITAN 360 LCD"; color: page.shell.secondaryText }
                    ComboBox {
                        id: displayComposition
                        Layout.fillWidth: true
                        model: ["Liquid temperature", "Dual sensor", "Clock", "Keep current"]
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Kirigami.Icon {
                        source: "dialog-information"
                        color: page.shell.warningColor
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "Production needs a backend-owned global-profile contract so applying this composition is validated and recoverable as one operation."
                        color: page.shell.mutedText
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        onAccepted: {
            const name = profileName.text.trim().length > 0
                ? profileName.text.trim()
                : "Untitled profile"
            const composition = coolingComposition.currentText
                + " · " + lightingComposition.currentText
                + " · " + keyboardComposition.currentText
                + " / " + mouseComposition.currentText
                + " / " + audioComposition.currentText
            const existingIndex = page.shell.globalProfiles.map(item => item.name).indexOf(name)
            if (existingIndex < 0) {
                page.shell.globalProfiles = page.shell.globalProfiles.concat([{
                    key: name.toLowerCase().replace(/[^a-z0-9]+/g, "-"),
                    name: name,
                    description: "Custom global profile created in the prototype",
                    color: page.shell.accentColor,
                    automatic: false,
                    sections: ["Cooling", "Lighting", "Input", "Audio", "Displays"],
                    composition: composition
                }])
            } else {
                const updated = page.shell.globalProfiles.slice()
                const existing = updated[existingIndex]
                updated[existingIndex] = {
                    key: existing.key,
                    name: existing.name,
                    description: existing.description,
                    color: existing.color,
                    automatic: existing.automatic,
                    sections: existing.sections,
                    composition: composition
                }
                page.shell.globalProfiles = updated
            }
            page.shell.markDirty("Global profile")
        }
    }

    Dialog {
        id: ruleDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(620, parent.width - 60)
        modal: true
        title: ruleName.text.length > 0 ? "Edit launch rule" : "Add game or program"
        standardButtons: Dialog.Save | Dialog.Cancel

        ColumnLayout {
            width: parent.width
            spacing: page.shell.cardSpacing

            Label { text: "Type"; font.weight: Font.DemiBold }
            ComboBox {
                id: ruleKind
                Layout.fillWidth: true
                model: ["Game", "Application"]
            }

            Label { text: "Display name"; font.weight: Font.DemiBold }
            TextField {
                id: ruleName
                Layout.fillWidth: true
                placeholderText: "Example: Blender"
            }

            Label { text: "Process or executable match"; font.weight: Font.DemiBold }
            TextField {
                id: ruleMatch
                Layout.fillWidth: true
                placeholderText: "Example: blender"
            }

            Label { text: "Activate global profile"; font.weight: Font.DemiBold }
            ComboBox {
                id: ruleProfile
                Layout.fillWidth: true
                model: page.shell.globalProfiles.map(profile => profile.name)
            }

            CheckBox {
                text: "Restore the previous profile when the program exits"
                checked: true
            }
        }

        onAccepted: {
            const name = ruleName.text.trim().length > 0 ? ruleName.text.trim() : "New program"
            const match = ruleMatch.text.trim().length > 0 ? ruleMatch.text.trim() : name.toLowerCase()
            page.launchRules = page.launchRules.concat([{
                program: name,
                match: match,
                profile: ruleProfile.currentText,
                kind: ruleKind.currentText,
                enabled: true
            }])
            page.shell.markDirty("Application launch rule")
        }
    }
}
