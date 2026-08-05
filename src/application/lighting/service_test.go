package lighting

import (
	"context"
	"errors"
	"sync"
	"testing"
)

type fakeInventory struct {
	mu       sync.Mutex
	revision uint64
	target   Target
	err      error
}

func (inventory *fakeInventory) Snapshot(context.Context) (Snapshot, error) {
	inventory.mu.Lock()
	defer inventory.mu.Unlock()
	if inventory.err != nil {
		return Snapshot{}, inventory.err
	}
	target := inventory.target
	target.SupportedProfileIDs = append([]string(nil), target.SupportedProfileIDs...)
	target.Operations = append([]string(nil), target.Operations...)
	return Snapshot{Revision: inventory.revision, Targets: []Target{target}}, nil
}

func (inventory *fakeInventory) setProfile(profile string) {
	inventory.mu.Lock()
	defer inventory.mu.Unlock()
	if inventory.target.ActiveProfile != profile {
		inventory.target.ActiveProfile = profile
		inventory.revision++
	}
}

type fakeAssigner struct {
	calls []Assignment
	apply func(Assignment) error
}

func (assigner *fakeAssigner) AssignProfile(_ context.Context, assignment Assignment) error {
	assigner.calls = append(assigner.calls, assignment)
	if assigner.apply == nil {
		return nil
	}
	return assigner.apply(assignment)
}

func TestAssignProfileRejectsBeforeDispatch(t *testing.T) {
	tests := []struct {
		name    string
		command Command
		modify  func(*fakeInventory)
		code    string
	}{
		{name: "missing revision", command: Command{DeviceID: "hub", TargetID: "channel:7", ProfileID: "rainbow"}, code: "required"},
		{name: "stale revision", command: command(8, "rainbow"), code: "stale-revision"},
		{name: "unknown target", command: Command{ExpectedRevision: 7, DeviceID: "hub", TargetID: "channel:8", ProfileID: "rainbow"}, code: "target-not-found"},
		{name: "unpublished operation", command: command(7, "rainbow"), modify: func(inventory *fakeInventory) { inventory.target.Operations = []string{"read"} }, code: "operation-unavailable"},
		{name: "unsupported profile", command: command(7, "temperature"), code: "profile-not-supported"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			inventory := fixtureInventory()
			if test.modify != nil {
				test.modify(inventory)
			}
			assigner := &fakeAssigner{}
			result := NewService(inventory, assigner).AssignProfile(context.Background(), test.command)
			if result.Status != StatusRejected || result.Issue == nil || result.Issue.Code != test.code {
				t.Fatalf("unexpected result: %#v", result)
			}
			if len(assigner.calls) != 0 {
				t.Fatalf("rejected command dispatched %d times", len(assigner.calls))
			}
		})
	}
}

func TestAssignProfileNoOpDoesNotDispatch(t *testing.T) {
	inventory := fixtureInventory()
	assigner := &fakeAssigner{}
	result := NewService(inventory, assigner).AssignProfile(context.Background(), command(7, "static"))
	if result.Status != StatusSucceeded || result.Changed || result.Recovery != RecoveryNotNeeded {
		t.Fatalf("unexpected no-op result: %#v", result)
	}
	if len(assigner.calls) != 0 {
		t.Fatalf("no-op dispatched %d times", len(assigner.calls))
	}
}

func TestAssignProfileSucceedsOnlyAfterReadBack(t *testing.T) {
	inventory := fixtureInventory()
	assigner := &fakeAssigner{apply: func(assignment Assignment) error {
		inventory.setProfile(assignment.ProfileID)
		return nil
	}}
	result := NewService(inventory, assigner).AssignProfile(context.Background(), command(7, "rainbow"))
	if result.Status != StatusSucceeded || !result.Changed || result.Revision != 8 ||
		result.ObservedProfile != "rainbow" || result.Persistence != "unknown" {
		t.Fatalf("unexpected success result: %#v", result)
	}
	if len(assigner.calls) != 1 || assigner.calls[0].Scope != "channel" ||
		assigner.calls[0].ChannelID == nil || *assigner.calls[0].ChannelID != 7 {
		t.Fatalf("unexpected assignment: %#v", assigner.calls)
	}
}

func TestAssignProfileReportsRejectedDriverWithVerifiedPreviousState(t *testing.T) {
	inventory := fixtureInventory()
	assigner := &fakeAssigner{apply: func(Assignment) error { return errors.New("rejected") }}
	result := NewService(inventory, assigner).AssignProfile(context.Background(), command(7, "rainbow"))
	if result.Status != StatusFailedRestored || result.Recovery != RecoveryVerified ||
		result.ObservedProfile != "static" || result.Issue == nil || result.Issue.Code != "driver-rejected" {
		t.Fatalf("unexpected driver rejection: %#v", result)
	}
	if len(assigner.calls) != 1 {
		t.Fatalf("driver rejection dispatched %d times", len(assigner.calls))
	}
}

func TestAssignProfileRestoresAfterVerificationMismatch(t *testing.T) {
	inventory := fixtureInventory()
	assigner := &fakeAssigner{apply: func(assignment Assignment) error {
		if assignment.ProfileID == "rainbow" {
			inventory.setProfile("wrong-profile")
		} else {
			inventory.setProfile(assignment.ProfileID)
		}
		return nil
	}}
	result := NewService(inventory, assigner).AssignProfile(context.Background(), command(7, "rainbow"))
	if result.Status != StatusFailedRestored || result.Recovery != RecoveryVerified ||
		result.Changed || result.ObservedProfile != "static" || result.Revision != 9 ||
		result.Issue == nil || result.Issue.Code != "verification-failed" {
		t.Fatalf("unexpected recovery result: %#v", result)
	}
	if len(assigner.calls) != 2 || assigner.calls[1].ProfileID != "static" {
		t.Fatalf("unexpected recovery calls: %#v", assigner.calls)
	}
}

func TestAssignProfileNeverClaimsSuccessWhenRecoveryCannotVerify(t *testing.T) {
	inventory := fixtureInventory()
	assigner := &fakeAssigner{apply: func(Assignment) error {
		inventory.setProfile("wrong-profile")
		return nil
	}}
	result := NewService(inventory, assigner).AssignProfile(context.Background(), command(7, "rainbow"))
	if result.Status != StatusFailedRestoreUnverified || result.Recovery != RecoveryUnverified ||
		!result.Changed || result.ObservedProfile != "wrong-profile" ||
		result.Issue == nil || result.Issue.Code != "recovery-unverified" {
		t.Fatalf("unexpected unverified recovery result: %#v", result)
	}
	if len(assigner.calls) != 2 {
		t.Fatalf("unverified recovery dispatched %d times", len(assigner.calls))
	}
}

func fixtureInventory() *fakeInventory {
	channelID := 7
	return &fakeInventory{
		revision: 7,
		target: Target{
			DeviceID:            "hub",
			ID:                  "channel:7",
			Scope:               "channel",
			ChannelID:           &channelID,
			ActiveProfile:       "static",
			SupportedProfileIDs: []string{"static", "rainbow"},
			Operations:          []string{"read", OperationAssignProfile},
		},
	}
}

func command(revision uint64, profile string) Command {
	return Command{ExpectedRevision: revision, DeviceID: "hub", TargetID: "channel:7", ProfileID: profile}
}
