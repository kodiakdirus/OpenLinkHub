package devices

import (
	"OpenLinkHub/src/common"
	"testing"
)

func TestGetDevicesSnapshotDoesNotExposeRegistryMapOrEntries(t *testing.T) {
	mutex.Lock()
	original := devices
	devices = map[string]*common.Device{
		"hub": {Serial: "hub", Product: "System Hub", Firmware: "1.2.3"},
	}
	mutex.Unlock()
	t.Cleanup(func() {
		mutex.Lock()
		devices = original
		mutex.Unlock()
	})

	snapshot := GetDevicesSnapshot()
	delete(snapshot, "hub")
	snapshot["injected"] = &common.Device{Serial: "injected"}

	second := GetDevicesSnapshot()
	if len(second) != 1 || second["hub"] == nil || second["injected"] != nil {
		t.Fatalf("snapshot map changed registry: %#v", second)
	}
	second["hub"].Product = "Changed"
	third := GetDevicesSnapshot()
	if third["hub"].Product != "System Hub" {
		t.Fatalf("snapshot entry changed registry: %#v", third["hub"])
	}
}
