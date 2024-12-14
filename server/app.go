package server

type App struct {
	AppName string `json:"name"`
	// relative app dir
	AppDir     string `json:"appDir"`
	ScriptName string `json:"scriptName"`
	ScriptMD5  string `json:"scriptMD5"`
	ScriptURL  string `json:"scriptURL"`
	Version    string `json:"version"`
	Metric     string `json:"metric"`
}
