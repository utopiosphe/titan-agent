package controller

import (
	"context"
	"crypto/md5"
	"fmt"
	"os"
	"path"

	log "github.com/sirupsen/logrus"
)

type AppArguments struct {
	AppsWorkingDir string
	AppConfig      *AppConfig
}

type Application struct {
	args *AppArguments

	script *Script

	scriptFileMD5     string
	scriptFileContent []byte

	ctx       context.Context
	ctxCancel context.CancelFunc
	stopCh    chan bool
}

func NewApplication(args *AppArguments) (*Application, error) {
	ctx, cancel := context.WithCancel(context.Background())
	app := &Application{
		args:      args,
		stopCh:    make(chan bool),
		ctx:       ctx,
		ctxCancel: cancel,
	}

	if err := app.loadScript(); err != nil {
		return nil, err
	}

	app.renewScript()

	return app, nil
}

func (app *Application) Stop() {
	// app.eventsChan <- &StopEvent{}
	app.ctxCancel()
	<-app.stopCh
	log.Printf("app %s stop", app.args.AppConfig.AppName)
}

func (app *Application) Run() error {
	loop := true

	for loop {
		script := app.currentScript()
		select {
		case ev := <-script.events():
			script.handleEvent(ev)
		case <-app.ctx.Done():
			script.stop()
			loop = false
			log.Info("ctx done, Run() will quit")
		}
	}

	app.stopCh <- true
	return nil
}

func (app *Application) currentScript() *Script {
	return app.script
}

func (app *Application) renewScript() {
	oldScript := app.script
	if oldScript != nil {
		oldScript.stop()
	}

	newScript := newScript(app.scriptFileMD5, app.scriptFileContent)
	newScript.start()

	app.script = newScript
}

func (app *Application) loadScript() error {
	scriptPath := path.Join(app.args.AppsWorkingDir, app.args.AppConfig.AppDir, app.args.AppConfig.ScriptName)
	b, err := os.ReadFile(scriptPath)
	if err != nil {
		return err
	}

	app.scriptFileContent = b
	app.scriptFileMD5 = fmt.Sprintf("%x", md5.Sum(b))

	return nil
}
