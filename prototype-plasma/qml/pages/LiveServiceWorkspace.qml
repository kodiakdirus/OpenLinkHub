import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

ScrollView {
    id: page
    objectName: "liveServiceWorkspace"
    required property var shell
    required property string section
    contentWidth: availableWidth
    readonly property bool integrations: section === "integrations"
    readonly property var service: shell.backendClient.serviceInfo
    readonly property var featureNames: ({
        frontend: "Web interface", metrics: "Prometheus metrics", memory: "Memory support",
        openrgb: "OpenRGB", "virtual-gamepad": "Virtual gamepad", motherboard: "Motherboard support",
        "display-geometry": "Display geometry"
    })

    ColumnLayout {
        width: page.availableWidth
        spacing: page.shell.cardSpacing
        Panel {
            shell: page.shell
            Layout.fillWidth: true
            PanelHeader {
                shell: page.shell
                iconName: page.integrations ? "network-connect" : "dialog-information"
                title: page.integrations ? "Service integrations"
                    : page.section === "profiles" ? "Global profiles are not available yet" : "Automation editing is not available yet"
                subtitle: page.integrations ? "Reported by the connected service"
                    : "This client cannot save or activate these settings on your hardware."
            }
            Label {
                Layout.fillWidth: true
                text: page.integrations
                    ? "Integration status is read-only. Enabling integrations and exporting sensors to Plasma System Monitor are not implemented in this client."
                    : page.section === "profiles"
                        ? "Use Cooling to edit existing fan curves and Lighting to manage supported device lighting. Whole-system profile composition and application launch rules still need service support."
                        : "The client does not create schedules or application rules. Existing service automations continue independently."
                color: page.shell.secondaryText
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Button {
                    visible: page.section === "profiles"
                    text: "Fan curves"
                    icon.name: "temperature-normal"
                    onClicked: page.shell.navigate("cooling")
                }
                Button {
                    visible: page.section === "profiles"
                    text: "Lighting"
                    icon.name: "preferences-desktop-color"
                    onClicked: page.shell.navigate("lighting")
                }
                Button {
                    text: "Explore in Demo"
                    enabled: !page.shell.backendClient.commandBusy && !page.shell.backendClient.coolingBusy
                    onClicked: page.shell.backendClient.setMode("demo")
                    ToolTip.visible: hovered
                    ToolTip.text: "Opens simulated controls. Your saved startup data source stays unchanged."
                }
            }
        }
        Panel {
            shell: page.shell
            visible: page.integrations
            Layout.fillWidth: true
            Label {
                text: "Service version: " + (page.service.version || "Not reported")
                color: page.shell.primaryText
            }
            Label {
                visible: !(page.service.features || []).length
                text: "Integration status is not reported by the current connection."
                color: page.shell.mutedText
            }
            Repeater {
                model: page.service.features || []
                delegate: ControlRow {
                    required property var modelData
                    shell: page.shell
                    feature: ({title: page.featureNames[modelData.id] || modelData.id,
                        description: modelData.reason || "Reported service configuration",
                        kind: "stat", value: modelData.available ? "Available" : "Unavailable"})
                }
            }
        }
    }
}
