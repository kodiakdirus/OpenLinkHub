package monitor

import (
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

func sleepSignal(value bool) *dbus.Signal {
	return &dbus.Signal{Name: "org.freedesktop.login1.Manager.PrepareForSleep", Body: []interface{}{value}}
}

func TestResumeRestartsWhileCleanupIsBlocked(t *testing.T) {
	sleep.Store(false)
	defer sleep.Store(false)
	signals := make(chan *dbus.Signal, 8)
	release := make(chan struct{})
	defer close(release)
	started := make(chan struct{}, 2)
	restarted := make(chan struct{})
	done := make(chan struct{})
	go func() {
		defer close(done)
		runSleepSignals(signals, 10*time.Millisecond, func() {
			started <- struct{}{}
			<-release
		}, func() { close(restarted) })
	}()
	signals <- sleepSignal(true)
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("cleanup did not start")
	}
	signals <- sleepSignal(true)
	signals <- &dbus.Signal{Name: "unrelated", Body: []interface{}{false}}
	signals <- sleepSignal(false)
	select {
	case <-restarted:
	case <-time.After(time.Second):
		t.Fatal("blocked cleanup prevented resume recovery")
	}
	<-done
	if !sleep.Load() {
		t.Fatal("hotplug enabled before process replacement")
	}
	select {
	case <-started:
		t.Fatal("duplicate suspend started cleanup twice")
	default:
	}
}

func TestSleepSignalsIgnoreMalformedEvents(t *testing.T) {
	sleep.Store(false)
	defer sleep.Store(false)
	signals := make(chan *dbus.Signal, 5)
	signals <- nil
	signals <- &dbus.Signal{Name: "unrelated", Body: []interface{}{true}}
	signals <- &dbus.Signal{Name: "org.freedesktop.login1.Manager.PrepareForSleep"}
	signals <- &dbus.Signal{Name: "org.freedesktop.login1.Manager.PrepareForSleep", Body: []interface{}{"true"}}
	close(signals)
	runSleepSignals(signals, time.Millisecond, func() { t.Error("unexpected cleanup") }, func() { t.Error("unexpected restart") })
	if sleep.Load() {
		t.Fatal("malformed event disabled hotplug")
	}
}

func TestResumeWithoutSuspendStillRecovers(t *testing.T) {
	sleep.Store(false)
	defer sleep.Store(false)
	signals := make(chan *dbus.Signal, 1)
	signals <- sleepSignal(false)
	restarted := make(chan struct{})
	go runSleepSignals(signals, time.Millisecond, func() { t.Error("unexpected cleanup") }, func() { close(restarted) })
	select {
	case <-restarted:
	case <-time.After(time.Second):
		t.Fatal("resume did not recover")
	}
}
