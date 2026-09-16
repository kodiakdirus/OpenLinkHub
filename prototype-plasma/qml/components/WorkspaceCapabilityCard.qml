import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Panel {
    id: card
    objectName: "workspaceCapabilityCard"
    required property var capability
    readonly property var copy: ({
        DPI: {title: "Sensitivity", detail: "DPI stages and pointer range", missing: "The service does not report DPI values for this device yet."},
        Buttons: {title: "Button assignments", detail: "Mouse buttons and shortcuts", missing: "Button assignments are not reported by the service yet."},
        Keys: {title: "Keyboard", detail: "Key assignments and keyboard behavior", missing: "Key assignments are not reported by the service yet."},
        Performance: {title: "Polling & performance", detail: "Input reporting options", missing: "Polling settings are not reported by the service yet."},
        Display: {title: "LCD display", detail: "Display capabilities", missing: "Display settings are not reported by the service yet."},
        Audio: {title: "Headset audio", detail: "Audio settings and controls", missing: "Audio settings are not reported by the service yet."},
        Actuation: {title: "Key actuation", detail: "Key travel and activation", missing: "Actuation settings are not reported by the service yet."},
        Controls: {title: "Controller inputs", detail: "Button and stick settings", missing: "Controller settings are not reported by the service yet."},
        Analog: {title: "Analog response", detail: "Stick response and dead zones", missing: "Analog settings are not reported by the service yet."},
        Vibration: {title: "Vibration", detail: "Controller feedback", missing: "Vibration settings are not reported by the service yet."},
        Pairing: {title: "Wireless pairing", detail: "Receiver and paired devices", missing: "Paired-device details are not reported by the service yet."}
    })[capability.name] || ({title: capability.name || "Settings", detail: "Reported device settings", missing: "Detailed settings are not reported by the service yet."})
    readonly property var reportedItems: {
        const items = []
        ;(capability.groups || []).forEach(group => (group.items || []).forEach(item => {
            const value = String(item.value === undefined ? "" : item.value).trim()
            // Consolidate missing values and capability-only placeholders.
            // The complete diagnostic view remains available under Devices.
            if (!value || value === "Not reported" || value === "Unavailable"
                || /^[—–-]+$/.test(value) || (item.description || "").indexOf("Detailed read mapping") >= 0) return
            items.push({title: item.title, value: value})
        }))
        return items
    }

    PanelHeader {
        shell: card.shell
        iconName: card.capability.icon || "preferences-system"
        title: card.copy.title
        subtitle: card.copy.detail
    }
    Label {
        visible: card.reportedItems.length === 0
        Layout.fillWidth: true
        text: card.copy.missing
        color: card.shell.mutedText
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: card.reportedItems
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 18
            Label {
                Layout.fillWidth: true
                text: modelData.title
                color: card.shell.secondaryText
                wrapMode: Text.WordWrap
            }
            Label {
                Layout.maximumWidth: card.width * 0.5
                text: modelData.value
                color: card.shell.primaryText
                font.weight: Font.DemiBold
                wrapMode: Text.WrapAnywhere
            }
        }
    }
}
