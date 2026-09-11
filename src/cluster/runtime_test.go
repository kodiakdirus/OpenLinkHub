package cluster

import (
	"OpenLinkHub/src/common"
	"context"
	"reflect"
	"testing"
	"time"
)

func TestProfileChangeRejectsBlockedRendererBeforePersistence(t *testing.T) {
	d := &Device{DeviceProfile: &DeviceProfile{RGBProfile: "nebula"}}
	release, started := make(chan struct{}), make(chan struct{})
	defer close(release)
	d.renderer.Start(func(context.Context) { close(started); <-release })
	<-started
	result := make(chan uint8, 1)
	go func() { result <- d.UpdateRgbProfile(0, "static") }()
	select {
	case code := <-result:
		if code != 0 {
			t.Fatal("blocked renderer accepted a profile change")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("profile update hung on renderer")
	}
	if d.DeviceProfile.RGBProfile != "nebula" {
		t.Fatal("saved effect changed before stop completed")
	}
}

func TestIdentificationOnlyOverlaysSelectedDeviceUntilExpiry(t *testing.T) {
	d := &Device{DeviceProfile: &DeviceProfile{RGBProfile: "nebula"}, Controllers: []*common.ClusterController{{Serial: "hub", LedChannels: 1, WriteColorEx: func([]byte, int) {}}}}
	d.updateRuntimeState()
	revision := d.runtimeState().Revision
	d.overlayDevice = "hub"
	d.overlayExpiry = time.Now().Add(time.Second)
	other := []byte{1, 2, 3}
	d.applyIdentification("keyboard", other)
	if !reflect.DeepEqual(other, []byte{1, 2, 3}) {
		t.Fatal("changed another member")
	}
	selected := []byte{1, 2, 3}
	d.applyIdentification("hub", selected)
	if !reflect.DeepEqual(selected, []byte{64, 64, 64}) {
		t.Fatal("missing locator")
	}
	d.overlayExpiry = time.Now().Add(-time.Second)
	restored := []byte{4, 5, 6}
	d.applyIdentification("hub", restored)
	if !reflect.DeepEqual(restored, []byte{4, 5, 6}) {
		t.Fatal("expired overlay changed the saved frame")
	}
	if revision != d.runtimeState().Revision || d.DeviceProfile.RGBProfile != "nebula" {
		t.Fatal("identification changed saved state")
	}
}

func TestRecoveryRechecksRevisionUnderLifecycleLock(t *testing.T) {
	d := &Device{DeviceProfile: &DeviceProfile{RGBProfile: "nebula"}}
	d.updateRuntimeState()
	if err := d.recoverRenderer(context.Background(), d.runtimeState().Revision+1); err == nil {
		t.Fatal("stale catalog restarted renderer")
	}
	if d.renderer.State() != "stopped" {
		t.Fatal("stale request changed renderer")
	}
}

func TestCatalogDeduplicatesPhysicalMembers(t *testing.T) {
	d := &Device{DeviceProfile: &DeviceProfile{RGBProfile: "nebula"}, Controllers: []*common.ClusterController{
		{Serial: "hub", LedChannels: 1, WriteColorEx: func([]byte, int) {}},
		{Serial: "hub", LedChannels: 1, WriteColorEx: func([]byte, int) {}},
	}}
	d.updateRuntimeState()
	if got := d.runtimeState().Members; !reflect.DeepEqual(got, []string{"hub"}) {
		t.Fatal(got)
	}
}
