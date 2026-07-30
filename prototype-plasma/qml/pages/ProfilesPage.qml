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
    property var profiles: [
        {
            name: "Quiet Focus",
            description: "Low-noise cooling, dim static lighting, desktop input mappings",
            color: "#7aa8ff",
            automatic: false,
            sections: ["Cooling", "Lighting", "Input", "Audio"]
        },
        {
            name: "Balanced",
            description: "Everyday cooling, Aurora lighting, standard peripheral settings",
            color: "#66d7c5",
            automatic: true,
            sections: ["Cooling", "Lighting", "Input", "Audio", "Displays"]
        },
        {
            name: "Gaming",
            description: "Performance cooling, game lighting, game-specific input profiles",
            color: "#ee876f",
            automatic: true,
            sections: ["Cooling", "Lighting", "Input", "Audio", "Displays"]
        },
        {
            name: "Creator",
            description: "Balanced cooling, neutral lighting, productivity input mappings, display metrics",
            color: "#e8bd57",
            automatic: false,
            sections: ["Cooling", "Lighting", "Input", "Audio", "Displays"]
        }
    ]
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
                            model: page.profiles

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
                                                page.profiles = page.profiles.concat([{
                                                    name: modelData.name + " copy",
                                                    description: modelData.description,
                                                    color: modelData.color,
                                                    automatic: false,
                                                    sections: modelData.sections
                                                }])
                                                page.shell.markDirty("Global profile copy")
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Button {
                                            text: page.selectedProfile === index ? "Active" : "Activate"
                                            icon.name: page.selectedProfile === index ? "dialog-ok" : "media-playback-start"
                                            highlighted: page.selectedProfile === index
                                            onClicked: {
                                                page.selectedProfile = index
                                                page.shell.previewMode(
                                                    modelData.name === "Gaming" ? "performance"
                                                    : modelData.name === "Quiet Focus" ? "quiet"
                                                    : "balanced"
                                                )
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
                                    model: page.profiles.map(profile => profile.name)
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
        width: Math.min(620, parent.width - 60)
        modal: true
        title: profileName.text.length > 0 ? "Edit global profile" : "New global profile"
        standardButtons: Dialog.Save | Dialog.Cancel

        ColumnLayout {
            width: parent.width
            spacing: page.shell.cardSpacing

            Label {
                Layout.fillWidth: true
                text: "Global profiles reference purpose-specific cooling, lighting, input, audio, and display profiles."
                color: page.shell.mutedText
                wrapMode: Text.WordWrap
            }

            Label { text: "Profile name"; font.weight: Font.DemiBold }
            TextField {
                id: profileName
                Layout.fillWidth: true
                placeholderText: "Example: Simulation"
            }

            Label { text: "Starting point"; font.weight: Font.DemiBold }
            ComboBox {
                id: startingPoint
                Layout.fillWidth: true
                model: ["Quiet Focus", "Balanced", "Gaming", "Blank profile"]
            }

            CheckBox { text: "Include cooling-profile assignments"; checked: true }
            CheckBox { text: "Include lighting scene and brightness"; checked: true }
            CheckBox { text: "Include keyboard, mouse, and controller profiles"; checked: true }
            CheckBox { text: "Include audio and display settings"; checked: true }
        }

        onAccepted: {
            const name = profileName.text.trim().length > 0
                ? profileName.text.trim()
                : "Untitled profile"
            if (page.profiles.map(item => item.name).indexOf(name) < 0) {
                page.profiles = page.profiles.concat([{
                    name: name,
                    description: "Custom global profile created in the prototype",
                    color: page.shell.accentColor,
                    automatic: false,
                    sections: ["Cooling", "Lighting", "Input", "Audio", "Displays"]
                }])
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
                model: page.profiles.map(profile => profile.name)
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
