package server

import (
	"encoding/json"
	"os"
)

type Config struct {
	LuaFileList        []*File              `json:"luaList"`
	ControllerFileList []*File              `json:"controllerList"`
	AppFileList        []*App               `json:"appList"`
	Resources          map[string]*Resource `json:"resources"`
	NodeTags           map[string][]string  `json:"nodeTags"`
	TestNodes          map[string]*TestApp  `json:"testNodes"`
}

type File struct {
	Name    string `json:"name"`
	Version string `json:"version"`
	MD5     string `json:"md5"`
	URL     string `json:"url"`
	OS      string `json:"os"`
	Tag     string `json:"tag"`
}

type App struct {
	AppName string `json:"name"`
	// relative app dir
	AppDir       string   `json:"appDir"`
	ScriptName   string   `json:"scriptName"`
	AppVersion   string   `json:"appVersion"`
	ScriptMD5    string   `json:"scriptMD5"`
	ScriptURL    string   `json:"scriptURL"`
	ReqResources []string `json:"reqResources"`
	Tag          string   `json:"tag"`
}

type Resource struct {
	Name        string `json:"name"`
	OS          string `json:"os"`
	MinCPU      int    `json:"minCPU"`
	MinMemoryMB int64  `json:"minMemoryMB"`
	MinDiskGB   int64  `json:"minDiskGB"`
}

type TestApp struct {
	LuaScript  string   `json:"luaScript"`
	Controller string   `json:"controller"`
	Apps       []string `json:"apps"`
}

func ParseConfig(filePath string) (*Config, error) {
	buf, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}

	config := Config{}
	err = json.Unmarshal(buf, &config)
	if err != nil {
		return nil, err
	}

	return &config, nil
}
