// Package lighting coordinates guarded lighting commands independently from
// HTTP and product-specific device implementations.
package lighting

import (
	"context"
	"fmt"
	"strings"
	"sync"
)

const OperationAssignProfile = "assign-profile"

type Status string

const (
	StatusSucceeded               Status = "succeeded"
	StatusRejected                Status = "rejected"
	StatusFailedRestored          Status = "failed-restored"
	StatusFailedRestoreUnverified Status = "failed-restore-unverified"
)

type Recovery string

const (
	RecoveryNotNeeded  Recovery = "not-needed"
	RecoveryVerified   Recovery = "verified"
	RecoveryUnverified Recovery = "unverified"
)

type Target struct {
	DeviceID            string
	ID                  string
	Scope               string
	ChannelID           *int
	ActiveProfile       string
	SupportedProfileIDs []string
	Operations          []string
}

type Snapshot struct {
	Revision uint64
	Targets  []Target
}

type InventoryReader interface {
	Snapshot(context.Context) (Snapshot, error)
}

type Assignment struct {
	DeviceID  string
	TargetID  string
	Scope     string
	ChannelID *int
	ProfileID string
}

type LightingAssigner interface {
	AssignProfile(context.Context, Assignment) error
}

type Command struct {
	ExpectedRevision uint64
	DeviceID         string
	TargetID         string
	ProfileID        string
}

type Issue struct {
	Field   string
	Code    string
	Message string
}

type Result struct {
	Status           Status
	Revision         uint64
	Changed          bool
	DeviceID         string
	TargetID         string
	PreviousProfile  string
	RequestedProfile string
	ObservedProfile  string
	Recovery         Recovery
	Persistence      string
	Issue            *Issue
}

type Service struct {
	mu        sync.Mutex
	locker    sync.Locker
	inventory InventoryReader
	assigner  LightingAssigner
}

func NewService(inventory InventoryReader, assigner LightingAssigner) *Service {
	return &Service{inventory: inventory, assigner: assigner}
}

// NewServiceWithLocker lets the transport serialize this transaction with
// other guarded mutations without coupling the application layer to HTTP.
func NewServiceWithLocker(inventory InventoryReader, assigner LightingAssigner, locker sync.Locker) *Service {
	return &Service{inventory: inventory, assigner: assigner, locker: locker}
}

// AssignProfile validates and executes one target-specific profile assignment.
// It is deliberately transport-neutral and serializes its complete
// read/dispatch/verify/recover transaction.
func (service *Service) AssignProfile(ctx context.Context, command Command) Result {
	command.DeviceID = strings.TrimSpace(command.DeviceID)
	command.TargetID = strings.TrimSpace(command.TargetID)
	command.ProfileID = strings.TrimSpace(command.ProfileID)
	result := Result{
		Status:           StatusRejected,
		DeviceID:         command.DeviceID,
		TargetID:         command.TargetID,
		RequestedProfile: command.ProfileID,
		Recovery:         RecoveryNotNeeded,
		Persistence:      "unknown",
	}
	if issue := validateCommand(command); issue != nil {
		result.Issue = issue
		return result
	}
	if service == nil || service.inventory == nil || service.assigner == nil {
		result.Issue = issue("service", "unavailable", "The lighting application service is not configured.")
		return result
	}

	locker := service.locker
	if locker == nil {
		locker = &service.mu
	}
	locker.Lock()
	defer locker.Unlock()

	before, err := service.inventory.Snapshot(ctx)
	if err != nil {
		result.Issue = issue("service", "inventory-unavailable", "Current lighting state could not be read.")
		return result
	}
	result.Revision = before.Revision
	if command.ExpectedRevision != before.Revision {
		result.Issue = issue(
			"expectedRevision",
			"stale-revision",
			fmt.Sprintf("Expected revision %d; current revision is %d.", command.ExpectedRevision, before.Revision),
		)
		return result
	}

	target, found := findTarget(before, command.DeviceID, command.TargetID)
	if !found || !wellFormedTarget(target) {
		result.Issue = issue("targetId", "target-not-found", "Choose a target published by the current lighting inventory.")
		return result
	}
	result.PreviousProfile = target.ActiveProfile
	result.ObservedProfile = target.ActiveProfile
	if !contains(target.Operations, OperationAssignProfile) {
		result.Issue = issue("targetId", "operation-unavailable", "This target does not publish profile assignment.")
		return result
	}
	if !contains(target.SupportedProfileIDs, command.ProfileID) {
		result.Issue = issue("profileId", "profile-not-supported", "Choose a profile published for this target.")
		return result
	}
	if target.ActiveProfile == command.ProfileID {
		result.Status = StatusSucceeded
		return result
	}

	assignment := assignmentFor(target, command.ProfileID)
	applyErr := service.assigner.AssignProfile(ctx, assignment)
	after, readErr := service.inventory.Snapshot(ctx)
	if readErr == nil {
		result.Revision = after.Revision
		if observed, ok := findTarget(after, command.DeviceID, command.TargetID); ok {
			result.ObservedProfile = observed.ActiveProfile
			if applyErr == nil && observed.ActiveProfile == command.ProfileID {
				result.Status = StatusSucceeded
				result.Changed = true
				return result
			}
			if observed.ActiveProfile == target.ActiveProfile {
				result.Status = StatusFailedRestored
				result.Recovery = RecoveryVerified
				result.Issue = assignmentFailureIssue(applyErr)
				return result
			}
		}
	}

	// Recovery is a service safety obligation and must still run if the caller's
	// request context was cancelled after dispatch.
	recoveryContext := context.WithoutCancel(ctx)
	_ = service.assigner.AssignProfile(recoveryContext, assignmentFor(target, target.ActiveProfile))
	restored, restoreReadErr := service.inventory.Snapshot(recoveryContext)
	if restoreReadErr == nil {
		result.Revision = restored.Revision
		if observed, ok := findTarget(restored, command.DeviceID, command.TargetID); ok {
			result.ObservedProfile = observed.ActiveProfile
			if observed.ActiveProfile == target.ActiveProfile {
				result.Status = StatusFailedRestored
				result.Changed = false
				result.Recovery = RecoveryVerified
				result.Issue = assignmentFailureIssue(applyErr)
				return result
			}
			result.Changed = observed.ActiveProfile != target.ActiveProfile
		}
	}

	result.Status = StatusFailedRestoreUnverified
	result.Recovery = RecoveryUnverified
	result.Issue = issue("profileId", "recovery-unverified", "Neither the requested profile nor the previous profile could be verified.")
	return result
}

func validateCommand(command Command) *Issue {
	if command.ExpectedRevision == 0 {
		return issue("expectedRevision", "required", "A positive state revision is required.")
	}
	if command.DeviceID == "" {
		return issue("deviceId", "required", "Choose a published device.")
	}
	if command.TargetID == "" {
		return issue("targetId", "required", "Choose a published lighting target.")
	}
	if command.ProfileID == "" {
		return issue("profileId", "required", "Choose a published lighting profile.")
	}
	return nil
}

func wellFormedTarget(target Target) bool {
	switch target.Scope {
	case "device":
		return target.ID == "device" && target.ChannelID == nil
	case "channel":
		return target.ChannelID != nil && target.ID == fmt.Sprintf("channel:%d", *target.ChannelID)
	default:
		return false
	}
}

func assignmentFor(target Target, profileID string) Assignment {
	var channelID *int
	if target.ChannelID != nil {
		value := *target.ChannelID
		channelID = &value
	}
	return Assignment{
		DeviceID:  target.DeviceID,
		TargetID:  target.ID,
		Scope:     target.Scope,
		ChannelID: channelID,
		ProfileID: profileID,
	}
}

func findTarget(snapshot Snapshot, deviceID, targetID string) (Target, bool) {
	for _, target := range snapshot.Targets {
		if target.DeviceID == deviceID && target.ID == targetID {
			return target, true
		}
	}
	return Target{}, false
}

func contains(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}

func issue(field, code, message string) *Issue {
	return &Issue{Field: field, Code: code, Message: message}
}

func assignmentFailureIssue(applyErr error) *Issue {
	if applyErr != nil {
		return issue("targetId", "driver-rejected", "The device adapter rejected the requested assignment; the previous profile is verified.")
	}
	return issue("profileId", "verification-failed", "The requested profile did not verify; the previous profile is verified.")
}
