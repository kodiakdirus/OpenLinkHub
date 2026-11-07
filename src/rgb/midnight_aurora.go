package rgb

import (
	"math"
	"math/rand"
	"time"
)

// Exact sRGB anchors from the requested reference, darkest to warmest.
var midnightAuroraPalette = [...]struct{ R, G, B float64 }{
	{8, 11, 20}, {16, 22, 47}, {37, 37, 88}, {114, 72, 217},
	{41, 211, 194}, {236, 111, 120}, {242, 180, 95},
}

// MidnightAurora renders Nebula-style waves using the Midnight Aurora palette.
func (r *ActiveRGB) MidnightAurora(startTime *time.Time) {
	buf := map[int][]byte{}
	elapsed := time.Since(*startTime).Milliseconds()
	progress := math.Mod(float64(elapsed)/(r.RgbModeSpeed*5000), 1.0)

	if progress >= 1.0 {
		*startTime = time.Now()
		elapsed = 0
		progress = 0
	}

	colors := generateMidnightAuroraColors(r.LightChannels, progress, r.RGBBrightness)

	for j, c := range colors {
		if len(r.Buffer) > 0 {
			r.Buffer[j] = byte(c.R)
			r.Buffer[j+r.ColorOffset] = byte(c.G)
			r.Buffer[j+(r.ColorOffset*2)] = byte(c.B)
		} else {
			buf[j] = []byte{
				byte(c.R),
				byte(c.G),
				byte(c.B),
			}
			if r.IsAIO && r.HasLCD {
				if j > 15 && j < 20 {
					buf[j] = []byte{0, 0, 0}
				}
			}
		}
	}

	r.Raw = buf
	if r.Inverted {
		r.Output = SetColorInverted(buf)
	} else {
		r.Output = SetColor(buf)
	}
}

// midnightAuroraColor interpolates in RGB so the reference's dark anchors
// retain their luminance instead of being replaced by an HSV hue sweep.
func midnightAuroraColor(t float64) (r, g, b float64) {
	t = math.Max(0, math.Min(1, t)) * float64(len(midnightAuroraPalette)-1)
	index := int(t)
	if index == len(midnightAuroraPalette)-1 {
		c := midnightAuroraPalette[index]
		return c.R, c.G, c.B
	}
	a, z := midnightAuroraPalette[index], midnightAuroraPalette[index+1]
	f := t - float64(index)
	return lerp(a.R, z.R, f), lerp(a.G, z.G, f), lerp(a.B, z.B, f)
}

func generateMidnightAuroraColors(lightChannels int, progress, brightness float64) []struct{ R, G, B float64 } {
	colors := make([]struct{ R, G, B float64 }, lightChannels)
	for i := range colors {
		pos := float64(i)/float64(lightChannels) + progress
		t := (math.Sin(pos*math.Pi*2) + 1) * 0.5
		r, g, b := midnightAuroraColor(t)
		gain := brightness * 0.6 // Preserve Nebula's subdued base lighting.
		if rand.Float64() < 0.001 {
			// Twinkles stay within the reference palette, at full user brightness.
			r, g, b = midnightAuroraColor(rand.Float64())
			gain = brightness
		}
		colors[i] = struct{ R, G, B float64 }{r * gain, g * gain, b * gain}
	}
	return colors
}
