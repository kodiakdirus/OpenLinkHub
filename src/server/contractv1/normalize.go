package contractv1

import (
	"encoding/json"
	"fmt"
	"math"
	"net"
	"sort"
	"strconv"
	"strings"
)

var capabilityLabels = map[string]string{
	"overview":    "Overview",
	"cooling":     "Cooling",
	"sensors":     "Sensors",
	"lighting":    "Lighting",
	"topology":    "Topology",
	"display":     "Display",
	"keys":        "Keys",
	"actuation":   "Actuation",
	"buttons":     "Buttons",
	"dpi":         "DPI",
	"performance": "Performance",
	"profiles":    "Profiles",
	"audio":       "Audio",
	"power":       "Power",
	"controls":    "Controls",
	"analog":      "Analog",
	"vibration":   "Vibration",
	"pairing":     "Pairing",
	"wireless":    "Wireless",
}

func BuildService(input ServiceInput, deviceCount int) ServiceDescriptor {
	loopback := isLoopback(input.ListenAddress)
	scope := "network"
	if loopback {
		scope = "loopback"
	}

	features := environmentFeatures(input)
	warnings := make([]string, 0, 2)
	if !loopback {
		warnings = append(
			warnings,
			"The service listener is not restricted to loopback.",
		)
	}
	if input.ManualMode {
		warnings = append(
			warnings,
			"Manual mode disables normal automatic temperature control.",
		)
	}

	return ServiceDescriptor{
		Service:  "OpenLinkHub",
		Contract: APIVersion,
		Build: Build{
			Version:  input.Version,
			Revision: input.BuildRevision,
			Time:     input.BuildTime,
			Modified: input.BuildModified,
		},
		Listener: Listener{
			Scope:    scope,
			Loopback: loopback,
			Port:     input.ListenPort,
		},
		Frontend:       input.Frontend,
		Metrics:        input.Metrics,
		ManualMode:     input.ManualMode,
		SystemService:  input.SystemService,
		DeviceCount:    deviceCount,
		Persistence:    "unknown",
		MutationAccess: "guarded-labels-lighting-ownership",
		Features:       features,
		Warnings:       warnings,
	}
}

func BuildManifest(input Input) CapabilityManifest {
	devices := normalizeDevices(input.Devices)
	result := make([]DeviceCapability, 0, len(devices))
	for _, device := range devices {
		result = append(result, DeviceCapability{
			ID:           device.ID,
			Product:      device.Product,
			ProductID:    device.ProductID,
			ProductType:  device.ProductType,
			DeviceType:   device.DeviceType,
			Online:       device.Online,
			Transport:    device.Transport,
			Capabilities: device.Capabilities,
		})
	}
	return CapabilityManifest{
		Devices:  result,
		Features: environmentFeatures(input.Service),
	}
}

func BuildSnapshot(input Input) Snapshot {
	devices := normalizeDevices(input.Devices)
	service := BuildService(input.Service, visibleDeviceCount(devices))

	system := SystemSnapshot{}
	if input.CPUTemperature != nil {
		system.CPU = &Measurement{Value: *input.CPUTemperature, Unit: "celsius"}
	}
	if input.GPUTemperature != nil {
		system.GPU = &Measurement{Value: *input.GPUTemperature, Unit: "celsius"}
	}

	return Snapshot{
		Service:         service,
		System:          system,
		Devices:         devices,
		CoolingProfiles: normalizeCoolingProfiles(input.CoolingProfiles),
		Scheduler:       normalizeScheduler(input.Scheduler),
		Displays:        normalizeDisplays(input.Displays),
		Dashboard:       normalizeDashboard(input.Dashboard),
		LCDAssets:       normalizeLCDAssets(input.LCDImages),
		LCDProfiles:     normalizeLCDProfiles(input.CustomLCDProfiles),
	}
}

func environmentFeatures(input ServiceInput) []FeatureFlag {
	return []FeatureFlag{
		{ID: "frontend", Available: input.Frontend, ReadOnly: true},
		{ID: "metrics", Available: input.Metrics, ReadOnly: true, Reason: disabledReason(input.Metrics, "Disabled in service configuration")},
		{ID: "memory", Available: input.Memory, ReadOnly: true, Reason: disabledReason(input.Memory, "Disabled in service configuration")},
		{ID: "openrgb", Available: input.OpenRGB, ReadOnly: true, Reason: disabledReason(input.OpenRGB, "Disabled in service configuration")},
		{ID: "virtual-gamepad", Available: input.Gamepad, ReadOnly: true, Reason: disabledReason(input.Gamepad, "Disabled in service configuration")},
		{ID: "motherboard", Available: input.Motherboard, ReadOnly: true, Reason: disabledReason(input.Motherboard, "Disabled in service configuration")},
		{ID: "display-geometry", Available: input.DisplayGeometry, ReadOnly: true, Reason: disabledReason(input.DisplayGeometry, "No display geometry was detected")},
	}
}

func disabledReason(available bool, reason string) string {
	if available {
		return ""
	}
	return reason
}

func isLoopback(address string) bool {
	normalized := strings.TrimSpace(strings.Trim(address, "[]"))
	if strings.EqualFold(normalized, "localhost") {
		return true
	}
	ip := net.ParseIP(normalized)
	return ip != nil && ip.IsLoopback()
}

func visibleDeviceCount(devices []DeviceState) int {
	count := 0
	for _, device := range devices {
		if device.Transport != "internal" {
			count++
		}
	}
	return count
}

func normalizeDevices(inputs []DeviceInput) []DeviceState {
	devices := make([]DeviceState, 0, len(inputs))
	for _, input := range inputs {
		devices = append(devices, normalizeDevice(input))
	}
	sort.Slice(devices, func(i, j int) bool {
		leftInternal := devices[i].Transport == "internal"
		rightInternal := devices[j].Transport == "internal"
		if leftInternal != rightInternal {
			return !leftInternal
		}
		leftReceiver := devices[i].Transport == "receiver"
		rightReceiver := devices[j].Transport == "receiver"
		if leftReceiver != rightReceiver {
			return !leftReceiver
		}
		leftName := strings.ToLower(devices[i].Product)
		rightName := strings.ToLower(devices[j].Product)
		if leftName != rightName {
			return leftName < rightName
		}
		return devices[i].ID < devices[j].ID
	})
	return devices
}

func normalizeDevice(input DeviceInput) DeviceState {
	detail := mapping(input.Detail)
	channels := normalizeChannels(detail)
	labelTargets := normalizeLabelTargets(detail, channels)
	transport := deviceTransport(input, detail)
	online := true
	if value, ok := booleanValue(lookup(detail, "Connected")); ok {
		online = value
	}

	firmware := input.Firmware
	if firmware == "" {
		firmware = textValue(lookup(detail, "firmware"))
	}

	battery := (*Measurement)(nil)
	if input.Battery != nil && !isUSB(detail) {
		battery = &Measurement{
			Value: float64(input.Battery.Level),
			Unit:  "percent",
		}
	}

	profile := DeviceProfileState{
		Active:     activeDeviceProfile(detail),
		SavedCount: collectionLength(lookup(detail, "userProfiles")),
	}
	lighting := normalizeLighting(
		input.Product,
		detail,
		channels,
		input.LightingData,
		input.LightingChannelAssignment,
		input.LightingOwnershipTransition,
		input.LightingRGBCluster,
	)
	capabilities := inferCapabilities(
		input,
		detail,
		channels,
		transport,
		lighting,
		labelTargets,
	)

	return DeviceState{
		ID:           input.ID,
		Product:      input.Product,
		ProductID:    input.ProductID,
		ProductType:  input.ProductType,
		DeviceType:   normalizedDeviceType(input.DeviceType, transport),
		Firmware:     firmware,
		Online:       online,
		Hidden:       input.Hidden,
		Transport:    transport,
		Battery:      battery,
		Profile:      profile,
		Capabilities: capabilities,
		Channels:     channels,
		Lighting:     lighting,
		LabelTargets: labelTargets,
	}
}

func normalizeLabelTargets(detail map[string]any, channels []Channel) []LabelTarget {
	targets := make([]LabelTarget, 0, len(channels)+1)
	deviceProfile := mapping(lookup(detail, "DeviceProfile"))
	deviceLabel := lookup(deviceProfile, "label")
	if deviceLabel == nil {
		deviceLabel = lookup(detail, "label")
	}
	if deviceLabel != nil {
		targets = append(targets, LabelTarget{
			ID:    "device",
			Scope: "device",
			Name:  "Whole device",
			Label: textValue(deviceLabel),
		})
	}

	rawChannels := mapping(lookup(detail, "devices"))
	for _, channel := range channels {
		raw := mapping(rawChannels[channel.ID])
		if lookup(raw, "label") == nil {
			continue
		}
		channelID, err := strconv.Atoi(channel.ID)
		if err != nil {
			continue
		}
		name := channel.Name
		if name == "" {
			name = "Channel " + channel.ID
		}
		targets = append(targets, LabelTarget{
			ID:        "channel:" + channel.ID,
			Scope:     "channel",
			ChannelID: &channelID,
			Name:      name,
			Label:     channel.Label,
		})
	}
	return targets
}

func normalizedDeviceType(deviceType, transport string) string {
	if transport == "receiver" {
		return "receiver"
	}
	if deviceType == "" {
		return "unknown"
	}
	return deviceType
}

func deviceTransport(input DeviceInput, detail map[string]any) string {
	upper := strings.ToUpper(input.Product)
	if input.Hidden {
		if input.ProductType == 997 || input.ProductType == 998 ||
			strings.Contains(upper, "SLIPSTREAM") ||
			strings.Contains(upper, "DONGLE") ||
			strings.Contains(upper, "RECEIVER") {
			return "receiver"
		}
		return "internal"
	}
	if usb, ok := booleanValue(lookup(detail, "Usb")); ok && !usb {
		return "wireless"
	}
	return "usb"
}

func isUSB(detail map[string]any) bool {
	usb, ok := booleanValue(lookup(detail, "Usb"))
	return ok && usb
}

func normalizeChannels(detail map[string]any) []Channel {
	raw := mapping(lookup(detail, "devices"))
	keys := sortedKeys(raw)
	channels := make([]Channel, 0, len(keys))
	for _, id := range keys {
		value := mapping(raw[id])
		hasSpeed, _ := booleanValue(lookup(value, "HasSpeed"))
		hasTemps, _ := booleanValue(lookup(value, "HasTemps"))
		isProbe, _ := booleanValue(lookup(value, "IsTemperatureProbe"))
		aio, _ := booleanValue(lookup(value, "AIO"))
		temperature, temperatureOK := numberValue(lookup(value, "temperature"))
		rpm, rpmOK := numberValue(lookup(value, "rpm"))
		hasTemperature := hasTemps || isProbe || (temperatureOK && temperature != 0)

		name := textValue(lookup(value, "name"))
		if name == "" {
			name = "Channel " + id
		}
		label := textValue(lookup(value, "label"))
		if strings.EqualFold(label, "set label") || strings.EqualFold(label, "label") {
			label = ""
		}

		channel := Channel{
			ID:             id,
			Name:           name,
			Label:          label,
			Description:    textValue(lookup(value, "description")),
			Role:           channelRole(value, hasSpeed, hasTemperature, isProbe, aio),
			HasSpeed:       hasSpeed,
			HasTemperature: hasTemperature,
		}
		if port, ok := integerValue(lookup(value, "portId")); ok {
			channel.Port = &port
		}
		if hasSpeed && rpmOK {
			channel.Speed = &Measurement{Value: rpm, Unit: "rpm"}
		}
		if hasTemperature && temperatureOK {
			channel.Temperature = &Measurement{Value: temperature, Unit: "celsius"}
		}
		if profile := textValue(lookup(value, "profile")); profile != "" {
			channel.CoolingProfile = &ProfileReference{ID: profile, Name: profile}
		}
		if effect := textValue(lookup(value, "rgb")); effect != "" {
			channel.LightingEffect = &ProfileReference{ID: effect, Name: effect}
		}
		channels = append(channels, channel)
	}
	return channels
}

func channelRole(
	value map[string]any,
	hasSpeed, hasTemperature, isProbe, aio bool,
) string {
	name := strings.ToUpper(
		textValue(lookup(value, "name")) + " " +
			textValue(lookup(value, "description")),
	)
	switch {
	case aio || strings.Contains(name, "PUMP"):
		return "pump"
	case isProbe:
		return "probe"
	case hasSpeed:
		return "fan"
	case hasTemperature:
		return "sensor"
	default:
		return "channel"
	}
}

func inferCapabilities(
	input DeviceInput,
	detail map[string]any,
	channels []Channel,
	transport string,
	lighting *LightingCatalog,
	labelTargets []LabelTarget,
) []Capability {
	result := []Capability{newCapability("overview", nil)}
	if len(labelTargets) > 0 {
		result[0].Access = "read-write"
		result[0].Operations = []string{"read", "update-label"}
		result[0].Options = map[string]any{"labelTargetCount": len(labelTargets)}
	}
	if transport == "internal" {
		return result
	}
	if transport == "receiver" {
		result = append(result, newCapability("wireless", nil))
		result = append(result, Capability{
			ID:         "pairing",
			Label:      capabilityLabels["pairing"],
			Available:  false,
			Access:     "unavailable",
			Reason:     "The current service does not publish paired-device inventory for this receiver.",
			Operations: []string{},
		})
		return result
	}

	hasSpeed := false
	hasTemperature := false
	for _, channel := range channels {
		hasSpeed = hasSpeed || channel.HasSpeed
		hasTemperature = hasTemperature || channel.HasTemperature
	}
	if hasSpeed {
		result = append(result, newCapability(
			"cooling",
			map[string]any{"channelCount": countChannels(channels, func(channel Channel) bool { return channel.HasSpeed })},
		))
	}
	if hasTemperature || collectionLength(lookup(detail, "TemperatureProbes")) > 0 {
		result = append(result, newCapability(
			"sensors",
			map[string]any{"channelCount": countChannels(channels, func(channel Channel) bool { return channel.HasTemperature })},
		))
	}
	if lighting != nil || hasAnyKey(detail, "RGBModes", "Rgb", "LEDChannels", "ChangeableLedChannels") {
		options := map[string]any{}
		if lighting != nil {
			options["effectCount"] = lighting.ProfileCount
			options["targetCount"] = len(lighting.Targets)
		}
		capability := newCapability("lighting", options)
		if lighting != nil {
			for _, target := range lighting.Targets {
				if stringSliceContains(target.Operations, "assign-profile") {
					capability.Access = "read-write"
					capability.Operations = []string{"read", "assign-profile"}
					break
				}
			}
		}
		result = append(result, capability)
	}
	if len(channels) > 0 {
		result = append(result, newCapability(
			"topology",
			map[string]any{"channelCount": len(channels)},
		))
	}
	if boolValue(lookup(detail, "HasLCD")) || hasAnyKey(detail, "LCDModes") {
		result = append(result, newCapability(
			"display",
			map[string]any{"brightnessModeCount": collectionLength(lookup(detail, "LCDBrightnessLevels"))},
		))
	}

	switch input.DeviceType {
	case "keyboard", "keypad":
		result = append(result, newCapability("keys", nil))
		if containsKey(detail, "Actuation") {
			result = append(result, newCapability("actuation", nil))
		}
		result = append(result, performanceCapability(detail))
		result = append(result, profilesCapability(detail))
	case "mouse":
		result = append(result, newCapability("buttons", nil))
		result = append(result, dpiCapability(detail))
		result = append(result, performanceCapability(detail))
		result = append(result, profilesCapability(detail))
	case "headset":
		result = append(result, newCapability("audio", nil))
		result = append(result, newCapability("buttons", nil))
	case "gamepad":
		result = append(result,
			newCapability("controls", nil),
			newCapability("analog", nil),
			newCapability("vibration", nil),
		)
	}

	if input.Battery != nil && !isUSB(detail) {
		result = append(result, newCapability("power", nil))
	}
	if transport == "wireless" {
		result = append(result, newCapability("wireless", nil))
	}
	return uniqueCapabilities(result)
}

func newCapability(id string, options map[string]any) Capability {
	return Capability{
		ID:         id,
		Label:      capabilityLabels[id],
		Available:  true,
		Access:     "read",
		Operations: []string{"read"},
		Options:    options,
	}
}

func stringSliceContains(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}

func performanceCapability(detail map[string]any) Capability {
	values := stringValues(lookup(detail, "PollingRates"))
	return newCapability("performance", map[string]any{"pollingRates": values})
}

func profilesCapability(detail map[string]any) Capability {
	return newCapability(
		"profiles",
		map[string]any{"savedCount": collectionLength(lookup(detail, "userProfiles"))},
	)
}

func dpiCapability(detail map[string]any) Capability {
	options := map[string]any{}
	if value, ok := integerValue(lookup(detail, "DPIAmount")); ok {
		options["stageCount"] = value
	}
	if value, ok := integerValue(lookup(detail, "MinDPI")); ok {
		options["minimum"] = value
	}
	if value, ok := integerValue(lookup(detail, "MaxDPI")); ok {
		options["maximum"] = value
	}
	return newCapability("dpi", options)
}

func uniqueCapabilities(input []Capability) []Capability {
	seen := make(map[string]bool, len(input))
	result := make([]Capability, 0, len(input))
	for _, capability := range input {
		if capability.ID == "" || seen[capability.ID] {
			continue
		}
		seen[capability.ID] = true
		result = append(result, capability)
	}
	return result
}

func countChannels(channels []Channel, include func(Channel) bool) int {
	count := 0
	for _, channel := range channels {
		if include(channel) {
			count++
		}
	}
	return count
}

func activeDeviceProfile(detail map[string]any) string {
	profile := mapping(lookup(detail, "DeviceProfile"))
	for _, key := range []string{"Profile", "ActiveProfile", "RGBProfile"} {
		if value := textValue(lookup(profile, key)); value != "" {
			return value
		}
	}
	for _, key := range []string{"Profile", "ActiveProfile", "RGBProfile", "SlipstreamRGBProfile"} {
		if value := textValue(lookup(detail, key)); value != "" {
			return value
		}
	}
	return "service-managed"
}

func normalizeLighting(
	product string,
	detail map[string]any,
	channels []Channel,
	raw any,
	channelAssignment bool,
	ownershipTransition bool,
	rgbCluster *bool,
) *LightingCatalog {
	catalogData := mapping(raw)
	profileData := mapping(lookup(catalogData, "profiles"))
	if len(profileData) == 0 {
		return nil
	}

	profileKeys := sortedKeys(profileData)
	profiles := make([]LightingProfile, 0, len(profileKeys))
	for _, id := range profileKeys {
		value := mapping(profileData[id])
		name := textValue(lookup(value, "profileName"))
		if name == "" {
			name = title(id)
		}
		brightness, _ := numberValue(lookup(value, "brightness"))
		speed, _ := numberValue(lookup(value, "speed"))
		smoothness, _ := numberValue(lookup(value, "smoothness"))
		minimum, _ := numberValue(lookup(value, "minTemp"))
		maximum, _ := numberValue(lookup(value, "maxTemp"))
		direction, _ := numberValue(lookup(value, "rgbDirection"))
		gradients := make([]string, 0)
		for _, gradientID := range sortedKeys(mapping(lookup(value, "gradients"))) {
			gradients = append(
				gradients,
				colorHex(mapping(lookup(mapping(lookup(value, "gradients")), gradientID))),
			)
		}
		profiles = append(profiles, LightingProfile{
			ID:                  id,
			Name:                name,
			Speed:               speed,
			Brightness:          int(math.Round(brightness * 100)),
			Smoothness:          int(math.Round(smoothness)),
			StartColor:          colorHex(mapping(lookup(value, "start"))),
			MiddleColor:         colorHex(mapping(lookup(value, "middle"))),
			EndColor:            colorHex(mapping(lookup(value, "end"))),
			GradientColors:      gradients,
			MinTemperature:      minimum,
			MaxTemperature:      maximum,
			Direction:           int(math.Round(direction)),
			AlternateColors:     boolValue(lookup(value, "alternateColors")),
			PerLED:              boolValue(lookup(value, "perLed")),
			TemperatureReactive: strings.HasSuffix(id, "-temperature") || maximum > 0,
		})
	}
	sort.Slice(profiles, func(i, j int) bool {
		left := strings.ToLower(profiles[i].Name)
		right := strings.ToLower(profiles[j].Name)
		if left != right {
			return left < right
		}
		return profiles[i].ID < profiles[j].ID
	})

	profileIDs := make(map[string]bool, len(profiles))
	supportedProfileIDs := make([]string, 0, len(profiles))
	for _, profile := range profiles {
		profileIDs[profile.ID] = true
		supportedProfileIDs = append(supportedProfileIDs, profile.ID)
	}
	assignmentBlockReason := lightingAssignmentBlockReason(detail, rgbCluster)
	assignmentAvailable := channelAssignment && assignmentBlockReason == ""
	targets := make([]LightingTarget, 0)
	for _, channel := range channels {
		if channel.LightingEffect == nil {
			continue
		}
		channelID, err := strconv.Atoi(channel.ID)
		if err != nil || channelID < 0 {
			continue
		}
		active := channel.LightingEffect.ID
		if !profileIDs[active] && len(profiles) > 0 {
			active = profiles[0].ID
		}
		name := channel.Label
		if name == "" {
			name = channel.Name
		}
		operations := []string{"read"}
		if assignmentAvailable {
			operations = append(operations, "assign-profile")
		}
		description := fmt.Sprintf("Channel %s · %s", channel.ID, channel.Description)
		if assignmentBlockReason != "" {
			description += " · " + assignmentBlockReason
		}
		targets = append(targets, LightingTarget{
			ID:                  fmt.Sprintf("channel:%d", channelID),
			Scope:               "channel",
			ChannelID:           &channelID,
			Name:                fmt.Sprintf("%s · Ch %s", name, channel.ID),
			Description:         description,
			ActiveProfile:       active,
			SupportedProfileIDs: append([]string(nil), supportedProfileIDs...),
			Operations:          operations,
			Identifiable:        false,
		})
	}
	if len(targets) == 0 {
		active := activeDeviceProfile(detail)
		if !profileIDs[active] && len(profiles) > 0 {
			active = profiles[0].ID
		}
		targets = append(targets, LightingTarget{
			ID:                  "device",
			Scope:               "device",
			Name:                "Whole device",
			Description:         product + " lighting surface",
			ActiveProfile:       active,
			SupportedProfileIDs: append([]string(nil), supportedProfileIDs...),
			Operations:          []string{"read"},
			Identifiable:        false,
		})
	}

	return &LightingCatalog{
		Source:       "OpenLinkHub versioned capability contract",
		Device:       textOr(lookup(catalogData, "device"), product),
		DefaultColor: colorHex(mapping(lookup(catalogData, "defaultColor"))),
		Ownership:    normalizeLightingOwnership(detail, targets, profiles, ownershipTransition, rgbCluster),
		Targets:      targets,
		Profiles:     profiles,
		ProfileCount: len(profiles),
	}
}

func normalizeLightingOwnership(detail map[string]any, targets []LightingTarget, profiles []LightingProfile, transitionAvailable bool, rgbCluster *bool) LightingOwnership {
	controller := "individual"
	mode := "individual"
	label := "Individual devices"
	description := "Each published target uses its own saved lighting effect."
	profile := mapping(lookup(detail, "DeviceProfile"))
	if enabled, ok := booleanValue(lookup(profile, "OpenRGBIntegration")); ok && enabled {
		controller = "openrgb"
		mode = "external"
		label = "OpenRGB"
		description = "OpenRGB currently owns this device's lighting output."
	} else if rgbClusterEnabled(profile, rgbCluster) {
		controller = "rgb-cluster"
		mode = "synchronized"
		label = "RGB Cluster"
		description = "One synchronized controller owns this device's lighting targets."
	}

	operations := []string{"read"}
	if transitionAvailable && controller != "openrgb" {
		operations = append(operations, "change-controller")
	}
	return LightingOwnership{
		Controller:             controller,
		Mode:                   mode,
		Label:                  label,
		Description:            description,
		Operations:             operations,
		AffectedTargetCount:    len(targets),
		SavedIndividualSummary: summarizeIndividualLighting(targets, profiles),
	}
}

func summarizeIndividualLighting(targets []LightingTarget, profiles []LightingProfile) string {
	if len(targets) == 0 {
		return "No individual lighting targets"
	}
	profileNames := make(map[string]string, len(profiles))
	for _, profile := range profiles {
		profileNames[profile.ID] = profile.Name
	}
	active := targets[0].ActiveProfile
	for _, target := range targets[1:] {
		if target.ActiveProfile != active {
			return fmt.Sprintf("%d saved individual effects", len(targets))
		}
	}
	name := profileNames[active]
	if name == "" {
		name = title(active)
	}
	targetWord := "targets"
	if len(targets) == 1 {
		targetWord = "target"
	}
	return fmt.Sprintf("%s on %d %s", name, len(targets), targetWord)
}

func lightingAssignmentBlockReason(detail map[string]any, rgbCluster *bool) string {
	profile := mapping(lookup(detail, "DeviceProfile"))
	if enabled, ok := booleanValue(lookup(profile, "OpenRGBIntegration")); ok && enabled {
		return "Managed by OpenRGB"
	}
	if rgbClusterEnabled(profile, rgbCluster) {
		return "Managed by RGB Cluster"
	}
	return ""
}

func rgbClusterEnabled(profile map[string]any, authoritative *bool) bool {
	if authoritative != nil {
		return *authoritative
	}
	enabled, ok := booleanValue(lookup(profile, "RGBCluster"))
	return ok && enabled
}

func colorHex(color map[string]any) string {
	channel := func(name string) int {
		value, _ := numberValue(lookup(color, name))
		return max(0, min(255, int(math.Round(value))))
	}
	return fmt.Sprintf("#%02x%02x%02x", channel("red"), channel("green"), channel("blue"))
}

func normalizeCoolingProfiles(raw any) []CoolingProfileSummary {
	values := mapping(raw)
	keys := sortedKeys(values)
	profiles := make([]CoolingProfileSummary, 0, len(keys))
	for _, id := range keys {
		value := mapping(values[id])
		sensorType, _ := integerValue(lookup(value, "sensor"))
		profiles = append(profiles, CoolingProfileSummary{
			ID:         id,
			SensorType: sensorType,
			Sensor:     textValue(lookup(value, "sensorString")),
			ZeroRPM:    boolValue(lookup(value, "zeroRpm")),
			Linear:     boolValue(lookup(value, "linear")),
			Hidden:     boolValue(lookup(value, "Hidden")),
			PointCount: nestedCollectionLength(lookup(value, "points")),
			StepCount:  collectionLength(lookup(value, "profiles")),
		})
	}
	return profiles
}

func normalizeScheduler(raw any) SchedulerState {
	value := mapping(raw)
	return SchedulerState{
		LightingEnabled: boolValue(lookup(value, "rgbControl")),
		LightsOff:       textValue(lookup(value, "rgbOff")),
		LightsOn:        textValue(lookup(value, "rgbOn")),
		LCDEnabled:      boolValue(lookup(value, "lcdControl")),
		LightsOut:       boolValue(lookup(value, "LightsOut")),
	}
}

func normalizeDisplays(raw any) []DisplayState {
	values := slice(raw)
	displays := make([]DisplayState, 0, len(values))
	for _, item := range values {
		value := mapping(item)
		id, _ := integerValue(lookup(value, "Index"))
		width, _ := integerValue(lookup(value, "Width"))
		height, _ := integerValue(lookup(value, "Height"))
		position := "primary"
		if boolValue(lookup(value, "Left")) {
			position = "left"
		} else if boolValue(lookup(value, "Top")) {
			position = "top"
		}
		displays = append(displays, DisplayState{
			ID:       id,
			Name:     textValue(lookup(value, "Name")),
			Width:    width,
			Height:   height,
			Position: position,
		})
	}
	sort.Slice(displays, func(i, j int) bool { return displays[i].ID < displays[j].ID })
	return displays
}

func normalizeDashboard(raw any) DashboardState {
	value := mapping(raw)
	return DashboardState{
		Celsius:     boolValue(lookup(value, "celsius")),
		ShowCPU:     boolValue(lookup(value, "showCpu")),
		ShowGPU:     boolValue(lookup(value, "showGpu")),
		ShowDisk:    boolValue(lookup(value, "showDisk")),
		ShowDevices: boolValue(lookup(value, "showDevices")),
		ShowBattery: boolValue(lookup(value, "showBattery")),
		LightingOff: boolValue(lookup(value, "rgbOff")),
	}
}

func normalizeLCDAssets(raw any) []LCDAsset {
	values := slice(raw)
	assets := make([]LCDAsset, 0, len(values))
	for _, item := range values {
		value := mapping(item)
		frames, _ := integerValue(lookup(value, "Frames"))
		assets = append(assets, LCDAsset{
			Name:   textValue(lookup(value, "Name")),
			Frames: frames,
		})
	}
	sort.Slice(assets, func(i, j int) bool {
		return strings.ToLower(assets[i].Name) < strings.ToLower(assets[j].Name)
	})
	return assets
}

func normalizeLCDProfiles(raw any) []LCDProfileSummary {
	values := mapping(raw)
	keys := sortedKeys(values)
	names := map[string]string{
		"100": "Arc",
		"101": "Double Arc",
		"102": "Animation",
	}
	profiles := make([]LCDProfileSummary, 0, len(keys))
	for _, id := range keys {
		name := names[id]
		if name == "" {
			name = "Custom mode " + id
		}
		profiles = append(profiles, LCDProfileSummary{ID: id, Name: name})
	}
	return profiles
}

func mapping(value any) map[string]any {
	if value == nil {
		return map[string]any{}
	}
	if converted, ok := value.(map[string]any); ok {
		return converted
	}
	payload, err := json.Marshal(value)
	if err != nil {
		return map[string]any{}
	}
	converted := map[string]any{}
	if err := json.Unmarshal(payload, &converted); err != nil {
		return map[string]any{}
	}
	return converted
}

func slice(value any) []any {
	if value == nil {
		return []any{}
	}
	if converted, ok := value.([]any); ok {
		return converted
	}
	payload, err := json.Marshal(value)
	if err != nil {
		return []any{}
	}
	converted := []any{}
	if err := json.Unmarshal(payload, &converted); err != nil {
		return []any{}
	}
	return converted
}

func lookup(value map[string]any, key string) any {
	if found, ok := value[key]; ok {
		return found
	}
	for current, found := range value {
		if strings.EqualFold(current, key) {
			return found
		}
	}
	return nil
}

func containsKey(value map[string]any, fragment string) bool {
	for key := range value {
		if strings.Contains(strings.ToLower(key), strings.ToLower(fragment)) {
			return true
		}
	}
	return false
}

func hasAnyKey(value map[string]any, keys ...string) bool {
	for _, key := range keys {
		if lookup(value, key) != nil {
			return true
		}
	}
	return false
}

func numberValue(value any) (float64, bool) {
	switch converted := value.(type) {
	case float64:
		return converted, true
	case float32:
		return float64(converted), true
	case int:
		return float64(converted), true
	case int8:
		return float64(converted), true
	case int16:
		return float64(converted), true
	case int32:
		return float64(converted), true
	case int64:
		return float64(converted), true
	case uint:
		return float64(converted), true
	case uint8:
		return float64(converted), true
	case uint16:
		return float64(converted), true
	case uint32:
		return float64(converted), true
	case uint64:
		return float64(converted), true
	default:
		return 0, false
	}
}

func integerValue(value any) (int, bool) {
	number, ok := numberValue(value)
	if !ok {
		return 0, false
	}
	return int(math.Round(number)), true
}

func booleanValue(value any) (bool, bool) {
	converted, ok := value.(bool)
	return converted, ok
}

func boolValue(value any) bool {
	converted, _ := booleanValue(value)
	return converted
}

func textValue(value any) string {
	switch converted := value.(type) {
	case string:
		return converted
	case fmt.Stringer:
		return converted.String()
	default:
		return ""
	}
}

func textOr(value any, fallback string) string {
	text := textValue(value)
	if text == "" {
		return fallback
	}
	return text
}

func collectionLength(value any) int {
	switch converted := value.(type) {
	case []any:
		return len(converted)
	case map[string]any:
		return len(converted)
	case nil:
		return 0
	default:
		payload, err := json.Marshal(converted)
		if err != nil {
			return 0
		}
		var sequence []any
		if json.Unmarshal(payload, &sequence) == nil {
			return len(sequence)
		}
		var entries map[string]any
		if json.Unmarshal(payload, &entries) == nil {
			return len(entries)
		}
		return 0
	}
}

func nestedCollectionLength(value any) int {
	total := 0
	for _, item := range mapping(value) {
		total += collectionLength(item)
	}
	return total
}

func stringValues(value any) []string {
	result := make([]string, 0)
	if entries := mapping(value); len(entries) > 0 {
		for _, key := range sortedKeys(entries) {
			text := textValue(entries[key])
			if text == "" {
				text = key
			}
			result = append(result, text)
		}
		return result
	}
	for _, item := range slice(value) {
		text := textValue(item)
		if text != "" {
			result = append(result, text)
		}
	}
	return result
}

func sortedKeys(value map[string]any) []string {
	keys := make([]string, 0, len(value))
	for key := range value {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool {
		leftNumber, leftErr := strconv.Atoi(keys[i])
		rightNumber, rightErr := strconv.Atoi(keys[j])
		if leftErr == nil && rightErr == nil {
			return leftNumber < rightNumber
		}
		if leftErr == nil {
			return true
		}
		if rightErr == nil {
			return false
		}
		return strings.ToLower(keys[i]) < strings.ToLower(keys[j])
	})
	return keys
}

func title(value string) string {
	words := strings.Fields(
		strings.NewReplacer("-", " ", "_", " ").Replace(value),
	)
	for index, word := range words {
		if word == "" {
			continue
		}
		words[index] = strings.ToUpper(word[:1]) + word[1:]
	}
	return strings.Join(words, " ")
}
