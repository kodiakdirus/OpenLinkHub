package lighting

import (
	"context"
	"errors"
	"sync"
	"testing"
)

type ownershipFakeInventory struct {
	mu       sync.Mutex
	revision uint64
	state    OwnershipState
	err      error
}

func (inventory *ownershipFakeInventory) OwnershipSnapshot(context.Context) (OwnershipSnapshot, error) {
	inventory.mu.Lock()
	defer inventory.mu.Unlock()
	if inventory.err != nil {
		return OwnershipSnapshot{}, inventory.err
	}
	state := inventory.state
	state.Operations = append([]string(nil), state.Operations...)
	return OwnershipSnapshot{Revision: inventory.revision, States: []OwnershipState{state}}, nil
}

func (inventory *ownershipFakeInventory) setController(controller Controller) {
	inventory.mu.Lock()
	defer inventory.mu.Unlock()
	if inventory.state.Controller != controller {
		inventory.state.Controller = controller
		inventory.revision++
	}
}

type ownershipFakeSwitcher struct {
	calls []OwnershipTransition
	apply func(OwnershipTransition) error
}

func (switcher *ownershipFakeSwitcher) SwitchController(_ context.Context, transition OwnershipTransition) error {
	switcher.calls = append(switcher.calls, transition)
	if switcher.apply == nil {
		return nil
	}
	return switcher.apply(transition)
}

func TestChangeControllerRejectsBeforeDispatch(t *testing.T) {
	tests := []struct {
		name    string
		command OwnershipCommand
		modify  func(*ownershipFakeInventory)
		code    string
	}{
		{name: "missing revision", command: ownershipCommand(0, ControllerIndividual, ControllerRGBCluster), code: "required"},
		{name: "stale revision", command: ownershipCommand(6, ControllerIndividual, ControllerRGBCluster), code: "stale-revision"},
		{name: "unknown device", command: OwnershipCommand{ExpectedRevision: 7, DeviceID: "unknown", ExpectedController: ControllerIndividual, RequestedController: ControllerRGBCluster}, code: "device-not-found"},
		{name: "owner changed", command: ownershipCommand(7, ControllerRGBCluster, ControllerIndividual), code: "owner-changed"},
		{name: "unpublished operation", command: ownershipCommand(7, ControllerIndividual, ControllerRGBCluster), modify: func(inventory *ownershipFakeInventory) { inventory.state.Operations = []string{"read"} }, code: "operation-unavailable"},
		{name: "invalid expected controller", command: ownershipCommand(7, ControllerOpenRGB, ControllerIndividual), code: "invalid"},
		{name: "invalid requested controller", command: ownershipCommand(7, ControllerIndividual, ControllerOpenRGB), code: "invalid"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			inventory := ownershipFixtureInventory()
			if test.modify != nil {
				test.modify(inventory)
			}
			switcher := &ownershipFakeSwitcher{}
			result := NewOwnershipService(inventory, switcher).ChangeController(context.Background(), test.command)
			if result.Status != StatusRejected || result.Issue == nil || result.Issue.Code != test.code {
				t.Fatalf("unexpected result: %#v", result)
			}
			if len(switcher.calls) != 0 {
				t.Fatalf("rejected command dispatched %d times", len(switcher.calls))
			}
		})
	}
}

func TestChangeControllerNoOpDoesNotDispatch(t *testing.T) {
	inventory := ownershipFixtureInventory()
	switcher := &ownershipFakeSwitcher{}
	result := NewOwnershipService(inventory, switcher).ChangeController(
		context.Background(), ownershipCommand(7, ControllerIndividual, ControllerIndividual),
	)
	if result.Status != StatusSucceeded || result.Changed || result.Recovery != RecoveryNotNeeded {
		t.Fatalf("unexpected no-op result: %#v", result)
	}
	if len(switcher.calls) != 0 {
		t.Fatalf("no-op dispatched %d times", len(switcher.calls))
	}
}

func TestChangeControllerSucceedsOnlyAfterReadBack(t *testing.T) {
	inventory := ownershipFixtureInventory()
	switcher := &ownershipFakeSwitcher{apply: func(transition OwnershipTransition) error {
		inventory.setController(transition.Controller)
		return nil
	}}
	result := NewOwnershipService(inventory, switcher).ChangeController(
		context.Background(), ownershipCommand(7, ControllerIndividual, ControllerRGBCluster),
	)
	if result.Status != StatusSucceeded || !result.Changed || result.Revision != 8 ||
		result.ObservedController != ControllerRGBCluster || result.AffectedTargetCount != 7 ||
		result.SavedIndividualEffect != "Off on 7 targets" {
		t.Fatalf("unexpected success result: %#v", result)
	}
	if len(switcher.calls) != 1 || switcher.calls[0].DeviceID != "hub" ||
		switcher.calls[0].Controller != ControllerRGBCluster {
		t.Fatalf("unexpected transition: %#v", switcher.calls)
	}
}

func TestChangeControllerReportsRejectedDriverWithVerifiedPreviousState(t *testing.T) {
	inventory := ownershipFixtureInventory()
	switcher := &ownershipFakeSwitcher{apply: func(OwnershipTransition) error { return errors.New("rejected") }}
	result := NewOwnershipService(inventory, switcher).ChangeController(
		context.Background(), ownershipCommand(7, ControllerIndividual, ControllerRGBCluster),
	)
	if result.Status != StatusFailedRestored || result.Recovery != RecoveryVerified ||
		result.ObservedController != ControllerIndividual || result.Issue == nil ||
		result.Issue.Code != "driver-rejected" {
		t.Fatalf("unexpected driver rejection: %#v", result)
	}
	if len(switcher.calls) != 1 {
		t.Fatalf("driver rejection dispatched %d times", len(switcher.calls))
	}
}

func TestChangeControllerRestoresAfterVerificationMismatch(t *testing.T) {
	inventory := ownershipFixtureInventory()
	switcher := &ownershipFakeSwitcher{apply: func(transition OwnershipTransition) error {
		if transition.Controller == ControllerRGBCluster {
			inventory.setController(ControllerOpenRGB)
		} else {
			inventory.setController(transition.Controller)
		}
		return nil
	}}
	result := NewOwnershipService(inventory, switcher).ChangeController(
		context.Background(), ownershipCommand(7, ControllerIndividual, ControllerRGBCluster),
	)
	if result.Status != StatusFailedRestored || result.Recovery != RecoveryVerified || result.Changed ||
		result.ObservedController != ControllerIndividual || result.Revision != 9 ||
		result.Issue == nil || result.Issue.Code != "verification-failed" {
		t.Fatalf("unexpected recovery result: %#v", result)
	}
	if len(switcher.calls) != 2 || switcher.calls[1].Controller != ControllerIndividual {
		t.Fatalf("unexpected recovery calls: %#v", switcher.calls)
	}
}

func TestChangeControllerNeverClaimsSuccessWhenRecoveryCannotVerify(t *testing.T) {
	inventory := ownershipFixtureInventory()
	switcher := &ownershipFakeSwitcher{apply: func(OwnershipTransition) error {
		inventory.setController(ControllerOpenRGB)
		return nil
	}}
	result := NewOwnershipService(inventory, switcher).ChangeController(
		context.Background(), ownershipCommand(7, ControllerIndividual, ControllerRGBCluster),
	)
	if result.Status != StatusFailedRestoreUnverified || result.Recovery != RecoveryUnverified ||
		!result.Changed || result.ObservedController != ControllerOpenRGB ||
		result.Issue == nil || result.Issue.Code != "recovery-unverified" {
		t.Fatalf("unexpected unverified recovery result: %#v", result)
	}
	if len(switcher.calls) != 2 {
		t.Fatalf("unverified recovery dispatched %d times", len(switcher.calls))
	}
}

func ownershipFixtureInventory() *ownershipFakeInventory {
	return &ownershipFakeInventory{
		revision: 7,
		state: OwnershipState{
			DeviceID:              "hub",
			Controller:            ControllerIndividual,
			Operations:            []string{"read", OperationChangeController},
			AffectedTargetCount:   7,
			SavedIndividualEffect: "Off on 7 targets",
		},
	}
}

func ownershipCommand(revision uint64, expected, requested Controller) OwnershipCommand {
	return OwnershipCommand{
		ExpectedRevision: revision, DeviceID: "hub", ExpectedController: expected, RequestedController: requested,
	}
}
