package k100airWU

import (
	"reflect"
	"testing"
)

type toggleEvent struct {
	command uint16
	pressed bool
}

func TestKeyboardTogglePressReleaseAndForcedRelease(t *testing.T) {
	var events []toggleEvent
	device := &Device{
		keyboardToggleKeys: make(map[string]uint16),
		keyboardToggleEmit: func(command uint16, pressed bool) {
			events = append(events, toggleEvent{command: command, pressed: pressed})
		},
	}

	device.toggleKeyboardAction("G1", 33)
	device.toggleKeyboardAction("G1", 33)
	device.toggleKeyboardAction("G1", 33)
	device.releaseKeyboardToggles()

	want := []toggleEvent{
		{command: 33, pressed: true},
		{command: 33, pressed: false},
		{command: 33, pressed: true},
		{command: 33, pressed: false},
	}
	if !reflect.DeepEqual(events, want) {
		t.Fatalf("unexpected toggle events: got %#v, want %#v", events, want)
	}
	if len(device.keyboardToggleKeys) != 0 {
		t.Fatalf("toggle state was not cleared: %#v", device.keyboardToggleKeys)
	}
}
