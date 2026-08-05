package server

import (
	"OpenLinkHub/src/application/lighting"
	"OpenLinkHub/src/common"
	"OpenLinkHub/src/server/contractv1"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakeLightingCommandService struct {
	result  lighting.Result
	command lighting.Command
	calls   int
}

func (service *fakeLightingCommandService) AssignProfile(_ context.Context, command lighting.Command) lighting.Result {
	service.calls++
	service.command = command
	return service.result
}

type fakeChannelLightingDriver struct{}

func (*fakeChannelLightingDriver) UpdateRgbProfile(int, string) uint8 { return 1 }

func TestChannelLightingCapabilityResolverFailsClosed(t *testing.T) {
	tests := []struct {
		name   string
		device *common.Device
		want   bool
	}{
		{name: "link hub driver", device: &common.Device{ProductType: common.ProductTypeLinkHub, Instance: &fakeChannelLightingDriver{}}, want: true},
		{name: "wrong family", device: &common.Device{ProductType: common.ProductTypeK100, Instance: &fakeChannelLightingDriver{}}, want: false},
		{name: "missing method", device: &common.Device{ProductType: common.ProductTypeLinkHub, Instance: struct{}{}}, want: false},
		{name: "missing instance", device: &common.Device{ProductType: common.ProductTypeLinkHub}, want: false},
		{name: "missing device", device: nil, want: false},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := supportsChannelLightingAssignment(test.device); got != test.want {
				t.Fatalf("supportsChannelLightingAssignment() = %v, want %v", got, test.want)
			}
		})
	}
}

func TestLightingAssignmentV1RejectsMalformedJSONBeforeApplicationService(t *testing.T) {
	service := installLightingRouteFixture(t, lighting.Result{})
	request := httptest.NewRequest(http.MethodPut, "/api/v1/lighting/assignment", strings.NewReader(`{"expectedRevision":1,"unexpected":true}`))
	response := httptest.NewRecorder()
	setRoutes().ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest || service.calls != 0 || !strings.Contains(response.Body.String(), "invalid-json") {
		t.Fatalf("malformed response = %d %s; calls = %d", response.Code, response.Body.String(), service.calls)
	}
}

func TestLightingAssignmentV1MapsGuardedApplicationOutcomes(t *testing.T) {
	tests := []struct {
		name       string
		result     lighting.Result
		wantStatus int
		wantCode   string
	}{
		{
			name: "stale", wantStatus: http.StatusConflict, wantCode: "stale-revision",
			result: rejectedLightingResult("stale-revision"),
		},
		{
			name: "unsupported operation", wantStatus: http.StatusUnprocessableEntity, wantCode: "operation-unavailable",
			result: rejectedLightingResult("operation-unavailable"),
		},
		{
			name: "no-op", wantStatus: http.StatusOK,
			result: lighting.Result{Status: lighting.StatusSucceeded, Revision: 7, DeviceID: "hub", TargetID: "channel:7", PreviousProfile: "static", RequestedProfile: "static", ObservedProfile: "static", Recovery: lighting.RecoveryNotNeeded, Persistence: "unknown"},
		},
		{
			name: "success", wantStatus: http.StatusOK,
			result: lighting.Result{Status: lighting.StatusSucceeded, Revision: 8, Changed: true, DeviceID: "hub", TargetID: "channel:7", PreviousProfile: "static", RequestedProfile: "rainbow", ObservedProfile: "rainbow", Recovery: lighting.RecoveryNotNeeded, Persistence: "unknown"},
		},
		{
			name: "restored", wantStatus: http.StatusInternalServerError, wantCode: "verification-failed",
			result: lighting.Result{Status: lighting.StatusFailedRestored, Revision: 9, DeviceID: "hub", TargetID: "channel:7", PreviousProfile: "static", RequestedProfile: "rainbow", ObservedProfile: "static", Recovery: lighting.RecoveryVerified, Persistence: "unknown", Issue: &lighting.Issue{Field: "profileId", Code: "verification-failed", Message: "restored"}},
		},
		{
			name: "recovery unverified", wantStatus: http.StatusInternalServerError, wantCode: "recovery-unverified",
			result: lighting.Result{Status: lighting.StatusFailedRestoreUnverified, Revision: 9, Changed: true, DeviceID: "hub", TargetID: "channel:7", PreviousProfile: "static", RequestedProfile: "rainbow", ObservedProfile: "wrong", Recovery: lighting.RecoveryUnverified, Persistence: "unknown", Issue: &lighting.Issue{Field: "profileId", Code: "recovery-unverified", Message: "unverified"}},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			service := installLightingRouteFixture(t, test.result)
			request := httptest.NewRequest(http.MethodPut, "/api/v1/lighting/assignment", strings.NewReader(`{"expectedRevision":7,"deviceId":"hub","targetId":"channel:7","profileId":"rainbow"}`))
			response := httptest.NewRecorder()
			setRoutes().ServeHTTP(response, request)
			if response.Code != test.wantStatus {
				t.Fatalf("status = %d, want %d; body = %s", response.Code, test.wantStatus, response.Body.String())
			}
			if response.Header().Get("Cache-Control") != "no-store" || service.calls != 1 {
				t.Fatalf("response boundary or dispatch count is wrong: %#v calls=%d", response.Header(), service.calls)
			}
			if service.command.DeviceID != "hub" || service.command.TargetID != "channel:7" || service.command.ProfileID != "rainbow" {
				t.Fatalf("unexpected application command: %#v", service.command)
			}
			var document struct {
				Kind     string                              `json:"kind"`
				Revision uint64                              `json:"revision"`
				Data     contractv1.LightingAssignmentResult `json:"data"`
			}
			if err := json.Unmarshal(response.Body.Bytes(), &document); err != nil {
				t.Fatal(err)
			}
			if document.Kind != "command-result" || document.Revision < 1 || document.Data.Operation != "lighting.assign-profile" {
				t.Fatalf("unexpected result document: %#v", document)
			}
			if test.wantCode != "" && (len(document.Data.Issues) != 1 || document.Data.Issues[0].Code != test.wantCode) {
				t.Fatalf("unexpected issues: %#v", document.Data.Issues)
			}
		})
	}
}

func installLightingRouteFixture(t *testing.T, result lighting.Result) *fakeLightingCommandService {
	t.Helper()
	originalInput := apiV1Input
	originalService := apiV1LightingCommands
	apiV1StateRevision = contractv1.RevisionTracker{}
	apiV1Input = func() contractv1.Input {
		return contractv1.Input{Service: contractv1.ServiceInput{Version: "test", ListenAddress: "127.0.0.1", ListenPort: 27003}}
	}
	service := &fakeLightingCommandService{result: result}
	apiV1LightingCommands = service
	t.Cleanup(func() {
		apiV1Input = originalInput
		apiV1LightingCommands = originalService
		apiV1StateRevision = contractv1.RevisionTracker{}
	})
	return service
}

func rejectedLightingResult(code string) lighting.Result {
	return lighting.Result{
		Status: lighting.StatusRejected, Revision: 7, DeviceID: "hub", TargetID: "channel:7",
		RequestedProfile: "rainbow", Recovery: lighting.RecoveryNotNeeded, Persistence: "unknown",
		Issue: &lighting.Issue{Field: "targetId", Code: code, Message: code},
	}
}
