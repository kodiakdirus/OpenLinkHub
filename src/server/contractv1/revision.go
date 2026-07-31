package contractv1

import (
	"crypto/sha256"
	"encoding/json"
	"sync"
)

// RevisionTracker assigns a process-local, monotonically increasing revision
// whenever the normalized contract state changes.
type RevisionTracker struct {
	mu          sync.Mutex
	initialized bool
	revision    uint64
	digest      [sha256.Size]byte
}

// Observe returns the current revision for value. The first successfully
// encoded value is revision 1; identical values retain their revision.
func (tracker *RevisionTracker) Observe(value any) uint64 {
	payload, err := json.Marshal(value)
	if err != nil {
		tracker.mu.Lock()
		defer tracker.mu.Unlock()
		if tracker.revision == 0 {
			tracker.revision = 1
		}
		return tracker.revision
	}

	digest := sha256.Sum256(payload)

	tracker.mu.Lock()
	defer tracker.mu.Unlock()

	if !tracker.initialized {
		tracker.initialized = true
		tracker.digest = digest
		tracker.revision = 1
		return tracker.revision
	}

	if tracker.digest != digest {
		tracker.digest = digest
		tracker.revision++
	}
	return tracker.revision
}
