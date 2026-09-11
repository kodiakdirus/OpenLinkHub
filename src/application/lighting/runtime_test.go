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
func (f *fakeRuntime) Recover(ctx context.Context) error {
	if f.block != nil {
		<-f.block
	}
	return nil
}
func (f *fakeRuntime) Identify(ctx context.Context, id string, until time.Time) error {
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
