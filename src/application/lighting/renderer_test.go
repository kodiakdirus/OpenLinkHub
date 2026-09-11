package lighting

import (
	"context"
	"testing"
	"time"
)

func TestBlockedWriterCannotBlockStopOrSpawnReplacement(t *testing.T) {
	var renderer Renderer
	release, started := make(chan struct{}), make(chan struct{})
	defer close(release)
	if !renderer.Start(func(ctx context.Context) { close(started); <-release }) {
		t.Fatal("start failed")
	}
	<-started
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()
	if renderer.Stop(ctx) == nil {
		t.Fatal("blocked writer was reported stopped")
	}
	if renderer.Start(func(context.Context) {}) {
		t.Fatal("overlapping writer started")
	}
}

func TestRendererStopDoesNotNeedExitSignalConsumer(t *testing.T) {
	var renderer Renderer
	started := make(chan struct{})
	renderer.Start(func(ctx context.Context) { close(started); <-ctx.Done() })
	<-started
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := renderer.Stop(ctx); err != nil {
		t.Fatal(err)
	}
	if !renderer.Start(func(context.Context) {}) {
		t.Fatal("completed generation could not be replaced")
	}
	if err := renderer.Stop(ctx); err != nil {
		t.Fatal(err)
	}
}
