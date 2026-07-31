package contractv1

type stateChannel struct {
	ID             string            `json:"id"`
	Name           string            `json:"name"`
	Label          string            `json:"label,omitempty"`
	Description    string            `json:"description,omitempty"`
	Role           string            `json:"role"`
	Port           *int              `json:"port,omitempty"`
	HasSpeed       bool              `json:"hasSpeed"`
	HasTemperature bool              `json:"hasTemperature"`
	CoolingProfile *ProfileReference `json:"coolingProfile,omitempty"`
	LightingEffect *ProfileReference `json:"lightingEffect,omitempty"`
}

type stateDevice struct {
	ID           string             `json:"id"`
	Product      string             `json:"product"`
	ProductID    uint16             `json:"productId"`
	ProductType  uint16             `json:"productType"`
	DeviceType   string             `json:"deviceType"`
	Firmware     string             `json:"firmware,omitempty"`
	Hidden       bool               `json:"hidden"`
	Transport    string             `json:"transport"`
	Profile      DeviceProfileState `json:"profile"`
	Capabilities []Capability       `json:"capabilities"`
	Channels     []stateChannel     `json:"channels"`
	Lighting     *LightingCatalog   `json:"lighting,omitempty"`
}

type stateProjection struct {
	Service         ServiceDescriptor       `json:"service"`
	Devices         []stateDevice           `json:"devices"`
	CoolingProfiles []CoolingProfileSummary `json:"coolingProfiles"`
	Scheduler       SchedulerState          `json:"scheduler"`
	Displays        []DisplayState          `json:"displays"`
	Dashboard       DashboardState          `json:"dashboard"`
	LCDAssets       []LCDAsset              `json:"lcdAssets"`
	LCDProfiles     []LCDProfileSummary     `json:"lcdProfiles"`
}

type telemetryChannel struct {
	ID          string       `json:"id"`
	Speed       *Measurement `json:"speed,omitempty"`
	Temperature *Measurement `json:"temperature,omitempty"`
}

type telemetryDevice struct {
	ID       string             `json:"id"`
	Online   bool               `json:"online"`
	Battery  *Measurement       `json:"battery,omitempty"`
	Channels []telemetryChannel `json:"channels"`
}

type telemetryProjection struct {
	System  SystemSnapshot    `json:"system"`
	Devices []telemetryDevice `json:"devices"`
}

// StateRevisionValue excludes rapidly changing measurements so future writes
// can use Revision as a meaningful optimistic-concurrency boundary.
func StateRevisionValue(snapshot Snapshot) any {
	devices := make([]stateDevice, 0, len(snapshot.Devices))
	for _, device := range snapshot.Devices {
		channels := make([]stateChannel, 0, len(device.Channels))
		for _, channel := range device.Channels {
			channels = append(channels, stateChannel{
				ID:             channel.ID,
				Name:           channel.Name,
				Label:          channel.Label,
				Description:    channel.Description,
				Role:           channel.Role,
				Port:           channel.Port,
				HasSpeed:       channel.HasSpeed,
				HasTemperature: channel.HasTemperature,
				CoolingProfile: channel.CoolingProfile,
				LightingEffect: channel.LightingEffect,
			})
		}
		devices = append(devices, stateDevice{
			ID:           device.ID,
			Product:      device.Product,
			ProductID:    device.ProductID,
			ProductType:  device.ProductType,
			DeviceType:   device.DeviceType,
			Firmware:     device.Firmware,
			Hidden:       device.Hidden,
			Transport:    device.Transport,
			Profile:      device.Profile,
			Capabilities: device.Capabilities,
			Channels:     channels,
			Lighting:     device.Lighting,
		})
	}
	return stateProjection{
		Service:         snapshot.Service,
		Devices:         devices,
		CoolingProfiles: snapshot.CoolingProfiles,
		Scheduler:       snapshot.Scheduler,
		Displays:        snapshot.Displays,
		Dashboard:       snapshot.Dashboard,
		LCDAssets:       snapshot.LCDAssets,
		LCDProfiles:     snapshot.LCDProfiles,
	}
}

// TelemetryRevisionValue contains only live availability and measurements.
func TelemetryRevisionValue(snapshot Snapshot) any {
	devices := make([]telemetryDevice, 0, len(snapshot.Devices))
	for _, device := range snapshot.Devices {
		channels := make([]telemetryChannel, 0, len(device.Channels))
		for _, channel := range device.Channels {
			channels = append(channels, telemetryChannel{
				ID:          channel.ID,
				Speed:       channel.Speed,
				Temperature: channel.Temperature,
			})
		}
		devices = append(devices, telemetryDevice{
			ID:       device.ID,
			Online:   device.Online,
			Battery:  device.Battery,
			Channels: channels,
		})
	}
	return telemetryProjection{System: snapshot.System, Devices: devices}
}
