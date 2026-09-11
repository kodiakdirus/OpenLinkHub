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
	Recover(context.Context, uint64) error
	Identify(context.Context, uint64, string, time.Time) error
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
	shared  chan struct{}
	mu      sync.Mutex
	lease   *Lease
	timer   *time.Timer
	closed  bool
}

func NewRuntimeService(driver RuntimeDriver, timeout time.Duration) *RuntimeService {
	return &RuntimeService{driver: driver, timeout: timeout, slot: make(chan struct{}, 1)}
}

// NewRuntimeServiceWithGate shares admission with legacy/versioned lighting
// mutations. The gate is held until the driver actually finishes, not just
// until the HTTP caller times out.
func NewRuntimeServiceWithGate(driver RuntimeDriver, timeout time.Duration, gate chan struct{}) *RuntimeService {
	s := NewRuntimeService(driver, timeout)
	s.shared = gate
	return s
}

func (s *RuntimeService) acquire() bool {
	select {
	case s.slot <- struct{}{}:
	default:
		return false
	}
	if s.shared != nil {
		select {
		case s.shared <- struct{}{}:
		default:
			<-s.slot
			return false
		}
	}
	return true
}
func (s *RuntimeService) release() {
	if s.shared != nil {
		<-s.shared
	}
	<-s.slot
}

func (s *RuntimeService) State() RuntimeState {
	state := s.driver.State()
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		state.Operations = []string{}
	}
	if s.lease != nil {
		value := *s.lease
		state.Lease = &value
	}
	return state
}

func (s *RuntimeService) run(ctx context.Context, operation func(context.Context) RuntimeResult) RuntimeResult {
	if !s.acquire() {
		return RuntimeResult{Status: "busy", Message: "A lighting operation is still running; no overlapping command was started."}
	}
	ctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()
	result := make(chan RuntimeResult, 1)
	go func() {
		value := RuntimeResult{Status: "unverified", Message: "Lighting adapter failed; physical outcome is unverified."}
		defer func() {
			_ = recover()
			s.release()
			result <- value
		}()
		if ctx.Err() != nil {
			value = RuntimeResult{Status: "timeout", Message: "Lighting command expired before dispatch."}
			return
		}
		value = operation(ctx)
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
		if err := s.driver.Recover(ctx, command.ExpectedRevision); err != nil {
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
		// Install expiry before dispatch: panics and late replies must not
		// leave an active lease with no cleanup scheduled.
		s.mu.Lock()
		s.timer = time.AfterFunc(time.Until(lease.ExpiresAt), func() { s.expire(lease.ID) })
		s.mu.Unlock()
		applied := false
		defer func() {
			if !applied {
				cleanup, cancel := context.WithTimeout(context.Background(), s.timeout)
				defer cancel()
				_ = s.restore(cleanup, lease.ID)
			}
		}()
		if err := s.driver.Identify(ctx, command.ExpectedRevision, lease.DeviceID, lease.ExpiresAt); err != nil {
			return RuntimeResult{Status: "unverified", Message: err.Error()}
		}
		if ctx.Err() != nil || !time.Now().Before(lease.ExpiresAt) {
			return RuntimeResult{Status: "timeout", Message: "Identification finished after its deadline; the override is being removed."}
		}
		s.mu.Lock()
		closed := s.closed
		s.mu.Unlock()
		if closed {
			return RuntimeResult{Status: "unavailable", Message: "Lighting is shutting down; the override is being removed."}
		}
		applied = true
		return RuntimeResult{Status: "identifying", Message: "Identifying this device temporarily; the saved scene is unchanged.", State: s.State()}
	})
}

func (s *RuntimeService) restore(ctx context.Context, id string) (err error) {
	defer func() {
		if recover() != nil {
			err = errors.New("Identification restoration failed unexpectedly")
		}
		if err != nil {
			s.mu.Lock()
			if s.lease != nil && s.lease.ID == id {
				s.lease.Status = "restore-unverified"
			}
			s.mu.Unlock()
		}
	}()
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
	if s.shared != nil {
		s.shared <- struct{}{}
	}
	defer s.release()
	ctx, cancel := context.WithTimeout(context.Background(), s.timeout)
	defer cancel()
	_ = s.restore(ctx, id)
}

func (s *RuntimeService) Close(ctx context.Context) error {
	s.mu.Lock()
	s.closed = true
	s.mu.Unlock()
	ctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()
	select {
	case s.slot <- struct{}{}:
	case <-ctx.Done():
		return ctx.Err()
	}
	if s.shared != nil {
		select {
		case s.shared <- struct{}{}:
		case <-ctx.Done():
			<-s.slot
			return ctx.Err()
		}
	}
	done := make(chan error, 1)
	go func() {
		var err error
		defer func() { s.release(); done <- err }()
		s.mu.Lock()
		lease := s.lease
		s.mu.Unlock()
		if lease != nil {
			err = s.restore(ctx, lease.ID)
		}
	}()
	select {
	case err := <-done:
		return err
	case <-ctx.Done():
		return ctx.Err()
	}
}
