package server

import (
	"OpenLinkHub/src/application/lighting"
	"OpenLinkHub/src/dispatcher"
	"OpenLinkHub/src/server/contractv1"
	"context"
	"errors"
	"fmt"
	"reflect"
)

type contractV1LightingInventoryAdapter struct {
	read func(context.Context) (contractv1.Snapshot, uint64, error)
}

func newContractV1LightingInventoryAdapter(
	read func(context.Context) (contractv1.Snapshot, uint64, error),
) *contractV1LightingInventoryAdapter {
	return &contractV1LightingInventoryAdapter{read: read}
}

func (adapter *contractV1LightingInventoryAdapter) Snapshot(ctx context.Context) (lighting.Snapshot, error) {
	if adapter == nil || adapter.read == nil {
		return lighting.Snapshot{}, errors.New("lighting inventory adapter is not configured")
	}
	snapshot, revision, err := adapter.read(ctx)
	if err != nil {
		return lighting.Snapshot{}, err
	}
	result := lighting.Snapshot{Revision: revision, Targets: []lighting.Target{}}
	for _, device := range snapshot.Devices {
		if device.Lighting == nil {
			continue
		}
		for _, target := range device.Lighting.Targets {
			var channelID *int
			if target.ChannelID != nil {
				value := *target.ChannelID
				channelID = &value
			}
			result.Targets = append(result.Targets, lighting.Target{
				DeviceID:            device.ID,
				ID:                  target.ID,
				Scope:               target.Scope,
				ChannelID:           channelID,
				ActiveProfile:       target.ActiveProfile,
				SupportedProfileIDs: append([]string(nil), target.SupportedProfileIDs...),
				Operations:          append([]string(nil), target.Operations...),
			})
		}
	}
	return result, nil
}

type legacyLightingAssignerAdapter struct {
	dispatch dispatcher.DeviceDispatcher
}

func newLegacyLightingAssignerAdapter(dispatch dispatcher.DeviceDispatcher) *legacyLightingAssignerAdapter {
	return &legacyLightingAssignerAdapter{dispatch: dispatch}
}

func (adapter *legacyLightingAssignerAdapter) AssignProfile(
	ctx context.Context,
	assignment lighting.Assignment,
) (err error) {
	if adapter == nil || adapter.dispatch == nil {
		return errors.New("legacy lighting dispatcher is not configured")
	}
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	channelID := -1
	switch assignment.Scope {
	case "device":
		if assignment.TargetID != "device" || assignment.ChannelID != nil {
			return errors.New("invalid whole-device lighting target")
		}
	case "channel":
		if assignment.ChannelID == nil || assignment.TargetID != fmt.Sprintf("channel:%d", *assignment.ChannelID) {
			return errors.New("invalid channel lighting target")
		}
		channelID = *assignment.ChannelID
	default:
		return errors.New("unsupported lighting target scope")
	}

	defer func() {
		if recovered := recover(); recovered != nil {
			err = fmt.Errorf("legacy lighting dispatcher panicked: %v", recovered)
		}
	}()
	values := adapter.dispatch(
		assignment.DeviceID,
		"UpdateRgbProfile",
		channelID,
		assignment.ProfileID,
	)
	if len(values) != 1 || !values[0].IsValid() {
		return errors.New("legacy lighting dispatcher returned no result")
	}
	if values[0].Kind() < reflect.Uint || values[0].Kind() > reflect.Uint64 {
		return errors.New("legacy lighting dispatcher returned an invalid result")
	}
	if values[0].Uint() != 1 {
		return errors.New("legacy lighting dispatcher rejected the assignment")
	}
	return nil
}
