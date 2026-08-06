package server

import (
	"OpenLinkHub/src/application/lighting"
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
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"reflect"
	"sort"
	"strings"
	"sync"
	"time"
)

var apiV1StateRevision contractv1.RevisionTracker
var apiV1TelemetryRevision contractv1.RevisionTracker
var apiV1Input = collectV1Input
var apiV1WriteMutex sync.Mutex
var apiV1ApplyLabel = applyLabelV1

type lightingAssignmentCommander interface {
	AssignProfile(context.Context, lighting.Command) lighting.Result
}

var apiV1LightingCommands lightingAssignmentCommander = newAPIV1LightingService()

type channelLightingProfileAssigner interface {
	UpdateRgbProfile(int, string) uint8
}

type lightingOwnershipCommander interface {
	ChangeController(context.Context, lighting.OwnershipCommand) lighting.OwnershipResult
}

type rgbClusterOwnershipSwitcher interface {
	ProcessSetRgbCluster(bool) uint8
}

type rgbClusterOwnershipReader interface {
	GetRgbCluster() bool
}

var apiV1LightingOwnershipCommands lightingOwnershipCommander = newAPIV1LightingOwnershipService()

func newAPIV1LightingService() *lighting.Service {
	inventory := newContractV1LightingInventoryAdapter(
		func(ctx context.Context) (contractv1.Snapshot, uint64, error) {
			select {
			case <-ctx.Done():
				return contractv1.Snapshot{}, 0, ctx.Err()
			default:
			}
			snapshot := contractv1.BuildSnapshot(apiV1Input())
			revision := apiV1StateRevision.Observe(contractv1.StateRevisionValue(snapshot))
			return snapshot, revision, nil
		},
	)
	return lighting.NewServiceWithLocker(
		inventory,
		newLegacyLightingAssignerAdapter(devices.CallDeviceMethod),
		&apiV1WriteMutex,
	)
}

func newAPIV1LightingOwnershipService() *lighting.OwnershipService {
	inventory := newContractV1LightingInventoryAdapter(
		func(ctx context.Context) (contractv1.Snapshot, uint64, error) {
			select {
			case <-ctx.Done():
				return contractv1.Snapshot{}, 0, ctx.Err()
			default:
			}
			snapshot := contractv1.BuildSnapshot(apiV1Input())
			revision := apiV1StateRevision.Observe(contractv1.StateRevisionValue(snapshot))
			return snapshot, revision, nil
		},
	)
	return lighting.NewOwnershipServiceWithLocker(
		inventory,
		newLegacyLightingOwnershipSwitcherAdapter(devices.CallDeviceMethod),
		&apiV1WriteMutex,
	)
}

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

func putDeviceLabelV1(w http.ResponseWriter, request *http.Request) {
	command := contractv1.LabelCommand{}
	decoder := json.NewDecoder(request.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&command); err != nil {
		sendLabelCommandError(
			w,
			currentV1StateRevision(),
			http.StatusBadRequest,
			"The label request is not valid JSON.",
			contractv1.CommandIssue{Field: "body", Code: "invalid-json", Message: err.Error()},
		)
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		sendLabelCommandError(
			w,
			currentV1StateRevision(),
			http.StatusBadRequest,
			"The label request must contain one JSON object.",
			contractv1.CommandIssue{Field: "body", Code: "trailing-data", Message: "Remove content after the command object."},
		)
		return
	}

	command.DeviceID = strings.TrimSpace(command.DeviceID)
	command.TargetID = strings.TrimSpace(command.TargetID)
	command.Label = strings.TrimSpace(command.Label)
	issues := validateLabelCommand(command)
	if len(issues) > 0 {
		sendLabelCommandErrors(
			w,
			currentV1StateRevision(),
			http.StatusBadRequest,
			"Correct the highlighted label fields and try again.",
			issues,
		)
		return
	}

	apiV1WriteMutex.Lock()
	defer apiV1WriteMutex.Unlock()

	before := contractv1.BuildSnapshot(apiV1Input())
	revision := apiV1StateRevision.Observe(contractv1.StateRevisionValue(before))
	if command.ExpectedRevision != revision {
		sendLabelCommandError(
			w,
			revision,
			http.StatusConflict,
			"OpenLinkHub state changed after this editor was opened. Refresh and review the current label before applying.",
			contractv1.CommandIssue{Field: "expectedRevision", Code: "stale-revision", Message: fmt.Sprintf("Expected revision %d; current revision is %d.", command.ExpectedRevision, revision)},
		)
		return
	}

	target, found := findLabelTarget(before, command.DeviceID, command.TargetID)
	if !found {
		sendLabelCommandError(
			w,
			revision,
			http.StatusNotFound,
			"That label target is unavailable or no longer connected.",
			contractv1.CommandIssue{Field: "targetId", Code: "target-not-found", Message: "Refresh the device and choose a published label target."},
		)
		return
	}
	if target.Label == command.Label {
		sendLabelCommandResult(w, http.StatusOK, revision, contractv1.LabelCommandResult{
			Operation:       "device-label.update",
			Status:          "succeeded",
			Message:         "The requested label is already active.",
			Changed:         false,
			RefreshRequired: false,
			Target:          &target,
			Issues:          []contractv1.CommandIssue{},
		})
		return
	}

	if !apiV1ApplyLabel(command.DeviceID, target, command.Label) {
		sendLabelCommandError(
			w,
			revision,
			http.StatusUnprocessableEntity,
			"OpenLinkHub could not apply the label to that target.",
			contractv1.CommandIssue{Field: "targetId", Code: "apply-failed", Message: "The device driver rejected or does not implement this label operation."},
		)
		return
	}

	after := contractv1.BuildSnapshot(apiV1Input())
	newRevision := apiV1StateRevision.Observe(contractv1.StateRevisionValue(after))
	verified, found := findLabelTarget(after, command.DeviceID, command.TargetID)
	if !found || verified.Label != command.Label {
		sendLabelCommandError(
			w,
			newRevision,
			http.StatusInternalServerError,
			"The device accepted the label request, but the refreshed service state did not confirm it.",
			contractv1.CommandIssue{Field: "label", Code: "verification-failed", Message: "No success was reported because read-back verification failed."},
		)
		return
	}

	sendLabelCommandResult(w, http.StatusOK, newRevision, contractv1.LabelCommandResult{
		Operation:       "device-label.update",
		Status:          "succeeded",
		Message:         "Label applied and verified from refreshed service state.",
		Changed:         true,
		RefreshRequired: false,
		Target:          &verified,
		Issues:          []contractv1.CommandIssue{},
	})
}

func putLightingAssignmentV1(w http.ResponseWriter, request *http.Request) {
	command := contractv1.LightingAssignmentCommand{}
	decoder := json.NewDecoder(request.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&command); err != nil {
		sendLightingAssignmentError(
			w,
			currentV1StateRevision(),
			http.StatusBadRequest,
			"The lighting assignment is not valid JSON.",
			contractv1.CommandIssue{Field: "body", Code: "invalid-json", Message: err.Error()},
		)
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		sendLightingAssignmentError(
			w,
			currentV1StateRevision(),
			http.StatusBadRequest,
			"The lighting assignment must contain one JSON object.",
			contractv1.CommandIssue{Field: "body", Code: "trailing-data", Message: "Remove content after the command object."},
		)
		return
	}

	result := apiV1LightingCommands.AssignProfile(request.Context(), lighting.Command{
		ExpectedRevision: command.ExpectedRevision,
		DeviceID:         command.DeviceID,
		TargetID:         command.TargetID,
		ProfileID:        command.ProfileID,
	})
	status := lightingAssignmentHTTPStatus(result)
	revision := result.Revision
	if revision == 0 {
		revision = currentV1StateRevision()
	}
	issues := []contractv1.CommandIssue{}
	if result.Issue != nil {
		issues = append(issues, contractv1.CommandIssue{
			Field: result.Issue.Field, Code: result.Issue.Code, Message: result.Issue.Message,
		})
	}
	sendLightingAssignmentResult(w, status, revision, contractv1.LightingAssignmentResult{
		Operation:        "lighting.assign-profile",
		Status:           string(result.Status),
		Message:          lightingAssignmentMessage(result),
		Changed:          result.Changed,
		RefreshRequired:  result.Issue != nil && result.Issue.Code == "stale-revision",
		DeviceID:         result.DeviceID,
		TargetID:         result.TargetID,
		PreviousProfile:  result.PreviousProfile,
		RequestedProfile: result.RequestedProfile,
		ObservedProfile:  result.ObservedProfile,
		Recovery:         string(result.Recovery),
		Persistence:      result.Persistence,
		Issues:           issues,
	})
}

func putLightingOwnershipV1(w http.ResponseWriter, request *http.Request) {
	command := contractv1.LightingOwnershipCommand{}
	decoder := json.NewDecoder(request.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&command); err != nil {
		sendLightingOwnershipError(w, currentV1StateRevision(), http.StatusBadRequest, "The lighting ownership request is not valid JSON.", contractv1.CommandIssue{Field: "body", Code: "invalid-json", Message: err.Error()})
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		sendLightingOwnershipError(w, currentV1StateRevision(), http.StatusBadRequest, "The lighting ownership request must contain one JSON object.", contractv1.CommandIssue{Field: "body", Code: "trailing-data", Message: "Remove content after the command object."})
		return
	}
	result := apiV1LightingOwnershipCommands.ChangeController(request.Context(), lighting.OwnershipCommand{
		ExpectedRevision:    command.ExpectedRevision,
		DeviceID:            command.DeviceID,
		ExpectedController:  lighting.Controller(command.ExpectedController),
		RequestedController: lighting.Controller(command.RequestedController),
	})
	status := lightingOwnershipHTTPStatus(result)
	revision := result.Revision
	if revision == 0 {
		revision = currentV1StateRevision()
	}
	issues := []contractv1.CommandIssue{}
	if result.Issue != nil {
		issues = append(issues, contractv1.CommandIssue{Field: result.Issue.Field, Code: result.Issue.Code, Message: result.Issue.Message})
	}
	sendLightingOwnershipResult(w, status, revision, contractv1.LightingOwnershipResult{
		Operation: "lighting.change-controller", Status: string(result.Status), Message: lightingOwnershipMessage(result),
		Changed: result.Changed, RefreshRequired: result.Issue != nil && (result.Issue.Code == "stale-revision" || result.Issue.Code == "owner-changed"),
		DeviceID: result.DeviceID, PreviousController: string(result.PreviousController), RequestedController: string(result.RequestedController),
		ObservedController: string(result.ObservedController), AffectedTargetCount: result.AffectedTargetCount,
		SavedIndividualSummary: result.SavedIndividualEffect, Recovery: string(result.Recovery), Persistence: "unknown", Issues: issues,
	})
}

func lightingOwnershipHTTPStatus(result lighting.OwnershipResult) int {
	if result.Status == lighting.StatusSucceeded {
		return http.StatusOK
	}
	if result.Status == lighting.StatusFailedRestored || result.Status == lighting.StatusFailedRestoreUnverified {
		return http.StatusInternalServerError
	}
	if result.Issue == nil {
		return http.StatusUnprocessableEntity
	}
	switch result.Issue.Code {
	case "required", "invalid":
		return http.StatusBadRequest
	case "stale-revision", "owner-changed":
		return http.StatusConflict
	case "device-not-found":
		return http.StatusNotFound
	case "service", "unavailable", "inventory-unavailable":
		return http.StatusServiceUnavailable
	default:
		return http.StatusUnprocessableEntity
	}
}

func lightingOwnershipMessage(result lighting.OwnershipResult) string {
	if result.Status == lighting.StatusSucceeded {
		if result.Changed {
			return "Lighting controller changed and verified from refreshed service state."
		}
		return "The requested lighting controller is already active."
	}
	if result.Status == lighting.StatusFailedRestored {
		return "The controller change failed; the previous controller was restored and verified."
	}
	if result.Status == lighting.StatusFailedRestoreUnverified {
		return "The controller change failed and recovery could not be verified. Refresh before issuing another command."
	}
	if result.Issue != nil {
		return result.Issue.Message
	}
	return "The lighting controller change was rejected."
}

func sendLightingOwnershipError(w http.ResponseWriter, revision uint64, status int, message string, issue contractv1.CommandIssue) {
	sendLightingOwnershipResult(w, status, revision, contractv1.LightingOwnershipResult{
		Operation: "lighting.change-controller", Status: string(lighting.StatusRejected), Message: message,
		RefreshRequired: status == http.StatusConflict, Recovery: string(lighting.RecoveryNotNeeded), Persistence: "unknown",
		Issues: []contractv1.CommandIssue{issue},
	})
}

func sendLightingOwnershipResult(w http.ResponseWriter, status int, revision uint64, result contractv1.LightingOwnershipResult) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(contractv1.Wrap("command-result", revision, result))
}

func lightingAssignmentHTTPStatus(result lighting.Result) int {
	if result.Status == lighting.StatusSucceeded {
		return http.StatusOK
	}
	if result.Status == lighting.StatusFailedRestored || result.Status == lighting.StatusFailedRestoreUnverified {
		return http.StatusInternalServerError
	}
	if result.Issue == nil {
		return http.StatusUnprocessableEntity
	}
	switch result.Issue.Code {
	case "required":
		return http.StatusBadRequest
	case "stale-revision":
		return http.StatusConflict
	case "target-not-found":
		return http.StatusNotFound
	case "service", "unavailable", "inventory-unavailable":
		return http.StatusServiceUnavailable
	default:
		return http.StatusUnprocessableEntity
	}
}

func lightingAssignmentMessage(result lighting.Result) string {
	if result.Status == lighting.StatusSucceeded {
		if result.Changed {
			return "Lighting profile assigned and verified from refreshed service state."
		}
		return "The requested lighting profile is already active."
	}
	if result.Status == lighting.StatusFailedRestored {
		return "The lighting assignment failed; the previous profile was restored and verified."
	}
	if result.Status == lighting.StatusFailedRestoreUnverified {
		return "The lighting assignment failed and recovery could not be verified. Refresh before issuing another command."
	}
	if result.Issue != nil {
		return result.Issue.Message
	}
	return "The lighting assignment was rejected."
}

func sendLightingAssignmentError(w http.ResponseWriter, revision uint64, status int, message string, issue contractv1.CommandIssue) {
	sendLightingAssignmentResult(w, status, revision, contractv1.LightingAssignmentResult{
		Operation:       "lighting.assign-profile",
		Status:          string(lighting.StatusRejected),
		Message:         message,
		Changed:         false,
		RefreshRequired: status == http.StatusConflict,
		Recovery:        string(lighting.RecoveryNotNeeded),
		Persistence:     "unknown",
		Issues:          []contractv1.CommandIssue{issue},
	})
}

func sendLightingAssignmentResult(w http.ResponseWriter, status int, revision uint64, result contractv1.LightingAssignmentResult) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(contractv1.Wrap("command-result", revision, result))
}

func validateLabelCommand(command contractv1.LabelCommand) []contractv1.CommandIssue {
	issues := make([]contractv1.CommandIssue, 0, 4)
	if command.ExpectedRevision == 0 {
		issues = append(issues, contractv1.CommandIssue{Field: "expectedRevision", Code: "required", Message: "A positive state revision is required."})
	}
	if command.DeviceID == "" || !common.AlphanumericDashSemiColon.MatchString(command.DeviceID) {
		issues = append(issues, contractv1.CommandIssue{Field: "deviceId", Code: "invalid", Message: "Choose a device published by the current snapshot."})
	}
	if command.TargetID == "" {
		issues = append(issues, contractv1.CommandIssue{Field: "targetId", Code: "required", Message: "Choose a published label target."})
	}
	if len(command.Label) > 64 {
		issues = append(issues, contractv1.CommandIssue{Field: "label", Code: "length", Message: "Use no more than 64 characters."})
	} else if command.Label != "" && !common.AlphanumericDisplayName.MatchString(command.Label) {
		issues = append(issues, contractv1.CommandIssue{Field: "label", Code: "characters", Message: "Use letters, numbers, spaces, and # . : _ - only."})
	}
	return issues
}

func currentV1StateRevision() uint64 {
	snapshot := contractv1.BuildSnapshot(apiV1Input())
	return apiV1StateRevision.Observe(contractv1.StateRevisionValue(snapshot))
}

func findLabelTarget(snapshot contractv1.Snapshot, deviceID, targetID string) (contractv1.LabelTarget, bool) {
	for _, device := range snapshot.Devices {
		if device.ID != deviceID {
			continue
		}
		for _, target := range device.LabelTargets {
			if target.ID == targetID {
				return target, true
			}
		}
		return contractv1.LabelTarget{}, false
	}
	return contractv1.LabelTarget{}, false
}

func applyLabelV1(deviceID string, target contractv1.LabelTarget, label string) (success bool) {
	channelID := -1
	if target.ChannelID != nil {
		channelID = *target.ChannelID
	}
	defer func() {
		if recover() != nil {
			success = false
		}
	}()
	result := devices.CallDeviceMethod(deviceID, "UpdateDeviceLabel", channelID, label)
	return len(result) > 0 && result[0].Uint() == 1
}

func sendLabelCommandError(w http.ResponseWriter, revision uint64, status int, message string, issue contractv1.CommandIssue) {
	sendLabelCommandErrors(w, revision, status, message, []contractv1.CommandIssue{issue})
}

func sendLabelCommandErrors(w http.ResponseWriter, revision uint64, status int, message string, issues []contractv1.CommandIssue) {
	sendLabelCommandResult(w, status, revision, contractv1.LabelCommandResult{
		Operation:       "device-label.update",
		Status:          "rejected",
		Message:         message,
		Changed:         false,
		RefreshRequired: status == http.StatusConflict,
		Issues:          issues,
	})
}

func sendLabelCommandResult(w http.ResponseWriter, status int, revision uint64, result contractv1.LabelCommandResult) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(contractv1.Wrap("command-result", revision, result))
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
	deviceMap := devices.GetDevicesSnapshot()
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
			ID:                          id,
			Product:                     device.Product,
			ProductID:                   device.ProductId,
			ProductType:                 device.ProductType,
			DeviceType:                  semanticDeviceType(device.DeviceType),
			Firmware:                    device.Firmware,
			Hidden:                      device.Hidden,
			Detail:                      device.GetDevice,
			Battery:                     battery,
			LightingData:                lighting[id],
			LightingChannelAssignment:   supportsChannelLightingAssignment(device),
			LightingOwnershipTransition: supportsLightingOwnershipTransition(device),
			LightingRGBCluster:          readLightingRGBCluster(id, device),
		})
	}
	return input
}

func supportsLightingOwnershipTransition(device *common.Device) bool {
	if device == nil || device.Instance == nil {
		return false
	}
	switch device.ProductType {
	case common.ProductTypeLinkHub, common.ProductTypeK100AirWU, common.ProductTypeScimitarRgbEliteWU:
	default:
		return false
	}
	_, canWrite := device.Instance.(rgbClusterOwnershipSwitcher)
	_, canRead := device.Instance.(rgbClusterOwnershipReader)
	return canWrite && canRead
}

func readLightingRGBCluster(deviceID string, device *common.Device) *bool {
	if !supportsLightingOwnershipTransition(device) {
		return nil
	}
	result := devices.CallDeviceMethod(deviceID, "GetRgbCluster")
	if len(result) != 1 || !result[0].IsValid() || result[0].Kind() != reflect.Bool {
		return nil
	}
	value := result[0].Bool()
	return &value
}

func supportsChannelLightingAssignment(device *common.Device) bool {
	if device == nil || device.ProductType != common.ProductTypeLinkHub || device.Instance == nil {
		return false
	}
	_, supported := device.Instance.(channelLightingProfileAssigner)
	return supported
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
