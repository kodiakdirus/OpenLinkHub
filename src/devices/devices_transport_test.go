package devices

import (
	"OpenLinkHub/src/common"
	"OpenLinkHub/src/dispatcher"
	"testing"
)

type transportFake struct {
	dispatches int
	stops      int
}

func (d *transportFake) SetDispatcher(dispatcher.DeviceDispatcher) { d.dispatches++ }
func (d *transportFake) StopDirty() uint8 {
	d.stops++
	return 1
}

func preserveRegistries(t *testing.T) {
	t.Helper()
	mutex.Lock()
	originalDevices := devices
	originalUSB := usbDevices
	devices = make(map[string]*common.Device)
	usbDevices = make(map[string]*common.Device)
	mutex.Unlock()
	t.Cleanup(func() {
		mutex.Lock()
		devices = originalDevices
		usbDevices = originalUSB
		mutex.Unlock()
	})
}

func TestLogicalRegistrationCanShadowTrackedPhysicalUSBInstance(t *testing.T) {
	preserveRegistries(t)
	usbInstance := &transportFake{}
	pairedInstance := &transportFake{}
	usb := &common.Device{Serial: "shared", Instance: usbInstance}
	paired := &common.Device{Serial: "shared", Instance: pairedInstance}

	addUSBDevice(usb)
	addDevice(paired)

	mutex.Lock()
	active := devices["shared"]
	trackedUSB := usbDevices["shared"]
	mutex.Unlock()
	if active != paired || trackedUSB != usb {
		t.Fatal("physical USB tracking changed logical transport selection")
	}
}

func TestUSBRetirementPreservesShadowingLogicalTransport(t *testing.T) {
	preserveRegistries(t)
	usb := &common.Device{Serial: "shared", Instance: &transportFake{}}
	paired := &common.Device{Serial: "shared", Instance: &transportFake{}}
	addUSBDevice(usb)
	addDevice(paired)

	if got := getUSBDevice("shared", 0); got != usb {
		t.Fatalf("hotplug selected wrong transport: %#v", got)
	}
	retireUSBDevice(usb, false)

	mutex.Lock()
	active := devices["shared"]
	_, usbStillTracked := usbDevices["shared"]
	mutex.Unlock()
	if usbStillTracked || active != paired {
		t.Fatal("USB retirement disturbed logical transport selection")
	}
}

func TestLateUSBRegistrationTakesOwnershipFromPairedTransport(t *testing.T) {
	preserveRegistries(t)
	paired := &common.Device{Serial: "shared", Instance: &transportFake{}}
	usb := &common.Device{Serial: "shared", Instance: &transportFake{}}
	addDevice(paired)
	addUSBDevice(usb)

	mutex.Lock()
	active := devices["shared"]
	mutex.Unlock()
	if active != usb {
		t.Fatal("physical USB transport did not take active ownership")
	}
}

func TestReplacementUSBRegistrationStopsPreviousInstance(t *testing.T) {
	preserveRegistries(t)
	oldInstance := &transportFake{}
	newInstance := &transportFake{}
	oldUSB := &common.Device{Serial: "shared", Instance: oldInstance}
	newUSB := &common.Device{Serial: "shared", Instance: newInstance}
	addUSBDevice(oldUSB)
	addUSBDevice(newUSB)

	mutex.Lock()
	active := devices["shared"]
	tracked := usbDevices["shared"]
	mutex.Unlock()
	if oldInstance.stops != 1 || active != newUSB || tracked != newUSB {
		t.Fatalf("replacement did not retire old instance: stops=%d", oldInstance.stops)
	}
}
