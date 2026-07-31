"""Pure API adapters used by the read-only Plasma client."""

from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Any, Mapping


class PayloadError(ValueError):
    """Raised when a legacy response cannot be normalized safely."""


@dataclass(frozen=True)
class ApiEnvelope:
    code: int
    status: int | None
    message: str
    data: Any = None
    device: Any = None
    devices: Any = None
    dashboard: Any = None

    @classmethod
    def from_bytes(cls, payload: bytes) -> "ApiEnvelope":
        try:
            decoded = json.loads(payload)
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise PayloadError("The service returned malformed JSON.") from error
        return cls.from_mapping(decoded)

    @classmethod
    def from_mapping(cls, decoded: Any) -> "ApiEnvelope":
        if not isinstance(decoded, Mapping):
            raise PayloadError("The service response is not a JSON object.")

        code = decoded.get("code", 0)
        if not isinstance(code, int):
            raise PayloadError("The service response has an invalid code field.")
        status = decoded.get("status")
        if status is not None and not isinstance(status, int):
            raise PayloadError("The service response has an invalid status field.")

        return cls(
            code=code,
            status=status,
            message=str(decoded.get("message", "")),
            data=decoded.get("data"),
            device=decoded.get("device"),
            devices=decoded.get("devices"),
            dashboard=decoded.get("dashboard"),
        )


@dataclass(frozen=True)
class VersionedDocument:
    api_version: str
    kind: str
    revision: int
    data: Mapping[str, Any]

    @classmethod
    def from_bytes(cls, payload: bytes, *, kind: str) -> "VersionedDocument":
        try:
            decoded = json.loads(payload)
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise PayloadError("The service returned malformed JSON.") from error
        return cls.from_mapping(decoded, kind=kind)

    @classmethod
    def from_mapping(
        cls,
        decoded: Any,
        *,
        kind: str,
    ) -> "VersionedDocument":
        if not isinstance(decoded, Mapping):
            raise PayloadError("The versioned response is not a JSON object.")
        api_version = decoded.get("apiVersion")
        response_kind = decoded.get("kind")
        revision = decoded.get("revision")
        data = decoded.get("data")
        if api_version != "1.0" or response_kind != kind:
            raise PayloadError("The service does not support contract 1.0.")
        if not isinstance(revision, int) or revision < 1:
            raise PayloadError("The versioned response has an invalid revision.")
        if not isinstance(data, Mapping):
            raise PayloadError("The versioned response has an invalid data object.")
        return cls(
            api_version=api_version,
            kind=response_kind,
            revision=revision,
            data=data,
        )


def _mapping(value: Any) -> Mapping[str, Any]:
    return value if isinstance(value, Mapping) else {}


def _items(value: Any) -> list[tuple[str, Mapping[str, Any]]]:
    if not isinstance(value, Mapping):
        return []
    return [
        (str(key), item)
        for key, item in value.items()
        if isinstance(item, Mapping)
    ]


def _number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    return None


def _text(value: Any, fallback: str = "") -> str:
    return str(value) if value not in (None, "") else fallback


def _format_temperature(value: Any) -> str:
    number = _number(value)
    if number is None:
        return "—"
    return f"{number:.1f}°C"


def _format_rpm(value: Any) -> str:
    number = _number(value)
    if number is None:
        return "—"
    return f"{round(number):,} RPM"


def _stat(
    title: str,
    value: str,
    description: str = "",
    *,
    accent: bool = False,
) -> dict[str, Any]:
    return {
        "title": title,
        "description": description,
        "kind": "stat",
        "value": value,
        "accent": accent,
    }


def _group(
    title: str,
    icon: str,
    description: str,
    items: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "title": title,
        "icon": icon,
        "description": description,
        "items": items,
    }


def _tab(
    name: str,
    icon: str,
    groups: list[dict[str, Any]],
    **extra: Any,
) -> dict[str, Any]:
    tab = {"name": name, "icon": icon, "groups": groups, "readOnly": True}
    tab.update(extra)
    return tab


def _color_hex(value: Any) -> str:
    color = _mapping(value)

    def channel(name: str) -> int:
        number = _number(color.get(name))
        return max(0, min(255, round(number if number is not None else 0)))

    return f"#{channel('red'):02x}{channel('green'):02x}{channel('blue'):02x}"


def _profile_display_name(key: str, profile: Mapping[str, Any]) -> str:
    reported = _text(profile.get("profileName"))
    if reported:
        return reported
    purpose_names = {
        "keyboard": "Per-key Colors",
        "mouse": "Zone Colors",
    }
    if key in purpose_names:
        return purpose_names[key]
    return key.replace("-", " ").replace("_", " ").title()


def _normalize_lighting(
    product: str,
    detail: Mapping[str, Any],
    channels: list[tuple[str, Mapping[str, Any]]],
    raw_library: Mapping[str, Any],
) -> dict[str, Any]:
    profiles: list[dict[str, Any]] = []
    for key, profile in _items(raw_library.get("profiles")):
        gradients = [
            _color_hex(color)
            for _, color in sorted(
                _items(profile.get("gradients")),
                key=lambda item: (
                    0,
                    int(item[0]),
                )
                if item[0].isdigit()
                else (1, item[0]),
            )
        ]
        brightness = _number(profile.get("brightness"))
        profiles.append(
            {
                "key": key,
                "name": _profile_display_name(key, profile),
                "speed": _number(profile.get("speed")) or 0,
                "brightness": round((brightness or 0) * 100),
                "smoothness": round(_number(profile.get("smoothness")) or 0),
                "startColor": _color_hex(profile.get("start")),
                "middleColor": _color_hex(profile.get("middle")),
                "endColor": _color_hex(profile.get("end")),
                "gradientColors": gradients,
                "minTemperature": _number(profile.get("minTemp")) or 0,
                "maxTemperature": _number(profile.get("maxTemp")) or 0,
                "direction": round(_number(profile.get("rgbDirection")) or 0),
                "alternateColors": bool(profile.get("alternateColors")),
                "perLed": bool(profile.get("perLed")),
                "temperatureReactive": (
                    key.endswith("-temperature")
                    or (_number(profile.get("maxTemp")) or 0) > 0
                ),
            }
        )
    profiles.sort(key=lambda profile: (profile["name"].casefold(), profile["key"]))

    profile_keys = {profile["key"] for profile in profiles}
    targets: list[dict[str, Any]] = []
    ordered_channels = sorted(
        channels,
        key=lambda item: (
            0,
            int(item[0]),
        )
        if item[0].isdigit()
        else (1, item[0]),
    )
    for channel_id, channel in ordered_channels:
        active_profile = _text(channel.get("rgb"))
        if not active_profile:
            continue
        reported_label = _text(channel.get("label"))
        if reported_label.casefold() in {"set label", "label"}:
            reported_label = ""
        target_name = _text(
            reported_label or channel.get("name"),
            f"Channel {channel_id}",
        )
        targets.append(
            {
                "key": channel_id,
                "name": f"{target_name} · Ch {channel_id}",
                "description": (
                    f"Channel {channel_id} · "
                    f"{_text(channel.get('description'), 'attached lighting device')}"
                ),
                "activeProfile": (
                    active_profile if active_profile in profile_keys else profiles[0]["key"]
                    if profiles else active_profile
                ),
            }
        )

    if not targets:
        device_profile = _mapping(detail.get("DeviceProfile"))
        active_profile = _text(
            device_profile.get("RGBProfile")
            or detail.get("RGBProfile")
            or detail.get("SlipstreamRGBProfile")
        )
        if active_profile not in profile_keys and profiles:
            active_profile = profiles[0]["key"]
        zone_count = round(_number(detail.get("ZoneAmount")) or 0)
        if zone_count > 1:
            target_description = f"{zone_count} color zones · one device effect"
        elif "K100" in product.upper() or detail.get("UIKeyboard"):
            target_description = "Keyboard lighting surface"
        else:
            target_description = "Whole-device lighting target"
        targets.append(
            {
                "key": "device",
                "name": "Whole device",
                "description": target_description,
                "activeProfile": active_profile,
            }
        )

    return {
        "source": "OpenLinkHub /api/color/ filtered device library",
        "device": _text(raw_library.get("device"), product),
        "defaultColor": _color_hex(raw_library.get("defaultColor")),
        "targets": targets,
        "profiles": profiles,
        "profileCount": len(profiles),
    }


CAPABILITY_ICONS = {
    "Cooling": "temperature-normal",
    "Sensors": "office-chart-line",
    "Lighting": "preferences-desktop-color",
    "Topology": "view-list-tree",
    "Display": "video-display",
    "Keys": "input-keyboard",
    "Actuation": "input-keyboard",
    "Buttons": "configure-shortcuts",
    "DPI": "input-mouse",
    "Performance": "preferences-system-performance",
    "Profiles": "document-multiple",
    "Audio": "audio-headphones",
    "Power": "battery",
    "Controls": "input-gaming",
    "Analog": "office-chart-line",
    "Vibration": "preferences-desktop-notification-bell",
    "Pairing": "network-wireless",
    "Wireless": "network-wireless",
}


def _device_icon(product: str, detail: Mapping[str, Any]) -> str:
    upper = product.upper()
    keyboard_tokens = (
        "KEYBOARD", "K55", "K60", "K65", "K68", "K70", "K95", "K100", "STRAFE"
    )
    if any(token in upper for token in keyboard_tokens):
        return "input-keyboard"
    if "SCUF" in upper or "CONTROLLER" in upper:
        return "input-gaming"
    if any(token in upper for token in ("HEADSET", "VIRTUOSO", "HS80", "VOID")):
        return "audio-headphones"
    mouse_tokens = (
        "MOUSE", "SCIMITAR", "M65", "M75", "HARPOON", "IRONCLAW",
        "DARKSTAR", "KATAR", "SABRE",
    )
    if any(token in upper for token in mouse_tokens):
        return "input-mouse"
    if "SLIPSTREAM" in upper or "DONGLE" in upper:
        return "network-wireless"
    if "PSU" in upper or detail.get("Psu"):
        return "preferences-system-power-management"
    if any(token in upper for token in ("LCD", "DISPLAY", "XENEON")) and not detail.get("devices"):
        return "video-display"
    if "MEMORY" in upper or "DRAM" in upper:
        return "memory"
    if detail.get("devices") or "HUB" in upper or "COMMANDER" in upper:
        return "drive-multidisk"
    return "applications-system"


def _infer_capabilities(
    product: str,
    detail: Mapping[str, Any],
    channels: list[tuple[str, Mapping[str, Any]]],
) -> list[str]:
    capabilities: list[str] = []
    upper = product.upper()

    def add(name: str, condition: bool = True) -> None:
        if condition and name not in capabilities:
            capabilities.append(name)

    add("Cooling", any(bool(channel.get("HasSpeed")) for _, channel in channels))
    add(
        "Sensors",
        bool(detail.get("TemperatureProbes"))
        or any(
            bool(channel.get("HasTemps"))
            or bool(channel.get("IsTemperatureProbe"))
            or _number(channel.get("temperature")) not in (None, 0.0)
            for _, channel in channels
        ),
    )
    add(
        "Lighting",
        any(
            key in detail
            for key in ("RGBModes", "Rgb", "LEDChannels", "ChangeableLedChannels")
        )
        or any(_text(channel.get("rgb")) != "" for _, channel in channels),
    )
    add("Topology", bool(channels))
    add("Display", bool(detail.get("HasLCD")) or bool(detail.get("LCDModes")))

    keyboard_tokens = (
        "K55", "K60", "K65", "K68", "K70", "K95", "K100", "KEYBOARD", "STRAFE"
    )
    keyboard = (
        any(token in upper for token in keyboard_tokens)
        or "KeyboardKey" in detail
        or "UIKeyboard" in detail
    )
    mouse_tokens = (
        "SCIMITAR", "M65", "M75", "HARPOON", "IRONCLAW",
        "DARKSTAR", "KATAR", "SABRE", "MOUSE",
    )
    mouse = (
        any(token in upper for token in mouse_tokens)
        or "DPIAmount" in detail
        or "MaxDPI" in detail
    )
    headset = (
        any(token in upper for token in ("HEADSET", "VIRTUOSO", "HS80", "VOID"))
        or any(key in detail for key in ("Equalizers", "NoiseCancellation", "SideTone"))
    )
    controller = (
        "SCUF" in upper
        or "CONTROLLER" in upper
        or any(key in detail for key in ("VibrationValue", "EmulationMode", "CurveData"))
    )

    add("Keys", keyboard)
    add("Actuation", keyboard and any("Actuation" in key for key in detail))
    add("Buttons", mouse or headset)
    add("DPI", mouse)
    add("Performance", (keyboard or mouse) and "PollingRates" in detail)
    add("Profiles", keyboard or bool(detail.get("userProfiles")))
    add("Audio", headset)
    add("Controls", controller)
    add("Analog", controller)
    add("Vibration", controller)
    add(
        "Power",
        _number(detail.get("BatteryLevel")) is not None
        and detail.get("Usb") is not True,
    )
    add("Wireless", bool(detail.get("Connected")) and not bool(detail.get("Usb", True)))
    add("Pairing", "SLIPSTREAM" in upper or "DONGLE" in upper)

    return capabilities


def _profile_name(detail: Mapping[str, Any]) -> str:
    profile = _mapping(detail.get("DeviceProfile"))
    return _text(
        profile.get("Profile")
        or profile.get("ActiveProfile")
        or profile.get("RGBProfile"),
        "Service managed",
    )


def _transport_display_name(product: str) -> str:
    upper = product.upper()
    if upper in {"SLIPSTREAM", "SLIPSTREAM WIRELESS"}:
        return "Slipstream Receiver"
    if "DONGLE" in upper or "RECEIVER" in upper:
        return product
    return f"{product} Receiver"


def _is_user_transport(product: str) -> bool:
    upper = product.upper()
    return any(token in upper for token in ("SLIPSTREAM", "DONGLE", "RECEIVER"))


def _build_tabs(
    product: str,
    firmware: str,
    capabilities: list[str],
    detail: Mapping[str, Any],
    channels: list[tuple[str, Mapping[str, Any]]],
    battery: float | None,
    lighting_library: Mapping[str, Any],
    *,
    transport: bool = False,
) -> list[dict[str, Any]]:
    identity_items = [
        _stat(
            "Connection",
            "Detected transport · live" if transport else "Connected · live",
            "Read from the loopback service",
            accent=True,
        ),
        _stat("Product", product, "Backend-reported identity"),
        _stat("Firmware", firmware or "Not reported", "Backend-reported firmware"),
        _stat(
            "Capability source",
            "Legacy adapter",
            "Provisional until the versioned capability manifest exists",
        ),
    ]
    if battery is not None:
        identity_items.append(_stat("Battery", f"{round(battery)}%", "Read-only telemetry"))

    tabs = [
        _tab(
            "Overview",
            "view-grid",
            [
                _group(
                    "Live identity",
                    "dialog-ok",
                    "This Phase 1 tab contains read-only service state.",
                    identity_items,
                ),
                _group(
                    "Detected capabilities",
                    "view-list-details",
                    "Legacy payload inference is visible and deliberately provisional.",
                    [
                        _stat(name, "Available", "No mutation callback is connected")
                        for name in capabilities
                    ]
                    or [_stat("Detailed controls", "Not reported")],
                ),
            ],
        )
    ]

    for capability in capabilities:
        icon = CAPABILITY_ICONS.get(capability, "applications-system")
        items: list[dict[str, Any]] = []
        description = "Detected from the current legacy device payload."
        tab_extra: dict[str, Any] = {}

        if capability == "Cooling":
            for channel_id, channel in channels:
                if not channel.get("HasSpeed"):
                    continue
                title = _text(channel.get("label") or channel.get("name"), f"Channel {channel_id}")
                value = _format_rpm(channel.get("rpm"))
                profile = _text(channel.get("profile"), "No profile reported")
                items.append(_stat(title, value, f"Channel {channel_id} · {profile}"))
        elif capability == "Sensors":
            for channel_id, channel in channels:
                temperature = _number(channel.get("temperature"))
                if temperature in (None, 0.0) and not channel.get("IsTemperatureProbe"):
                    continue
                title = _text(channel.get("label") or channel.get("name"), f"Sensor {channel_id}")
                items.append(
                    _stat(
                        title,
                        _format_temperature(temperature),
                        f"Channel {channel_id} · read-only",
                        accent=temperature not in (None, 0.0),
                    )
                )
        elif capability == "Lighting":
            normalized_lighting = _normalize_lighting(
                product,
                detail,
                channels,
                lighting_library,
            )
            if channels:
                for channel_id, channel in channels:
                    rgb = _text(channel.get("rgb"))
                    if rgb:
                        title = _text(channel.get("label") or channel.get("name"), f"Channel {channel_id}")
                        items.append(_stat(title, rgb, f"Channel {channel_id} · active effect"))
            if not items:
                items.append(_stat("Active lighting", _profile_name(detail), "Read-only profile state"))
            items.extend(
                [
                    _stat(
                        "Supported effects",
                        str(normalized_lighting["profileCount"]),
                        "Filtered by the backend for this device",
                    ),
                    _stat(
                        "Lighting targets",
                        str(len(normalized_lighting["targets"])),
                        "Whole-device or channel-level assignment scope",
                    ),
                ]
            )
            tab_extra["lightingEditor"] = normalized_lighting
        elif capability == "Topology":
            items = [
                _stat(
                    _text(channel.get("label") or channel.get("name"), f"Channel {channel_id}"),
                    _text(channel.get("description"), "Attached device"),
                    f"Channel {channel_id} · port {_text(channel.get('portId'), '—')}",
                )
                for channel_id, channel in channels
            ]
        elif capability == "Display":
            brightness_levels = detail.get("LCDBrightnessLevels", [])
            items = [
                _stat("LCD support", "Available", "Reported by the device"),
                _stat(
                    "LCD brightness modes",
                    str(len(brightness_levels) if isinstance(brightness_levels, (list, dict)) else 0),
                    "Reported options",
                ),
            ]
        elif capability == "DPI":
            items = [
                _stat("DPI stages", _text(detail.get("DPIAmount"), "Not reported")),
                _stat(
                    "DPI range",
                    f"{_text(detail.get('MinDPI'), '—')}–{_text(detail.get('MaxDPI'), '—')}",
                    "Backend-reported limits",
                ),
            ]
        elif capability == "Performance":
            items = [
                _stat(
                    "Polling-rate options",
                    str(len(_mapping(detail.get("PollingRates")))),
                    "Read-only option inventory",
                )
            ]
        elif capability == "Profiles":
            profiles = detail.get("userProfiles", [])
            items = [
                _stat("Active profile", _profile_name(detail)),
                _stat(
                    "Saved snapshots",
                    str(len(profiles) if isinstance(profiles, (list, dict)) else 0),
                    "Device-local profiles",
                ),
            ]
        elif capability == "Power":
            value = f"{round(battery)}%" if battery is not None else "Not reported"
            items = [_stat("Battery level", value)]
        elif capability == "Wireless" and transport:
            items = [
                _stat(
                    "Receiver transport",
                    "Detected",
                    "OpenLinkHub marks this service-owned transport as hidden",
                    accent=True,
                )
            ]
        elif capability == "Pairing" and transport:
            items = [
                _stat(
                    "Receiver",
                    "Available",
                    "The wireless transport is present and managed by OpenLinkHub",
                    accent=True,
                ),
                _stat(
                    "Paired-device inventory",
                    "Not reported",
                    "The legacy device endpoint exposes no receiver detail",
                ),
            ]

        if not items:
            items = [
                _stat(
                    capability,
                    "Available",
                    "Detailed read mapping is scheduled for a later Phase 1 fixture",
                )
            ]

        tabs.append(
            _tab(
                capability,
                icon,
                [
                    _group(
                        f"Live {capability.lower()} state",
                        icon,
                        description,
                        items,
                    )
                ],
                **tab_extra,
            )
        )

    return tabs


class LegacySnapshot:
    """Normalize a set of successful legacy GET responses."""

    def __init__(
        self,
        *,
        inventory: Mapping[str, Any],
        details: Mapping[str, Mapping[str, Any]],
        batteries: Mapping[str, Any] | None = None,
        lighting_profiles: Mapping[str, Any] | None = None,
        cpu_temperature: Any = None,
        gpu_temperature: Any = None,
    ) -> None:
        self.inventory = inventory
        self.details = details
        self.batteries = _mapping(batteries)
        self.lighting_profiles = _mapping(lighting_profiles)
        self.cpu_temperature = cpu_temperature
        self.gpu_temperature = gpu_temperature

    def build(self) -> dict[str, Any]:
        records = _mapping(self.inventory.get("devices"))
        devices: list[dict[str, Any]] = []
        all_channels: list[tuple[str, Mapping[str, Any]]] = []
        coolant: float | None = None

        for device_id, wrapper in _items(records):
            product = _text(wrapper.get("Product"), "Unknown device")
            if product.casefold() == "cluster":
                continue
            transport = bool(wrapper.get("Hidden"))
            if transport and not _is_user_transport(product):
                continue

            detail = _mapping(self.details.get(device_id))
            if not detail:
                detail = _mapping(wrapper.get("GetDevice"))

            channels = _items(detail.get("devices"))
            all_channels.extend(channels)
            firmware = _text(detail.get("firmware") or wrapper.get("Firmware"))
            battery_record = _mapping(self.batteries.get(device_id))
            battery = _number(
                battery_record.get("Level")
                if battery_record
                else detail.get("BatteryLevel")
            )
            if detail.get("Usb") is True:
                battery = None
            capabilities = _infer_capabilities(product, detail, channels)
            if transport:
                capabilities = ["Wireless", "Pairing"]
            lighting_library = _mapping(self.lighting_profiles.get(device_id))

            for _, channel in channels:
                temperature = _number(channel.get("temperature"))
                if temperature not in (None, 0.0) and (
                    bool(channel.get("AIO"))
                    or "AIO" in _text(channel.get("description")).upper()
                    or "PUMP" in _text(channel.get("description")).upper()
                ):
                    coolant = temperature

            subtitle_parts = ["Live"]
            if transport:
                subtitle_parts.extend(
                    ["Service transport", "paired inventory unavailable"]
                )
            elif firmware:
                subtitle_parts.append(f"Firmware {firmware}")
            if channels:
                subtitle_parts.append(f"{len(channels)} channels")
            if battery is not None:
                subtitle_parts.append(f"Battery {round(battery)}%")

            devices.append(
                {
                    "id": device_id,
                    "name": (
                        _transport_display_name(product)
                        if transport
                        else product
                    ),
                    "icon": _device_icon(product, detail),
                    "subtitle": " · ".join(subtitle_parts),
                    "capabilities": capabilities,
                    "tabs": _build_tabs(
                        product,
                        firmware,
                        capabilities,
                        detail,
                        channels,
                        battery,
                        lighting_library,
                        transport=transport,
                    ),
                    "connected": bool(detail.get("Connected", True)),
                    "source": "live-transport" if transport else "live",
                }
            )

        # Go map iteration order is deliberately unstable. Present ordinary
        # devices deterministically and keep service transports grouped last so
        # cards do not jump between grid cells on every inventory response.
        devices.sort(
            key=lambda device: (
                device["source"] == "live-transport",
                device["name"].casefold(),
                device["id"],
            )
        )

        cooling_zones, zone_values = self._cooling_zones(all_channels)
        telemetry = {
            "cpu": _format_temperature(self.cpu_temperature),
            "gpu": _format_temperature(self.gpu_temperature),
            "coolant": _format_temperature(coolant),
            "acoustics": "Read-only",
        }
        overview_metrics = [
            {
                "key": "cpu",
                "label": "CPU",
                "detail": "OpenLinkHub service sensor",
                "icon": "cpu",
                "state": "Live" if telemetry["cpu"] != "—" else "Unavailable",
                "warning": telemetry["cpu"] == "—",
            },
            {
                "key": "gpu",
                "label": "GPU",
                "detail": "OpenLinkHub service sensor",
                "icon": "video-card-inactive",
                "state": "Live" if telemetry["gpu"] != "—" else "Unavailable",
                "warning": telemetry["gpu"] == "—",
            },
            {
                "key": "coolant",
                "label": "Coolant",
                "detail": "Detected AIO liquid sensor",
                "icon": "temperature-normal",
                "state": "Live" if telemetry["coolant"] != "—" else "Unavailable",
                "warning": telemetry["coolant"] == "—",
            },
            {
                "key": "acoustics",
                "label": "Service",
                "detail": "No write operations are connected",
                "icon": "network-connect",
                "state": "Read only",
                "warning": False,
            },
        ]
        return {
            "devices": devices,
            "telemetry": telemetry,
            "overviewMetrics": overview_metrics,
            "coolingZones": cooling_zones,
            "zoneValues": zone_values,
        }

    @staticmethod
    def _cooling_zones(
        channels: list[tuple[str, Mapping[str, Any]]],
    ) -> tuple[list[dict[str, Any]], dict[str, str]]:
        grouped: dict[str, dict[str, Any]] = {}
        for channel_id, channel in channels:
            if not channel.get("HasSpeed"):
                continue
            profile = _text(channel.get("profile"), "Unassigned")
            description = _text(channel.get("description"))
            name = _text(channel.get("name"))
            is_pump = bool(channel.get("AIO")) or "PUMP" in (description + " " + name).upper()
            key = "pump" if is_pump else profile.casefold().replace(" ", "-")
            group = grouped.setdefault(
                key,
                {
                    "key": key,
                    "name": "Pump" if is_pump else profile,
                    "icon": "media-playback-start" if is_pump else "temperature-normal",
                    "source": "Device sensor" if is_pump else "Service profile",
                    "temperature": "—",
                    "profile": profile,
                    "profiles": [profile],
                    "zeroRpm": False,
                    "minimum": 0,
                    "rpms": [],
                    "channels": [],
                },
            )
            rpm = _number(channel.get("rpm"))
            if rpm is not None:
                group["rpms"].append(rpm)
            group["channels"].append(channel_id)
            temperature = _number(channel.get("temperature"))
            if temperature not in (None, 0.0):
                group["temperature"] = _format_temperature(temperature)

        zones: list[dict[str, Any]] = []
        values: dict[str, str] = {}
        for group in grouped.values():
            rpms = group.pop("rpms")
            channels_for_group = group.pop("channels")
            average = sum(rpms) / len(rpms) if rpms else None
            group["channelSummary"] = ", ".join(channels_for_group)
            zones.append(group)
            values[group["key"]] = _format_rpm(average)
        return zones, values


def _contract_color(value: Any) -> dict[str, int]:
    text = _text(value).lstrip("#")
    if len(text) != 6:
        return {"red": 0, "green": 0, "blue": 0}
    try:
        return {
            "red": int(text[0:2], 16),
            "green": int(text[2:4], 16),
            "blue": int(text[4:6], 16),
        }
    except ValueError:
        return {"red": 0, "green": 0, "blue": 0}


def _legacy_lighting_from_contract(value: Any) -> dict[str, Any]:
    lighting = _mapping(value)
    profiles: dict[str, Any] = {}
    raw_profiles = lighting.get("profiles")
    if isinstance(raw_profiles, list):
        for raw in raw_profiles:
            profile = _mapping(raw)
            profile_id = _text(profile.get("id"))
            if not profile_id:
                continue
            gradients = {
                str(index): _contract_color(color)
                for index, color in enumerate(profile.get("gradientColors", []))
            }
            profiles[profile_id] = {
                "profileName": _text(profile.get("name"), profile_id),
                "speed": _number(profile.get("speed")) or 0,
                "brightness": (_number(profile.get("brightness")) or 0) / 100,
                "smoothness": _number(profile.get("smoothness")) or 0,
                "start": _contract_color(profile.get("startColor")),
                "middle": _contract_color(profile.get("middleColor")),
                "end": _contract_color(profile.get("endColor")),
                "gradients": gradients,
                "minTemp": _number(profile.get("minTemperature")) or 0,
                "maxTemp": _number(profile.get("maxTemperature")) or 0,
                "rgbDirection": _number(profile.get("direction")) or 0,
                "alternateColors": bool(profile.get("alternateColors")),
                "perLed": bool(profile.get("perLed")),
            }
    return {
        "device": _text(lighting.get("device")),
        "defaultColor": _contract_color(lighting.get("defaultColor")),
        "profiles": profiles,
    }


class ContractSnapshot:
    """Adapt a validated version 1 snapshot to the stable QML presentation model."""

    def __init__(self, data: Mapping[str, Any]) -> None:
        self.data = data

    def build(self) -> dict[str, Any]:
        raw_devices = self.data.get("devices")
        if not isinstance(raw_devices, list):
            raise PayloadError("The contract snapshot has no device inventory.")

        inventory: dict[str, Any] = {"devices": {}}
        details: dict[str, Mapping[str, Any]] = {}
        batteries: dict[str, Any] = {}
        lighting_profiles: dict[str, Any] = {}
        capabilities_by_id: dict[str, list[Mapping[str, Any]]] = {}

        for raw in raw_devices:
            device = _mapping(raw)
            device_id = _text(device.get("id"))
            if not device_id:
                continue
            product = _text(device.get("product"), "Unknown device")
            transport = _text(device.get("transport"), "usb")
            hidden = bool(device.get("hidden")) or transport in {
                "receiver",
                "internal",
            }
            channels: dict[str, Any] = {}
            raw_channels = device.get("channels")
            if isinstance(raw_channels, list):
                for raw_channel in raw_channels:
                    channel = _mapping(raw_channel)
                    channel_id = _text(channel.get("id"))
                    if not channel_id:
                        continue
                    speed = _mapping(channel.get("speed"))
                    temperature = _mapping(channel.get("temperature"))
                    cooling_profile = _mapping(channel.get("coolingProfile"))
                    lighting_effect = _mapping(channel.get("lightingEffect"))
                    channels[channel_id] = {
                        "name": _text(channel.get("name")),
                        "label": _text(channel.get("label")),
                        "description": _text(channel.get("description")),
                        "portId": channel.get("port"),
                        "HasSpeed": bool(channel.get("hasSpeed")),
                        "HasTemps": bool(channel.get("hasTemperature")),
                        "IsTemperatureProbe": channel.get("role") == "probe",
                        "AIO": channel.get("role") == "pump",
                        "rpm": speed.get("value"),
                        "temperature": temperature.get("value"),
                        "profile": _text(cooling_profile.get("id")),
                        "rgb": _text(lighting_effect.get("id")),
                    }

            profile = _mapping(device.get("profile"))
            detail: dict[str, Any] = {
                "Connected": bool(device.get("online", True)),
                "Usb": transport == "usb",
                "firmware": _text(device.get("firmware")),
                "devices": channels,
                "DeviceProfile": {"Profile": _text(profile.get("active"))},
                "userProfiles": [
                    {}
                    for _ in range(max(0, round(_number(profile.get("savedCount")) or 0)))
                ],
            }

            raw_capabilities = device.get("capabilities")
            capabilities = (
                [
                    capability
                    for capability in raw_capabilities
                    if isinstance(capability, Mapping)
                ]
                if isinstance(raw_capabilities, list)
                else []
            )
            capabilities_by_id[device_id] = capabilities
            for capability in capabilities:
                capability_id = _text(capability.get("id"))
                options = _mapping(capability.get("options"))
                if capability_id == "dpi":
                    detail["DPIAmount"] = options.get("stageCount")
                    detail["MinDPI"] = options.get("minimum")
                    detail["MaxDPI"] = options.get("maximum")
                elif capability_id == "performance":
                    rates = options.get("pollingRates")
                    if isinstance(rates, list):
                        detail["PollingRates"] = {
                            str(index): rate for index, rate in enumerate(rates)
                        }
                elif capability_id == "display":
                    detail["HasLCD"] = True
                    detail["LCDBrightnessLevels"] = [
                        {}
                        for _ in range(
                            max(
                                0,
                                round(
                                    _number(options.get("brightnessModeCount")) or 0
                                ),
                            )
                        )
                    ]

            inventory["devices"][device_id] = {
                "Product": product,
                "ProductType": device.get("productType"),
                "ProductId": device.get("productId"),
                "Firmware": _text(device.get("firmware")),
                "Hidden": hidden,
                "GetDevice": detail,
            }
            details[device_id] = detail

            battery = _mapping(device.get("battery"))
            if _number(battery.get("value")) is not None:
                batteries[device_id] = {"Level": battery.get("value")}

            lighting = _mapping(device.get("lighting"))
            if lighting:
                converted = _legacy_lighting_from_contract(lighting)
                lighting_profiles[device_id] = converted
                targets = lighting.get("targets")
                if isinstance(targets, list):
                    for target in targets:
                        target_data = _mapping(target)
                        target_id = _text(target_data.get("id"))
                        if target_id in channels:
                            channels[target_id]["rgb"] = _text(
                                target_data.get("activeProfile")
                            )
                        elif target_id == "device":
                            detail["DeviceProfile"]["RGBProfile"] = _text(
                                target_data.get("activeProfile")
                            )

        system = _mapping(self.data.get("system"))
        cpu = _mapping(system.get("cpu")).get("value")
        gpu = _mapping(system.get("gpu")).get("value")
        snapshot = LegacySnapshot(
            inventory=inventory,
            details=details,
            batteries=batteries,
            lighting_profiles=lighting_profiles,
            cpu_temperature=cpu,
            gpu_temperature=gpu,
        ).build()

        for device in snapshot["devices"]:
            device_id = device["id"]
            capabilities = capabilities_by_id.get(device_id, [])
            labels = [
                _text(capability.get("label"), _text(capability.get("id")).title())
                for capability in capabilities
                if _text(capability.get("id")) != "overview"
            ]
            contract_detail = details.get(device_id, {})
            contract_channels = _items(contract_detail.get("devices"))
            battery = _number(_mapping(batteries.get(device_id)).get("Level"))
            lighting = _mapping(lighting_profiles.get(device_id))
            transport = device["source"] == "live-transport"
            device["capabilities"] = labels
            device["tabs"] = _build_tabs(
                _text(
                    _mapping(inventory["devices"].get(device_id)).get("Product"),
                    device["name"],
                ),
                _text(contract_detail.get("firmware")),
                labels,
                contract_detail,
                contract_channels,
                battery,
                lighting,
                transport=transport,
            )
            device["source"] = (
                "contract-transport" if transport else "contract-v1"
            )
            overview = device["tabs"][0]
            overview["groups"][0]["description"] = (
                "This tab is normalized from the version 1 read-only contract."
            )
            overview["groups"][0]["items"][3] = _stat(
                "Capability source",
                "Versioned contract 1.0",
                "Backend-published semantic capabilities",
                accent=True,
            )
            overview["groups"][1]["description"] = (
                "Published by the backend rather than inferred from raw fields."
            )
            for item, capability in zip(
                overview["groups"][1]["items"],
                [
                    capability
                    for capability in capabilities
                    if _text(capability.get("id")) != "overview"
                ],
                strict=False,
            ):
                if not bool(capability.get("available", True)):
                    item["value"] = "Unavailable"
                    item["description"] = _text(capability.get("reason"))

        return snapshot
