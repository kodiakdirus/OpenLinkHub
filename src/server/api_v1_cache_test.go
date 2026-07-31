package server

import (
	"testing"
	"time"
)

func TestLightingProfileCacheBoundsExpensiveInventoryReads(t *testing.T) {
	cache := lightingProfileCache{ttl: 30 * time.Second}
	now := time.Unix(100, 0)
	loads := 0
	loader := func() map[string]interface{} {
		loads++
		return map[string]interface{}{"device": loads}
	}

	first := cache.get(now, loader)
	second := cache.get(now.Add(3*time.Second), loader)
	if loads != 1 || first["device"] != second["device"] {
		t.Fatalf("cache performed %d loads inside TTL", loads)
	}

	third := cache.get(now.Add(31*time.Second), loader)
	if loads != 2 || third["device"] != 2 {
		t.Fatalf("cache did not refresh after TTL: loads=%d value=%#v", loads, third)
	}

	cache.invalidate()
	cache.get(now.Add(32*time.Second), loader)
	if loads != 3 {
		t.Fatalf("cache invalidation did not force reload: %d", loads)
	}
}

func TestLightingProfileCacheRetainsEmptyInventory(t *testing.T) {
	cache := lightingProfileCache{ttl: 30 * time.Second}
	now := time.Unix(100, 0)
	loads := 0
	loader := func() map[string]interface{} {
		loads++
		return nil
	}

	if cache.get(now, loader) != nil || cache.get(now.Add(time.Second), loader) != nil {
		t.Fatal("empty inventory should remain empty")
	}
	if loads != 1 {
		t.Fatalf("empty inventory loaded %d times inside TTL", loads)
	}
}
