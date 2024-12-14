package redis

import (
	"context"
	"fmt"
	"time"
)

type Node struct {
	ID string `redis:"id"`
	// AndroidID           string
	// AndroidSerialNumber string

	OS              string `redis:"os"`
	Platform        string `redis:"platform"`
	PlatformVersion string `redis:"platformVersion"`
	Arch            string `redis:"arch"`
	BootTime        int64  `redis:"bootTime"`

	Macs string `redis:"macs"`

	CPUModuleName string  `redis:"cpuModuleName"`
	CPUCores      int     `redis:"cpuCores"`
	CPUMhz        float64 `redis:"cpuMhz"`

	TotalMemory     int64 `redis:"totalMemory"`
	UsedMemory      int64 `redis:"usedMemory"`
	AvailableMemory int64 `redis:"availableMemory"`

	TotalDisk int64 `redis:"totalDisk"`
	FreeDisk  int64 `redis:"freeDisk"`

	Baseboard string `redis:"baseboard"`

	LastActivityTime time.Time `redis:"lastActivityTime"`

	// Controller *Controller

	IP string `redis:"ip"`

	// AppList []*App

	// WorkingDir string
	Channel string `redis:"channel"`
}

func (redis *Redis) SetNode(ctx context.Context, n *Node) error {
	if n == nil {
		return fmt.Errorf("Redis.SetNode: node can not empty")
	}

	if len(n.ID) == 0 {
		return fmt.Errorf("Redis.SetNode: node ID can not empty")
	}

	key := fmt.Sprintf(RedisKeyNode, n.ID)
	err := redis.client.HSet(ctx, key, n).Err()
	if err != nil {
		return err
	}

	return nil
}

func (redis *Redis) GetNode(ctx context.Context, nodeID string) (*Node, error) {
	if len(nodeID) == 0 {
		return nil, fmt.Errorf("Redis.GetNode: nodeID can not empty")
	}

	key := fmt.Sprintf(RedisKeyNode, nodeID)
	res := redis.client.HGetAll(ctx, key)
	if res.Err() != nil {
		return nil, res.Err()
	}

	var n Node
	if err := res.Scan(&n); err != nil {
		return nil, err
	}

	return &n, nil
}
