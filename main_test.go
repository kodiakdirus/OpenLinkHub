package main

import (
	"testing"
	"time"
)

func TestStopWithinCompletes(t *testing.T) {
	if !stopWithin(func() {}, time.Second) {
		t.Fatal("completed cleanup timed out")
	}
}

func TestStopWithinBoundsBlockedCleanup(t *testing.T) {
	release := make(chan struct{})
	defer close(release)
	returned := make(chan bool, 1)
	go func() { returned <- stopWithin(func() { <-release }, 10*time.Millisecond) }()
	select {
	case ok := <-returned:
		if ok {
			t.Fatal("blocked cleanup reported success")
		}
	case <-time.After(time.Second):
		t.Fatal("shutdown deadline did not release caller")
	}
}
