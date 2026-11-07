package lcd

import (
	"OpenLinkHub/src/rgb"
	"bytes"
	"golang.org/x/image/font/opentype"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	"os"
	"testing"
)

func animationFixture(t *testing.T) {
	t.Helper()
	oldLCD, oldAnimation, oldText := lcd, animation, sensorTextCache
	t.Cleanup(func() { lcd, animation, sensorTextCache = oldLCD, oldAnimation, oldText })
	data, err := os.ReadFile("../../../static/fonts/teko.ttf")
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := opentype.Parse(data)
	if err != nil {
		t.Fatal(err)
	}
	lcd.sfntFont = parsed
	sensorTextCache = map[uint8]string{0: "CPU TEMP"}
	backgrounds := []AnimationFrames{}
	for index, c := range []color.RGBA{{10, 20, 30, 255}, {60, 10, 50, 255}} {
		canvas := image.NewRGBA(image.Rect(0, 0, 480, 480))
		draw.Draw(canvas, canvas.Bounds(), &image.Uniform{C: c}, image.Point{}, draw.Src)
		backgrounds = append(backgrounds, AnimationFrames{Canvas: canvas, Delay: float64(40 + index*10)})
	}
	animation = &Animation{Background: "test", Margin: 60, Workers: 2, Images: map[string][]AnimationFrames{"test": backgrounds}, Sensors: map[int]Sensors{0: {Sensor: 0, Enabled: true, TextColor: rgb.Color{Red: 41, Green: 211, Blue: 194}}}}
}

func TestAnimationFramesRefreshValuesWithoutResettingPhase(t *testing.T) {
	animationFixture(t)
	before := append([]byte(nil), animation.Images["test"][0].Canvas.Pix...)
	if AnimationFrameCount() != 2 {
		t.Fatal("frame count")
	}
	first, ok := GenerateAnimationScreenFrame(0, []float32{30})
	if !ok {
		t.Fatal("first frame")
	}
	second, ok := GenerateAnimationScreenFrame(1, []float32{60})
	if !ok {
		t.Fatal("second frame")
	}
	wrapped, ok := GenerateAnimationScreenFrame(2, []float32{60})
	if !ok {
		t.Fatal("wrapped frame")
	}
	if first.Delay != 40 || second.Delay != 50 || wrapped.Delay != 40 {
		t.Fatal("frame delays changed")
	}
	for _, sample := range []struct {
		frame Frames
		red   uint8
	}{{first, 10}, {second, 60}, {wrapped, 10}} {
		img, err := jpeg.Decode(bytes.NewReader(sample.frame.Buffer))
		if err != nil {
			t.Fatal(err)
		}
		c := color.RGBAModel.Convert(img.At(10, 10)).(color.RGBA)
		if d := int(c.R) - int(sample.red); d < -2 || d > 2 {
			t.Fatalf("wrong background/phase: %+v", c)
		}
	}
	if bytes.Equal(first.Buffer, wrapped.Buffer) {
		t.Fatal("new sensor value was not drawn on the same background frame")
	}
	if !bytes.Equal(before, animation.Images["test"][0].Canvas.Pix) {
		t.Fatal("cached background mutated")
	}
	batch := GenerateAnimationScreenImage([]float32{30})
	if len(batch) != 2 || !bytes.Equal(batch[0].Buffer, first.Buffer) {
		t.Fatal("legacy batch rendering changed")
	}
}

func TestAnimationFrameUnavailableAndNegativeIndex(t *testing.T) {
	animationFixture(t)
	if _, ok := GenerateAnimationScreenFrame(-1, nil); ok {
		t.Fatal("negative frame accepted")
	}
	animation.Background = "missing"
	if AnimationFrameCount() != 0 {
		t.Fatal("missing frame count")
	}
	if _, ok := GenerateAnimationScreenFrame(0, nil); ok {
		t.Fatal("missing background accepted")
	}
	if GenerateAnimationScreenImage(nil) != nil {
		t.Fatal("missing batch background")
	}
}
