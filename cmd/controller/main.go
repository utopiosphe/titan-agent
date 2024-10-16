package main

import (
	"agent/controller"
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	log "github.com/sirupsen/logrus"
	"github.com/urfave/cli/v2"
)

var versionCmd = &cli.Command{
	Name: "version",
	Before: func(cctx *cli.Context) error {
		return nil
	},
	Action: func(cctx *cli.Context) error {
		fmt.Println(controller.Version)
		return nil
	},
}
var runCmd = &cli.Command{
	Name:  "run",
	Usage: "run controller",
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
		&cli.StringFlag{
			Name:    "uuid",
			Usage:   "--uuid fbf600d4-8ada-11ef-9e79-c3ce2c7cb2d3",
			EnvVars: []string{"UUID"},
			Value:   "",
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
			UUID:                  cctx.String("uuid"),
		}

		ctr, err := controller.New(agrs)
		if err != nil {
			log.Fatal(err)
		}

		ctx, done := context.WithCancel(context.Background())
		sigChan := make(chan os.Signal, 2)
		go func() {
			<-sigChan
			done()
		}()

		signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT, syscall.SIGHUP)
		return ctr.Run(ctx)
	},
}

func main() {
	log.AddHook(&controller.LogHook{
		Fields: log.Fields{
			"app":     "controller",
			"version": controller.Version,
		},
		LogLevels: log.AllLevels,
	})

	commands := []*cli.Command{
		runCmd,
		versionCmd,
	}

	app := &cli.App{
		Name:     "controller",
		Usage:    "Manager and update application",
		Commands: commands,
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}
