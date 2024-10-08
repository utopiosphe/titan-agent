package server

import (
	"encoding/json"
	"os"
)

type Config struct {
	LuaFileList        []*File `json:"luaList"`
	ControllerFileList []*File `json:"controllerList"`
	AppFileList        []*App  `json:"appList"`
}

type File struct {
	Version string `json:"version"`
	MD5     string `json:"md5"`
	URL     string `json:"url"`
	OS      string `json:"os"`
}

type App struct {
	AppName string `json:"name"`
	// relative app dir
	AppDir     string `json:"appDir"`
	ScriptName string `json:"scriptName"`
	ScriptMD5  string `json:"scriptMD5"`
	ScriptURL  string `json:"scriptURL"`
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
