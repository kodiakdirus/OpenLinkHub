package voideliteW

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
)

// AudioSettings describes saved settings. Battery is telemetry; the revision
// deliberately excludes it. Firmware readback of sidetone is not supported.
type AudioSettings struct {
	Revision  string `json:"revision"`
	Connected bool   `json:"connected"`
	Battery   uint16 `json:"battery"`
	Enabled   bool   `json:"enabled"`
	Level     int    `json:"level"`
}

func (d *Device) AudioSettings() (AudioSettings, error) {
	d.audioControlMutex.Lock()
	defer d.audioControlMutex.Unlock()
	return d.audioSettings()
}

func (d *Device) audioSettings() (AudioSettings, error) {
	if d.DeviceProfile == nil {
		return AudioSettings{}, fmt.Errorf("headset profile unavailable")
	}
	s := AudioSettings{Connected: d.Connected, Battery: d.BatteryLevel,
		Enabled: d.DeviceProfile.SideTone == 1, Level: d.DeviceProfile.SideToneValue}
	hash := sha256.Sum256([]byte(fmt.Sprintf("%s:%t:%d", d.Serial, s.Enabled, s.Level)))
	s.Revision = hex.EncodeToString(hash[:])
	return s, nil
}

// ApplyAudioSettings checks the baseline before writing. A successful response
// verifies persistence and HID transport, never the audible sidetone level.
func (d *Device) ApplyAudioSettings(revision string, enabled bool, level int) error {
	d.audioControlMutex.Lock()
	defer d.audioControlMutex.Unlock()
	before, err := d.audioSettings()
	if err != nil {
		return err
	}
	if !before.Connected || d.Exit {
		return fmt.Errorf("headset disconnected")
	}
	if revision != before.Revision {
		return fmt.Errorf("stale revision; refresh before applying")
	}
	if level < 1 || level > 100 {
		return fmt.Errorf("sidetone level must be between 1 and 100")
	}
	d.DeviceProfile.SideTone = 0
	if enabled {
		d.DeviceProfile.SideTone = 1
	}
	d.DeviceProfile.SideToneValue = level
	if err = d.configureHeadsetChecked(); err != nil {
		d.DeviceProfile.SideTone = 0
		if before.Enabled {
			d.DeviceProfile.SideTone = 1
		}
		d.DeviceProfile.SideToneValue = before.Level
		return fmt.Errorf("HID outcome uncertain; refresh and review: %w", err)
	}
	d.saveDeviceProfile()
	contents, err := os.ReadFile(d.DeviceProfile.Path)
	if err != nil {
		return fmt.Errorf("cannot verify saved profile: %w", err)
	}
	var saved DeviceProfile
	if err = json.Unmarshal(contents, &saved); err != nil {
		return err
	}
	if (saved.SideTone == 1) != enabled || saved.SideToneValue != level {
		return fmt.Errorf("saved profile did not match requested sidetone")
	}
	return nil
}
