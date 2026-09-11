package server

import (
	"OpenLinkHub/src/application/lighting"
	"context"
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type runtimeRouteDriver struct{}

func (runtimeRouteDriver) State() lighting.RuntimeState {
	return lighting.RuntimeState{Revision: 7, Mode: "unknown", Renderer: "running", Profile: "nebula", Members: []string{"hub"}, Operations: []string{"recover", "identify"}}
}
func (runtimeRouteDriver) Recover(context.Context) error                     { return nil }
func (runtimeRouteDriver) Identify(context.Context, string, time.Time) error { return nil }
func (runtimeRouteDriver) Restore(context.Context, string) error             { return nil }

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
