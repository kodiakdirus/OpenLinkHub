package lsh

import "time"

// Sample expensive telemetry at the ordinary LCD cadence, independently of
// frame count/delay. Each encoded frame uses the latest one-second sample.
type lcdAnimationSamples struct {
	values      []float32
	sampledAt   time.Time
	initialized bool
}

func (s *lcdAnimationSamples) get(now time.Time, sample func() []float32) []float32 {
	if !s.initialized || now.Sub(s.sampledAt) >= time.Duration(lcdRefreshInterval)*time.Millisecond {
		s.values = sample()
		s.sampledAt = now
		s.initialized = true
	}
	return s.values
}
