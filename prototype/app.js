(() => {
    "use strict";

    const STORAGE_KEY = "openlinkhub-ui-concept-v1";
    const widgetMeta = {
        summary: ["System summary", "CPU, GPU, coolant, and acoustics", 0],
        cooling: ["Cooling at a glance", "Live zone status and curve previews", 1],
        devices: ["Devices", "Connected hardware shortcuts", 1],
        actions: ["Quick actions", "Common mode and lighting controls", 2],
        health: ["Health status", "Current warnings and alerts", 2]
    };

    const defaults = {
        theme: "dark",
        accent: "#66d7c5",
        density: "comfortable",
        radius: 12,
        sidebarLabels: true,
        systemMode: "balanced",
        lightsEnabled: true,
        brightness: 70,
        scene: "aurora",
        widgetOrder: ["summary", "cooling", "devices", "actions", "health"],
        hiddenWidgets: []
    };

    const state = Object.assign({}, defaults, loadState());
    const $ = (selector, root = document) => root.querySelector(selector);
    const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

    const routes = {
        overview: ["SYSTEM OVERVIEW", "Good morning, Kodi", "Everything is running normally"],
        cooling: ["THERMAL CONTROL", "Cooling", "Manage airflow by intent, zone, and temperature source"],
        lighting: ["LIGHTING", "Lighting scenes", "Create one visual language across compatible devices"],
        devices: ["HARDWARE", "Devices", "See connected hardware and the capabilities each device exposes"],
        automations: ["AUTOMATION", "Automations", "Make routine changes happen at the right time"],
        system: ["PREFERENCES", "System", "Personalize the interface and configure advanced capabilities"]
    };

    const devices = {
        hub: {
            title: "iCUE LINK System Hub",
            subtitle: "USB · Firmware 3.10.636",
            capabilities: ["Cooling zones", "Per-channel speed", "RGB", "LCD assignment", "Device positions", "Temperature probes"],
            tabs: [
                ["overview", "Overview", "Hub status", "See the connected LINK topology, firmware, and aggregate health in one place."],
                ["cooling", "Cooling", "Cooling channels", "Configure only the pump and fan channels exposed by the hub.", "cooling"],
                ["lighting", "Lighting", "Lighting zones", "Coordinate RGB-capable devices and channels attached to the hub.", "lighting"],
                ["topology", "Topology", "Device positions", "Arrange the physical LINK chain so labels and lighting order match the real build."],
                ["sensors", "Sensors", "Temperature sources", "Inspect coolant and probe telemetry available to cooling profiles."]
            ]
        },
        titan: {
            title: "TITAN 360 LCD",
            subtitle: "LINK · Coolant 38°C",
            capabilities: ["Pump control", "Radiator fans", "Coolant sensor", "LCD", "RGB", "Critical protection"],
            tabs: [
                ["overview", "Overview", "Cooler status", "See pump speed, coolant temperature, radiator state, and protection status."],
                ["cooling", "Cooling", "Pump and radiator", "Tune the pump and radiator fans with device-safe limits kept visible.", "cooling"],
                ["display", "Display", "LCD content", "Choose sensor layouts, media, rotation, and display brightness."],
                ["lighting", "Lighting", "Cooler lighting", "Configure the RGB zones supported by the pump cover and attached fans.", "lighting"],
                ["sensors", "Sensors", "Coolant telemetry", "Inspect coolant and related telemetry available from the cooler."]
            ]
        },
        keyboard: {
            title: "K100 AIR RGB",
            subtitle: "Wireless · Battery 82%",
            capabilities: ["Per-key RGB", "Key assignments", "Macros", "Profiles", "Control dial", "Polling and sleep"],
            tabs: [
                ["overview", "Overview", "Keyboard status", "See connection mode, battery, active profile, and firmware."],
                ["assignments", "Keys", "Key assignments", "Map supported keys, media controls, and the control dial."],
                ["lighting", "Lighting", "Per-key lighting", "Build keyboard lighting layers and include them in shared scenes.", "lighting"],
                ["macros", "Macros", "Macro library", "Create reusable actions and assign them to eligible keys."],
                ["wireless", "Wireless", "Polling and sleep", "Tune wireless behavior, polling, sleep timing, and battery-conscious options."]
            ]
        },
        mouse: {
            title: "Scimitar RGB Elite",
            subtitle: "USB · 1,000 Hz",
            capabilities: ["DPI stages", "Button mappings", "Macros", "Lighting zones", "Polling", "Angle snapping"],
            tabs: [
                ["overview", "Overview", "Mouse status", "See the active DPI stage, polling rate, profile, and firmware."],
                ["dpi", "DPI", "DPI stages", "Set sensitivity stages and choose the active stage indicator."],
                ["buttons", "Buttons", "Button mappings", "Assign actions and macros to supported mouse buttons."],
                ["lighting", "Lighting", "Mouse lighting", "Configure the mouse lighting zones or add them to a shared scene.", "lighting"],
                ["performance", "Performance", "Tracking behavior", "Tune polling, angle snapping, and other supported sensor options."]
            ]
        },
        slipstream: {
            title: "Slipstream receiver",
            subtitle: "USB · 2 paired devices",
            capabilities: ["Wireless transport", "Paired devices", "Battery telemetry", "Connection status"],
            tabs: [
                ["overview", "Overview", "Receiver status", "See connection health, firmware, and currently paired devices."],
                ["pairing", "Pairing", "Paired devices", "Review or change the devices attached to this receiver."],
                ["wireless", "Wireless", "Connection details", "Inspect transport status and supported wireless settings."],
                ["battery", "Battery", "Battery telemetry", "See the battery state reported by paired wireless devices."]
            ]
        },
        lcd: {
            title: "LCD Pump Cover",
            subtitle: "480 × 480 display",
            capabilities: ["Sensor layouts", "Images", "GIF animation", "Rotation", "Brightness", "Custom profiles"],
            tabs: [
                ["overview", "Overview", "Display status", "See the active layout, resolution, orientation, and brightness."],
                ["display", "Display", "Display layout", "Choose the content layout and screen orientation."],
                ["media", "Media", "Images and animation", "Manage compatible images and animated content."],
                ["sensors", "Sensors", "Sensor layouts", "Select the telemetry shown in supported LCD layouts."],
                ["brightness", "Brightness", "Display brightness", "Adjust panel brightness independently of RGB lighting."]
            ]
        }
    };

    const zoneData = {
        radiator: {
            eyebrow: "RADIATOR · 3 FANS", title: "Radiator cooling", profile: "radiator20",
            sensor: "coolant", zero: false, low: 20, high: 100, ramp: 40
        },
        case: {
            eyebrow: "CASE AIRFLOW · 3 FANS", title: "Case airflow", profile: "custom",
            sensor: "gpu", zero: true, low: 0, high: 80, ramp: 53
        },
        pump: {
            eyebrow: "TITAN PUMP · CHANNEL 2", title: "Pump cooling", profile: "custom",
            sensor: "coolant", zero: false, low: 31, high: 100, ramp: 40
        }
    };

    let activeZone = "radiator";

    function loadState() {
        try {
            return JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
        } catch {
            return {};
        }
    }

    function saveState(message = "Preference saved") {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
        const save = $("#saveState");
        if (save) {
            save.textContent = "Saved locally";
            clearTimeout(save._timer);
            save._timer = setTimeout(() => save.textContent = "Saved locally", 1200);
        }
        if (message) toast(message, "This prototype stores changes only in your browser.");
    }

    function hexToRgb(hex) {
        const value = hex.replace("#", "");
        const number = parseInt(value.length === 3 ? value.split("").map(v => v + v).join("") : value, 16);
        return `${(number >> 16) & 255}, ${(number >> 8) & 255}, ${number & 255}`;
    }

    function applyAppearance() {
        document.documentElement.dataset.theme = state.theme;
        document.documentElement.dataset.density = state.density;
        document.documentElement.style.setProperty("--accent", state.accent);
        document.documentElement.style.setProperty("--accent-rgb", hexToRgb(state.accent));
        document.documentElement.style.setProperty("--radius", `${state.radius}px`);
        document.documentElement.classList.toggle("sidebar-collapsed", !state.sidebarLabels);

        $$(".theme-choice").forEach(button => button.classList.toggle("active", button.dataset.themeChoice === state.theme));
        $$(".accent").forEach(button => button.classList.toggle("active", button.dataset.accent.toLowerCase() === state.accent.toLowerCase()));
        $$("[data-density-choice]").forEach(button => button.classList.toggle("active", button.dataset.densityChoice === state.density));
        $("#cornerRadius").value = state.radius;
        $("#cornerOutput").textContent = `${state.radius} px`;
        $("#sidebarLabels").checked = state.sidebarLabels;
        $("#systemMode").value = state.systemMode;
        $("#lightingEnabled").checked = state.lightsEnabled;
        $("#lightingBrightness").value = state.brightness;
        $("#brightnessOutput").textContent = `${state.brightness}%`;
        applyWidgetLayout();
    }

    function navigate(route) {
        if (!routes[route]) return;
        $$(".view").forEach(view => view.classList.toggle("active", view.dataset.view === route));
        $$(".nav-item").forEach(item => item.classList.toggle("active", item.dataset.route === route));
        $("#pageEyebrow").textContent = routes[route][0];
        $("#pageTitle").textContent = routes[route][1];
        $("#pageSubtitle").textContent = routes[route][2];
        $$(".overview-only").forEach(element => element.hidden = route !== "overview");
        history.replaceState(null, "", `#${route}`);
        closeDrawer();
        window.scrollTo({ top: 0, behavior: "smooth" });
    }

    function toast(title, detail = "") {
        const element = document.createElement("div");
        element.className = "toast";
        element.innerHTML = `<span>✓</span><div><strong>${title}</strong>${detail ? `<small>${detail}</small>` : ""}</div>`;
        $("#toastStack").append(element);
        setTimeout(() => {
            element.style.opacity = "0";
            element.style.transform = "translateY(8px)";
            setTimeout(() => element.remove(), 220);
        }, 3000);
    }

    function openDevice(key) {
        const device = devices[key] || devices.hub;
        $("#drawerTitle").textContent = device.title;
        $("#drawerSubtitle").textContent = device.subtitle;
        $("#drawerCapabilities").innerHTML = device.capabilities.map(item => `<span>${item}</span>`).join("");
        $("#drawerTabs").innerHTML = device.tabs.map((tab, index) => `<button type="button" role="tab" data-device-tab="${tab[0]}" aria-selected="${index === 0}" tabindex="${index === 0 ? "0" : "-1"}">${tab[1]}</button>`).join("");
        $("#drawerTabs").dataset.device = key;
        renderDeviceTab(device, device.tabs[0][0]);
        $("#deviceDrawer").classList.add("open");
        $("#deviceDrawer").setAttribute("aria-hidden", "false");
        $("#scrim").classList.add("open");
    }

    function renderDeviceTab(device, tabId) {
        const tab = device.tabs.find(item => item[0] === tabId) || device.tabs[0];
        $$("#drawerTabs [data-device-tab]").forEach(button => {
            const active = button.dataset.deviceTab === tab[0];
            button.classList.toggle("active", active);
            button.setAttribute("aria-selected", String(active));
            button.tabIndex = active ? 0 : -1;
        });
        const action = tab[4]
            ? `<button type="button" class="button primary" data-route="${tab[4]}">Open ${tab[1]}</button>`
            : `<button type="button" class="button ghost" data-device-demo="${tab[1]}">Explore ${tab[1]}</button>`;
        $("#drawerTabPanel").innerHTML = `<p class="eyebrow">SUPPORTED FOR THIS DEVICE</p><h3>${tab[2]}</h3><p>${tab[3]}</p>${action}`;
    }

    function closeDrawer() {
        $("#deviceDrawer").classList.remove("open");
        $("#deviceDrawer").setAttribute("aria-hidden", "true");
        $("#scrim").classList.remove("open");
    }

    function applySystemMode(mode, announce = true) {
        const profiles = {
            quiet: { cpu: 49, gpu: 54, coolant: 39, noise: "Very quiet", radiator: "610 RPM", caseFan: "0 RPM", pump: "1,420 RPM" },
            balanced: { cpu: 47, gpu: 51, coolant: 38, noise: "Quiet", radiator: "720 RPM", caseFan: "0 RPM", pump: "1,460 RPM" },
            performance: { cpu: 42, gpu: 46, coolant: 35, noise: "Audible", radiator: "1,180 RPM", caseFan: "920 RPM", pump: "1,890 RPM" },
            custom: { cpu: 46, gpu: 50, coolant: 37, noise: "Custom", radiator: "760 RPM", caseFan: "0 RPM", pump: "1,500 RPM" }
        };
        const profile = profiles[mode];
        state.systemMode = mode;
        $("#cpuMetric").textContent = profile.cpu;
        $("#gpuMetric").textContent = profile.gpu;
        $("#coolantMetric").textContent = profile.coolant;
        $("#noiseMetric").textContent = profile.noise;
        $("#radiatorRpm").textContent = profile.radiator;
        $("#caseRpm").textContent = profile.caseFan;
        $("#pumpRpm").textContent = profile.pump;
        if (announce) {
            saveState("");
            toast(`${mode[0].toUpperCase() + mode.slice(1)} mode previewed`, "Values changed only in the mock interface.");
        }
    }

    function drawCurve() {
        const low = Number($("#lowSpeed").value);
        const high = Number($("#highSpeed").value);
        const ramp = Number($("#rampTemp").value);
        $("#lowSpeedOutput").textContent = `${low}%`;
        $("#highSpeedOutput").textContent = `${high}%`;
        $("#rampTempOutput").textContent = `${ramp}°C`;

        const x = temperature => 60 + ((temperature - 30) / 25) * 550;
        const y = speed => 220 - speed * 2;
        const points = [
            [30, low],
            [Math.max(31, ramp - 4), low],
            [ramp, Math.min(high, low + 10)],
            [Math.min(52, ramp + 5), Math.round((low + high) * .58)],
            [55, high]
        ];
        const path = points.map((point, index) => `${index ? "L" : "M"}${x(point[0]).toFixed(1)} ${y(point[1]).toFixed(1)}`).join(" ");
        $("#curveLine").setAttribute("d", path);
        $("#curveArea").setAttribute("d", `${path} L610 220 L60 220 Z`);
        $("#curvePoints").innerHTML = points.map(point => `<circle class="curve-point" cx="${x(point[0])}" cy="${y(point[1])}" r="6"></circle>`).join("");
    }

    function loadZone(zone) {
        activeZone = zone;
        const data = zoneData[zone];
        $$(".zone-list-item[data-zone]").forEach(button => button.classList.toggle("active", button.dataset.zone === zone));
        $("#zoneEyebrow").textContent = data.eyebrow;
        $("#zoneTitle").textContent = data.title;
        $("#zoneProfile").value = data.profile;
        $("#zoneSensor").value = data.sensor;
        $("#zeroRpm").checked = data.zero;
        $("#lowSpeed").value = data.low;
        $("#highSpeed").value = data.high;
        $("#rampTemp").value = Math.min(50, data.ramp);
        drawCurve();
    }

    function applyScene(scene, color, announce = true) {
        state.scene = scene;
        $$(".scene-card").forEach(card => {
            const active = card.dataset.scene === scene;
            card.classList.toggle("active", active);
            const marker = $("b", card);
            if (active && !marker) card.insertAdjacentHTML("beforeend", "<b>Active</b>");
            if (!active && marker) marker.remove();
        });
        const selected = $(`.scene-card[data-scene="${scene}"]`);
        const title = $("strong", selected)?.textContent || "Lighting scene";
        $("#sceneTitle").textContent = title;
        $("#deskPreview").style.setProperty("--scene", color);
        if (announce) {
            saveState("");
            toast(`${title} selected`, "The desk preview has been updated.");
        }
    }

    function applyWidgetLayout() {
        const overview = $("#view-overview");
        const summary = $('[data-widget="summary"]', overview);
        const overviewGrid = $(".overview-grid", overview);
        const cooling = $('[data-widget="cooling"]', overview);
        const devicesWidget = $('[data-widget="devices"]', overview);
        const actions = $('[data-widget="actions"]', overview);
        const health = $('[data-widget="health"]', overview);
        const elements = { summary, cooling, devices: devicesWidget, actions, health };

        state.widgetOrder.forEach(key => {
            const element = elements[key];
            if (!element) return;
            element.classList.toggle("widget-hidden", state.hiddenWidgets.includes(key));
            if (key === "cooling" || key === "devices") {
                overviewGrid.append(element);
            } else if (key === "summary") {
                overview.insertBefore(element, overviewGrid);
            } else {
                overview.append(element);
            }
        });
    }

    function renderLayoutDialog() {
        $("#layoutList").innerHTML = state.widgetOrder.map((key, index) => {
            const [title, detail, group] = widgetMeta[key];
            const checked = !state.hiddenWidgets.includes(key);
            const previousKey = state.widgetOrder[index - 1];
            const nextKey = state.widgetOrder[index + 1];
            const canMoveUp = previousKey && widgetMeta[previousKey][2] === group;
            const canMoveDown = nextKey && widgetMeta[nextKey][2] === group;
            return `<div class="layout-item" data-layout-key="${key}">
                <span class="layout-handle">⋮⋮</span>
                <span><strong>${title}</strong><small>${detail}</small></span>
                <label class="toggle-label"><input type="checkbox" ${checked ? "checked" : ""}><span class="toggle"></span></label>
                <span class="layout-move">
                    <button type="button" data-move="-1" ${canMoveUp ? "" : "disabled"}>↑</button>
                    <button type="button" data-move="1" ${canMoveDown ? "" : "disabled"}>↓</button>
                </span>
            </div>`;
        }).join("");
    }

    function openLayoutDialog() {
        renderLayoutDialog();
        $("#layoutDialog").showModal();
    }

    function filterDevices() {
        const filter = $(".filter.active")?.dataset.filter || "all";
        const query = $("#deviceSearch").value.toLowerCase().trim();
        $$(".device-card").forEach(card => {
            const categoryMatch = filter === "all" || card.dataset.category === filter;
            const queryMatch = card.textContent.toLowerCase().includes(query);
            card.hidden = !(categoryMatch && queryMatch);
        });
    }

    function bindEvents() {
        document.addEventListener("click", event => {
            const routeTarget = event.target.closest("[data-route]");
            if (routeTarget) {
                navigate(routeTarget.dataset.route);
                return;
            }
            const deviceTarget = event.target.closest("[data-device]");
            if (deviceTarget) {
                openDevice(deviceTarget.dataset.device);
            }
        });

        $("#closeDrawer").addEventListener("click", closeDrawer);
        $("#scrim").addEventListener("click", closeDrawer);
        $("#drawerTabs").addEventListener("click", event => {
            const tab = event.target.closest("[data-device-tab]");
            if (!tab) return;
            const device = devices[event.currentTarget.dataset.device] || devices.hub;
            renderDeviceTab(device, tab.dataset.deviceTab);
        });
        $("#drawerTabPanel").addEventListener("click", event => {
            const demo = event.target.closest("[data-device-demo]");
            if (demo) toast(`${demo.dataset.deviceDemo} controls previewed`, "Only controls supported by this device would appear here.");
        });
        $("#systemMode").addEventListener("change", event => applySystemMode(event.target.value));

        $$("[data-action]").forEach(button => button.addEventListener("click", () => {
            if (button.dataset.action === "quiet") {
                $("#systemMode").value = "quiet";
                applySystemMode("quiet");
            }
            if (button.dataset.action === "lights") {
                state.lightsEnabled = !state.lightsEnabled;
                $("#lightingEnabled").checked = state.lightsEnabled;
                saveState("");
                toast(state.lightsEnabled ? "Lighting restored" : "Lights out", "All lighting changed in the prototype.");
            }
            if (button.dataset.action === "alerts") toast("All clear", "There are no simulated warnings or alerts.");
        }));

        $$(".zone-list-item[data-zone]").forEach(button => button.addEventListener("click", () => loadZone(button.dataset.zone)));
        $$("[data-zone-target]").forEach(button => button.addEventListener("click", () => loadZone(button.dataset.zoneTarget)));
        ["lowSpeed", "highSpeed", "rampTemp"].forEach(id => $(`#${id}`).addEventListener("input", drawCurve));
        $("#resetCurve").addEventListener("click", () => loadZone(activeZone));
        $("#applyCurve").addEventListener("click", () => {
            const zone = zoneData[activeZone];
            zone.low = Number($("#lowSpeed").value);
            zone.high = Number($("#highSpeed").value);
            zone.ramp = Number($("#rampTemp").value);
            zone.sensor = $("#zoneSensor").value;
            zone.profile = $("#zoneProfile").value;
            zone.zero = $("#zeroRpm").checked;
            toast("Curve applied to mock zone", "No hardware or backend request was made.");
        });
        $("#selectAllChannels").addEventListener("click", () => {
            $$(".channel-table input").forEach(input => input.checked = true);
            toast("All radiator channels selected");
        });
        $("#compareProfiles").addEventListener("click", () => toast("Profile comparison opened", "A future pass can import captured Windows/iCUE behavior here."));
        $("#newCoolingProfile").addEventListener("click", () => toast("New profile draft created", "The editor is ready for a custom curve."));
        $("#addZone").addEventListener("click", () => toast("Zone builder opened", "Group compatible cooling channels by their real-world role."));

        $$(".scene-card").forEach(card => card.addEventListener("click", () => applyScene(card.dataset.scene, card.dataset.color)));
        $("#lightingEnabled").addEventListener("change", event => {
            state.lightsEnabled = event.target.checked;
            $("#deskPreview").style.opacity = state.lightsEnabled ? "1" : ".22";
            saveState("");
            toast(state.lightsEnabled ? "Lighting enabled" : "Lighting disabled");
        });
        $("#lightingBrightness").addEventListener("input", event => {
            state.brightness = Number(event.target.value);
            $("#brightnessOutput").textContent = `${state.brightness}%`;
            $("#deskPreview").style.filter = `brightness(${.35 + state.brightness / 100})`;
        });
        $("#lightingBrightness").addEventListener("change", () => saveState(""));
        $(".lighting-targets").addEventListener("click", event => {
            const button = event.target.closest("button");
            if (!button) return;
            button.classList.toggle("active");
            toast(button.classList.contains("active") ? "Device added to scene" : "Device excluded from scene");
        });
        $("#applyScene").addEventListener("click", () => toast("Lighting scene applied", "Preview only—no backend request was made."));
        $("#newScene").addEventListener("click", () => toast("Scene composer opened", "A detailed effect editor would live here."));

        $$(".filter").forEach(button => button.addEventListener("click", () => {
            $$(".filter").forEach(item => item.classList.remove("active"));
            button.classList.add("active");
            filterDevices();
        }));
        $("#deviceSearch").addEventListener("input", filterDevices);
        $$(".capability-grid button").forEach(button => button.addEventListener("click", () => toast(button.dataset.capability, "This capability would open a focused configuration flow.")));

        $("#addAutomation").addEventListener("click", () => toast("Automation builder opened", "Choose a trigger, optional conditions, and one or more actions."));
        $$(".automation-card input").forEach(input => input.addEventListener("change", () => toast(input.checked ? "Automation enabled" : "Automation paused")));

        $$(".settings-nav button").forEach(button => button.addEventListener("click", () => {
            $$(".settings-nav button").forEach(item => item.classList.remove("active"));
            button.classList.add("active");
            $$(".settings-panel").forEach(panel => panel.classList.toggle("active", panel.dataset.settingsContent === button.dataset.settingsPanel));
        }));

        $$(".theme-choice").forEach(button => button.addEventListener("click", () => {
            state.theme = button.dataset.themeChoice;
            applyAppearance();
            saveState("Theme updated");
        }));
        $$(".accent").forEach(button => button.addEventListener("click", () => {
            state.accent = button.dataset.accent;
            applyAppearance();
            saveState("Accent color updated");
        }));
        $("#customAccent").addEventListener("input", event => {
            state.accent = event.target.value;
            applyAppearance();
        });
        $("#customAccent").addEventListener("change", () => saveState("Custom accent updated"));
        $$("[data-density-choice]").forEach(button => button.addEventListener("click", () => {
            state.density = button.dataset.densityChoice;
            applyAppearance();
            saveState("Interface density updated");
        }));
        $("#cornerRadius").addEventListener("input", event => {
            state.radius = Number(event.target.value);
            document.documentElement.style.setProperty("--radius", `${state.radius}px`);
            $("#cornerOutput").textContent = `${state.radius} px`;
        });
        $("#cornerRadius").addEventListener("change", () => saveState("Corner style updated"));
        $("#sidebarLabels").addEventListener("change", event => {
            state.sidebarLabels = event.target.checked;
            applyAppearance();
            saveState("Sidebar layout updated");
        });

        $("#customizeLayout").addEventListener("click", openLayoutDialog);
        $("#openLayoutFromSettings").addEventListener("click", openLayoutDialog);
        $("#layoutList").addEventListener("click", event => {
            const item = event.target.closest(".layout-item");
            if (!item) return;
            const key = item.dataset.layoutKey;
            const move = event.target.closest("[data-move]");
            if (move) {
                const index = state.widgetOrder.indexOf(key);
                const next = index + Number(move.dataset.move);
                if (next >= 0
                    && next < state.widgetOrder.length
                    && widgetMeta[state.widgetOrder[index]][2] === widgetMeta[state.widgetOrder[next]][2]) {
                    [state.widgetOrder[index], state.widgetOrder[next]] = [state.widgetOrder[next], state.widgetOrder[index]];
                    renderLayoutDialog();
                    applyWidgetLayout();
                    saveState("");
                }
            }
        });
        $("#layoutList").addEventListener("change", event => {
            const item = event.target.closest(".layout-item");
            if (!item) return;
            const key = item.dataset.layoutKey;
            state.hiddenWidgets = event.target.checked
                ? state.hiddenWidgets.filter(value => value !== key)
                : [...new Set([...state.hiddenWidgets, key])];
            applyWidgetLayout();
            saveState("");
        });
        $("#resetLayout").addEventListener("click", () => {
            state.widgetOrder = [...defaults.widgetOrder];
            state.hiddenWidgets = [];
            renderLayoutDialog();
            applyWidgetLayout();
            saveState("");
            toast("Dashboard layout reset");
        });

        $$(".capability-demo").forEach(button => button.addEventListener("click", () => toast("Capability flow opened", "This interaction is intentionally represented without backend wiring.")));
        $("#backupDemo").addEventListener("click", () => toast("Backup preview", "A real build would download the service-generated archive."));
        $("#restoreDemo").addEventListener("click", () => toast("Restore preview", "No file was uploaded or changed."));
        $("#restartDemo").addEventListener("click", () => toast("Restart simulated", "The OpenLinkHub service was not contacted."));
    }

    function initialize() {
        applyAppearance();
        bindEvents();
        applySystemMode(state.systemMode, false);
        loadZone("radiator");
        const selectedScene = $(`.scene-card[data-scene="${state.scene}"]`) || $(".scene-card");
        applyScene(selectedScene.dataset.scene, selectedScene.dataset.color, false);
        $("#deskPreview").style.opacity = state.lightsEnabled ? "1" : ".22";
        $("#deskPreview").style.filter = `brightness(${.35 + state.brightness / 100})`;
        const route = location.hash.slice(1);
        navigate(routes[route] ? route : "overview");
    }

    initialize();
})();
