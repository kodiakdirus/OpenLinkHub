package main

import (
	"OpenLinkHub/src/controller"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// waitForExit listens for a program termination and switches the device back to hardware mode
func waitForExit() {
	terminateSignals := make(chan os.Signal, 1)
	signal.Notify(terminateSignals, syscall.SIGINT, syscall.SIGTERM)
	for {
		select {
		case <-terminateSignals:
			if !stopWithin(controller.Stop, 10*time.Second) {
				fmt.Fprintln(os.Stderr, "Shutdown timed out waiting for device cleanup; exiting for service recovery")
				os.Exit(1)
			}
			os.Exit(0)
		}
	}
}

// main entry point
func main() {
	go waitForExit()
	controller.Start()
}

// stopWithin bounds process shutdown; it does not cancel a blocked driver call.
// The caller must exit the process when cleanup misses its deadline.
func stopWithin(stop func(), timeout time.Duration) bool {
	done := make(chan struct{})
	go func() {
		stop()
		close(done)
	}()
	timer := time.NewTimer(timeout)
	defer timer.Stop()
	select {
	case <-done:
		return true
	case <-timer.C:
		return false
	}
}
