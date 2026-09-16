package cluster

import (
	"OpenLinkHub/src/application/lighting"
	"context"
	"encoding/json"
	"errors"
	"hash/fnv"
	"sort"
	"time"
)

// RuntimeAdapter deliberately describes renderer observations separately from
// physical hardware mode. Existing family protocols expose no reviewed mode read.
type RuntimeAdapter struct{}

func (RuntimeAdapter) State() lighting.RuntimeState {
	if Get() == nil {
		return lighting.RuntimeState{Mode: "unknown", Renderer: "unavailable", Members: []string{}, Operations: []string{}}
	}
	return Get().runtimeState()
}
func (RuntimeAdapter) Recover(ctx context.Context, revision uint64) error {
	if Get() == nil {
		return errors.New("Cluster is unavailable")
	}
	return Get().recoverRenderer(ctx, revision)
}
func (RuntimeAdapter) Identify(ctx context.Context, revision uint64, serial string, expiry time.Time) error {
	if Get() == nil {
		return errors.New("Cluster is unavailable")
	}
	d := Get()
	if !d.lifecycle.TryLock() {
		return errors.New("A scene or membership change is still running")
	}
	defer d.lifecycle.Unlock()
	if d.runtimeState().Revision != revision {
		return errors.New("Lighting catalog changed before dispatch; refresh before retrying")
	}
	found := false
	for _, member := range d.runtimeState().Members {
		if member == serial {
			found = true
			break
		}
	}
	if !found || d.stopping.Load() {
		return errors.New("The selected Cluster member is no longer available")
	}
	if d.renderer.State() != "running" {
		return errors.New("Recover the renderer before identification")
	}
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if !time.Now().Before(expiry) {
		return errors.New("Identification lease has expired")
	}
	d.overlayMu.Lock()
	d.overlayDevice, d.overlayExpiry = serial, expiry
	d.overlayMu.Unlock()
	return nil
}
func (RuntimeAdapter) Restore(ctx context.Context, serial string) error {
	if Get() == nil {
		return errors.New("Cluster is unavailable")
	}
	d := Get()
	// Removing a RAM-only overlay cannot wait on a device writer. The next
	// successful frame uses the current saved scene, even after a USB stall.
	d.overlayMu.Lock()
	if d.overlayDevice == serial {
		d.overlayDevice = ""
	}
	restored := d.overlayDevice != serial
	d.overlayMu.Unlock()
	if !restored {
		return errors.New("Identification overlay removal did not verify")
	}
	return nil
}

func (d *Device) stopRenderer() error {
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()
	return d.renderer.Stop(ctx)
}

func (d *Device) recoverRenderer(ctx context.Context, revision uint64) error {
	if !d.lifecycle.TryLock() {
		return errors.New("A scene change is still running")
	}
	defer d.lifecycle.Unlock()
	if d.runtimeState().Revision != revision {
		return errors.New("Lighting catalog changed before dispatch; refresh before retrying")
	}
	if err := d.renderer.Stop(ctx); err != nil {
		return errors.New("Renderer still has an unfinished writer; no overlapping renderer was started")
	}
	if ctx.Err() != nil {
		return ctx.Err()
	}
	d.setDeviceColor()
	ticker := time.NewTicker(10 * time.Millisecond)
	defer ticker.Stop()
	for {
		if d.renderer.State() == "running" {
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
		}
	}
}

func (d *Device) updateRuntimeState() {
	state := lighting.RuntimeState{Mode: "unknown", Members: []string{}, Operations: []string{}}
	seen := make(map[string]bool)
	d.mutex.RLock()
	for _, c := range d.Controllers {
		if c != nil && c.WriteColorEx != nil && c.LedChannels > 0 && !seen[c.Serial] {
			seen[c.Serial] = true
			state.Members = append(state.Members, c.Serial)
		}
	}
	d.mutex.RUnlock()
	sort.Strings(state.Members)
	if d.DeviceProfile != nil {
		state.Profile = d.DeviceProfile.RGBProfile
	}
	if len(state.Members) > 0 && state.Profile != "" {
		state.Operations = []string{"recover", "identify"}
	}
	// This revision is a runtime-catalog precondition, distinct from API snapshot
	// configuration revisions. Identification/heartbeats do not advance it.
	data, _ := json.Marshal(struct {
		Profile string
		Members []string
	}{state.Profile, state.Members})
	hash := fnv.New64a()
	_, _ = hash.Write(data)
	state.Revision = hash.Sum64() >> 11
	if state.Revision == 0 {
		state.Revision = 1
	}
	d.runtimeMu.Lock()
	d.runtime = state
	d.runtimeMu.Unlock()
}

func (d *Device) runtimeState() lighting.RuntimeState {
	d.runtimeMu.Lock()
	state := d.runtime
	state.Members = append([]string{}, state.Members...)
	state.Operations = append([]string{}, state.Operations...)
	d.runtimeMu.Unlock()
	if d.stopping.Load() {
		state.Operations = []string{}
	}
	state.Mode = "unknown"
	state.Renderer = d.renderer.State()
	return state
}

func (d *Device) applyIdentification(serial string, data []byte) {
	d.overlayMu.Lock()
	active := d.overlayDevice == serial && time.Now().Before(d.overlayExpiry)
	d.overlayMu.Unlock()
	if !active {
		return
	}
	// Modest fixed white locator; existing family brightness/current limits still
	// run downstream. Every other member retains its normal generated frame.
	for i := range data {
		data[i] = 64
	}
}
