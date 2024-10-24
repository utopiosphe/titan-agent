package main

import (
	"agent/controller"
	"context"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

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

var testCmd = &cli.Command{
	Name: "test",
	Flags: []cli.Flag{
		&cli.StringFlag{
			Name:     "path",
			Usage:    "--path=/path/to/luafile",
			Required: true,
			Value:    "",
		},
		&cli.IntFlag{
			Name:  "time",
			Usage: "--time 60",
			Value: 60,
		},
	},
	Before: func(cctx *cli.Context) error {
		return nil
	},

	Action: func(cctx *cli.Context) error {
		luaPath := cctx.String("path")
		controllerArgs := &controller.ConrollerArgs{WorkingDir: filepath.Dir(luaPath), RelAppsDir: ""}
		appConfig := &controller.AppConfig{AppName: "test", AppDir: "", ScriptName: filepath.Base(luaPath)}

		args := &controller.AppArguments{ControllerArgs: controllerArgs, AppConfig: appConfig}
		app, err := controller.NewApplication(args, nil)
		if err != nil {
			return err
		}

		t := cctx.Int("time")

		go func() {
			time.Sleep(time.Duration(t) * time.Second)
			app.Stop()
		}()

		app.Run()
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
		&cli.StringFlag{
			Name:    "log-file",
			Usage:   "--log-file /path/to/logfile",
			EnvVars: []string{"LOG_FILE"},
			Value:   "",
		},
	},
	Before: func(cctx *cli.Context) error {
		return nil
	},
	Action: func(cctx *cli.Context) error {
		// set log file
		logFile := cctx.String("log-file")
		if len(logFile) != 0 {
			file, err := os.OpenFile(logFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
			if err != nil {
				log.Fatalf("open file %s, failed:%s", logFile, err.Error())
			}
			defer file.Close()

			log.SetOutput(file)
			os.Stdout = file
		}

		args := &controller.ConrollerArgs{
			WorkingDir:            cctx.String("working-dir"),
			ServerURL:             cctx.String("server-url"),
			ScriptUpdateInvterval: cctx.Int("script-interval"),
			AppConfigsFileName:    cctx.String("appconfigs-filename"),
			RelAppsDir:            cctx.String("rel-apps-dir"),
			UUID:                  cctx.String("uuid"),
		}

		ctr, err := controller.New(args)
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
	commands := []*cli.Command{
		runCmd,
		versionCmd,
		testCmd,
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
