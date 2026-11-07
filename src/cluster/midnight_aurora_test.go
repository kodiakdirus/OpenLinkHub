package cluster

import (
	"OpenLinkHub/src/config"
	"OpenLinkHub/src/logger"
	"OpenLinkHub/src/rgb"
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestMidnightAuroraCatalogUpgradeAndDispatch(t *testing.T) {
	previous := pwd
	defer func() { pwd = previous }()
	// rgb.Init reads the repository's actual default catalog.
	wd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err = os.Chdir(filepath.Join(wd, "../..")); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(wd)
	rgb.Init()
	testConfigDir := t.TempDir()
	if err = os.WriteFile(filepath.Join(testConfigDir, "config.json"), []byte(`{"logFile":"-","logLevel":"info"}`), 0600); err != nil {
		t.Fatal(err)
	}
	if err = os.Chdir(testConfigDir); err != nil {
		t.Fatal(err)
	}
	config.Init()
	logger.Init()
	if err = os.Chdir(filepath.Join(wd, "../..")); err != nil {
		t.Fatal(err)
	}
	pwd = t.TempDir()
	if err = os.MkdirAll(filepath.Join(pwd, "database/rgb"), 0700); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(pwd, "database/rgb/cluster.json")
	original := rgb.RGB{Profiles: map[string]rgb.Profile{"nebula": {ProfileName: "My Nebula", Speed: 3, Brightness: 0.7}}}
	data, _ := json.Marshal(original)
	if err = os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
	brightness := uint8(0)
	device := &Device{Serial: "cluster", Product: "Cluster", RGBModes: []string{"nebula", "midnight-aurora"}, DeviceProfile: &DeviceProfile{RGBProfile: "nebula", BrightnessSlider: &brightness}}
	device.loadRgb()
	profile := device.GetRgbProfile("midnight-aurora")
	if profile == nil || profile.ProfileName != "Midnight Aurora" || profile.Speed != 5 {
		t.Fatalf("missing new profile: %+v", profile)
	}
	if device.GetRgbProfile("nebula").Speed != 3 || device.DeviceProfile.RGBProfile != "nebula" {
		t.Fatal("existing settings changed")
	}
	start := time.Now()
	active := rgb.Exit()
	active.RGBStartColor = rgb.GenerateRandomColor(1)
	active.RGBEndColor = rgb.GenerateRandomColor(1)
	frame := device.generateRgbEffect(24, &start, "midnight-aurora", active)
	if !bytes.Equal(frame, make([]byte, 72)) {
		t.Fatalf("dispatch/blackout failed: %v", frame)
	}
	brightness = 100
	frame = device.generateRgbEffect(24, &start, "midnight-aurora", active)
	if len(frame) != 72 || bytes.Equal(frame, make([]byte, 72)) {
		t.Fatal("dispatch produced no colors")
	}
	saved, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var catalog rgb.RGB
	if err = json.Unmarshal(saved, &catalog); err != nil {
		t.Fatal(err)
	}
	if catalog.Profiles["midnight-aurora"].ProfileName != "Midnight Aurora" || catalog.Profiles["nebula"].Speed != 3 {
		t.Fatal("catalog upgrade did not preserve profiles")
	}
}
