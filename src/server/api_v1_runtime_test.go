package server

import (
	"OpenLinkHub/src/application/lighting"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type runtimeRouteDriver struct{}

func (runtimeRouteDriver) State() lighting.RuntimeState {
	return lighting.RuntimeState{Revision: 7, Mode: "unknown", Renderer: "running", Profile: "nebula", Members: []string{"hub"}, Operations: []string{"recover", "identify"}}
}
func (runtimeRouteDriver) Recover(context.Context, uint64) error                     { return nil }
func (runtimeRouteDriver) Identify(context.Context, uint64, string, time.Time) error { return nil }
func (runtimeRouteDriver) Restore(context.Context, string) error                     { return nil }

func TestRuntimeRoutesValidateAndReturnTypedResults(t *testing.T) {
	original := apiV1Runtime
	apiV1Runtime = lighting.NewRuntimeService(runtimeRouteDriver{}, time.Second)
	defer func() { _ = apiV1Runtime.Close(context.Background()); apiV1Runtime = original }()
	for _, tc := range []struct {
		body string
		code int
	}{
		{`{"expectedRevision":6}`, 409},
		{`{"expectedRevision":7,"unknown":true}`, 400},
		{`{"expectedRevision":7} {}`, 400},
		{`{"expectedRevision":7}`, 200},
	} {
		w := httptest.NewRecorder()
		recoverLighting(w, httptest.NewRequest("PUT", "/api/v1/lighting/recover", strings.NewReader(tc.body)))
		if w.Code != tc.code {
			t.Fatalf("%s: %d %s", tc.body, w.Code, w.Body.String())
		}
	}
	w := httptest.NewRecorder()
	getLightingRuntime(w, httptest.NewRequest("GET", "/api/v1/lighting/runtime", nil))
	var doc map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &doc); err != nil {
		t.Fatal(err)
	}
	if doc["kind"] != "lighting-runtime" || w.Header().Get("Cache-Control") != "no-store" {
		t.Fatal(doc)
	}
}

func TestLegacyLeaseGuardRunsInsideSharedGate(t *testing.T) {
	oldRuntime, oldGate := apiV1Runtime, lightingMutationGate
	lightingMutationGate = make(chan struct{}, 1)
	apiV1Runtime = lighting.NewRuntimeServiceWithGate(runtimeRouteDriver{}, time.Second, lightingMutationGate)
	defer func() {
		_ = apiV1Runtime.Close(context.Background())
		apiV1Runtime, lightingMutationGate = oldRuntime, oldGate
	}()
	result := apiV1Runtime.Identify(context.Background(), lighting.RuntimeCommand{ExpectedRevision: 7, DeviceID: "hub", DurationMS: 1000})
	if result.State.Lease == nil {
		t.Fatal(result)
	}
	mux := http.NewServeMux()
	calls := 0
	handleFunc(mux, "/api/color", http.MethodPost, func(w http.ResponseWriter, r *http.Request) { calls++; w.WriteHeader(200) })
	lightingMutationGate <- struct{}{}
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, httptest.NewRequest("POST", "/api/color", nil))
	if w.Code != 503 {
		t.Fatalf("lease check ran outside gate: %d", w.Code)
	}
	<-lightingMutationGate
	w = httptest.NewRecorder()
	mux.ServeHTTP(w, httptest.NewRequest("POST", "/api/color", nil))
	if w.Code != 409 || calls != 0 {
		t.Fatalf("active lease permitted mutation: %d, calls %d", w.Code, calls)
	}
}

func TestRuntimeRejectsOversizeBodyIncludingWhitespace(t *testing.T) {
	w := httptest.NewRecorder()
	recoverLighting(w, httptest.NewRequest("PUT", "/api/v1/lighting/recover", strings.NewReader(`{"expectedRevision":7}`+strings.Repeat(" ", 5000))))
	if w.Code != 400 {
		t.Fatalf("oversize command got %d", w.Code)
	}
}
