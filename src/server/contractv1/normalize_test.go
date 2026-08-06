package contractv1

import (
	"encoding/json"
	"strings"
	"testing"
)

func fixtureInput() Input {
	cpu := 52.25
	gpu := 47.0
	return Input{
		Service: ServiceInput{
			Version:         "0.8.9",
			BuildRevision:   "abc1234",
			ListenAddress:   "127.0.0.1",
			ListenPort:      27003,
			Frontend:        true,
			Metrics:         true,
			SystemService:   true,
			Gamepad:         true,
			DisplayGeometry: true,
		},
		CPUTemperature: &cpu,
		GPUTemperature: &gpu,
		Devices: []DeviceInput{
			{
				ID:          "hub",
				Product:     "iCUE LINK System Hub",
				ProductID:   1,
				ProductType: 0,
				DeviceType:  "cooler",
				Firmware:    "3.10.636",
				Detail: map[string]any{
					"ConfigPath": "/etc/OpenLinkHub",
					"Connected":  true,
					"Usb":        true,
					"devices": map[string]any{
						"1": map[string]any{
							"name":        "Radiator",
							"label":       "Top radiator",
							"description": "Fan channel",
							"HasSpeed":    true,
							"rpm":         600,
							"profile":     "Balanced",
							"rgb":         "static",
							"portId":      1,
						},
						"2": map[string]any{
							"name":        "Pump",
							"description": "AIO pump",
							"HasSpeed":    true,
							"HasTemps":    true,
							"AIO":         true,
							"rpm":         1500,
							"temperature": 38.5,
							"profile":     "Pump",
							"rgb":         "liquid-temperature",
							"portId":      2,
						},
					},
				},
				LightingData: map[string]any{
					"device": "hub",
					"profiles": map[string]any{
						"static": map[string]any{
							"profileName": "Static",
							"brightness":  0.7,
							"start": map[string]any{
								"red":   0,
								"green": 120,
								"blue":  212,
							},
						},
						"liquid-temperature": map[string]any{
							"profileName": "Liquid Temperature",
							"maxTemp":     60,
						},
					},
				},
				LightingChannelAssignment: true,
			},
			{
				ID:          "receiver",
				Product:     "SLIPSTREAM",
				ProductID:   2,
				ProductType: 998,
				DeviceType:  "unknown",
				Hidden:      true,
				Detail:      map[string]any{},
			},
			{
				ID:          "cluster",
				Product:     "Cluster",
				ProductType: 999,
				DeviceType:  "virtual",
				Hidden:      true,
				Detail:      map[string]any{},
			},
		},
		CoolingProfiles: map[string]any{
			"Balanced": map[string]any{
				"sensor":       0,
				"sensorString": "CPU",
				"zeroRpm":      false,
				"linear":       true,
				"points": map[string]any{
					"0": []any{20, 30},
					"1": []any{40, 50},
				},
			},
		},
		Scheduler: map[string]any{
			"rgbControl": true,
			"rgbOff":     "23:00",
			"rgbOn":      "07:00",
			"lcdControl": true,
			"LightsOut":  false,
		},
		Displays: []any{
			map[string]any{
				"Index":  0,
				"Name":   "Primary",
				"Width":  2560,
				"Height": 1440,
			},
		},
		Dashboard: map[string]any{
			"celsius":     true,
			"showCpu":     true,
			"showGpu":     true,
			"showDevices": true,
		},
		LCDImages: []any{
			map[string]any{"Name": "logo.gif", "Frames": 12},
		},
		CustomLCDProfiles: map[string]any{"100": map[string]any{}},
	}
}

func TestBuildSnapshotNormalizesCapabilitiesAndTelemetry(t *testing.T) {
	snapshot := BuildSnapshot(fixtureInput())
	if snapshot.Service.Listener.Scope != "loopback" {
		t.Fatalf("listener scope = %q, want loopback", snapshot.Service.Listener.Scope)
	}
	if snapshot.Service.DeviceCount != 2 {
		t.Fatalf("device count = %d, want 2 visible devices", snapshot.Service.DeviceCount)
	}
	if snapshot.System.CPU == nil || snapshot.System.CPU.Value != 52.25 {
		t.Fatalf("CPU measurement was not normalized: %#v", snapshot.System.CPU)
	}
	if len(snapshot.Devices) != 3 || snapshot.Devices[1].Transport != "receiver" {
		t.Fatalf("device ordering or receiver normalization failed: %#v", snapshot.Devices)
	}

	hub := snapshot.Devices[0]
	if len(hub.Channels) != 2 || hub.Channels[1].Role != "pump" {
		t.Fatalf("channel normalization failed: %#v", hub.Channels)
	}
	if len(hub.LabelTargets) != 1 || hub.LabelTargets[0].ID != "channel:1" ||
		hub.LabelTargets[0].Label != "Top radiator" {
		t.Fatalf("label targets were not normalized: %#v", hub.LabelTargets)
	}
	if !hasOperation(hub.Capabilities, "overview", "update-label") {
		t.Fatalf("label mutation capability was not published: %#v", hub.Capabilities)
	}
	if hub.Lighting == nil || hub.Lighting.ProfileCount != 2 {
		t.Fatalf("lighting library was not normalized: %#v", hub.Lighting)
	}
	if len(hub.Lighting.Targets) != 2 || hub.Lighting.Targets[0].ID != "channel:1" ||
		hub.Lighting.Targets[0].Scope != "channel" || hub.Lighting.Targets[0].ChannelID == nil ||
		*hub.Lighting.Targets[0].ChannelID != 1 || len(hub.Lighting.Targets[0].SupportedProfileIDs) != 2 ||
		len(hub.Lighting.Targets[0].Operations) != 2 || hub.Lighting.Targets[0].Operations[0] != "read" ||
		hub.Lighting.Targets[0].Operations[1] != "assign-profile" ||
		hub.Lighting.Targets[0].Identifiable {
		t.Fatalf("lighting targets were not safely published: %#v", hub.Lighting.Targets)
	}
	if !hasCapability(hub.Capabilities, "cooling", true) ||
		!hasCapability(hub.Capabilities, "sensors", true) ||
		!hasCapability(hub.Capabilities, "lighting", true) {
		t.Fatalf("capability inference failed: %#v", hub.Capabilities)
	}
	if !hasOperation(hub.Capabilities, "lighting", "assign-profile") {
		t.Fatalf("lighting assignment capability was not published: %#v", hub.Capabilities)
	}
	if !hasCapability(snapshot.Devices[1].Capabilities, "pairing", false) {
		t.Fatalf("receiver pairing limitation was not explicit: %#v", snapshot.Devices[1])
	}
	if len(snapshot.CoolingProfiles) != 1 ||
		snapshot.CoolingProfiles[0].PointCount != 4 {
		t.Fatalf("cooling profiles were not summarized: %#v", snapshot.CoolingProfiles)
	}
	if len(snapshot.Displays) != 1 || snapshot.Displays[0].Width != 2560 {
		t.Fatalf("display geometry was not normalized: %#v", snapshot.Displays)
	}
	if len(snapshot.LCDAssets) != 1 || len(snapshot.LCDProfiles) != 1 {
		t.Fatalf("LCD inventory was not normalized")
	}
}

func TestDeviceProfileLabelPublishesWholeDeviceTarget(t *testing.T) {
	targets := normalizeLabelTargets(map[string]any{
		"DeviceProfile": map[string]any{"Label": "Keyboard"},
	}, nil)
	if len(targets) != 1 || targets[0].ID != "device" || targets[0].Label != "Keyboard" {
		t.Fatalf("whole-device label target was not normalized: %#v", targets)
	}
}

func TestLightingAssignmentRequiresExplicitChannelAuthorization(t *testing.T) {
	input := fixtureInput()
	input.Devices[0].LightingChannelAssignment = false
	targets := BuildSnapshot(input).Devices[0].Lighting.Targets
	for _, target := range targets {
		if stringSliceContains(target.Operations, "assign-profile") {
			t.Fatalf("read-only input published assignment: %#v", targets)
		}
	}

	input.Devices[0].Detail = map[string]any{
		"Connected":     true,
		"DeviceProfile": map[string]any{"RGBProfile": "static"},
	}
	wholeDevice := BuildSnapshot(input).Devices[0].Lighting.Targets
	if len(wholeDevice) != 1 || wholeDevice[0].ID != "device" ||
		stringSliceContains(wholeDevice[0].Operations, "assign-profile") {
		t.Fatalf("channel authorization leaked to whole-device target: %#v", wholeDevice)
	}
}

func TestLightingAssignmentIsSuppressedByExternalLightingControl(t *testing.T) {
	tests := []struct {
		name   string
		field  string
		reason string
	}{
		{name: "rgb cluster", field: "RGBCluster", reason: "Managed by RGB Cluster"},
		{name: "openrgb", field: "OpenRGBIntegration", reason: "Managed by OpenRGB"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			input := fixtureInput()
			detail := input.Devices[0].Detail.(map[string]any)
			detail["DeviceProfile"] = map[string]any{test.field: true}
			targets := BuildSnapshot(input).Devices[0].Lighting.Targets
			if len(targets) == 0 {
				t.Fatal("expected normalized lighting targets")
			}
			for _, target := range targets {
				if stringSliceContains(target.Operations, "assign-profile") {
					t.Fatalf("externally managed target published assignment: %#v", target)
				}
				if !strings.Contains(target.Description, test.reason) {
					t.Fatalf("target description %q does not disclose %q", target.Description, test.reason)
				}
			}
		})
	}
}

func TestSnapshotDoesNotLeakRawPathsOrInternalObjects(t *testing.T) {
	payload, err := json.Marshal(BuildSnapshot(fixtureInput()))
	if err != nil {
		t.Fatal(err)
	}
	text := string(payload)
	for _, forbidden := range []string{"ConfigPath", "/etc/OpenLinkHub", "Instance"} {
		if strings.Contains(text, forbidden) {
			t.Fatalf("contract payload leaked %q: %s", forbidden, text)
		}
	}
}

func TestRevisionTrackerIsStableAndMonotonic(t *testing.T) {
	var tracker RevisionTracker
	if got := tracker.Observe(map[string]any{"value": 1}); got != 1 {
		t.Fatalf("first revision = %d, want 1", got)
	}
	if got := tracker.Observe(map[string]any{"value": 1}); got != 1 {
		t.Fatalf("stable revision = %d, want 1", got)
	}
	if got := tracker.Observe(map[string]any{"value": 2}); got != 2 {
		t.Fatalf("changed revision = %d, want 2", got)
	}
}

func TestStateAndTelemetryRevisionsAreIndependent(t *testing.T) {
	snapshot := BuildSnapshot(fixtureInput())
	var state RevisionTracker
	var telemetry RevisionTracker

	if got := state.Observe(StateRevisionValue(snapshot)); got != 1 {
		t.Fatalf("first state revision = %d, want 1", got)
	}
	if got := telemetry.Observe(TelemetryRevisionValue(snapshot)); got != 1 {
		t.Fatalf("first telemetry revision = %d, want 1", got)
	}

	snapshot.System.CPU.Value = 53.5
	snapshot.Devices[0].Channels[0].Speed.Value = 625
	snapshot.Devices[0].Online = false
	if got := state.Observe(StateRevisionValue(snapshot)); got != 1 {
		t.Fatalf("telemetry changed state revision to %d", got)
	}
	if got := telemetry.Observe(TelemetryRevisionValue(snapshot)); got != 2 {
		t.Fatalf("telemetry revision = %d, want 2", got)
	}

	snapshot.Devices[0].Channels[0].CoolingProfile = &ProfileReference{
		ID:   "Performance",
		Name: "Performance",
	}
	if got := state.Observe(StateRevisionValue(snapshot)); got != 2 {
		t.Fatalf("configuration revision = %d, want 2", got)
	}
}

func hasCapability(capabilities []Capability, id string, available bool) bool {
	for _, capability := range capabilities {
		if capability.ID == id && capability.Available == available {
			return true
		}
	}
	return false
}

func hasOperation(capabilities []Capability, id, operation string) bool {
	for _, capability := range capabilities {
		if capability.ID != id {
			continue
		}
		for _, candidate := range capability.Operations {
			if candidate == operation {
				return true
			}
		}
	}
	return false
}
