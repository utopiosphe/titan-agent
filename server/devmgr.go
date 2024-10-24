package server

import (
	"context"
	"sync"
	"time"
)

const (
	keepaliveInterval = 30 * time.Second
	offlineTime       = 120 * time.Second
)

type DevMgr struct {
	agents      sync.Map
	controllers sync.Map
}

func newDevMgr(ctx context.Context) *DevMgr {
	dm := &DevMgr{}
	go dm.startTicker(ctx)

	return dm
}

func (dm *DevMgr) startTicker(ctx context.Context) {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop() // 确保在程序结束时停止 ticker

	for {
		select {
		case <-ticker.C:
			dm.keepalive()
		case <-ctx.Done():
			return
		}
	}
}

func (dm *DevMgr) keepalive() {
	offlineAgents := make([]*Device, 0)
	dm.agents.Range(func(key, value any) bool {
		d := value.(*Device)
		if d != nil && time.Since(d.LastActivityTime) > offlineTime {
			offlineAgents = append(offlineAgents, d)
		}
		return true
	})

	for _, d := range offlineAgents {
		dm.removeAgent(d)
	}

	offlineControllers := make([]*Device, 0)
	dm.controllers.Range(func(key, value any) bool {
		d := value.(*Device)
		if d != nil && time.Since(d.LastActivityTime) > offlineTime {
			offlineControllers = append(offlineControllers, d)
		}
		return true
	})

	for _, controller := range offlineControllers {
		dm.removeAgent(controller)
	}
}

func (dm *DevMgr) addAgent(device *Device) {
	dm.agents.Store(device.UUID, device)
}

func (dm *DevMgr) removeAgent(device *Device) {
	dm.agents.Delete(device.UUID)
}

func (dm *DevMgr) getAgent(uuid string) *Device {
	v, ok := dm.agents.Load(uuid)
	if !ok {
		return nil
	}
	return v.(*Device)
}

func (dm *DevMgr) getAgents() []*Device {
	devices := make([]*Device, 0)
	dm.agents.Range(func(key, value any) bool {
		d := value.(*Device)
		if d != nil {
			devices = append(devices, d)
		}
		return true
	})

	return devices
}

func (dm *DevMgr) updateAgent(d *Device) {
	if len(d.UUID) == 0 {
		return
	}

	device := dm.getAgent(d.UUID)
	if device == nil {
		dm.addAgent(d)
		return
	}

	device.LastActivityTime = d.LastActivityTime
}

func (dm *DevMgr) addController(device *Device) {
	dm.controllers.Store(device.UUID, device)
}

func (dm *DevMgr) removeController(device *Device) {
	dm.controllers.Delete(device.UUID)
}

func (dm *DevMgr) getController(uuid string) *Device {
	v, ok := dm.controllers.Load(uuid)
	if !ok {
		return nil
	}
	return v.(*Device)
}

func (dm *DevMgr) getControllers() []*Device {
	devices := make([]*Device, 0)
	dm.controllers.Range(func(key, value any) bool {
		d := value.(*Device)
		if d != nil {
			devices = append(devices, d)
		}
		return true
	})

	return devices
}

func (dm *DevMgr) updateController(d *Device) {
	if len(d.UUID) == 0 {
		return
	}

	device := dm.getController(d.UUID)
	if device == nil {
		dm.addController(d)
		return
	}

	device.LastActivityTime = d.LastActivityTime
}
