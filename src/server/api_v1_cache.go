package server

import (
	"sync"
	"time"
)

type lightingProfileCache struct {
	mu      sync.Mutex
	loaded  bool
	value   map[string]interface{}
	expires time.Time
	ttl     time.Duration
}

func (cache *lightingProfileCache) get(
	now time.Time,
	loader func() map[string]interface{},
) map[string]interface{} {
	cache.mu.Lock()
	defer cache.mu.Unlock()
	if cache.loaded && now.Before(cache.expires) {
		return cache.value
	}
	cache.value = loader()
	cache.loaded = true
	cache.expires = now.Add(cache.ttl)
	return cache.value
}

func (cache *lightingProfileCache) invalidate() {
	cache.mu.Lock()
	defer cache.mu.Unlock()
	cache.loaded = false
	cache.value = nil
	cache.expires = time.Time{}
}

var apiV1Lighting = lightingProfileCache{ttl: 30 * time.Second}
