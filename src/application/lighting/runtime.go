package lighting

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"sync"
	"time"
)

// RuntimeState describes observations, never inferring physical mode from saved
// ownership or successful writes. Revision covers the saved effect and members.
type RuntimeState struct {
	Revision   uint64   `json:"revision"`
	Mode       string   `json:"mode"`
	Renderer   string   `json:"renderer"`
	Profile    string   `json:"profile"`
	Members    []string `json:"members"`
	Operations []string `json:"operations"`
	Lease      *Lease   `json:"lease,omitempty"`
}

type Lease struct {
	ID        string    `json:"id"`
	DeviceID  string    `json:"deviceId"`
	ExpiresAt time.Time `json:"expiresAt"`
	Status    string    `json:"status"`
}

// RuntimeDriver implementations must not save profiles or alter ownership or
// cooling. Identify must enforce expiry in the output path, independent of HTTP.
// Restore must remove the overlay and read back its removal.
type RuntimeDriver interface {
	State() RuntimeState
	Recover(context.Context) error
	Identify(context.Context, string, time.Time) error
	Restore(context.Context, string) error
}

type RuntimeCommand struct {
	ExpectedRevision uint64 `json:"expectedRevision"`
	DeviceID         string `json:"deviceId,omitempty"`
	DurationMS       int    `json:"durationMs,omitempty"`
	LeaseID          string `json:"leaseId,omitempty"`
}

type RuntimeResult struct {
	Status  string       `json:"status"`
	Message string       `json:"message"`
	State   RuntimeState `json:"state"`
}

// RuntimeService permits one in-flight operation. A timeout does not cancel an
// uncooperative driver: the slot stays occupied until it actually returns.
type RuntimeService struct {
	driver  RuntimeDriver
	timeout time.Duration
	slot    chan struct{}
	mu      sync.Mutex
	lease   *Lease
	timer   *time.Timer
	closed  bool
}

func NewRuntimeService(driver RuntimeDriver, timeout time.Duration) *RuntimeService {
	return &RuntimeService{driver: driver, timeout: timeout, slot: make(chan struct{}, 1)}
}

func (s *RuntimeService) State() RuntimeState {
	state := s.driver.State()
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.lease != nil {
		value := *s.lease
		state.Lease = &value
	}
	return state
}

func (s *RuntimeService) run(ctx context.Context, operation func(context.Context) RuntimeResult) RuntimeResult {
	select {
	case s.slot <- struct{}{}:
	default:
		return RuntimeResult{Status: "busy", Message: "A lighting operation is still running; no overlapping command was started."}
	}
	ctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()
	result := make(chan RuntimeResult, 1)
	go func() {
		defer func() {
			if recover() != nil {
				result <- RuntimeResult{Status: "unverified", Message: "Lighting adapter failed; physical outcome is unverified."}
			}
		}()
		defer func() { <-s.slot }()
		if ctx.Err() != nil {
			result <- RuntimeResult{Status: "timeout", Message: "Lighting command expired before dispatch."}
			return
		}
		result <- operation(ctx)
	}()
	select {
	case value := <-result:
		return value
	case <-ctx.Done():
		return RuntimeResult{Status: "timeout", Message: "Lighting operation timed out. Its outcome is unverified; an unfinished driver retains the operation lock."}
	}
}

func (s *RuntimeService) validate(command RuntimeCommand, operation string) RuntimeResult {
	state := s.State()
	s.mu.Lock()
	closed := s.closed
	s.mu.Unlock()
	if closed {
		return RuntimeResult{Status: "unavailable", Message: "Lighting is shutting down.", State: state}
	}
	if command.ExpectedRevision == 0 || command.ExpectedRevision != state.Revision {
		return RuntimeResult{Status: "stale-revision", Message: "Refresh lighting state before trying again.", State: state}
	}
	if !contains(state.Operations, operation) {
		return RuntimeResult{Status: "unsupported", Message: "This runtime does not support the requested operation.", State: state}
	}
	return RuntimeResult{State: state}
}

func (s *RuntimeService) Recover(ctx context.Context, command RuntimeCommand) RuntimeResult {
	return s.run(ctx, func(ctx context.Context) RuntimeResult {
		result := s.validate(command, "recover")
		if result.Status != "" {
			return result
		}
		if result.State.Lease != nil {
			return RuntimeResult{Status: "busy", Message: "End identification before recovering the synchronized renderer."}
		}
		if err := s.driver.Recover(ctx); err != nil {
			return RuntimeResult{Status: "unverified", Message: err.Error(), State: s.State()}
		}
		state := s.State()
		if state.Revision != command.ExpectedRevision || state.Renderer != "running" {
			return RuntimeResult{Status: "unverified", Message: "The saved scene or renderer did not verify after recovery.", State: state}
		}
		return RuntimeResult{Status: "effect-restarted", Message: "Saved scene restarted. Physical lighting mode remains unknown where the device has no mode read-back.", State: state}
	})
}

func (s *RuntimeService) Identify(ctx context.Context, command RuntimeCommand) RuntimeResult {
	return s.run(ctx, func(ctx context.Context) RuntimeResult {
		result := s.validate(command, "identify")
		if result.Status != "" {
			return result
		}
		if command.DurationMS < 1000 || command.DurationMS > 5000 || !contains(result.State.Members, command.DeviceID) {
			return RuntimeResult{Status: "invalid", Message: "Choose a published whole device and a duration from 1000 to 5000 ms."}
		}
		s.mu.Lock()
		lease := s.lease
		s.mu.Unlock()
		if lease != nil {
			if command.LeaseID != lease.ID {
				return RuntimeResult{Status: "busy", Message: "Another identification lease owns this renderer."}
			}
			if err := s.restore(ctx, lease.ID); err != nil {
				return RuntimeResult{Status: "unverified", Message: err.Error()}
			}
		} else if command.LeaseID != "" {
			return RuntimeResult{Status: "invalid", Message: "The identification lease has expired; start a new lease."}
		}
		token := make([]byte, 16)
		if _, err := rand.Read(token); err != nil {
			return RuntimeResult{Status: "unavailable", Message: "Unable to create an identification lease."}
		}
		lease = &Lease{ID: hex.EncodeToString(token), DeviceID: command.DeviceID, ExpiresAt: time.Now().Add(time.Duration(command.DurationMS) * time.Millisecond), Status: "active"}
		s.mu.Lock()
		s.lease = lease
		s.mu.Unlock()
		if err := s.driver.Identify(ctx, lease.DeviceID, lease.ExpiresAt); err != nil {
			cleanup, cancel := context.WithTimeout(context.WithoutCancel(ctx), s.timeout)
			defer cancel()
			_ = s.restore(cleanup, lease.ID)
			return RuntimeResult{Status: "unverified", Message: err.Error(), State: s.State()}
		}
		s.mu.Lock()
		s.timer = time.AfterFunc(time.Until(lease.ExpiresAt), func() { s.expire(lease.ID) })
		s.mu.Unlock()
		return RuntimeResult{Status: "identifying", Message: "Identifying this device temporarily; the saved scene is unchanged.", State: s.State()}
	})
}

func (s *RuntimeService) restore(ctx context.Context, id string) error {
	s.mu.Lock()
	lease := s.lease
	if lease == nil || lease.ID != id {
		s.mu.Unlock()
		return nil
	}
	lease.Status = "restoring"
	if s.timer != nil {
		s.timer.Stop()
	}
	deviceID := lease.DeviceID
	s.mu.Unlock()
	if err := s.driver.Restore(ctx, deviceID); err != nil {
		s.mu.Lock()
		if s.lease != nil && s.lease.ID == id {
			s.lease.Status = "restore-unverified"
		}
		s.mu.Unlock()
		return err
	}
	s.mu.Lock()
	if s.lease != nil && s.lease.ID == id {
		s.lease = nil
	}
	s.mu.Unlock()
	return nil
}

func (s *RuntimeService) Cancel(ctx context.Context, id string) RuntimeResult {
	if id == "" {
		return RuntimeResult{Status: "invalid", Message: "A matching lease ID is required."}
	}
	return s.run(ctx, func(ctx context.Context) RuntimeResult {
		s.mu.Lock()
		lease := s.lease
		mismatch := lease != nil && lease.ID != id
		s.mu.Unlock()
		if mismatch {
			return RuntimeResult{Status: "busy", Message: "The lease ID does not match the active identification."}
		}
		if err := s.restore(ctx, id); err != nil {
			return RuntimeResult{Status: "unverified", Message: err.Error(), State: s.State()}
		}
		return RuntimeResult{Status: "restored", Message: "Temporary override removed. The next successful frame uses the saved scene; physical output is not verified.", State: s.State()}
	})
}

func (s *RuntimeService) expire(id string) {
	// Wait for the actual operation to finish, not just its HTTP deadline. The
	// driver also enforces expiry at frame generation, so no queued renewal can
	// extend an expired override while this cleanup waits.
	s.slot <- struct{}{}
	defer func() { <-s.slot }()
	ctx, cancel := context.WithTimeout(context.Background(), s.timeout)
	defer cancel()
	_ = s.restore(ctx, id)
}

func (s *RuntimeService) Close(ctx context.Context) error {
	s.mu.Lock()
	s.closed = true
	lease := s.lease
	s.mu.Unlock()
	if lease == nil {
		return nil
	}
	result := s.Cancel(ctx, lease.ID)
	if result.Status != "restored" {
		return errors.New(result.Message)
	}
	return nil
}
