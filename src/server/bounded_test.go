package server

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestBlockedLightingHTTPRetainsSlotAfterTimeout(t *testing.T) {
	release, started := make(chan struct{}), make(chan struct{})
	gate := make(chan struct{}, 1)
	handler := boundedHandler(func(w http.ResponseWriter, r *http.Request) { close(started); <-release; w.WriteHeader(200) }, gate, 10*time.Millisecond)
	first := httptest.NewRecorder()
	handler(first, httptest.NewRequest("PUT", "/", nil))
	if first.Code != 504 {
		t.Fatalf("got %d", first.Code)
	}
	<-started
	second := httptest.NewRecorder()
	handler(second, httptest.NewRequest("PUT", "/", nil))
	if second.Code != 503 {
		t.Fatalf("retry got %d", second.Code)
	}
	close(release)
}
