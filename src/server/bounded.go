package server

import (
	"context"
	"net/http"
	"net/http/httptest"
	"time"
)

// boundedHandler bounds the caller, not an uncooperative legacy driver. The
// worker retains its slot until it finishes, preventing accumulating retries.
func boundedHandler(handler http.HandlerFunc, gate chan struct{}, timeout time.Duration) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		select {
		case gate <- struct{}{}:
		default:
			http.Error(w, "A previous operation is still running; refresh before retrying.", http.StatusServiceUnavailable)
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), timeout)
		defer cancel()
		done := make(chan *httptest.ResponseRecorder, 1)
		go func() {
			defer func() { <-gate }()
			recorder := httptest.NewRecorder()
			defer func() {
				if recover() != nil {
					recorder = httptest.NewRecorder()
					http.Error(recorder, "Operation failed", http.StatusInternalServerError)
				}
				done <- recorder
			}()
			if ctx.Err() != nil {
				http.Error(recorder, "Operation expired before dispatch", http.StatusGatewayTimeout)
				return
			}
			handler(recorder, r.WithContext(ctx))
		}()
		select {
		case response := <-done:
			for key, values := range response.Header() {
				for _, value := range values {
					w.Header().Add(key, value)
				}
			}
			w.WriteHeader(response.Code)
			_, _ = w.Write(response.Body.Bytes())
		case <-ctx.Done():
			http.Error(w, "Operation timed out; outcome unverified. An unfinished operation remains locked.", http.StatusGatewayTimeout)
		}
	}
}

var snapshotGate = make(chan struct{}, 1)
var lightingMutationGate = make(chan struct{}, 1)
