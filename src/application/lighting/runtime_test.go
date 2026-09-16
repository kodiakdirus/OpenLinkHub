package lighting

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

type fakeRuntime struct {
	mu          sync.Mutex
	overlay     string
	until       time.Time
	block       chan struct{}
	restoreFail bool
}

func (f *fakeRuntime) State() RuntimeState {
	return RuntimeState{Revision: 7, Mode: "unknown", Renderer: "running", Profile: "nebula", Members: []string{"hub", "keyboard"}, Operations: []string{"recover", "identify"}}
}
func (f *fakeRuntime) Recover(ctx context.Context, revision uint64) error {
	if f.block != nil {
		<-f.block
	}
	return nil
}
func (f *fakeRuntime) Identify(ctx context.Context, revision uint64, id string, until time.Time) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.overlay, f.until = id, until
	return nil
}
func (f *fakeRuntime) Restore(ctx context.Context, id string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.restoreFail {
		return errors.New("restore failed")
	}
	f.overlay = ""
	return nil
}

func TestRuntimeLeaseExpiryRestoresWithoutClient(t *testing.T) {
	f := &fakeRuntime{}
	service := NewRuntimeService(f, time.Second)
	result := service.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 7, DeviceID: "hub", DurationMS: 1000})
	if result.Status != "identifying" || result.State.Lease == nil {
		t.Fatalf("%+v", result)
	}
	deadline := time.After(2 * time.Second)
	for service.State().Lease != nil {
		select {
		case <-deadline:
			t.Fatal("lease never restored")
		case <-time.After(10 * time.Millisecond):
		}
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.overlay != "" {
		t.Fatal("overlay still active")
	}
	if service.State().Revision != 7 {
		t.Fatal("identification changed configuration")
	}
}

func TestRuntimeLeaseReplacementCancellationAndValidation(t *testing.T) {
	f := &fakeRuntime{}
	s := NewRuntimeService(f, time.Second)
	first := s.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 7, DeviceID: "hub", DurationMS: 5000})
	id := first.State.Lease.ID
	if got := s.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 7, DeviceID: "keyboard", DurationMS: 1000}); got.Status != "busy" {
		t.Fatal(got)
	}
	if got := s.Cancel(context.Background(), "wrong"); got.Status != "busy" {
		t.Fatal(got)
	}
	next := s.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 7, DeviceID: "keyboard", DurationMS: 1000, LeaseID: id})
	if next.Status != "identifying" {
		t.Fatal(next)
	}
	if got := s.Cancel(context.Background(), next.State.Lease.ID); got.Status != "restored" {
		t.Fatal(got)
	}
	if got := s.Cancel(context.Background(), next.State.Lease.ID); got.Status != "restored" {
		t.Fatal("cancel not idempotent", got)
	}
	if got := s.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 6, DeviceID: "hub", DurationMS: 1000}); got.Status != "stale-revision" {
		t.Fatal(got)
	}
	if got := s.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 7, DeviceID: "hub", DurationMS: 9000}); got.Status != "invalid" {
		t.Fatal(got)
	}
}

func TestRuntimeTimeoutRetainsWriterAndDoesNotClaimMeasuredMode(t *testing.T) {
	f := &fakeRuntime{block: make(chan struct{})}
	defer close(f.block)
	s := NewRuntimeService(f, 10*time.Millisecond)
	if result := s.Recover(context.Background(), RuntimeCommand{ExpectedRevision: 7}); result.Status != "timeout" {
		t.Fatal(result)
	}
	if result := s.Recover(context.Background(), RuntimeCommand{ExpectedRevision: 7}); result.Status != "busy" {
		t.Fatal(result)
	}
	if s.State().Mode != "unknown" {
		t.Fatal("inferred physical mode")
	}
}

func TestRuntimeFailedRestorationRetainsLease(t *testing.T) {
	f := &fakeRuntime{restoreFail: true}
	s := NewRuntimeService(f, time.Second)
	result := s.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 7, DeviceID: "hub", DurationMS: 1000})
	if result = s.Cancel(context.Background(), result.State.Lease.ID); result.Status != "unverified" {
		t.Fatal(result)
	}
	if s.State().Lease.Status != "restore-unverified" {
		t.Fatal("failed restoration hidden")
	}
	f.mu.Lock()
	f.restoreFail = false
	f.mu.Unlock()
	if err := s.Close(context.Background()); err != nil {
		t.Fatal(err)
	}
	if result = s.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 7, DeviceID: "hub", DurationMS: 1000}); result.Status != "unavailable" {
		t.Fatal(result)
	}
}

func TestRuntimeRetainsSharedMutationGateAfterTimeout(t *testing.T) {
	f := &fakeRuntime{block: make(chan struct{})}
	gate := make(chan struct{}, 1)
	s := NewRuntimeServiceWithGate(f, 10*time.Millisecond, gate)
	if got := s.Recover(context.Background(), RuntimeCommand{ExpectedRevision: 7}); got.Status != "timeout" {
		t.Fatal(got)
	}
	select {
	case gate <- struct{}{}:
		t.Fatal("legacy writer could overlap timed-out runtime operation")
	default:
	}
	close(f.block)
	deadline := time.After(time.Second)
	for len(gate) != 0 {
		select {
		case <-deadline:
			t.Fatal("gate never released")
		case <-time.After(time.Millisecond):
		}
	}
}

type lateRuntime struct {
	fakeRuntime
	entered       chan struct{}
	release       chan struct{}
	panicIdentify bool
}

func (f *lateRuntime) Identify(ctx context.Context, revision uint64, id string, expiry time.Time) error {
	if f.panicIdentify {
		panic("fake identify failure")
	}
	close(f.entered)
	<-f.release
	return f.fakeRuntime.Identify(ctx, revision, id, expiry)
}

func TestLateIdentificationRestoresBeforeReleasingOperation(t *testing.T) {
	f := &lateRuntime{entered: make(chan struct{}), release: make(chan struct{})}
	s := NewRuntimeService(f, 10*time.Millisecond)
	result := s.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 7, DeviceID: "hub", DurationMS: 1000})
	if result.Status != "timeout" {
		t.Fatal(result)
	}
	<-f.entered
	if got := s.Cancel(context.Background(), s.State().Lease.ID); got.Status != "busy" {
		t.Fatal(got)
	}
	close(f.release)
	deadline := time.After(time.Second)
	for s.State().Lease != nil {
		select {
		case <-deadline:
			t.Fatal("late identify lease leaked")
		case <-time.After(time.Millisecond):
		}
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.overlay != "" {
		t.Fatal("late identify overlay survived cleanup")
	}
}

func TestPanickingIdentifyStillRestoresLease(t *testing.T) {
	f := &lateRuntime{panicIdentify: true}
	s := NewRuntimeService(f, time.Second)
	if got := s.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 7, DeviceID: "hub", DurationMS: 1000}); got.Status != "unverified" {
		t.Fatal(got)
	}
	if s.State().Lease != nil {
		t.Fatal("panic left active lease")
	}
}

type blockedRestore struct {
	fakeRuntime
	release chan struct{}
}

func (f *blockedRestore) Restore(ctx context.Context, id string) error {
	<-f.release
	return f.fakeRuntime.Restore(ctx, id)
}
func TestCloseDeadlineDoesNotReleaseBlockedRestoration(t *testing.T) {
	f := &blockedRestore{release: make(chan struct{})}
	s := NewRuntimeService(f, 10*time.Millisecond)
	_ = s.Identify(context.Background(), RuntimeCommand{ExpectedRevision: 7, DeviceID: "hub", DurationMS: 1000})
	if err := s.Close(context.Background()); err == nil {
		t.Fatal("blocked restoration reported closed")
	}
	if len(s.State().Operations) != 0 {
		t.Fatal("shutdown still advertises operations")
	}
	if got := s.Recover(context.Background(), RuntimeCommand{ExpectedRevision: 7}); got.Status != "busy" {
		t.Fatal(got)
	}
	close(f.release)
}
