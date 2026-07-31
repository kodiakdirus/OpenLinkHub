package server

import (
	"OpenLinkHub/src/server/contractv1"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestSnapshotV1DocumentAndReadOnlyMethodBoundary(t *testing.T) {
	originalInput := apiV1Input
	apiV1Input = func() contractv1.Input {
		return contractv1.Input{
			Service: contractv1.ServiceInput{
				Version:       "test",
				ListenAddress: "127.0.0.1",
				ListenPort:    27003,
			},
		}
	}
	t.Cleanup(func() { apiV1Input = originalInput })

	handler := setRoutes()

	request := httptest.NewRequest(http.MethodGet, "/api/v1/snapshot", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("GET status = %d, want 200", response.Code)
	}
	if response.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("missing no-store cache boundary")
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
