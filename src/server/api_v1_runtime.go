package server

import (
	"OpenLinkHub/src/application/lighting"
	"OpenLinkHub/src/cluster"
	"OpenLinkHub/src/server/contractv1"
	"encoding/json"
	"io"
	"net/http"
	"time"
)

var apiV1Runtime = lighting.NewRuntimeService(cluster.RuntimeAdapter{}, 2*time.Second)

func getLightingRuntime(w http.ResponseWriter, r *http.Request) {
	state := apiV1Runtime.State()
	// Live heartbeat/lease data must not reuse a configuration-only ETag.
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(contractv1.Wrap("lighting-runtime", state.Revision, state))
}

func runtimeCommand(w http.ResponseWriter, r *http.Request, action string) {
	var command lighting.RuntimeCommand
	decoder := json.NewDecoder(io.LimitReader(r.Body, 4096))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&command); err != nil {
		http.Error(w, "Invalid lighting command", http.StatusBadRequest)
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		http.Error(w, "Expected one command", http.StatusBadRequest)
		return
	}
	var result lighting.RuntimeResult
	switch action {
	case "recover":
		result = apiV1Runtime.Recover(r.Context(), command)
	case "identify":
		result = apiV1Runtime.Identify(r.Context(), command)
	case "cancel":
		result = apiV1Runtime.Cancel(r.Context(), command.LeaseID)
	}
	code := http.StatusOK
	switch result.Status {
	case "timeout":
		code = http.StatusGatewayTimeout
	case "unverified":
		code = http.StatusServiceUnavailable
	case "busy", "stale-revision":
		code = http.StatusConflict
	case "invalid":
		code = http.StatusBadRequest
	case "unsupported", "unavailable":
		code = http.StatusUnprocessableEntity
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(contractv1.Wrap("lighting-runtime-result", result.State.Revision, result))
}

func recoverLighting(w http.ResponseWriter, r *http.Request)      { runtimeCommand(w, r, "recover") }
func identifyLighting(w http.ResponseWriter, r *http.Request)     { runtimeCommand(w, r, "identify") }
func cancelIdentification(w http.ResponseWriter, r *http.Request) { runtimeCommand(w, r, "cancel") }
