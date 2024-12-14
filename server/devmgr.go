package server

import (
	"agent/redis"
	"context"
	"encoding/json"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
)

const (
	keepaliveInterval = 30 * time.Second
	offlineTime       = 120 * time.Second
)

type Controller struct {
	Device
}

type Agent struct {
	Device
}

type DevMgr struct {
	agents      sync.Map
	controllers sync.Map
	redis       *redis.Redis
}

func newDevMgr(ctx context.Context, redis *redis.Redis) *DevMgr {
	dm := &DevMgr{redis: redis}
	go dm.startTicker(ctx)

	return dm
}

func (dm *DevMgr) startTicker(ctx context.Context) {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

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
	offlineAgents := make([]*Agent, 0)
	dm.agents.Range(func(key, value any) bool {
		d := value.(*Agent)
		if d != nil && time.Since(d.LastActivityTime) > offlineTime {
			offlineAgents = append(offlineAgents, d)
		}
		return true
	})

	for _, d := range offlineAgents {
		dm.removeAgent(d)
	}

	offlineControllers := make([]*Controller, 0)
	dm.controllers.Range(func(key, value any) bool {
		d := value.(*Controller)
		if d != nil && time.Since(d.LastActivityTime) > offlineTime {
			offlineControllers = append(offlineControllers, d)
		}
		return true
	})

	for _, controller := range offlineControllers {
		dm.removeController(controller)
	}
}

func (dm *DevMgr) addAgent(agent *Agent) {
	dm.agents.Store(agent.UUID, agent)
}

func (dm *DevMgr) removeAgent(agent *Agent) {
	dm.agents.Delete(agent.UUID)
}

func (dm *DevMgr) getAgent(uuid string) *Agent {
	v, ok := dm.agents.Load(uuid)
	if !ok {
		return nil
	}
	return v.(*Agent)
}

func (dm *DevMgr) getAgents() []*Agent {
	agents := make([]*Agent, 0)
	dm.agents.Range(func(key, value any) bool {
		d := value.(*Agent)
		if d != nil {
			agents = append(agents, d)
		}
		return true
	})

	return agents
}

func (dm *DevMgr) updateAgent(ag *Agent) {
	if len(ag.UUID) == 0 {
		return
	}

	agent := dm.getAgent(ag.UUID)
	if agent == nil {
		dm.addAgent(ag)
		return
	}

	agent.LastActivityTime = ag.LastActivityTime
}

func (dm *DevMgr) addController(controller *Controller) {
	dm.controllers.Store(controller.UUID, controller)
}

func (dm *DevMgr) removeController(controller *Controller) {
	dm.controllers.Delete(controller.UUID)
}

func (dm *DevMgr) getController(uuid string) *Controller {
	v, ok := dm.controllers.Load(uuid)
	if !ok {
		return nil
	}
	return v.(*Controller)
}

func (dm *DevMgr) getControllers() []*Controller {
	controllers := make([]*Controller, 0)
	dm.controllers.Range(func(key, value any) bool {
		d := value.(*Controller)
		if d != nil {
			controllers = append(controllers, d)
		}
		return true
	})

	return controllers
}

func (dm *DevMgr) updateController(c *Controller) {
	if len(c.UUID) == 0 {
		return
	}

	controller := dm.getController(c.UUID)
	if controller == nil {
		dm.addController(c)
		dm.redis.SetNode(context.Background(), controllerToNode(c))
		return
	}

	controller.LastActivityTime = c.LastActivityTime
}

func controllerToNode(c *Controller) *redis.Node {
	buf, err := json.Marshal(c)
	if err != nil {
		log.Error("controllerToNode ", err.Error())
		return nil
	}

	node := &redis.Node{}
	err = json.Unmarshal(buf, node)
	if err != nil {
		log.Error("controllerToNode ", err.Error())
		return nil
	}

	node.ID = c.UUID
	node.LastActivityTime = time.Now()
	return node
}
