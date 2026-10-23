package server

import (
	"OpenLinkHub/src/devices"
	"OpenLinkHub/src/devices/voideliteW"
	"encoding/json"
	"io"
	"net/http"
	"sort"
	"sync"
)

var headsetAudioMutex sync.Mutex
var headsetAudioGate = make(chan struct{}, 1)
var audioHeadsetLookup = func(id string) headsetAudioDriver {
	entry := devices.GetDevicesSnapshot()[id]
	if entry == nil {
		return nil
	}
	d, _ := entry.Instance.(*voideliteW.Device)
	if d == nil {
		return nil
	}
	return d
}

type headsetAudioDriver interface {
	AudioSettings() (voideliteW.AudioSettings, error)
	ApplyAudioSettings(string, bool, int) error
}
type headsetAudioCommand struct {
	DeviceID         string `json:"deviceId"`
	ExpectedRevision string `json:"expectedRevision"`
	Enabled          *bool  `json:"enabled"`
	Level            *int   `json:"level"`
}

func headsetAudio(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	headsetAudioMutex.Lock()
	defer headsetAudioMutex.Unlock()
	if r.Method == http.MethodGet {
		items := []any{}
		ids := []string{}
		for id := range devices.GetDevicesSnapshot() {
			ids = append(ids, id)
		}
		sort.Strings(ids)
		for _, id := range ids {
			if d := audioHeadsetLookup(id); d != nil {
				if state, err := d.AudioSettings(); err == nil {
					items = append(items, map[string]any{"deviceId": id, "settings": state})
				}
			}
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"apiVersion": "1.0", "kind": "headset-audio", "data": items})
		return
	}
	if r.Method != http.MethodPut {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	var command headsetAudioCommand
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 2048))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&command); err != nil {
		http.Error(w, "Invalid audio command", 400)
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		http.Error(w, "Expected one command", 400)
		return
	}
	if command.Enabled == nil || command.Level == nil || *command.Level < 1 || *command.Level > 100 || command.ExpectedRevision == "" {
		http.Error(w, "Expected revision, enabled and level (1–100)", 400)
		return
	}
	d := audioHeadsetLookup(command.DeviceID)
	if d == nil {
		http.Error(w, "Supported headset unavailable", 404)
		return
	}
	before, err := d.AudioSettings()
	if err != nil || !before.Connected {
		http.Error(w, "Headset disconnected", 409)
		return
	}
	if before.Revision != command.ExpectedRevision {
		http.Error(w, "Settings changed; refresh", 409)
		return
	}
	if err := d.ApplyAudioSettings(command.ExpectedRevision, *command.Enabled, *command.Level); err != nil {
		http.Error(w, err.Error(), 503)
		return
	}
	after, err := d.AudioSettings()
	if err != nil || !after.Connected || after.Enabled != *command.Enabled || after.Level != *command.Level {
		http.Error(w, "Audio outcome unverified; refresh", 503)
		return
	}
	_ = json.NewEncoder(w).Encode(map[string]any{"apiVersion": "1.0", "kind": "headset-audio-result",
		"data": map[string]any{"deviceId": command.DeviceID, "settings": after, "persistence": "verified",
			"message": "Sidetone saved and sent. Confirm the sound on your headset."}})
}
