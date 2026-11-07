package rgb

import (
	"bytes"
	"math"
	"testing"
	"time"
)

func TestMidnightAuroraReferencePalette(t *testing.T) {
	want := [][3]float64{{8, 11, 20}, {16, 22, 47}, {37, 37, 88}, {114, 72, 217}, {41, 211, 194}, {236, 79.75, 91}, {242, 164.5, 58.25}}
	for i, c := range want {
		r, g, b := midnightAuroraColor(float64(i) / 6)
		if math.Abs(r-c[0])+math.Abs(g-c[1])+math.Abs(b-c[2]) > 1e-8 {
			t.Fatalf("anchor %d: %v %v %v", i, r, g, b)
		}
	}
	// The old teal/coral RGB midpoint had saturation below 15%; retain
	// the palette saturation through this transition without a brightness lift.
	r, g, b := midnightAuroraColor(4.5 / 6)
	h, s, v := midnightAuroraHSV(r, g, b)
	if s < 0.7 || h < 240 || h > 300 || math.Abs(v-223.5/255) > 1e-8 {
		t.Fatalf("washed out transition: h=%v s=%v v=%v", h, s, v)
	}
	for i := 0; i <= 600; i++ {
		r, g, b := midnightAuroraColor(float64(i) / 600)
		for _, c := range []float64{r, g, b} {
			if c < 0 || c > 255 {
				t.Fatalf("out of range: %v", c)
			}
		}
	}
}

func TestMidnightAuroraBrightnessAndWave(t *testing.T) {
	for _, n := range []int{0, 1, 20, 200} {
		for _, level := range []float64{0, 0.25, 1} {
			colors := generateMidnightAuroraColors(n, 0.2, level)
			if len(colors) != n {
				t.Fatal("wrong frame length")
			}
			for _, c := range colors {
				for _, v := range []float64{c.R, c.G, c.B} {
					if math.IsNaN(v) || v < 0 || v > 255*level {
						t.Fatalf("invalid brightness: %v", c)
					}
				}
			}
		}
	}
	// Brightness zero must produce exact black, even with twinkles.
	start := time.Now()
	r := &ActiveRGB{LightChannels: 32, RgbModeSpeed: 5, RGBBrightness: 0}
	r.MidnightAurora(&start)
	if !bytes.Equal(r.Output, make([]byte, 96)) {
		t.Fatal("zero brightness is not black")
	}
	// AIO's LCD-covered LEDs retain Nebula's blackout behavior.
	r = &ActiveRGB{LightChannels: 24, RgbModeSpeed: 5, RGBBrightness: 1, IsAIO: true, HasLCD: true}
	r.MidnightAurora(&start)
	if len(r.Output) != 72 || !bytes.Equal(r.Output[48:60], make([]byte, 12)) {
		t.Fatal("AIO mask changed")
	}
	// Planar output supports devices with separate color planes.
	r = &ActiveRGB{LightChannels: 4, RgbModeSpeed: 5, RGBBrightness: 1, Buffer: make([]byte, 12), ColorOffset: 4}
	r.MidnightAurora(&start)
	if bytes.Equal(r.Buffer, make([]byte, 12)) {
		t.Fatal("planar output was not populated")
	}
}

// Assert visible variety locally, not merely across the entire concatenated
// Cluster. The previous one-wave-per-Cluster rendering fails this check.
func TestMidnightAuroraSimultaneousLocalColorVariety(t *testing.T) {
	for _, channels := range []int{24, 120, 360, 720} {
		for phase := 0; phase < 24; phase++ {
			for offset := 0; offset+24 <= channels; offset += 24 {
				cool, warm, dark := 0, 0, 0
				for i := offset; i < offset+24; i++ {
					r, g, b := midnightAuroraWaveColor(i, channels, float64(phase)/24)
					if (b > r*1.3 || g > r*1.3) && math.Max(g, b) > 80 {
						cool++
					}
					if r > g*1.1 && r > b*1.3 && r > 150 {
						warm++
					}
					if math.Max(r, math.Max(g, b)) < 50 {
						dark++
					}
				}
				if cool < 2 || warm < 2 || dark < 2 {
					t.Fatalf("channels=%d phase=%d offset=%d: cool=%d warm=%d dark=%d", channels, phase, offset, cool, warm, dark)
				}
			}
		}
	}
}
