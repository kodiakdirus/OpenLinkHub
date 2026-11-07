package lsh

import (
	"testing"
	"time"
)

func TestLCDAnimationSamplesRefreshIndependentlyOfLongLoop(t *testing.T) {
	var cache lcdAnimationSamples
	start := time.Unix(100, 0)
	calls := 0
	sample := func() []float32 { calls++; return []float32{float32(calls)} }
	for frame := 0; frame < 160; frame++ {
		values := cache.get(start.Add(time.Duration(frame)*50*time.Millisecond), sample)
		want := frame/20 + 1
		if calls != want || values[0] != float32(want) {
			t.Fatalf("frame%d calls%d value%v want%d", frame, calls, values, want)
		}
	}
	if calls != 8 {
		t.Fatalf("eight-second animation sampled%d times", calls)
	}
}
func TestLCDAnimationSamplesDoNotPollRepeatedlyOnEmptyResult(t *testing.T) {
	var cache lcdAnimationSamples
	start := time.Unix(100, 0)
	calls := 0
	sample := func() []float32 { calls++; return nil }
	cache.get(start, sample)
	cache.get(start.Add(50*time.Millisecond), sample)
	if calls != 1 {
		t.Fatal("empty readings caused per-frame sampling")
	}
	cache.get(start.Add(3*time.Second), sample)
	if calls != 2 {
		t.Fatal("missed interval caused polling burst")
	}
}
