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

// midnightAuroraHSV preserves each reference anchor's value (including the
// near-black navy colors) while letting us blend without gray crossfades.
func midnightAuroraHSV(r, g, b float64) (h, s, v float64) {
	high, low := math.Max(r, math.Max(g, b)), math.Min(r, math.Min(g, b))
	delta := high - low
	v = high / 255
	if high == 0 || delta == 0 {
		return 0, 0, v
	}
	s = delta / high
	switch high {
	case r:
		h = 60 * math.Mod((g-b)/delta, 6)
	case g:
		h = 60 * ((b-r)/delta + 2)
	default:
		h = 60 * ((r-g)/delta + 4)
	}
	if h < 0 {
		h += 360
	}
	return
}

// midnightAuroraColor blends hue/saturation/value rather than desaturating
// complementary colors with RGB mixing. Warm anchors get a 25% saturation lift;
// value, brightness, timing and the reference's dark/cool anchors are unchanged.
func midnightAuroraColor(t float64) (r, g, b float64) {
	position := math.Max(0, math.Min(1, t)) * float64(len(midnightAuroraPalette)-1)
	index := int(position)
	if index == len(midnightAuroraPalette)-1 {
		index--
	}
	f := position - float64(index)
	a, z := midnightAuroraPalette[index], midnightAuroraPalette[index+1]
	h1, s1, v1 := midnightAuroraHSV(a.R, a.G, a.B)
	h2, s2, v2 := midnightAuroraHSV(z.R, z.G, z.B)
	delta := math.Mod(h2-h1+540, 360) - 180
	if index == 4 {
		// Route teal -> coral through blue/violet, not yellow-green.
		delta = math.Mod(h2-h1+360, 360)
	}
	h := math.Mod(h1+delta*f+360, 360)
	warm := math.Max(0, math.Min(1, position-4))
	s := math.Min(1, lerp(s1, s2, f)*(1+0.25*warm))
	v := lerp(v1, v2, f)
	c := v * s
	x := c * (1 - math.Abs(math.Mod(h/60, 2)-1))
	m := v - c
	switch {
	case h < 60:
		r, g, b = c, x, 0
	case h < 120:
		r, g, b = x, c, 0
	case h < 180:
		r, g, b = 0, c, x
	case h < 240:
		r, g, b = 0, x, c
	case h < 300:
		r, g, b = x, 0, c
	default:
		r, g, b = c, 0, x
	}
	return (r + m) * 255, (g + m) * 255, (b + m) * 255
}

// midnightAuroraWaveColor repeats the full palette over short spatial waves.
// A Cluster may concatenate hundreds of LEDs: scaling one wave across that
// entire layout made each fan/peripheral display only a narrow palette slice.
func midnightAuroraWaveColor(index, channels int, progress float64) (r, g, b float64) {
	wavelength := math.Min(24, float64(channels))
	if wavelength <= 0 {
		return 0, 0, 0
	}
	pos := float64(index)/wavelength + progress
	t := (math.Sin(pos*math.Pi*2) + 1) * 0.5
	return midnightAuroraColor(t)
}

func generateMidnightAuroraColors(lightChannels int, progress, brightness float64) []struct{ R, G, B float64 } {
	colors := make([]struct{ R, G, B float64 }, lightChannels)
	for i := range colors {
		r, g, b := midnightAuroraWaveColor(i, lightChannels, progress)
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
