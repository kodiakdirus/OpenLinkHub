package server

import (
	"OpenLinkHub/src/application/lighting"
	"OpenLinkHub/src/server/contractv1"
	"context"
	"reflect"
	"testing"
)

func TestContractV1LightingInventoryAdapterCopiesReadOnlyTargets(t *testing.T) {
	channelID := 7
	adapter := newContractV1LightingInventoryAdapter(func(context.Context) (contractv1.Snapshot, uint64, error) {
		return contractv1.Snapshot{Devices: []contractv1.DeviceState{{
			ID: "hub",
			Lighting: &contractv1.LightingCatalog{Targets: []contractv1.LightingTarget{{
				ID: "channel:7", Scope: "channel", ChannelID: &channelID,
				ActiveProfile: "static", SupportedProfileIDs: []string{"static", "rainbow"},
				Operations: []string{"read"}, Identifiable: false,
			}}},
		}}}, 12, nil
	})

	snapshot, err := adapter.Snapshot(context.Background())
	if err != nil || snapshot.Revision != 12 || len(snapshot.Targets) != 1 {
		t.Fatalf("unexpected inventory: %#v %v", snapshot, err)
	}
	target := snapshot.Targets[0]
	if target.DeviceID != "hub" || target.ID != "channel:7" || target.ChannelID == nil ||
		*target.ChannelID != 7 || len(target.Operations) != 1 || target.Operations[0] != "read" {
		t.Fatalf("unexpected target: %#v", target)
	}
	if containsString(target.Operations, lighting.OperationAssignProfile) {
		t.Fatalf("inactive adapter published assignment: %#v", target)
	}
}

func TestLegacyLightingAssignerAdapterContainsReflectionBoundary(t *testing.T) {
	channelID := 7
	called := false
	adapter := newLegacyLightingAssignerAdapter(func(deviceID, method string, args ...interface{}) []reflect.Value {
		called = true
		if deviceID != "hub" || method != "UpdateRgbProfile" || len(args) != 2 ||
			args[0] != 7 || args[1] != "rainbow" {
			t.Fatalf("unexpected dispatch: %q %q %#v", deviceID, method, args)
		}
		return []reflect.Value{reflect.ValueOf(uint8(1))}
	})
	err := adapter.AssignProfile(context.Background(), lighting.Assignment{
		DeviceID: "hub", TargetID: "channel:7", Scope: "channel",
		ChannelID: &channelID, ProfileID: "rainbow",
	})
	if err != nil || !called {
		t.Fatalf("assignment = %v, called = %v", err, called)
	}
}

func TestLegacyLightingAssignerAdapterFailsClosed(t *testing.T) {
	tests := []struct {
		name     string
		dispatch func(string, string, ...interface{}) []reflect.Value
	}{
		{name: "missing result", dispatch: func(string, string, ...interface{}) []reflect.Value { return nil }},
		{name: "rejected result", dispatch: func(string, string, ...interface{}) []reflect.Value {
			return []reflect.Value{reflect.ValueOf(uint8(0))}
		}},
		{name: "invalid result", dispatch: func(string, string, ...interface{}) []reflect.Value { return []reflect.Value{reflect.ValueOf("yes")} }},
		{name: "panic", dispatch: func(string, string, ...interface{}) []reflect.Value { panic("driver") }},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			adapter := newLegacyLightingAssignerAdapter(test.dispatch)
			err := adapter.AssignProfile(context.Background(), lighting.Assignment{
				DeviceID: "keyboard", TargetID: "device", Scope: "device", ProfileID: "static",
			})
			if err == nil {
				t.Fatal("unsafe legacy result was accepted")
			}
		})
	}
}

func containsString(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}
