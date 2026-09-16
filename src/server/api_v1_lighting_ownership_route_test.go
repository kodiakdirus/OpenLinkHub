package server

import (
	"OpenLinkHub/src/application/lighting"
	"OpenLinkHub/src/server/contractv1"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakeLightingOwnershipCommandService struct {
	result  lighting.OwnershipResult
	command lighting.OwnershipCommand
	calls   int
}

func (service *fakeLightingOwnershipCommandService) ChangeController(_ context.Context, command lighting.OwnershipCommand) lighting.OwnershipResult {
	service.calls++
	service.command = command
	return service.result
}

func TestLightingOwnershipV1RejectsMalformedJSONBeforeApplicationService(t *testing.T) {
	service := installLightingOwnershipRouteFixture(t, lighting.OwnershipResult{})
	request := httptest.NewRequest(http.MethodPut, "/api/v1/lighting/ownership", strings.NewReader(`{"expectedRevision":1,"unexpected":true}`))
	response := httptest.NewRecorder()
	setRoutes().ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest || service.calls != 0 || !strings.Contains(response.Body.String(), "invalid-json") {
		t.Fatalf("malformed response = %d %s; calls = %d", response.Code, response.Body.String(), service.calls)
	}
}

func TestLightingOwnershipV1MapsGuardedApplicationOutcomes(t *testing.T) {
	tests := []struct {
		name       string
		result     lighting.OwnershipResult
		wantStatus int
		wantCode   string
	}{
		{name: "stale", wantStatus: http.StatusConflict, wantCode: "stale-revision", result: rejectedOwnershipResult("stale-revision")},
		{name: "unsupported", wantStatus: http.StatusUnprocessableEntity, wantCode: "operation-unavailable", result: rejectedOwnershipResult("operation-unavailable")},
		{name: "success", wantStatus: http.StatusOK, result: lighting.OwnershipResult{Status: lighting.StatusSucceeded, Revision: 8, Changed: true, DeviceID: "hub", PreviousController: lighting.ControllerIndividual, RequestedController: lighting.ControllerRGBCluster, ObservedController: lighting.ControllerRGBCluster, AffectedTargetCount: 7, SavedIndividualEffect: "Static on 7 targets", Recovery: lighting.RecoveryNotNeeded}},
		{name: "restored", wantStatus: http.StatusInternalServerError, wantCode: "verification-failed", result: lighting.OwnershipResult{Status: lighting.StatusFailedRestored, Revision: 9, DeviceID: "hub", PreviousController: lighting.ControllerIndividual, RequestedController: lighting.ControllerRGBCluster, ObservedController: lighting.ControllerIndividual, Recovery: lighting.RecoveryVerified, Issue: &lighting.Issue{Field: "requestedController", Code: "verification-failed", Message: "restored"}}},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			service := installLightingOwnershipRouteFixture(t, test.result)
			request := httptest.NewRequest(http.MethodPut, "/api/v1/lighting/ownership", strings.NewReader(`{"expectedRevision":7,"deviceId":"hub","expectedController":"individual","requestedController":"rgb-cluster"}`))
			response := httptest.NewRecorder()
			setRoutes().ServeHTTP(response, request)
			if response.Code != test.wantStatus {
				t.Fatalf("status = %d, want %d; body = %s", response.Code, test.wantStatus, response.Body.String())
			}
			if response.Header().Get("Cache-Control") != "no-store" || service.calls != 1 {
				t.Fatalf("response boundary or dispatch count is wrong: %#v calls=%d", response.Header(), service.calls)
			}
			if service.command.DeviceID != "hub" || service.command.ExpectedController != lighting.ControllerIndividual || service.command.RequestedController != lighting.ControllerRGBCluster {
				t.Fatalf("unexpected application command: %#v", service.command)
			}
			var document struct {
				Kind     string                             `json:"kind"`
				Revision uint64                             `json:"revision"`
				Data     contractv1.LightingOwnershipResult `json:"data"`
			}
			if err := json.Unmarshal(response.Body.Bytes(), &document); err != nil {
				t.Fatal(err)
			}
			if document.Kind != "command-result" || document.Revision < 1 || document.Data.Operation != "lighting.change-controller" {
				t.Fatalf("unexpected result: %#v", document)
			}
			if test.wantCode != "" && (len(document.Data.Issues) != 1 || document.Data.Issues[0].Code != test.wantCode) {
				t.Fatalf("unexpected issues: %#v", document.Data.Issues)
			}
		})
	}
}

func installLightingOwnershipRouteFixture(t *testing.T, result lighting.OwnershipResult) *fakeLightingOwnershipCommandService {
	t.Helper()
	originalInput := apiV1Input
	originalService := apiV1LightingOwnershipCommands
	apiV1StateRevision = contractv1.RevisionTracker{}
	apiV1Input = func() contractv1.Input {
		return contractv1.Input{Service: contractv1.ServiceInput{Version: "test", ListenAddress: "127.0.0.1", ListenPort: 27003}}
	}
	service := &fakeLightingOwnershipCommandService{result: result}
	apiV1LightingOwnershipCommands = service
	t.Cleanup(func() {
		apiV1Input = originalInput
		apiV1LightingOwnershipCommands = originalService
		apiV1StateRevision = contractv1.RevisionTracker{}
	})
	return service
}

func rejectedOwnershipResult(code string) lighting.OwnershipResult {
	return lighting.OwnershipResult{Status: lighting.StatusRejected, Revision: 7, DeviceID: "hub", RequestedController: lighting.ControllerRGBCluster, Recovery: lighting.RecoveryNotNeeded, Issue: &lighting.Issue{Field: "deviceId", Code: code, Message: code}}
}
