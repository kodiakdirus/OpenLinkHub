package lighting

import (
	"context"
	"fmt"
	"strings"
	"sync"
)

const OperationChangeController = "change-controller"

type Controller string

const (
	ControllerIndividual Controller = "individual"
	ControllerRGBCluster Controller = "rgb-cluster"
	ControllerOpenRGB    Controller = "openrgb"
)

type OwnershipState struct {
	DeviceID              string
	Controller            Controller
	Operations            []string
	AffectedTargetCount   int
	SavedIndividualEffect string
}

type OwnershipSnapshot struct {
	Revision uint64
	States   []OwnershipState
}

type OwnershipInventoryReader interface {
	OwnershipSnapshot(context.Context) (OwnershipSnapshot, error)
}

type OwnershipTransition struct {
	DeviceID   string
	Controller Controller
}

type OwnershipSwitcher interface {
	SwitchController(context.Context, OwnershipTransition) error
}

type OwnershipCommand struct {
	ExpectedRevision    uint64
	DeviceID            string
	ExpectedController  Controller
	RequestedController Controller
}

type OwnershipResult struct {
	Status                Status
	Revision              uint64
	Changed               bool
	DeviceID              string
	PreviousController    Controller
	RequestedController   Controller
	ObservedController    Controller
	AffectedTargetCount   int
	SavedIndividualEffect string
	Recovery              Recovery
	Issue                 *Issue
}

type OwnershipService struct {
	mu        sync.Mutex
	locker    sync.Locker
	inventory OwnershipInventoryReader
	switcher  OwnershipSwitcher
}

func NewOwnershipService(inventory OwnershipInventoryReader, switcher OwnershipSwitcher) *OwnershipService {
	return &OwnershipService{inventory: inventory, switcher: switcher}
}

func NewOwnershipServiceWithLocker(inventory OwnershipInventoryReader, switcher OwnershipSwitcher, locker sync.Locker) *OwnershipService {
	return &OwnershipService{inventory: inventory, switcher: switcher, locker: locker}
}

// ChangeController models one whole-device lighting ownership transition. It
// is intentionally transport-neutral and remains fake-backed until a separate
// checkpoint connects a reviewed driver adapter and versioned route.
func (service *OwnershipService) ChangeController(ctx context.Context, command OwnershipCommand) OwnershipResult {
	command.DeviceID = strings.TrimSpace(command.DeviceID)
	result := OwnershipResult{
		Status:              StatusRejected,
		DeviceID:            command.DeviceID,
		RequestedController: command.RequestedController,
		Recovery:            RecoveryNotNeeded,
	}
	if command.ExpectedRevision == 0 {
		result.Issue = issue("expectedRevision", "required", "A positive state revision is required.")
		return result
	}
	if command.DeviceID == "" {
		result.Issue = issue("deviceId", "required", "Choose a published device.")
		return result
	}
	if !transitionController(command.ExpectedController) {
		result.Issue = issue("expectedController", "invalid", "Choose the controller published by the current ownership state.")
		return result
	}
	if !transitionController(command.RequestedController) {
		result.Issue = issue("requestedController", "invalid", "Choose Individual devices or RGB Cluster.")
		return result
	}
	if service == nil || service.inventory == nil || service.switcher == nil {
		result.Issue = issue("service", "unavailable", "The lighting ownership service is not configured.")
		return result
	}

	locker := service.locker
	if locker == nil {
		locker = &service.mu
	}
	locker.Lock()
	defer locker.Unlock()

	before, err := service.inventory.OwnershipSnapshot(ctx)
	if err != nil {
		result.Issue = issue("service", "inventory-unavailable", "Current lighting ownership could not be read.")
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
	state, found := findOwnershipState(before, command.DeviceID)
	if !found {
		result.Issue = issue("deviceId", "device-not-found", "Choose a device published by the current ownership inventory.")
		return result
	}
	result.PreviousController = state.Controller
	result.ObservedController = state.Controller
	result.AffectedTargetCount = state.AffectedTargetCount
	result.SavedIndividualEffect = state.SavedIndividualEffect
	if command.ExpectedController != state.Controller {
		result.Issue = issue("expectedController", "owner-changed", "The lighting controller changed; refresh and review the transition again.")
		return result
	}
	if command.RequestedController == state.Controller {
		result.Status = StatusSucceeded
		return result
	}
	if !contains(state.Operations, OperationChangeController) {
		result.Issue = issue("deviceId", "operation-unavailable", "This device does not publish a lighting-controller transition.")
		return result
	}

	transition := OwnershipTransition{DeviceID: command.DeviceID, Controller: command.RequestedController}
	applyErr := service.switcher.SwitchController(ctx, transition)
	after, readErr := service.inventory.OwnershipSnapshot(ctx)
	if readErr == nil {
		result.Revision = after.Revision
		if observed, ok := findOwnershipState(after, command.DeviceID); ok {
			result.ObservedController = observed.Controller
			if applyErr == nil && observed.Controller == command.RequestedController {
				result.Status = StatusSucceeded
				result.Changed = true
				return result
			}
			if observed.Controller == state.Controller {
				result.Status = StatusFailedRestored
				result.Recovery = RecoveryVerified
				result.Issue = ownershipFailureIssue(applyErr)
				return result
			}
		}
	}

	recoveryContext := context.WithoutCancel(ctx)
	_ = service.switcher.SwitchController(recoveryContext, OwnershipTransition{
		DeviceID: command.DeviceID, Controller: state.Controller,
	})
	restored, restoreReadErr := service.inventory.OwnershipSnapshot(recoveryContext)
	if restoreReadErr == nil {
		result.Revision = restored.Revision
		if observed, ok := findOwnershipState(restored, command.DeviceID); ok {
			result.ObservedController = observed.Controller
			if observed.Controller == state.Controller {
				result.Status = StatusFailedRestored
				result.Recovery = RecoveryVerified
				result.Issue = ownershipFailureIssue(applyErr)
				return result
			}
			result.Changed = observed.Controller != state.Controller
		}
	}

	result.Status = StatusFailedRestoreUnverified
	result.Recovery = RecoveryUnverified
	result.Issue = issue("requestedController", "recovery-unverified", "Neither the requested controller nor the previous controller could be verified.")
	return result
}

func transitionController(controller Controller) bool {
	return controller == ControllerIndividual || controller == ControllerRGBCluster
}

func findOwnershipState(snapshot OwnershipSnapshot, deviceID string) (OwnershipState, bool) {
	for _, state := range snapshot.States {
		if state.DeviceID == deviceID {
			return state, true
		}
	}
	return OwnershipState{}, false
}

func ownershipFailureIssue(err error) *Issue {
	if err != nil {
		return issue("requestedController", "driver-rejected", "The driver rejected the lighting-controller transition; the previous controller was verified.")
	}
	return issue("requestedController", "verification-failed", "The requested lighting controller could not be verified; the previous controller was restored.")
}
