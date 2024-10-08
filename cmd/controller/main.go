package main

import (
	"agent/controller"
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/urfave/cli/v2"
)

func main() {
	app := &cli.App{
		Name:  "agent",
		Usage: "Manager and update business process",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:     "working-dir",
				Usage:    "--working-dir=/path/to/working/dir",
				EnvVars:  []string{"WORKING_DIR"},
				Required: true,
				Value:    "",
			},
			&cli.IntFlag{
				Name:    "script-interval",
				Usage:   "--script-interval 60",
				EnvVars: []string{"SCRIPT_INTERVAL"},
				Value:   60,
			},
			&cli.StringFlag{
				Name:     "server-url",
				Usage:    "--server-url http://localhost:8080/update/lua",
				EnvVars:  []string{"SERVER_URL"},
				Required: true,
				Value:    "http://localhost:8080/update/lua",
			},
			&cli.StringFlag{
				Name:    "rel-apps-dir",
				Usage:   "--rel-app-dir apps",
				EnvVars: []string{"RELATIVE_APPS_DIR"},
				Value:   "apps",
			},
			&cli.StringFlag{
				Name:    "appconfigs-filename",
				Usage:   "--appconfigs-filename config.json",
				EnvVars: []string{"APPCONFIGFS_FILENAME"},
				Value:   "config.json",
			},
		},
		Before: func(cctx *cli.Context) error {
			return nil
		},
		Action: func(cctx *cli.Context) error {
			agrs := &controller.ConrollerArgs{
				WorkingDir:            cctx.String("working-dir"),
				ServerURL:             cctx.String("server-url"),
				ScriptUpdateInvterval: cctx.Int("script-interval"),
				AppConfigsFileName:    cctx.String("appconfigs-filename"),
				RelAppsDir:            cctx.String("rel-apps-dir"),
			}

			ctr, err := controller.New(agrs)
			if err != nil {
				log.Fatal(err)
			}

			ctx, done := context.WithTimeout(context.Background(), 10*time.Second)
			sigChan := make(chan os.Signal, 2)
			go func() {
				<-sigChan
				done()
			}()

			signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT, syscall.SIGHUP)
			return ctr.Run(ctx)
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}
