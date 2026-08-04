package server

import (
	"OpenLinkHub/src/server/contractv1"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestSnapshotV1DocumentAndReadOnlyMethodBoundary(t *testing.T) {
	originalInput := apiV1Input
	apiV1StateRevision = contractv1.RevisionTracker{}
	apiV1TelemetryRevision = contractv1.RevisionTracker{}
	apiV1Input = func() contractv1.Input {
		return contractv1.Input{
			Service: contractv1.ServiceInput{
				Version:       "test",
				ListenAddress: "127.0.0.1",
				ListenPort:    27003,
			},
		}
	}
	t.Cleanup(func() {
		apiV1Input = originalInput
		apiV1StateRevision = contractv1.RevisionTracker{}
		apiV1TelemetryRevision = contractv1.RevisionTracker{}
	})

	handler := setRoutes()

	request := httptest.NewRequest(http.MethodGet, "/api/v1/snapshot", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("GET status = %d, want 200", response.Code)
	}
	if response.Header().Get("Cache-Control") != "private, no-cache" {
		t.Fatalf("missing revalidation cache boundary")
	}
	etag := response.Header().Get("ETag")
	if etag == "" {
		t.Fatalf("missing snapshot ETag")
	}
	document := map[string]any{}
	if err := json.Unmarshal(response.Body.Bytes(), &document); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if document["apiVersion"] != "1.0" || document["kind"] != "snapshot" {
		t.Fatalf("unexpected contract document: %#v", document)
	}
	if revision, ok := document["revision"].(float64); !ok || revision < 1 {
		t.Fatalf("invalid contract revision: %#v", document["revision"])
	}
	if revision, ok := document["telemetryRevision"].(float64); !ok || revision < 1 {
		t.Fatalf("invalid telemetry revision: %#v", document["telemetryRevision"])
	}

	request = httptest.NewRequest(http.MethodGet, "/api/v1/snapshot", nil)
	request.Header.Set("If-None-Match", etag)
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusNotModified || response.Body.Len() != 0 {
		t.Fatalf("conditional GET = %d with %d bytes, want 304/empty", response.Code, response.Body.Len())
	}

	request = httptest.NewRequest(http.MethodPost, "/api/v1/snapshot", nil)
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusMethodNotAllowed {
		t.Fatalf("POST status = %d, want 405", response.Code)
	}
}

func TestLegacyRootRouteRemainsAvailable(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/api/", nil)
	response := httptest.NewRecorder()
	setRoutes().ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("legacy root status = %d, want 200", response.Code)
	}
}

func TestDeviceLabelV1AppliesAndVerifiesWithExpectedRevision(t *testing.T) {
	originalInput := apiV1Input
	originalApply := apiV1ApplyLabel
	apiV1StateRevision = contractv1.RevisionTracker{}
	apiV1TelemetryRevision = contractv1.RevisionTracker{}
	label := "Radiator"
	apiV1Input = func() contractv1.Input { return labelInput(label) }
	applyCalls := 0
	apiV1ApplyLabel = func(deviceID string, target contractv1.LabelTarget, value string) bool {
		applyCalls++
		if deviceID != "hub" || target.ID != "channel:7" {
			t.Fatalf("unexpected target: %s %#v", deviceID, target)
		}
		label = value
		return true
	}
	t.Cleanup(func() {
		apiV1Input = originalInput
		apiV1ApplyLabel = originalApply
		apiV1StateRevision = contractv1.RevisionTracker{}
		apiV1TelemetryRevision = contractv1.RevisionTracker{}
	})

	body := `{"expectedRevision":1,"deviceId":"hub","targetId":"channel:7","label":"Rear Radiator"}`
	request := httptest.NewRequest(http.MethodPut, "/api/v1/devices/label", strings.NewReader(body))
	response := httptest.NewRecorder()
	setRoutes().ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("PUT status = %d, body = %s", response.Code, response.Body.String())
	}
	if applyCalls != 1 || label != "Rear Radiator" {
		t.Fatalf("apply calls = %d, label = %q", applyCalls, label)
	}
	document := struct {
		Revision uint64                        `json:"revision"`
		Kind     string                        `json:"kind"`
		Data     contractv1.LabelCommandResult `json:"data"`
	}{}
	if err := json.Unmarshal(response.Body.Bytes(), &document); err != nil {
		t.Fatal(err)
	}
	if document.Kind != "command-result" || document.Revision != 2 ||
		document.Data.Status != "succeeded" || !document.Data.Changed ||
		document.Data.Target == nil || document.Data.Target.Label != "Rear Radiator" {
		t.Fatalf("unexpected command result: %#v", document)
	}
}

func TestDeviceLabelV1RejectsStaleAndInvalidCommands(t *testing.T) {
	originalInput := apiV1Input
	originalApply := apiV1ApplyLabel
	apiV1StateRevision = contractv1.RevisionTracker{}
	label := "Radiator"
	apiV1Input = func() contractv1.Input { return labelInput(label) }
	applyCalls := 0
	apiV1ApplyLabel = func(_ string, _ contractv1.LabelTarget, _ string) bool {
		applyCalls++
		return true
	}
	t.Cleanup(func() {
		apiV1Input = originalInput
		apiV1ApplyLabel = originalApply
		apiV1StateRevision = contractv1.RevisionTracker{}
	})

	if got := currentV1StateRevision(); got != 1 {
		t.Fatalf("initial revision = %d", got)
	}
	label = "Externally Changed"
	if got := currentV1StateRevision(); got != 2 {
		t.Fatalf("changed revision = %d", got)
	}

	tests := []struct {
		name   string
		body   string
		status int
		code   string
	}{
		{
			name:   "stale",
			body:   `{"expectedRevision":1,"deviceId":"hub","targetId":"channel:7","label":"Rear"}`,
			status: http.StatusConflict,
			code:   "stale-revision",
		},
		{
			name:   "invalid characters",
			body:   `{"expectedRevision":2,"deviceId":"hub","targetId":"channel:7","label":"Rear / unsafe"}`,
			status: http.StatusBadRequest,
			code:   "characters",
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodPut, "/api/v1/devices/label", strings.NewReader(test.body))
			response := httptest.NewRecorder()
			setRoutes().ServeHTTP(response, request)
			if response.Code != test.status {
				t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
			}
			var document struct {
				Data contractv1.LabelCommandResult `json:"data"`
			}
			if err := json.Unmarshal(response.Body.Bytes(), &document); err != nil {
				t.Fatal(err)
			}
			if document.Data.Status != "rejected" || len(document.Data.Issues) != 1 || document.Data.Issues[0].Code != test.code {
				t.Fatalf("unexpected rejection: %#v", document.Data)
			}
		})
	}
	if applyCalls != 0 {
		t.Fatalf("rejected commands reached dispatcher %d times", applyCalls)
	}
}

func TestDeviceLabelV1ClearsPublishedLabel(t *testing.T) {
	originalInput := apiV1Input
	originalApply := apiV1ApplyLabel
	apiV1StateRevision = contractv1.RevisionTracker{}
	apiV1TelemetryRevision = contractv1.RevisionTracker{}
	label := "Rear Radiator"
	apiV1Input = func() contractv1.Input { return labelInput(label) }
	applyCalls := 0
	apiV1ApplyLabel = func(deviceID string, target contractv1.LabelTarget, value string) bool {
		applyCalls++
		if deviceID != "hub" || target.ID != "channel:7" || value != "" {
			t.Fatalf("unexpected clear request: %q %#v %q", deviceID, target, value)
		}
		label = value
		return true
	}
	t.Cleanup(func() {
		apiV1Input = originalInput
		apiV1ApplyLabel = originalApply
		apiV1StateRevision = contractv1.RevisionTracker{}
		apiV1TelemetryRevision = contractv1.RevisionTracker{}
	})

	body := `{"expectedRevision":1,"deviceId":"hub","targetId":"channel:7","label":""}`
	request := httptest.NewRequest(http.MethodPut, "/api/v1/devices/label", strings.NewReader(body))
	response := httptest.NewRecorder()
	setRoutes().ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("PUT status = %d, body = %s", response.Code, response.Body.String())
	}
	if applyCalls != 1 || label != "" {
		t.Fatalf("apply calls = %d, label = %q", applyCalls, label)
	}
	var document struct {
		Revision uint64                        `json:"revision"`
		Kind     string                        `json:"kind"`
		Data     contractv1.LabelCommandResult `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &document); err != nil {
		t.Fatal(err)
	}
	if document.Kind != "command-result" || document.Revision != 2 ||
		document.Data.Status != "succeeded" || !document.Data.Changed ||
		document.Data.Target == nil || document.Data.Target.Label != "" {
		t.Fatalf("unexpected clear result: %#v", document)
	}
}

func TestDeviceLabelV1DoesNotClaimUnverifiedSuccess(t *testing.T) {
	originalInput := apiV1Input
	originalApply := apiV1ApplyLabel
	apiV1StateRevision = contractv1.RevisionTracker{}
	apiV1Input = func() contractv1.Input { return labelInput("Radiator") }
	apiV1ApplyLabel = func(_ string, _ contractv1.LabelTarget, _ string) bool { return true }
	t.Cleanup(func() {
		apiV1Input = originalInput
		apiV1ApplyLabel = originalApply
		apiV1StateRevision = contractv1.RevisionTracker{}
	})

	body := `{"expectedRevision":1,"deviceId":"hub","targetId":"channel:7","label":"Rear"}`
	request := httptest.NewRequest(http.MethodPut, "/api/v1/devices/label", strings.NewReader(body))
	response := httptest.NewRecorder()
	setRoutes().ServeHTTP(response, request)
	if response.Code != http.StatusInternalServerError || !strings.Contains(response.Body.String(), "verification-failed") {
		t.Fatalf("verification response = %d %s", response.Code, response.Body.String())
	}
}

func labelInput(label string) contractv1.Input {
	return contractv1.Input{
		Service: contractv1.ServiceInput{Version: "test", ListenAddress: "127.0.0.1", ListenPort: 27003},
		Devices: []contractv1.DeviceInput{{
			ID: "hub", Product: "Hub", DeviceType: "cooler",
			Detail: map[string]any{
				"Connected": true,
				"devices": map[string]any{
					"7": map[string]any{"name": "Radiator", "label": label, "HasSpeed": true},
				},
			},
		}},
	}
}
