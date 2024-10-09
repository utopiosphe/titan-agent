package controller

import (
	"agent/dev"
	"context"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"time"

	log "github.com/sirupsen/logrus"
)

const (
	Version     = "0.1.1"
	httpTimeout = 10 * time.Second
)

type ConrollerArgs struct {
	WorkingDir            string
	ScriptUpdateInvterval int
	ServerURL             string
	RelAppsDir            string
	AppConfigsFileName    string
}

type App struct {
	appConfig *AppConfig
	app       *Application
}

type Controller struct {
	args          *ConrollerArgs
	appConfigs    []*AppConfig
	appConfigsMD5 string
	apps          map[string]*App
}

func New(args *ConrollerArgs) (*Controller, error) {
	c := &Controller{apps: make(map[string]*App), args: args}

	appsDir := path.Join(args.WorkingDir, args.RelAppsDir)
	err := os.MkdirAll(appsDir, os.ModePerm)
	if err != nil {
		return nil, err
	}

	return c, nil
}

func (c *Controller) Run(ctx context.Context) error {
	c.loadLocal()
	c.updateAppsFromServer()
	c.newApps()

	scriptUpdateinterval := time.Second * time.Duration(c.args.ScriptUpdateInvterval)
	ticker := time.NewTicker(scriptUpdateinterval)
	appUpdateTime := time.Now()
	for {
		select {
		case <-ticker.C:
			elapsed := time.Since(appUpdateTime)
			if elapsed > scriptUpdateinterval {
				err := c.updateAppsFromServer()
				if err == nil {
					c.renewApps()
				} else {
					log.Infof("Controller.Run updateAppsFromServer %s", err.Error())
				}
				appUpdateTime = time.Now()
			}
		case <-ctx.Done():
			c.onStop()
			return nil
		}

	}

}

func (c *Controller) loadLocal() {
	appConfigs, err := c.loadLocalAppConfigs()
	if err != nil {
		log.Errorf("Controller.loadLocal load apps config:%v", err)
		return
	}

	c.appConfigsMD5 = c.configMD5(appConfigs)
	c.appConfigs = appConfigs
}

func (c *Controller) configMD5(appConfigs []*AppConfig) string {
	b, err := json.Marshal(appConfigs)
	if err != nil {
		log.Errorf("Controller.configMD5 Marshal:%s", err.Error())
		return ""
	}

	return fmt.Sprintf("%x", md5.Sum(b))
}

func (c *Controller) newApps() {
	if len(c.appConfigs) == 0 {
		return
	}

	appsWorkingDir := path.Join(c.args.WorkingDir, c.args.RelAppsDir)
	for _, appConfig := range c.appConfigs {
		app, err := NewApplication(&AppArguments{AppsWorkingDir: appsWorkingDir, AppConfig: appConfig})
		if err != nil {
			log.Errorf("Controller.newApps NewApplication failed:%s", err.Error())
			continue
		}
		c.apps[appConfig.AppName] = &App{appConfig: appConfig, app: app}

		go app.Run()
	}

}

func (c *Controller) renewApps() {
	if len(c.appConfigs) == 0 {
		return
	}

	appConfigMap := make(map[string]*AppConfig)
	for _, appConfig := range c.appConfigs {
		appConfigMap[appConfig.AppName] = appConfig
	}

	removeApps := make([]*App, 0, len(c.apps))
	for _, app := range c.apps {
		appConfig, ok := appConfigMap[app.appConfig.AppName]
		if !ok {
			removeApps = append(removeApps, app)
			continue
		}

		if c.isAppConfigChange(app.appConfig, appConfig) {
			removeApps = append(removeApps, app)
		}
	}

	// remove apps
	for _, app := range removeApps {
		app.app.Stop()
		delete(c.apps, app.appConfig.AppName)
	}

	// new apps
	appsWorkingDir := path.Join(c.args.WorkingDir, c.args.RelAppsDir)
	for _, appConfig := range c.appConfigs {
		_, ok := c.apps[appConfig.AppName]
		if !ok {
			app, err := NewApplication(&AppArguments{AppsWorkingDir: appsWorkingDir, AppConfig: appConfig})
			if err != nil {
				log.Errorf("Controller.newApps NewApplication failed:%s", err.Error())
				continue
			}
			c.apps[appConfig.AppName] = &App{appConfig: appConfig, app: app}

			go app.Run()
		}
	}

}

func (c *Controller) loadLocalAppConfigs() ([]*AppConfig, error) {
	configFilePath := path.Join(c.args.WorkingDir, c.args.RelAppsDir, c.args.AppConfigsFileName)
	b, err := os.ReadFile(configFilePath)
	if err != nil {
		return nil, err
	}

	appsConfig := make([]*AppConfig, 0)
	err = json.Unmarshal(b, &appsConfig)
	if err != nil {
		return nil, err
	}

	return appsConfig, nil
}

// updateAppsFromServer just get apps from server and save on local
func (c *Controller) updateAppsFromServer() error {
	// load config from server
	appConfigs, err := c.getAppConfigsFromServer()
	if err != nil {
		return err
	}

	// Filtering invalid configurations
	newAppConfigs := make([]*AppConfig, 0, len(appConfigs))
	appConfigMap := make(map[string]*AppConfig)
	for _, appConfig := range appConfigs {
		if _, ok := appConfigMap[appConfig.AppName]; ok {
			continue
		}
		appConfigMap[appConfig.AppName] = appConfig
		newAppConfigs = append(newAppConfigs, appConfig)

	}

	if !c.isAppsChange(newAppConfigs) {
		return fmt.Errorf("apps not change")
	}

	for _, appConfig := range newAppConfigs {
		scriptContent, err := c.getScriptFromServer(appConfig.ScriptURL)
		if err != nil {
			log.Errorf("Controller.updateAppConfigAndScriptFromServer getScriptFromServer faile %v", err.Error())
			continue
		}

		newMD5 := fmt.Sprintf("%x", md5.Sum(scriptContent))
		if newMD5 != appConfig.ScriptMD5 {
			log.Errorf("Controller.updateAppConfigAndScriptFromServer script md5 not match")
			continue
		}

		err = c.saveScript(scriptContent, appConfig)
		if err != nil {
			log.Errorf("Controller.updateAppConfigAndScriptFromServer saveScript faile %v", err.Error())
			continue
		}

	}

	// remove excess apps
	for _, appConfig := range c.appConfigs {
		if _, ok := appConfigMap[appConfig.AppName]; !ok {
			if err = c.removeAppDir(appConfig); err != nil {
				log.Errorf("Controller.updateAppConfigAndScriptFromServer removeAppDir %s", err.Error())
			}
		}
	}

	if err = c.saveAppConfigs(newAppConfigs); err != nil {
		log.Errorf("Controller.updateAppConfigAndScriptFromServer saveAppConfigs faile %v", err.Error())
		return err
	}

	c.appConfigsMD5 = c.configMD5(newAppConfigs)
	c.appConfigs = newAppConfigs

	return nil
}

func (c *Controller) isAppsChange(newAppConfigs []*AppConfig) bool {
	if len(c.apps) != len(newAppConfigs) {
		return true
	}

	for _, appConfig := range newAppConfigs {
		app, ok := c.apps[appConfig.AppName]
		if !ok {
			return true
		}

		if c.isAppConfigChange(app.appConfig, appConfig) {
			return true
		}
	}

	return false
}

func (c *Controller) isAppConfigChange(appConfig1 *AppConfig, appConfig2 *AppConfig) bool {
	if appConfig1 == nil && appConfig2 == nil {
		return false
	}

	b1, err := json.Marshal(appConfig1)
	if err != nil {
		return true
	}

	b2, err := json.Marshal(appConfig2)
	if err != nil {
		return true
	}

	config1MD5 := fmt.Sprintf("%x", md5.Sum(b1))
	config2MD5 := fmt.Sprintf("%x", md5.Sum(b2))

	return config1MD5 != config2MD5

}

func (c *Controller) getAppConfigsFromServer() ([]*AppConfig, error) {
	// TODO: add query string
	info := dev.GetDevInfo()
	queryString := info.ToURLQuery()

	url := fmt.Sprintf("%s?%s", c.args.ServerURL, queryString.Encode())

	ctx, cancel := context.WithTimeout(context.Background(), httpTimeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("getScriptInfoFromServer status code: %d, msg: %s, url: %s", resp.StatusCode, string(body), url)
	}

	// Read and handle the response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	appsConfigs := make([]*AppConfig, 0)
	err = json.Unmarshal(body, &appsConfigs)
	if err != nil {
		return nil, nil
	}
	return appsConfigs, nil
}

func (c *Controller) getScriptFromServer(url string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), httpTimeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("getScriptInfoFromServer status code: %d, msg: %s, url: %s", resp.StatusCode, string(body), url)
	}

	// Read and handle the response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	return body, nil
}

func (c *Controller) saveScript(content []byte, appConfig *AppConfig) error {
	appDir := path.Join(c.args.WorkingDir, c.args.RelAppsDir, appConfig.AppDir)
	err := os.MkdirAll(appDir, os.ModePerm)
	if err != nil {
		return err
	}

	filePath := path.Join(appDir, appConfig.ScriptName)
	f, err := os.OpenFile(filePath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = f.Write(content)
	return err
}

func (c *Controller) saveAppConfigs(appConfigs []*AppConfig) error {
	appDir := path.Join(c.args.WorkingDir, c.args.RelAppsDir)
	err := os.MkdirAll(appDir, os.ModePerm)
	if err != nil {
		return err
	}

	filePath := path.Join(appDir, c.args.AppConfigsFileName)
	f, err := os.OpenFile(filePath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return err
	}
	defer f.Close()

	b, err := json.Marshal(appConfigs)
	if err != nil {
		return err
	}
	_, err = f.Write(b)
	return err
}

func (c *Controller) removeAppDir(appConfig *AppConfig) error {
	appDir := path.Join(c.args.WorkingDir, c.args.RelAppsDir, appConfig.AppDir)
	return os.RemoveAll(appDir)
}

func (c *Controller) onStop() {
	c.stopAllApps()

	log.Infof("Controller.onStop")
}

func (c *Controller) stopAllApps() {
	for _, app := range c.apps {
		app.app.Stop()
	}

}
