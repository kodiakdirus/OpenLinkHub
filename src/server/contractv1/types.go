package contractv1

// Package contractv1 defines the additive API contract consumed by
// presentation clients. Reads remain broad; mutations are introduced as
// narrow, explicitly versioned commands.

const APIVersion = "1.0"

type Document struct {
	APIVersion        string `json:"apiVersion"`
	Kind              string `json:"kind"`
	Revision          uint64 `json:"revision"`
	TelemetryRevision uint64 `json:"telemetryRevision,omitempty"`
	Data              any    `json:"data"`
}

func Wrap(kind string, revision uint64, data any) Document {
	return Document{
		APIVersion: APIVersion,
		Kind:       kind,
		Revision:   revision,
		Data:       data,
	}
}

func WrapSnapshot(revision, telemetryRevision uint64, data Snapshot) Document {
	return Document{
		APIVersion:        APIVersion,
		Kind:              "snapshot",
		Revision:          revision,
		TelemetryRevision: telemetryRevision,
		Data:              data,
	}
}

type Build struct {
	Version  string `json:"version"`
	Revision string `json:"revision,omitempty"`
	Time     string `json:"time,omitempty"`
	Modified bool   `json:"modified"`
}

type Listener struct {
	Scope    string `json:"scope"`
	Loopback bool   `json:"loopback"`
	Port     int    `json:"port"`
}

type FeatureFlag struct {
	ID        string `json:"id"`
	Available bool   `json:"available"`
	ReadOnly  bool   `json:"readOnly"`
	Reason    string `json:"reason,omitempty"`
}

type ServiceDescriptor struct {
	Service        string        `json:"service"`
	Contract       string        `json:"contract"`
	Build          Build         `json:"build"`
	Listener       Listener      `json:"listener"`
	Frontend       bool          `json:"frontend"`
	Metrics        bool          `json:"metrics"`
	ManualMode     bool          `json:"manualMode"`
	SystemService  bool          `json:"systemService"`
	DeviceCount    int           `json:"deviceCount"`
	Persistence    string        `json:"persistence"`
	MutationAccess string        `json:"mutationAccess"`
	Features       []FeatureFlag `json:"features"`
	Warnings       []string      `json:"warnings"`
}

type ServiceInput struct {
	Version         string
	BuildRevision   string
	BuildTime       string
	BuildModified   bool
	ListenAddress   string
	ListenPort      int
	Frontend        bool
	Metrics         bool
	ManualMode      bool
	SystemService   bool
	Memory          bool
	OpenRGB         bool
	Gamepad         bool
	Motherboard     bool
	DisplayGeometry bool
}

type BatteryInput struct {
	Level      uint16
	DeviceType uint8
}

type DeviceInput struct {
	ID           string
	Product      string
	ProductID    uint16
	ProductType  uint16
	DeviceType   string
	Firmware     string
	Hidden       bool
	Detail       any
	Battery      *BatteryInput
	LightingData any
}

type Input struct {
	Service           ServiceInput
	Devices           []DeviceInput
	CPUTemperature    *float64
	GPUTemperature    *float64
	CoolingProfiles   any
	Scheduler         any
	Displays          any
	Dashboard         any
	LCDImages         any
	CustomLCDProfiles any
}

type Capability struct {
	ID         string         `json:"id"`
	Label      string         `json:"label"`
	Available  bool           `json:"available"`
	Access     string         `json:"access"`
	Reason     string         `json:"reason,omitempty"`
	Operations []string       `json:"operations"`
	Options    map[string]any `json:"options,omitempty"`
}

type ProfileReference struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type Measurement struct {
	Value float64 `json:"value"`
	Unit  string  `json:"unit"`
}

type Channel struct {
	ID             string            `json:"id"`
	Name           string            `json:"name"`
	Label          string            `json:"label,omitempty"`
	Description    string            `json:"description,omitempty"`
	Role           string            `json:"role"`
	Port           *int              `json:"port,omitempty"`
	HasSpeed       bool              `json:"hasSpeed"`
	HasTemperature bool              `json:"hasTemperature"`
	Speed          *Measurement      `json:"speed,omitempty"`
	Temperature    *Measurement      `json:"temperature,omitempty"`
	CoolingProfile *ProfileReference `json:"coolingProfile,omitempty"`
	LightingEffect *ProfileReference `json:"lightingEffect,omitempty"`
}

type LightingTarget struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	Description   string `json:"description"`
	ActiveProfile string `json:"activeProfile"`
}

type LightingProfile struct {
	ID                  string   `json:"id"`
	Name                string   `json:"name"`
	Speed               float64  `json:"speed"`
	Brightness          int      `json:"brightness"`
	Smoothness          int      `json:"smoothness"`
	StartColor          string   `json:"startColor"`
	MiddleColor         string   `json:"middleColor"`
	EndColor            string   `json:"endColor"`
	GradientColors      []string `json:"gradientColors"`
	MinTemperature      float64  `json:"minTemperature"`
	MaxTemperature      float64  `json:"maxTemperature"`
	Direction           int      `json:"direction"`
	AlternateColors     bool     `json:"alternateColors"`
	PerLED              bool     `json:"perLed"`
	TemperatureReactive bool     `json:"temperatureReactive"`
}

type LightingCatalog struct {
	Source       string            `json:"source"`
	Device       string            `json:"device"`
	DefaultColor string            `json:"defaultColor"`
	Targets      []LightingTarget  `json:"targets"`
	Profiles     []LightingProfile `json:"profiles"`
	ProfileCount int               `json:"profileCount"`
}

type DeviceProfileState struct {
	Active     string `json:"active"`
	SavedCount int    `json:"savedCount"`
}

type DeviceState struct {
	ID           string             `json:"id"`
	Product      string             `json:"product"`
	ProductID    uint16             `json:"productId"`
	ProductType  uint16             `json:"productType"`
	DeviceType   string             `json:"deviceType"`
	Firmware     string             `json:"firmware,omitempty"`
	Online       bool               `json:"online"`
	Hidden       bool               `json:"hidden"`
	Transport    string             `json:"transport"`
	Battery      *Measurement       `json:"battery,omitempty"`
	Profile      DeviceProfileState `json:"profile"`
	Capabilities []Capability       `json:"capabilities"`
	Channels     []Channel          `json:"channels"`
	Lighting     *LightingCatalog   `json:"lighting,omitempty"`
	LabelTargets []LabelTarget      `json:"labelTargets"`
}

type LabelTarget struct {
	ID        string `json:"id"`
	Scope     string `json:"scope"`
	ChannelID *int   `json:"channelId,omitempty"`
	Name      string `json:"name"`
	Label     string `json:"label"`
}

type LabelCommand struct {
	ExpectedRevision uint64 `json:"expectedRevision"`
	DeviceID         string `json:"deviceId"`
	TargetID         string `json:"targetId"`
	Label            string `json:"label"`
}

type CommandIssue struct {
	Field   string `json:"field,omitempty"`
	Code    string `json:"code"`
	Message string `json:"message"`
}

type LabelCommandResult struct {
	Operation       string         `json:"operation"`
	Status          string         `json:"status"`
	Message         string         `json:"message"`
	Changed         bool           `json:"changed"`
	RefreshRequired bool           `json:"refreshRequired"`
	Target          *LabelTarget   `json:"target,omitempty"`
	Issues          []CommandIssue `json:"issues"`
}

type DeviceCapability struct {
	ID           string       `json:"id"`
	Product      string       `json:"product"`
	ProductID    uint16       `json:"productId"`
	ProductType  uint16       `json:"productType"`
	DeviceType   string       `json:"deviceType"`
	Online       bool         `json:"online"`
	Transport    string       `json:"transport"`
	Capabilities []Capability `json:"capabilities"`
}

type CapabilityManifest struct {
	Devices  []DeviceCapability `json:"devices"`
	Features []FeatureFlag      `json:"environment"`
}

type CoolingProfileSummary struct {
	ID         string `json:"id"`
	SensorType int    `json:"sensorType"`
	Sensor     string `json:"sensor"`
	ZeroRPM    bool   `json:"zeroRpm"`
	Linear     bool   `json:"linear"`
	Hidden     bool   `json:"hidden"`
	PointCount int    `json:"pointCount"`
	StepCount  int    `json:"stepCount"`
}

type SchedulerState struct {
	LightingEnabled bool   `json:"lightingEnabled"`
	LightsOff       string `json:"lightsOff,omitempty"`
	LightsOn        string `json:"lightsOn,omitempty"`
	LCDEnabled      bool   `json:"lcdEnabled"`
	LightsOut       bool   `json:"lightsOut"`
}

type DisplayState struct {
	ID       int    `json:"id"`
	Name     string `json:"name"`
	Width    int    `json:"width"`
	Height   int    `json:"height"`
	Position string `json:"position"`
}

type DashboardState struct {
	Celsius     bool `json:"celsius"`
	ShowCPU     bool `json:"showCpu"`
	ShowGPU     bool `json:"showGpu"`
	ShowDisk    bool `json:"showDisk"`
	ShowDevices bool `json:"showDevices"`
	ShowBattery bool `json:"showBattery"`
	LightingOff bool `json:"lightingOff"`
}

type LCDAsset struct {
	Name   string `json:"name"`
	Frames int    `json:"frames"`
}

type LCDProfileSummary struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type SystemSnapshot struct {
	CPU *Measurement `json:"cpu,omitempty"`
	GPU *Measurement `json:"gpu,omitempty"`
}

type Snapshot struct {
	Service         ServiceDescriptor       `json:"service"`
	System          SystemSnapshot          `json:"system"`
	Devices         []DeviceState           `json:"devices"`
	CoolingProfiles []CoolingProfileSummary `json:"coolingProfiles"`
	Scheduler       SchedulerState          `json:"scheduler"`
	Displays        []DisplayState          `json:"displays"`
	Dashboard       DashboardState          `json:"dashboard"`
	LCDAssets       []LCDAsset              `json:"lcdAssets"`
	LCDProfiles     []LCDProfileSummary     `json:"lcdProfiles"`
}
