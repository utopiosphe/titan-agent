package main

import (
	"agent/agent"
	"context"
	"log"
	"time"
)

func main() {
	// memory, err := ghw.Memory()
	// if err != nil {
	// 	log.Print(err)
	// }
	// fmt.Println(memory.JSONString(true))

	// blk, err := ghw.Block()
	// if err != nil {
	// 	log.Print(err)
	// }
	// // blk.Disks[0].Model = "test"
	// fmt.Println(blk.JSONString(true))

	// gpu, err := ghw.GPU()
	// if err != nil {
	// 	log.Print(err)
	// }
	// fmt.Println(gpu.JSONString(true))

	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)
	statsCh, err := agent.MonitorNetworkStats(1*time.Second, ctx.Done())
	if err != nil {
		log.Fatal(err)
	}

	go func() {
		time.AfterFunc(30*time.Second, cancel)
	}()

	for {
		select {
		case stats := <-statsCh:
			log.Printf("Network stats: %+v", stats)

		case <-ctx.Done():
			log.Print("Cancelled")
			cancel()
			return
		}
	}

}
