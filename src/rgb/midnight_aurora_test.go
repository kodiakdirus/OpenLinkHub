package rgb

import (
	"bytes"
	"math"
	"testing"
	"time"
)

func TestMidnightAuroraReferencePalette(t *testing.T) {
	want := [][3]float64{{8, 11, 20}, {16, 22, 47}, {37, 37, 88}, {114, 72, 217}, {41, 211, 194}, {236, 111, 120}, {242, 180, 95}}
	for i, c := range want {
		r, g, b := midnightAuroraColor(float64(i) / 6)
		if math.Abs(r-c[0])+math.Abs(g-c[1])+math.Abs(b-c[2]) > 1e-9 {
			t.Fatalf("anchor %d: %v %v %v", i, r, g, b)
		}
	}
	r, g, b := midnightAuroraColor(0.75 / 6)
	if r != 14 || g != 19.25 || b != 40.25 {
		t.Fatalf("RGB interpolation: %v %v %v", r, g, b)
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
