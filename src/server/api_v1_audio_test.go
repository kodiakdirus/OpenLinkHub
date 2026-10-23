package server

import (
	"OpenLinkHub/src/devices/voideliteW"
	"bytes"
	"encoding/json"
	"net/http/httptest"
	"testing"
)

type fakeHeadsetAudio struct {
	state voideliteW.AudioSettings
	calls int
}

func (f *fakeHeadsetAudio) AudioSettings() (voideliteW.AudioSettings, error) { return f.state, nil }
func (f *fakeHeadsetAudio) ApplyAudioSettings(_ string, enabled bool, level int) error {
	f.calls++
	f.state.Enabled = enabled
	f.state.Level = level
	return nil
}
func TestHeadsetAudioGuardedWrites(t *testing.T) {
	old := audioHeadsetLookup
	defer func() { audioHeadsetLookup = old }()
	fake := &fakeHeadsetAudio{state: voideliteW.AudioSettings{Revision: "baseline", Connected: true, Battery: 70, Level: 25}}
	audioHeadsetLookup = func(id string) headsetAudioDriver {
		if id == "headset" {
			return fake
		}
		return nil
	}
	for _, test := range []struct {
		body string
		code int
	}{
		{`{"deviceId":"headset","expectedRevision":"old","enabled":true,"level":20}`, 409},
		{`{"deviceId":"headset","expectedRevision":"baseline","enabled":true,"level":101}`, 400},
		{`{"deviceId":"headset","expectedRevision":"baseline","enabled":true}`, 400},
		{`{"deviceId":"headset","expectedRevision":"baseline","enabled":true,"level":20,"other":true}`, 400},
		{`{"deviceId":"headset","expectedRevision":"baseline","enabled":true,"level":20} {}`, 400},
		{`{"deviceId":"missing","expectedRevision":"baseline","enabled":true,"level":20}`, 404},
	} {
		r := httptest.NewRequest("PUT", "/api/v1/audio/headsets", bytes.NewBufferString(test.body))
		w := httptest.NewRecorder()
		headsetAudio(w, r)
		if w.Code != test.code {
			t.Errorf("body %s: got %d want %d", test.body, w.Code, test.code)
		}
	}
	if fake.calls != 0 {
		t.Fatal("invalid command reached driver")
	}
	fake.state.Connected = false
	w := httptest.NewRecorder()
	headsetAudio(w, httptest.NewRequest("PUT", "/api/v1/audio/headsets", bytes.NewBufferString(`{"deviceId":"headset","expectedRevision":"baseline","enabled":true,"level":20}`)))
	if w.Code != 409 || fake.calls != 0 {
		t.Fatal("disconnected driver was called")
	}
	fake.state.Connected = true
	w = httptest.NewRecorder()
	headsetAudio(w, httptest.NewRequest("PUT", "/api/v1/audio/headsets", bytes.NewBufferString(`{"deviceId":"headset","expectedRevision":"baseline","enabled":true,"level":20}`)))
	var result map[string]any
	if w.Code != 200 || json.Unmarshal(w.Body.Bytes(), &result) != nil || fake.calls != 1 {
		t.Fatalf("valid command failed: %s", w.Body.String())
	}
}
