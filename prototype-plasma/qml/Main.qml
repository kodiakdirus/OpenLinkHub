import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "components"
import "pages"

ApplicationWindow {
    id: root

    width: 1500
    height: 900
    minimumWidth: 1120
    minimumHeight: 700
    visible: true
    title: "OpenLinkHub — Plasma Prototype"

    property string activeSection: "overview"
    property bool demoDialog: false
    property bool demoArrange: false
    property string activeGlobalProfile: "balanced"
    property int selectedDeviceIndex: 0
    property bool pendingChanges: false
    property bool lightsEnabled: true

    property string themeMode: "Dark"
    property color accentColor: "#66d7c5"
    property bool compactMode: false
    property bool sidebarLabels: true
    property int cornerRadius: 11

    readonly property int contentPadding: compactMode ? 13 : 17
    readonly property int cardSpacing: compactMode ? 10 : 14
    readonly property int sectionSpacing: compactMode ? 12 : 17
    readonly property color backgroundColor: themeMode === "Light"
        ? "#eef2f5"
        : themeMode === "Dim" ? "#192129" : "#0e151b"
    readonly property color sidebarColor: themeMode === "Light"
        ? "#e3e9ee"
        : themeMode === "Dim" ? "#141c23" : "#0b1116"
    readonly property color surface: themeMode === "Light"
        ? "#ffffff"
        : themeMode === "Dim" ? "#212c35" : "#151f27"
    readonly property color surfaceAlt: themeMode === "Light"
        ? "#f3f6f8"
        : themeMode === "Dim" ? "#27343e" : "#1b2730"
    readonly property color surfaceHover: themeMode === "Light"
        ? "#e8eef2"
        : themeMode === "Dim" ? "#30404c" : "#23323d"
    readonly property color outline: themeMode === "Light"
        ? "#ccd5dc"
        : themeMode === "Dim" ? "#3c4b56" : "#2b3a44"
    readonly property color primaryText: themeMode === "Light" ? "#172129" : "#eef4f6"
    readonly property color secondaryText: themeMode === "Light" ? "#43515b" : "#c4d0d6"
    readonly property color mutedText: themeMode === "Light" ? "#687781" : "#84949e"
    readonly property color successColor: "#73d575"
    readonly property color warningColor: "#e7b85c"
    readonly property color dangerColor: "#ee7278"
    readonly property var currentDevice: devices[selectedDeviceIndex]

    onDemoDialogChanged: {
        if (demoDialog) {
            Qt.callLater(function() {
                if (pageLoader.item && pageLoader.item.openPrimaryDialog) {
                    pageLoader.item.openPrimaryDialog()
                }
            })
        }
    }

    onDemoArrangeChanged: {
        if (demoArrange) {
            Qt.callLater(function() {
                if (pageLoader.item && pageLoader.item.openLayoutEditor) {
                    pageLoader.item.openLayoutEditor()
                }
            })
        }
    }

    palette.window: backgroundColor
    palette.windowText: primaryText
    palette.base: surface
    palette.alternateBase: surfaceAlt
    palette.text: primaryText
    palette.placeholderText: mutedText
    palette.button: surfaceAlt
    palette.buttonText: primaryText
    palette.highlight: accentColor
    palette.highlightedText: "#081214"
    palette.toolTipBase: surfaceAlt
    palette.toolTipText: primaryText

    property var navItems: [
        { key: "overview", label: "Overview", icon: "view-grid" },
        { key: "profiles", label: "Profiles", icon: "document-multiple" },
        { key: "devices", label: "Devices", icon: "drive-multidisk" },
        { key: "cooling", label: "Cooling", icon: "temperature-normal" },
        { key: "lighting", label: "Lighting", icon: "preferences-desktop-color" },
        { key: "input", label: "Input", icon: "input-keyboard" },
        { key: "audio", label: "Audio", icon: "audio-headphones" },
        { key: "displays", label: "Displays", icon: "video-display" },
        { key: "automations", label: "Automations", icon: "system-run" },
        { key: "integrations", label: "Integrations", icon: "network-connect" },
        { key: "service", label: "Service", icon: "preferences-system" }
    ]

    property var overviewMetrics: [
        { key: "cpu", label: "CPU", detail: "Ryzen processor", icon: "cpu", state: "Normal" },
        { key: "gpu", label: "GPU", detail: "Radeon graphics", icon: "video-card-inactive", state: "Normal" },
        { key: "coolant", label: "Coolant", detail: "TITAN 360 LCD", icon: "temperature-normal", state: "Stable" },
        { key: "acoustics", label: "Acoustics", detail: "Estimated from mock curves", icon: "audio-volume-low", state: "Good" }
    ]

    property var globalProfiles: [
        {
            key: "quiet",
            name: "Quiet Focus",
            description: "Low-noise cooling, dim static lighting, and desktop device profiles",
            color: "#7aa8ff",
            automatic: false,
            sections: ["Cooling", "Lighting", "Input", "Audio"],
            composition: "TitanQuiet · Static cyan · Desktop devices"
        },
        {
            key: "balanced",
            name: "Balanced",
            description: "Everyday cooling, Aurora lighting, and standard peripheral settings",
            color: "#66d7c5",
            automatic: true,
            sections: ["Cooling", "Lighting", "Input", "Audio", "Displays"],
            composition: "Balanced cooling · Aurora · Desktop devices"
        },
        {
            key: "gaming",
            name: "Gaming",
            description: "Performance cooling, game lighting, and game-specific device profiles",
            color: "#ee876f",
            automatic: true,
            sections: ["Cooling", "Lighting", "Input", "Audio", "Displays"],
            composition: "Performance cooling · Temperature · Gaming devices"
        },
        {
            key: "creator",
            name: "Creator",
            description: "Balanced cooling, neutral lighting, productivity mappings, and display metrics",
            color: "#e8bd57",
            automatic: false,
            sections: ["Cooling", "Lighting", "Input", "Audio", "Displays"],
            composition: "Balanced cooling · Static cyan · Creator devices"
        }
    ]

    property var profileTelemetry: ({
        quiet: {
            cpu: "49°C", gpu: "54°C", coolant: "39°C", acoustics: "Very quiet",
            radiator: "610 RPM", case: "0 RPM", pump: "1,420 RPM"
        },
        balanced: {
            cpu: "47°C", gpu: "51°C", coolant: "38°C", acoustics: "Quiet",
            radiator: "720 RPM", case: "0 RPM", pump: "1,460 RPM"
        },
        gaming: {
            cpu: "42°C", gpu: "46°C", coolant: "35°C", acoustics: "Audible",
            radiator: "1,180 RPM", case: "920 RPM", pump: "1,890 RPM"
        },
        creator: {
            cpu: "46°C", gpu: "50°C", coolant: "37°C", acoustics: "Custom",
            radiator: "760 RPM", case: "0 RPM", pump: "1,500 RPM"
        }
    })

    property var coolingZones: [
        {
            key: "radiator", name: "Radiator", icon: "temperature-normal",
            source: "Coolant", temperature: "38°C", profile: "Radiator 20",
            profiles: ["Radiator 20", "Quiet", "Balanced", "Performance", "Custom curve"],
            zeroRpm: false, minimum: 20
        },
        {
            key: "case", name: "Case Airflow", icon: "temperature-normal",
            source: "GPU", temperature: "34°C", profile: "GPU Quiet",
            profiles: ["GPU Quiet", "Balanced", "Performance", "Custom curve"],
            zeroRpm: true, minimum: 0
        },
        {
            key: "pump", name: "TITAN Pump", icon: "media-playback-start",
            source: "Coolant", temperature: "38°C", profile: "Balanced",
            profiles: ["Quiet", "Balanced", "Performance", "TITAN custom"],
            zeroRpm: false, minimum: 31
        }
    ]

    property var devices: [
        {
            id: "hub", name: "iCUE LINK System Hub", icon: "drive-multidisk",
            subtitle: "USB · Firmware 3.10.636 · 7 channels",
            capabilities: ["Cooling", "Lighting", "Topology", "Sensors"],
            tabs: deviceTabs("hub")
        },
        {
            id: "titan", name: "TITAN 360 LCD", icon: "temperature-normal",
            subtitle: "LINK · Coolant 38°C · Pump 1,460 RPM",
            capabilities: ["Cooling", "LCD", "Lighting", "Protection"],
            tabs: deviceTabs("titan")
        },
        {
            id: "keyboard", name: "K100 AIR RGB", icon: "input-keyboard",
            subtitle: "Wireless · Battery 82% · Active profile Desktop",
            capabilities: ["Keys", "Actuation", "Lighting", "Macros"],
            tabs: deviceTabs("keyboard")
        },
        {
            id: "mouse", name: "Scimitar RGB Elite", icon: "input-mouse",
            subtitle: "USB · 1,000 Hz · 1,600 DPI",
            capabilities: ["Buttons", "DPI", "Lighting", "Performance"],
            tabs: deviceTabs("mouse")
        },
        {
            id: "headset", name: "Virtuoso Wireless", icon: "audio-headphones",
            subtitle: "Slipstream · Battery 68% · Stereo",
            capabilities: ["Audio", "Buttons", "Lighting", "Power"],
            tabs: deviceTabs("headset")
        },
        {
            id: "controller", name: "SCUF Envision Pro", icon: "input-gaming",
            subtitle: "USB · XInput emulation · Profile Default",
            capabilities: ["Controls", "Analog", "Vibration", "Lighting"],
            tabs: deviceTabs("controller")
        },
        {
            id: "receiver", name: "Slipstream Receiver", icon: "network-wireless",
            subtitle: "USB · 2 paired devices",
            capabilities: ["Pairing", "Wireless", "Battery"],
            tabs: deviceTabs("receiver")
        }
    ]

    function control(title, description, kind, value, choices, extra) {
        const item = {
            title: title,
            description: description || "",
            kind: kind || "stat",
            value: value
        }
        if (choices) item.choices = choices
        if (extra) {
            for (const key in extra) item[key] = extra[key]
        }
        return item
    }

    function group(title, icon, description, items, badge, experimental) {
        return {
            title: title,
            icon: icon,
            description: description || "",
            items: items || [],
            badge: badge || "",
            experimental: Boolean(experimental)
        }
    }

    function tab(name, icon, groups) {
        return { name: name, icon: icon, groups: groups }
    }

    function deviceTabs(kind) {
        const overview = deviceName => tab("Overview", "view-grid", [
            group("Status", "dialog-ok", "Current mock health and identity.", [
                control("Connection", "Transport state", "stat", "Connected · mock", null, { accent: true }),
                control("Firmware", "Reported device firmware", "stat", kind === "hub" ? "3.10.636" : "Current"),
                control("Active device snapshot", "Purpose-specific device state", "choice", "Desktop", ["Desktop", "Gaming", "Quiet"])
            ]),
            group("Actions", "system-run", "Safe shortcuts for this device.", [
                control("Identify device", "Flash supported lighting zones", "action", "Identify", null, { icon: "visibility" }),
                control("Save snapshot", "Store current mock presentation", "action", "Save", null, { icon: "document-save" })
            ])
        ])

        if (kind === "hub") return [
            overview("iCUE LINK System Hub"),
            tab("Cooling", "temperature-normal", [
                group("Channel assignments", "temperature-normal", "Profiles are assigned per physical channel.", [
                    control("Radiator fans", "Channels 13, 14, and 17", "choice", "Radiator 20", ["Radiator 20", "Quiet", "Balanced", "Performance"]),
                    control("Case airflow", "Channels 15, 16, and 18", "choice", "GPU Quiet", ["GPU Quiet", "Balanced", "Performance"]),
                    control("Pump", "Channel 2", "choice", "Balanced", ["Quiet", "Balanced", "Performance", "TITAN custom"])
                ]),
                group("Protection", "security-high", "Independent safety behavior stays distinct from ordinary curves.", [
                    control("Critical coolant override", "All outputs switch to failsafe", "stat", "Armed", null, { accent: true }),
                    control("Failsafe output", "Critical-temperature response", "stat", "100%")
                ])
            ]),
            tab("Lighting", "preferences-desktop-color", [
                group("LINK lighting", "preferences-desktop-color", "Attached lighting zones and adapters.", [
                    control("Active scene", "All attached RGB devices", "choice", "Aurora", ["Aurora", "Static", "Temperature", "Off"]),
                    control("Brightness", "Global hub output", "slider", 70, null, { from: 0, to: 100, unit: "%" }),
                    control("Hardware lighting", "Used outside active software control", "toggle", true)
                ])
            ]),
            tab("Topology", "view-list-tree", [
                group("LINK chain", "view-list-tree", "Physical ordering informs labels and sequential effects.", [
                    control("Port 1", "Pump, radiator fans, LCD", "stat", "5 devices"),
                    control("Port 2", "Case fans", "stat", "3 devices"),
                    control("Arrange devices", "Edit physical order", "action", "Arrange", null, { icon: "transform-move" })
                ]),
                group("External devices", "network-connect", "Strips, adapters, and ARGB definitions.", [
                    control("Link adapter", "External lighting bridge", "toggle", false),
                    control("External device type", "Mock ARGB definition", "choice", "LED strip", ["LED strip", "Fan", "Pump", "Custom"]),
                    control("LED amount", "Addressable LED count", "slider", 30, null, { from: 1, to: 120, unit: "" })
                ])
            ]),
            tab("Sensors", "temperature-normal", [
                group("Telemetry", "office-chart-line", "Sources exposed by the hub and connected cooler.", [
                    control("Coolant temperature", "TITAN sensor", "stat", "38°C", null, { accent: true }),
                    control("Temperature probe 1", "Unassigned probe", "stat", "31°C"),
                    control("Temperature probe 2", "Unassigned probe", "stat", "—")
                ]),
                group("Global probes", "temperature-normal", "Reusable named sensor sources.", [
                    control("Create probe", "Expose a source to cooling and lighting", "action", "Add probe", null, { icon: "list-add" })
                ])
            ])
        ]

        if (kind === "titan") return [
            overview("TITAN 360 LCD"),
            tab("Cooling", "temperature-normal", [
                group("Pump", "media-playback-start", "Device-safe pump behavior.", [
                    control("Operating mode", "Mock pump mode", "choice", "Balanced", ["Quiet", "Balanced", "Performance", "Custom"]),
                    control("Minimum output", "Device-specific safe floor", "slider", 31, null, { from: 31, to: 100, unit: "%" }),
                    control("Control source", "Recommended source", "choice", "Coolant temperature", ["Coolant temperature", "CPU temperature"])
                ]),
                group("Radiator", "temperature-normal", "Three attached radiator fans.", [
                    control("Cooling curve", "Channels 13, 14, and 17", "choice", "Radiator 20", ["Radiator 20", "Quiet", "Balanced"]),
                    control("Zero RPM", "Unavailable for this pump", "stat", "Fans only")
                ])
            ]),
            tab("Display", "video-display", [
                group("LCD content", "video-display", "Sensor layouts, images, and animation.", [
                    control("Display mode", "Active LCD layout", "choice", "Liquid + CPU", ["Liquid temperature", "Liquid + CPU", "CPU + GPU", "Time", "Image", "Animation"]),
                    control("Brightness", "LCD panel brightness", "slider", 80, null, { from: 0, to: 100, unit: "%" }),
                    control("Rotation", "Panel orientation", "choice", "0°", ["0°", "90°", "180°", "270°"])
                ]),
                group("Media", "folder-pictures", "Compatible image and animation assets.", [
                    control("Image library", "JPG, BMP, WebP, and GIF", "action", "Browse", null, { icon: "folder-pictures" }),
                    control("Custom profile", "Arcs, sensors, spacing, and colors", "action", "Edit", null, { icon: "document-edit" })
                ])
            ]),
            tab("Lighting", "preferences-desktop-color", [
                group("Pump cover", "preferences-desktop-color", "Device lighting zones.", [
                    control("Effect", "Pump-cover lighting", "choice", "Aurora", ["Aurora", "Static", "Temperature", "Off"]),
                    control("Brightness", "RGB output", "slider", 70, null, { from: 0, to: 100, unit: "%" })
                ])
            ]),
            tab("Sensors", "temperature-normal", [
                group("Cooler telemetry", "office-chart-line", "Live mock sensor values.", [
                    control("Coolant", "Liquid temperature", "stat", "38°C", null, { accent: true }),
                    control("Pump", "Current speed", "stat", "1,460 RPM"),
                    control("Protection", "Critical override", "stat", "Armed", null, { accent: true })
                ])
            ])
        ]

        if (kind === "keyboard") return [
            overview("K100 AIR RGB"),
            tab("Keys", "input-keyboard", [
                group("Assignments", "input-keyboard", "Supported keys, modifiers, media, and profile switching.", [
                    control("G1", "Current assignment", "choice", "F · Toggle", ["Original key", "F · Toggle", "Macro: Push to talk", "Profile switch"]),
                    control("Control dial", "Dial action", "choice", "Volume", ["Volume", "Brightness", "Zoom", "Scroll"]),
                    control("Assignment browser", "Inspect every assignable key", "action", "Open", null, { icon: "configure-shortcuts" })
                ]),
                group("Macros", "media-record", "Reusable keyboard actions.", [
                    control("Macro library", "Delays, repeats, text, and release actions", "action", "Manage", null, { icon: "media-record" })
                ])
            ]),
            tab("Actuation", "input-keyboard", [
                group("Magnetic keys", "input-keyboard", "Actuation appears only on supported keyboards.", [
                    control("Actuation point", "Primary key press", "slider", 1.5, null, { from: 0.4, to: 3.6, step: 0.1, unit: " mm" }),
                    control("Rapid trigger", "Dynamic reset behavior", "toggle", true),
                    control("Secondary actuation", "Second action deeper in travel", "toggle", false)
                ]),
                group("FlashTap", "preferences-system-performance", "Priority behavior for opposing keys.", [
                    control("Mode", "SOCD handling", "choice", "Prioritize last", ["Off", "Prioritize last", "Prioritize first", "Neutral"]),
                    control("Indicator color", "FlashTap status", "color", "", ["#66d7c5", "#ed6d75", "#f0c75e"])
                ])
            ]),
            tab("Lighting", "preferences-desktop-color", [
                group("Per-key lighting", "preferences-desktop-color", "Edit eligible keys or join a shared scene.", [
                    control("Active effect", "Keyboard surface", "choice", "Aurora", ["Aurora", "Static", "Type lighting", "Ripple", "Off"]),
                    control("Brightness", "Keyboard LEDs", "slider", 65, null, { from: 0, to: 100, unit: "%" }),
                    control("Open key canvas", "Per-key editor", "action", "Edit keys", null, { icon: "input-keyboard" })
                ])
            ]),
            tab("Performance", "preferences-system-performance", [
                group("Input behavior", "preferences-system-performance", "Polling, debounce, and gaming lockouts.", [
                    control("Polling rate", "USB or wireless report rate", "choice", "1,000 Hz", ["125 Hz", "250 Hz", "500 Hz", "1,000 Hz"]),
                    control("Debounce", "Key filtering", "choice", "Normal", ["Low", "Normal", "High"]),
                    control("Disable Windows key", "Gaming lockout", "toggle", true),
                    control("Disable Alt+Tab", "Gaming lockout", "toggle", false)
                ])
            ]),
            tab("Profiles", "document-multiple", [
                group("Keyboard profiles", "document-multiple", "Purpose-named device profiles.", [
                    control("Active profile", "Current keyboard state", "choice", "Desktop", ["Desktop", "Palworld", "Gaming", "Battery saver"]),
                    control("Save as new", "Duplicate the current mock state", "action", "Save copy", null, { icon: "document-save-as" })
                ])
            ])
        ]

        if (kind === "mouse") return [
            overview("Scimitar RGB Elite"),
            tab("Buttons", "input-mouse", [
                group("Button assignments", "input-mouse", "Mouse actions, keys, media, scrolling, and macros.", [
                    control("Button 1", "Primary button", "stat", "Left click"),
                    control("Side button 1", "Current assignment", "choice", "1", ["Original", "1", "Macro: Melee", "Profile switch"]),
                    control("Assignment browser", "Review all supported buttons", "action", "Open", null, { icon: "configure-shortcuts" })
                ])
            ]),
            tab("DPI", "input-mouse", [
                group("DPI stages", "input-mouse", "Sensitivity stages and sniper behavior.", [
                    control("Active DPI", "Current sensitivity", "slider", 1600, null, { from: 100, to: 26000, step: 100, unit: " DPI" }),
                    control("Sniper DPI", "Momentary precision stage", "slider", 400, null, { from: 100, to: 5000, step: 100, unit: " DPI" }),
                    control("Indicator color", "Active DPI stage", "color", "", ["#66d7c5", "#e8bd57", "#ee7278"])
                ])
            ]),
            tab("Lighting", "preferences-desktop-color", [
                group("Mouse zones", "preferences-desktop-color", "Only zones reported by this mouse.", [
                    control("Effect", "Four lighting zones", "choice", "Static cyan", ["Static cyan", "Aurora", "Color pulse", "Off"]),
                    control("Brightness", "Mouse LEDs", "slider", 70, null, { from: 0, to: 100, unit: "%" })
                ])
            ]),
            tab("Performance", "preferences-system-performance", [
                group("Sensor behavior", "preferences-system-performance", "Tracking options exposed by the device.", [
                    control("Polling rate", "USB report rate", "choice", "1,000 Hz", ["125 Hz", "250 Hz", "500 Hz", "1,000 Hz", "2,000 Hz"]),
                    control("Angle snapping", "Straight-line correction", "toggle", false),
                    control("Motion sync", "Sensor synchronization", "toggle", true),
                    control("Lift height", "Tracking cutoff", "choice", "Low", ["Low", "Medium", "High"])
                ])
            ]),
            tab("Power", "battery", [
                group("Power behavior", "battery", "Wireless-capable devices would show battery settings.", [
                    control("Sleep timeout", "Idle power behavior", "choice", "15 minutes", ["Never", "5 minutes", "15 minutes", "30 minutes"])
                ])
            ])
        ]

        if (kind === "headset") return [
            overview("Virtuoso Wireless"),
            tab("Audio", "audio-headphones", [
                group("Sound", "audio-headphones", "Equalizer, ANC, and sidetone.", [
                    control("Equalizer", "Active audio curve", "choice", "Pure Direct", ["Pure Direct", "Bass Boost", "FPS Competition", "Custom"]),
                    control("Noise cancellation", "Supported headset mode", "choice", "Transparency", ["Off", "Transparency", "ANC"]),
                    control("Sidetone", "Microphone monitoring", "slider", 25, null, { from: 0, to: 100, unit: "%" }),
                    control("Mute indicator", "Lighting indicator", "toggle", true)
                ])
            ]),
            tab("Buttons", "configure-shortcuts", [
                group("Headset controls", "configure-shortcuts", "Button and wheel behavior.", [
                    control("Wheel", "Primary wheel action", "choice", "Volume", ["Volume", "Sidetone", "Track selection"]),
                    control("Multi-function button", "Current assignment", "choice", "Play / pause", ["Play / pause", "Mute", "Macro"])
                ])
            ]),
            tab("Lighting", "preferences-desktop-color", [
                group("Headset zones", "preferences-desktop-color", "Only supported earcup zones.", [
                    control("Effect", "Active headset lighting", "choice", "Static cyan", ["Static cyan", "Aurora", "Battery level", "Off"]),
                    control("Brightness", "Earcup LEDs", "slider", 40, null, { from: 0, to: 100, unit: "%" })
                ])
            ]),
            tab("Power", "battery", [
                group("Battery", "battery", "Wireless battery and sleep behavior.", [
                    control("Battery level", "Mock telemetry", "stat", "68%"),
                    control("Sleep timeout", "Idle headset sleep", "choice", "15 minutes", ["Never", "5 minutes", "15 minutes", "30 minutes"])
                ])
            ])
        ]

        if (kind === "controller") return [
            overview("SCUF Envision Pro"),
            tab("Controls", "input-gaming", [
                group("Button assignments", "input-gaming", "Controller buttons, keys, mouse, and macros.", [
                    control("Paddle 1", "Current assignment", "choice", "A", ["Original", "A", "Keyboard: Space", "Macro"]),
                    control("Paddle 2", "Current assignment", "choice", "B", ["Original", "B", "Keyboard: Shift", "Macro"]),
                    control("Assignment browser", "Review all controls", "action", "Open", null, { icon: "configure-shortcuts" })
                ])
            ]),
            tab("Analog", "office-chart-line", [
                group("Left stick", "office-chart-line", "Sensitivity and dead-zone curve.", [
                    control("Horizontal sensitivity", "X axis", "slider", 100, null, { from: 1, to: 200, unit: "%" }),
                    control("Vertical sensitivity", "Y axis", "slider", 100, null, { from: 1, to: 200, unit: "%" }),
                    control("Inner dead zone", "Minimum response", "slider", 5, null, { from: 0, to: 30, unit: "%" }),
                    control("Response graph", "Edit analog curve", "action", "Edit", null, { icon: "office-chart-line" })
                ])
            ]),
            tab("Vibration", "preferences-desktop-notification-bell", [
                group("Haptics", "preferences-desktop-notification-bell", "Controller vibration output.", [
                    control("Left motor", "Low-frequency motor", "slider", 75, null, { from: 0, to: 100, unit: "%" }),
                    control("Right motor", "High-frequency motor", "slider", 65, null, { from: 0, to: 100, unit: "%" })
                ])
            ]),
            tab("Lighting", "preferences-desktop-color", [
                group("Controller zones", "preferences-desktop-color", "Supported RGB zones.", [
                    control("Effect", "Controller lighting", "choice", "Static cyan", ["Static cyan", "Aurora", "Battery level", "Off"]),
                    control("Brightness", "Controller LEDs", "slider", 60, null, { from: 0, to: 100, unit: "%" })
                ])
            ]),
            tab("Power", "battery", [
                group("Sleep", "battery", "Idle power behavior.", [
                    control("Sleep timeout", "Controller idle time", "choice", "15 minutes", ["Never", "5 minutes", "15 minutes", "30 minutes"])
                ])
            ])
        ]

        return [
            overview("Slipstream Receiver"),
            tab("Pairing", "network-wireless", [
                group("Paired devices", "network-wireless", "Current mock wireless pairing.", [
                    control("K100 AIR RGB", "Keyboard transport", "stat", "Connected", null, { accent: true }),
                    control("Virtuoso Wireless", "Headset transport", "stat", "Connected", null, { accent: true }),
                    control("Pair a device", "Start a mock pairing flow", "action", "Pair", null, { icon: "list-add" })
                ])
            ]),
            tab("Wireless", "network-wireless", [
                group("Transport", "network-wireless", "Connection and radio details.", [
                    control("Connection quality", "Mock link health", "stat", "Excellent", null, { accent: true }),
                    control("Firmware", "Receiver firmware", "stat", "Current")
                ])
            ]),
            tab("Battery", "battery", [
                group("Paired battery telemetry", "battery", "Reported by wireless devices.", [
                    control("K100 AIR RGB", "Keyboard battery", "stat", "82%"),
                    control("Virtuoso Wireless", "Headset battery", "stat", "68%")
                ])
            ])
        ]
    }

    function groupsForSection(key) {
        if (key === "input") return [
            group("Keyboard", "input-keyboard", "Assignments, actuation, performance, and profiles.", [
                control("Active keyboard", "Capability-aware device", "choice", "K100 AIR RGB", ["K100 AIR RGB"]),
                control("Key assignments", "Keys, modifiers, media, macros, and profile switching", "action", "Open", null, { icon: "configure-shortcuts" }),
                control("Polling rate", "Mock report rate", "choice", "1,000 Hz", ["125 Hz", "250 Hz", "500 Hz", "1,000 Hz"]),
                control("Sleep timeout", "Wireless idle behavior", "choice", "15 minutes", ["Never", "5 minutes", "15 minutes", "30 minutes"])
            ], "Device-specific"),
            group("Mouse", "input-mouse", "DPI, buttons, gestures, and sensor behavior.", [
                control("Active mouse", "Capability-aware device", "choice", "Scimitar RGB Elite", ["Scimitar RGB Elite"]),
                control("DPI stages", "Sensitivity and stage colors", "action", "Configure", null, { icon: "input-mouse" }),
                control("Button mappings", "Buttons, macros, media, and profile switching", "action", "Open", null, { icon: "configure-shortcuts" }),
                control("Motion sync", "Sensor synchronization", "toggle", true)
            ], "Device-specific"),
            group("Controllers", "input-gaming", "Assignments, emulation, analog curves, and vibration.", [
                control("Virtual gamepad", "uinput-backed production capability", "toggle", false),
                control("Emulation", "Controller output mode", "choice", "XInput", ["XInput", "Disabled"]),
                control("Analog graph", "Dead zones and response curves", "action", "Edit", null, { icon: "office-chart-line" })
            ]),
            group("Macros & virtual input", "media-record", "Reusable actions shared by compatible devices.", [
                control("Macro library", "Delays, repeats, text, and release events", "action", "Manage", null, { icon: "media-record" }),
                control("Virtual keyboard", "Production backend capability", "stat", "Available"),
                control("Virtual mouse", "Relative and absolute output", "stat", "Available")
            ])
        ]

        if (key === "audio") return [
            group("Headset sound", "audio-headphones", "Equalizer and supported headset processing.", [
                control("Output profile", "Current equalizer", "choice", "Pure Direct", ["Pure Direct", "Bass Boost", "FPS Competition", "Custom"]),
                control("Noise cancellation", "Device-dependent modes", "choice", "Transparency", ["Off", "Transparency", "ANC"]),
                control("Sidetone", "Microphone monitoring", "slider", 25, null, { from: 0, to: 100, unit: "%" })
            ], "Virtuoso Wireless"),
            group("Headset controls", "configure-shortcuts", "Buttons, wheel, mute, and sleep.", [
                control("Mute indicator", "Visual mute state", "toggle", true),
                control("Wheel behavior", "Primary wheel action", "choice", "Volume", ["Volume", "Sidetone", "Track selection"]),
                control("Sleep timeout", "Wireless idle behavior", "choice", "15 minutes", ["Never", "5 minutes", "15 minutes", "30 minutes"])
            ]),
            group("Virtual audio", "audio-card", "Session-scoped routing and output selection.", [
                control("Output device", "Mock production target", "choice", "Default output", ["Default output", "Virtuoso Wireless", "Display audio"]),
                control("Virtual audio service", "Unavailable when the service runs only in system context", "stat", "Session required")
            ], "Environment-dependent", true),
            group("Media", "media-playback-start", "Playback telemetry and control.", [
                control("Now playing", "Mock MPRIS source", "stat", "No media"),
                control("Playback controls", "Previous, play/pause, and next", "action", "Open controls", null, { icon: "media-playback-start" })
            ])
        ]

        if (key === "displays") return [
            group("LCD layouts", "video-display", "Telemetry layouts, time, images, and animation.", [
                control("Active LCD", "Assigned display device", "choice", "TITAN LCD", ["TITAN LCD"]),
                control("Display mode", "Current layout", "choice", "Liquid + CPU", ["Liquid temperature", "Pump RPM", "CPU + GPU", "Time", "Image", "Animation"]),
                control("Rotation", "Panel orientation", "choice", "0°", ["0°", "90°", "180°", "270°"]),
                control("Brightness", "LCD panel output", "slider", 80, null, { from: 0, to: 100, unit: "%" })
            ]),
            group("Media library", "folder-pictures", "JPG, BMP, WebP, and GIF assets.", [
                control("Images and animation", "Browse mock LCD assets", "action", "Browse", null, { icon: "folder-pictures" }),
                control("Upload asset", "No file is sent in this prototype", "action", "Choose file", null, { icon: "document-open" })
            ]),
            group("Custom LCD profile", "document-edit", "Arcs, sensors, timing, spacing, and colors.", [
                control("Primary sensor", "First arc or text field", "choice", "Coolant temperature", ["CPU temperature", "GPU temperature", "Coolant temperature", "CPU load", "GPU load", "Pump RPM", "Date", "Time"]),
                control("Arc thickness", "Custom layout geometry", "slider", 12, null, { from: 1, to: 30, unit: " px" }),
                control("Profile editor", "Open the detailed mock editor", "action", "Edit", null, { icon: "document-edit" })
            ]),
            group("Desktop geometry", "preferences-desktop-display", "Monitor dimensions and placement for absolute input.", [
                control("Primary display", "Mock compositor geometry", "stat", "2560 × 1440"),
                control("Placement", "Virtual desktop coordinate", "stat", "0, 0"),
                control("Update geometry", "Production backend display endpoint", "action", "Refresh mock", null, { icon: "view-refresh" })
            ])
        ]

        if (key === "automations") return [
            group("Lighting schedule", "preferences-system-time", "Backend-supported RGB on/off timing.", [
                control("Schedule enabled", "Use daily on/off times", "toggle", true),
                control("Lights on", "Daily start time", "choice", "08:00", ["06:00", "08:00", "10:00", "Sunrise"]),
                control("Lights off", "Daily end time", "choice", "23:30", ["22:00", "23:30", "00:00", "Sunset"])
            ], "Backend-supported"),
            group("LCD schedule", "video-display", "Backend-supported display on/off timing.", [
                control("Schedule enabled", "Use daily LCD times", "toggle", true),
                control("Display on", "Daily start time", "choice", "08:00", ["06:00", "08:00", "10:00"]),
                control("Display off", "Daily end time", "choice", "23:30", ["22:00", "23:30", "00:00"])
            ], "Backend-supported"),
            group("Safety policy", "security-high", "Safety state is visible but remains owned by the service.", [
                control("Coolant protection", "Independent backend behavior", "stat", "Armed", null, { accent: true }),
                control("Failsafe output", "Critical-temperature response", "stat", "100%")
            ], "Read-only")
        ]

        return [
            group("OpenRGB", "network-connect", "External RGB target configuration.", [
                control("Integration enabled", "Production backend target", "toggle", false),
                control("Target host", "Mock endpoint", "stat", "127.0.0.1"),
                control("Target port", "Mock endpoint", "stat", "6742")
            ], "Backend-supported"),
            group("Hardware integrations", "applications-engineering", "Optional system and motherboard capabilities.", [
                control("Motherboard support", "SMBus-backed integration", "toggle", false),
                control("Memory lighting", "Supported DIMM control", "toggle", false),
                control("Gamepad support", "Virtual controller integration", "toggle", true)
            ], "Hardware-dependent"),
            group("Desktop integration", "preferences-desktop", "Native session conveniences.", [
                control("System tray", "Quick profile and status surface", "toggle", true),
                control("Notifications", "Warnings and connection state", "toggle", true),
                control("Media controls", "MPRIS playback integration", "toggle", true)
            ]),
            group("Observability", "office-chart-line", "Optional metrics and diagnostics.", [
                control("Prometheus metrics", "Production service option", "toggle", false),
                control("Telemetry preview", "Inspect mock sensor feed", "action", "Open", null, { icon: "office-chart-line" }),
                control("API explorer", "Planned developer-facing inspector", "action", "Explore", null, { icon: "applications-development" })
            ])
        ]
    }

    function workspaceMetadata(key) {
        const metadata = {
            input: {
                title: "Input",
                subtitle: "Keyboard, mouse, controller, macro, and virtual-input capabilities grouped by purpose.",
                icon: "input-keyboard"
            },
            audio: {
                title: "Audio",
                subtitle: "Headset sound, controls, equalizers, virtual audio, and media playback.",
                icon: "audio-headphones"
            },
            displays: {
                title: "Displays",
                subtitle: "LCD content, custom layouts, media assets, rotation, brightness, and geometry.",
                icon: "video-display"
            },
            automations: {
                title: "Automations",
                subtitle: "Verified schedules stay distinct from clearly labelled future orchestration concepts.",
                icon: "system-run"
            },
            integrations: {
                title: "Integrations",
                subtitle: "OpenRGB, system hardware, desktop-session conveniences, and observability.",
                icon: "network-connect"
            }
        }
        return metadata[key] || metadata.input
    }

    function metricValue(key) {
        return profileTelemetry[activeGlobalProfile][key] || "—"
    }

    function zoneRpm(key) {
        return profileTelemetry[activeGlobalProfile][key] || "—"
    }

    function previewGlobalProfile(profileKey) {
        activeGlobalProfile = profileKey
        let displayName = profileKey
        for (let i = 0; i < globalProfiles.length; ++i) {
            if (globalProfiles[i].key === profileKey) {
                displayName = globalProfiles[i].name
                break
            }
        }
        showToast(
            displayName + " global profile previewed",
            "Cooling, lighting, device-profile, and telemetry previews changed only in the mock interface."
        )
    }

    function navigate(key) {
        activeSection = key
        searchField.clear()
        searchPopup.close()
    }

    function selectDevice(id) {
        for (let i = 0; i < devices.length; ++i) {
            if (devices[i].id === id) {
                selectedDeviceIndex = i
                activeSection = "device"
                searchField.clear()
                searchPopup.close()
                return
            }
        }
    }

    function filteredDevices(query) {
        const needle = (query || "").trim().toLowerCase()
        if (!needle) return devices
        return devices.filter(device => {
            const haystack = [
                device.name,
                device.subtitle,
                device.capabilities.join(" "),
                device.tabs.map(item => item.name).join(" ")
            ].join(" ").toLowerCase()
            return haystack.indexOf(needle) >= 0
        })
    }

    function searchResults(query) {
        const needle = (query || "").trim().toLowerCase()
        if (!needle) return []
        const results = []
        navItems.forEach(item => {
            if ((item.label + " " + item.key).toLowerCase().indexOf(needle) >= 0) {
                results.push({
                    label: item.label,
                    detail: "Open workspace",
                    icon: item.icon,
                    key: item.key,
                    device: false
                })
            }
        })
        devices.forEach(device => {
            const text = device.name + " " + device.capabilities.join(" ") + " " +
                device.tabs.map(item => item.name).join(" ")
            if (text.toLowerCase().indexOf(needle) >= 0) {
                results.push({
                    label: device.name,
                    detail: device.capabilities.join(" · "),
                    icon: device.icon,
                    key: device.id,
                    device: true
                })
            }
        })
        return results.slice(0, 8)
    }

    function markDirty(label) {
        pendingChanges = true
        statusHint.text = "Pending mock change: " + label
    }

    function applyChanges() {
        pendingChanges = false
        statusHint.text = "Changes remain local to this prototype"
        showToast("Preview applied locally", "No backend request or hardware command was sent.")
    }

    function revertChanges() {
        pendingChanges = false
        statusHint.text = "Changes remain local to this prototype"
        showToast("Pending preview cleared", "Controls will fully reset when the prototype closes.")
    }

    function showToast(title, detail) {
        toastTitle.text = title
        toastDetail.text = detail || ""
        toast.open()
        toastTimer.restart()
    }

    function sectionTitle() {
        if (activeSection === "device") return currentDevice.name
        for (let i = 0; i < navItems.length; ++i) {
            if (navItems[i].key === activeSection) return navItems[i].label
        }
        return "OpenLinkHub"
    }

    function sectionSubtitle() {
        const subtitles = {
            overview: "Everything important, with the details one click away",
            profiles: "Whole-system profiles and game/application launch rules",
            devices: "Connected hardware and its actual capabilities",
            cooling: "Profiles, channels, sensor sources, and safety behavior",
            lighting: "Scenes, zones, per-device effects, and hardware lighting",
            input: "Keyboard, mouse, controller, and macro configuration",
            audio: "Headset audio, controls, equalizers, and routing",
            displays: "LCD layouts, media, sensors, brightness, and placement",
            automations: "Schedules and clearly-labelled future rules",
            integrations: "OpenRGB, Plasma system sensors, desktop, and metrics",
            service: "Presentation preferences and future service administration"
        }
        return activeSection === "device" ? currentDevice.subtitle : subtitles[activeSection]
    }

    background: Rectangle { color: root.backgroundColor }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: root.sidebarLabels ? 224 : 72
            color: root.sidebarColor
            border.color: root.outline

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.compactMode ? 9 : 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.topMargin: 6
                    Layout.bottomMargin: 12
                    spacing: 11

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 10
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14)
                        border.color: root.accentColor

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 23
                            height: 23
                            source: "drive-multidisk"
                            color: root.accentColor
                        }
                    }

                    Label {
                        visible: root.sidebarLabels
                        text: "OpenLinkHub"
                        color: root.primaryText
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }
                }

                Repeater {
                    model: root.navItems

                    delegate: NavItem {
                        required property var modelData
                        shell: root
                        itemKey: modelData.key
                        label: modelData.label
                        iconName: modelData.icon
                        selected: root.activeSection === modelData.key
                            || (root.activeSection === "device" && modelData.key === "devices")
                        Layout.fillWidth: true
                        onClicked: root.navigate(itemKey)
                    }
                }

                Item { Layout.fillHeight: true }

                AbstractButton {
                    Layout.fillWidth: true
                    implicitHeight: root.sidebarLabels ? 62 : 48
                    leftPadding: 14
                    rightPadding: 12
                    topPadding: 10
                    bottomPadding: 10
                    hoverEnabled: true
                    onClicked: root.navigate("service")

                    background: Rectangle {
                        radius: Math.max(6, root.cornerRadius - 3)
                        color: parent.hovered ? root.surfaceHover : root.surfaceAlt
                        border.color: root.outline
                    }

                    contentItem: RowLayout {
                        spacing: 11
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: root.warningColor
                        }
                        ColumnLayout {
                            visible: root.sidebarLabels
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                text: "Prototype mode"
                                color: root.primaryText
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: "No backend connected"
                                color: root.mutedText
                                font.pixelSize: 11
                            }
                        }
                    }

                    ToolTip.visible: hovered && !root.sidebarLabels
                    ToolTip.text: "Prototype mode · no backend"
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                id: topbar
                Layout.fillWidth: true
                Layout.preferredHeight: root.compactMode ? 74 : 84
                color: root.surface
                border.color: root.outline

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.contentPadding + 4
                    anchors.rightMargin: root.contentPadding + 4
                    spacing: 18

                    ColumnLayout {
                        Layout.preferredWidth: 300
                        spacing: 1

                        Label {
                            text: root.sectionTitle()
                            color: root.primaryText
                            font.pixelSize: root.compactMode ? 19 : 22
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Label {
                            text: root.sectionSubtitle()
                            color: root.mutedText
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    TextField {
                        id: searchField
                        Layout.preferredWidth: Math.min(430, Math.max(280, topbar.width * 0.30))
                        placeholderText: "Search settings and devices…"
                        leftPadding: 38

                        Kirigami.Icon {
                            anchors.left: parent.left
                            anchors.leftMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            width: 19
                            height: 19
                            source: "search"
                            color: root.mutedText
                        }

                        Label {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Ctrl+K"
                            color: root.mutedText
                            font.pixelSize: 10
                            visible: searchField.text.length === 0
                        }

                        onTextChanged: {
                            if (text.length > 0 && root.searchResults(text).length > 0) searchPopup.open()
                            else searchPopup.close()
                        }
                        onAccepted: {
                            const results = root.searchResults(text)
                            if (results.length > 0) {
                                if (results[0].device) root.selectDevice(results[0].key)
                                else root.navigate(results[0].key)
                            }
                        }

                        Popup {
                            id: searchPopup
                            y: searchField.height + 6
                            width: searchField.width
                            height: Math.min(390, searchList.contentHeight + 12)
                            padding: 6
                            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                            background: Rectangle {
                                color: root.surface
                                border.color: root.outline
                                radius: root.cornerRadius
                            }

                            contentItem: ListView {
                                id: searchList
                                clip: true
                                spacing: 3
                                model: root.searchResults(searchField.text)

                                delegate: AbstractButton {
                                    required property var modelData
                                    width: searchList.width
                                    height: 54
                                    hoverEnabled: true
                                    onClicked: {
                                        if (modelData.device) root.selectDevice(modelData.key)
                                        else root.navigate(modelData.key)
                                    }
                                    background: Rectangle {
                                        radius: 7
                                        color: parent.hovered ? root.surfaceHover : "transparent"
                                    }
                                    contentItem: RowLayout {
                                        spacing: 11
                                        Kirigami.Icon {
                            source: modelData.icon
                                            color: root.accentColor
                                            Layout.preferredWidth: 21
                                            Layout.preferredHeight: 21
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Label {
                                                text: modelData.label
                                                color: root.primaryText
                                                font.weight: Font.DemiBold
                                            }
                                            Label {
                                                text: modelData.detail
                                                color: root.mutedText
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                        Kirigami.Icon {
                            source: "go-next"
                                            color: root.mutedText
                                            Layout.preferredWidth: 16
                                            Layout.preferredHeight: 16
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StatusBadge {
                        shell: root
                        text: "Prototype · Offline"
                        badgeColor: root.warningColor
                        filled: true
                    }

                    ComboBox {
                        id: globalProfileCombo
                        model: root.globalProfiles
                        textRole: "name"
                        valueRole: "key"
                        displayText: "Global · " + currentText
                        currentIndex: root.globalProfiles
                            .map(profile => profile.key)
                            .indexOf(root.activeGlobalProfile)
                        Layout.preferredWidth: 190
                        onActivated: root.previewGlobalProfile(currentValue)
                        ToolTip.visible: hovered
                        ToolTip.text: "Active global profile · coordinates saved cooling, lighting, and device profiles"
                        Accessible.name: "Active global profile"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.pendingChanges ? 28 : 24
                color: root.pendingChanges
                    ? Qt.rgba(root.warningColor.r, root.warningColor.g, root.warningColor.b, 0.10)
                    : root.backgroundColor

                Label {
                    id: statusHint
                    anchors.left: parent.left
                    anchors.leftMargin: root.contentPadding + 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Changes remain local to this prototype"
                    color: root.pendingChanges ? root.warningColor : root.mutedText
                    font.pixelSize: 10
                }
            }

            Loader {
                id: pageLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: root.contentPadding
                Layout.rightMargin: root.contentPadding
                Layout.bottomMargin: root.contentPadding

                sourceComponent: {
                    switch (root.activeSection) {
                    case "overview": return overviewPageComponent
                    case "profiles": return profilesPageComponent
                    case "devices": return devicesPageComponent
                    case "cooling": return coolingPageComponent
                    case "lighting": return lightingPageComponent
                    case "integrations": return integrationsPageComponent
                    case "service": return servicePageComponent
                    case "device": return devicePageComponent
                    default: return featurePageComponent
                    }
                }
            }
        }
    }

    Component {
        id: overviewPageComponent
        OverviewPage { shell: root }
    }

    Component {
        id: devicesPageComponent
        DevicesPage { shell: root }
    }

    Component {
        id: profilesPageComponent
        ProfilesPage { shell: root }
    }

    Component {
        id: coolingPageComponent
        CoolingPage { shell: root }
    }

    Component {
        id: lightingPageComponent
        LightingPage { shell: root }
    }

    Component {
        id: integrationsPageComponent
        IntegrationsPage { shell: root }
    }

    Component {
        id: featurePageComponent
        FeatureWorkspace {
            shell: root
            workspaceTitle: root.workspaceMetadata(root.activeSection).title
            workspaceSubtitle: root.workspaceMetadata(root.activeSection).subtitle
            workspaceIcon: root.workspaceMetadata(root.activeSection).icon
            groups: root.groupsForSection(root.activeSection)
        }
    }

    Component {
        id: servicePageComponent
        ServicePage { shell: root }
    }

    Component {
        id: devicePageComponent
        DevicePage {
            shell: root
            device: root.currentDevice
        }
    }

    Popup {
        id: toast
        parent: Overlay.overlay
        x: parent.width - width - 26
        y: parent.height - height - 26
        width: 390
        modal: false
        focus: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: root.surface
            border.color: root.outline
            radius: root.cornerRadius
        }

        contentItem: RowLayout {
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: Qt.rgba(root.successColor.r, root.successColor.g, root.successColor.b, 0.14)
                Kirigami.Icon {
                            anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: "dialog-ok"
                    color: root.successColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    id: toastTitle
                    color: root.primaryText
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                Label {
                    id: toastDetail
                    color: root.mutedText
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Timer {
        id: toastTimer
        interval: 3300
        onTriggered: toast.close()
    }

    Shortcut {
        sequence: "Ctrl+K"
        onActivated: {
            searchField.forceActiveFocus()
            searchField.selectAll()
        }
    }

    Shortcut {
        sequence: "Ctrl+1"
        onActivated: root.navigate("overview")
    }

    Shortcut {
        sequence: "Ctrl+2"
        onActivated: root.navigate("devices")
    }
}
