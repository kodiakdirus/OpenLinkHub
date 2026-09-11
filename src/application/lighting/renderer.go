package lighting

import (
	"context"
	"sync"
	"time"
)

// Renderer owns exactly one generation. Cancellation signals never require a
// receiver; replacement waits for actual completion, including blocked writers.
type Renderer struct {
	mu        sync.Mutex
	cancel    context.CancelFunc
	done      chan struct{}
	lastFrame time.Time
}

func (r *Renderer) Start(run func(context.Context)) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.done != nil {
		select {
		case <-r.done:
		default:
			return false
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	r.cancel, r.done, r.lastFrame = cancel, done, time.Time{}
	go func() { defer close(done); run(ctx) }()
	return true
}

func (r *Renderer) Stop(ctx context.Context) error {
	r.mu.Lock()
	cancel, done := r.cancel, r.done
	r.mu.Unlock()
	if cancel == nil {
		return nil
	}
	cancel()
	select {
	case <-done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (r *Renderer) Frame() { r.mu.Lock(); r.lastFrame = time.Now(); r.mu.Unlock() }
func (r *Renderer) State() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.done == nil {
		return "stopped"
	}
	select {
	case <-r.done:
		return "stopped"
	default:
	}
	if r.lastFrame.IsZero() || time.Since(r.lastFrame) > time.Second {
		return "stalled"
	}
	return "running"
}
