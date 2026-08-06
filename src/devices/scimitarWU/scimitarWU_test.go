package scimitarWU

import "testing"

func TestGetRgbClusterReadsPersistedOwnership(t *testing.T) {
	tests := []struct {
		name    string
		profile *DeviceProfile
		want    bool
	}{
		{name: "missing profile", profile: nil, want: false},
		{name: "individual", profile: &DeviceProfile{RGBCluster: false}, want: false},
		{name: "rgb cluster", profile: &DeviceProfile{RGBCluster: true}, want: true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			device := &Device{DeviceProfile: test.profile}
			if got := device.GetRgbCluster(); got != test.want {
				t.Fatalf("GetRgbCluster() = %v, want %v", got, test.want)
			}
		})
	}
}
