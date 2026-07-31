package server

import (
	"OpenLinkHub/src/common"
	"OpenLinkHub/src/config"
	"OpenLinkHub/src/dashboard"
	"OpenLinkHub/src/devices"
	"OpenLinkHub/src/devices/lcd"
	"OpenLinkHub/src/display"
	"OpenLinkHub/src/scheduler"
	"OpenLinkHub/src/server/contractv1"
	"OpenLinkHub/src/stats"
	"OpenLinkHub/src/temperatures"
	"OpenLinkHub/src/version"
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"
)

var apiV1StateRevision contractv1.RevisionTracker
var apiV1TelemetryRevision contractv1.RevisionTracker
var apiV1Input = collectV1Input

func getServiceV1(w http.ResponseWriter, request *http.Request) {
	input := apiV1Input()
	snapshot := contractv1.BuildSnapshot(input)
	revision := apiV1StateRevision.Observe(contractv1.StateRevisionValue(snapshot))
	document := contractv1.Wrap(
		"service",
		revision,
		snapshot.Service,
	)
	sendV1(w, request, document, contractETag("service", revision, 0))
}

func getCapabilitiesV1(w http.ResponseWriter, request *http.Request) {
	input := apiV1Input()
	snapshot := contractv1.BuildSnapshot(input)
	revision := apiV1StateRevision.Observe(contractv1.StateRevisionValue(snapshot))
	document := contractv1.Wrap(
		"capabilities",
		revision,
		contractv1.BuildManifest(input),
	)
	sendV1(w, request, document, contractETag("capabilities", revision, 0))
}

func getSnapshotV1(w http.ResponseWriter, request *http.Request) {
	input := apiV1Input()
	snapshot := contractv1.BuildSnapshot(input)
	revision := apiV1StateRevision.Observe(contractv1.StateRevisionValue(snapshot))
	telemetryRevision := apiV1TelemetryRevision.Observe(
		contractv1.TelemetryRevisionValue(snapshot),
	)
	document := contractv1.WrapSnapshot(revision, telemetryRevision, snapshot)
	sendV1(
		w,
		request,
		document,
		contractETag("snapshot", revision, telemetryRevision),
	)
}

func sendV1(
	w http.ResponseWriter,
	request *http.Request,
	document contractv1.Document,
	etag string,
) {
	w.Header().Set("Cache-Control", "private, no-cache")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Vary", "Accept")
	w.Header().Set("ETag", etag)
	if etagMatches(request.Header.Get("If-None-Match"), etag) {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(document)
}

func contractETag(kind string, revision, telemetryRevision uint64) string {
	if telemetryRevision == 0 {
		return fmt.Sprintf("\"olh-v1-%s-s%d\"", kind, revision)
	}
	return fmt.Sprintf(
		"\"olh-v1-%s-s%d-t%d\"",
		kind,
		revision,
		telemetryRevision,
	)
}

func etagMatches(header, current string) bool {
	for _, candidate := range strings.Split(header, ",") {
		if strings.TrimSpace(candidate) == current ||
			strings.TrimSpace(candidate) == "*" {
			return true
		}
	}
	return false
}

func collectV1Input() contractv1.Input {
	configuration := config.GetConfig()
	build := version.GetBuildInfo()
	buildRevision := ""
	buildTime := ""
	buildModified := false
	buildVersion := version.Version
	if build != nil {
		buildRevision = build.Revision
		buildModified = build.Modified
		buildVersion = build.BuildVersion
		if !build.Time.IsZero() {
			buildTime = build.Time.UTC().Format("2006-01-02T15:04:05Z")
		}
	}

	displays := display.GetDisplays()
	input := contractv1.Input{
		Service: contractv1.ServiceInput{
			Version:         buildVersion,
			BuildRevision:   buildRevision,
			BuildTime:       buildTime,
			BuildModified:   buildModified,
			ListenAddress:   configuration.ListenAddress,
			ListenPort:      configuration.ListenPort,
			Frontend:        configuration.Frontend,
			Metrics:         configuration.Metrics,
			ManualMode:      configuration.Manual,
			SystemService:   config.IsSystemService(),
			Memory:          configuration.Memory,
			OpenRGB:         configuration.EnableOpenRGBTargetServer,
			Gamepad:         configuration.EnableGamepad,
			Motherboard:     configuration.EnableMotherboard,
			DisplayGeometry: len(displays) > 0,
		},
		CoolingProfiles:   temperatures.GetTemperatureProfiles(),
		Scheduler:         scheduler.GetScheduler(),
		Displays:          displays,
		Dashboard:         dashboard.GetDashboard(),
		LCDImages:         lcd.GetLcdImages(),
		CustomLCDProfiles: lcd.GetCustomLcdProfiles(),
	}

	cpu := float64(temperatures.GetCpuTemperature())
	gpu := float64(temperatures.GetGpuTemperature())
	input.CPUTemperature = &cpu
	input.GPUTemperature = &gpu

	batteries := stats.GetBatteryStats()
	lighting := apiV1Lighting.get(time.Now(), devices.GetRgbProfiles)
	deviceMap := devices.GetDevices()
	deviceIDs := make([]string, 0, len(deviceMap))
	for id := range deviceMap {
		deviceIDs = append(deviceIDs, id)
	}
	sort.Strings(deviceIDs)

	input.Devices = make([]contractv1.DeviceInput, 0, len(deviceIDs))
	for _, id := range deviceIDs {
		device := deviceMap[id]
		if device == nil {
			continue
		}
		var battery *contractv1.BatteryInput
		if value, ok := batteries[id]; ok {
			battery = &contractv1.BatteryInput{
				Level:      value.Level,
				DeviceType: value.DeviceType,
			}
		}
		input.Devices = append(input.Devices, contractv1.DeviceInput{
			ID:           id,
			Product:      device.Product,
			ProductID:    device.ProductId,
			ProductType:  device.ProductType,
			DeviceType:   semanticDeviceType(device.DeviceType),
			Firmware:     device.Firmware,
			Hidden:       device.Hidden,
			Detail:       device.GetDevice,
			Battery:      battery,
			LightingData: lighting[id],
		})
	}
	return input
}

func semanticDeviceType(deviceType uint32) string {
	switch deviceType {
	case common.DeviceTypeMotherboard:
		return "motherboard"
	case common.DeviceTypeDram:
		return "memory"
	case common.DeviceTypeGpu:
		return "gpu"
	case common.DeviceTypeCooler:
		return "cooler"
	case common.DeviceTypeLedstrip:
		return "lighting"
	case common.DeviceTypeKeyboard:
		return "keyboard"
	case common.DeviceTypeMouse:
		return "mouse"
	case common.DeviceTypeMousemat:
		return "mousemat"
	case common.DeviceTypeHeadset:
		return "headset"
	case common.DeviceTypeHeadsetStand:
		return "headset-stand"
	case common.DeviceTypeGamepad:
		return "gamepad"
	case common.DeviceTypeLight:
		return "light"
	case common.DeviceTypeSpeaker:
		return "speaker"
	case common.DeviceTypeVirtual:
		return "virtual"
	case common.DeviceTypeStorage:
		return "storage"
	case common.DeviceTypeCase:
		return "case"
	case common.DeviceTypeMicrophone:
		return "microphone"
	case common.DeviceTypeAccessory:
		return "accessory"
	case common.DeviceTypeKeypad:
		return "keypad"
	case common.DeviceTypeLaptop:
		return "laptop"
	case common.DeviceTypeMonitor:
		return "monitor"
	default:
		return "unknown"
	}
}
