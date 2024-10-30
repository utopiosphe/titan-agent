package server

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"

	log "github.com/sirupsen/logrus"
)

type ServerHandler struct {
	config *Config
	devMgr *DevMgr
	// appMap sync.Map
}

func (h *ServerHandler) handleGetLuaConfig(w http.ResponseWriter, r *http.Request) {
	h.handleLuaUpdate(w, r)
}

func (h *ServerHandler) handleLuaUpdate(w http.ResponseWriter, r *http.Request) {
	log.Debugf("handleLuaUpdate, queryString %s\n", r.URL.RawQuery)

	d := NewDeviceFromURLQuery(r.URL.Query())
	if d != nil {
		d.IP = getReadIP(r)
		h.devMgr.updateAgent(d)
	}

	os := r.URL.Query().Get("os")
	uuid := r.URL.Query().Get("uuid")

	var testScripName string
	testNode := h.config.TestNodes[uuid]
	if testNode != nil {
		testScripName = testNode.LuaScript
	}

	log.Printf("testNode %#v", testNode)
	var file *FileConfig = nil
	for _, f := range h.config.LuaFileList {
		if len(testScripName) > 0 {
			if f.Name == testScripName {
				file = f
				break
			}
		} else if f.OS == os {
			file = f
			break
		}
	}

	if file == nil {
		resultError(w, http.StatusBadRequest, fmt.Sprintf("can not find the os %s script", os))
		return
	}

	buf, err := json.Marshal(file)
	if err != nil {
		resultError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Write(buf)
}

func (h *ServerHandler) handleGetControllerConfig(w http.ResponseWriter, r *http.Request) {
	log.Debugf("handleGetControllerConfig, queryString %s\n", r.URL.RawQuery)
	// version := r.URL.Query().Get("version")
	os := r.URL.Query().Get("os")
	uuid := r.URL.Query().Get("uuid")

	var testControllerName string
	testNode := h.config.TestNodes[uuid]
	if testNode != nil {
		testControllerName = testNode.Controller
	}

	var file *FileConfig = nil
	for _, f := range h.config.ControllerFileList {
		if len(testControllerName) > 0 {
			if f.Name == testControllerName {
				file = f
				break
			}
		} else if f.OS == os {
			file = f
			break
		}
	}

	if file == nil {
		resultError(w, http.StatusBadRequest, fmt.Sprintf("can not find the os %s", os))
		return
	}

	buf, err := json.Marshal(file)
	if err != nil {
		resultError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Write(buf)
}

func (h *ServerHandler) handleGetAppsConfig(w http.ResponseWriter, r *http.Request) {
	log.Debugf("handleGetAppsConfig, queryString %s\n", r.URL.RawQuery)

	d := NewDeviceFromURLQuery(r.URL.Query())
	if d != nil {
		d.IP = getReadIP(r)
		h.devMgr.updateController(d)
	}

	uuid := r.URL.Query().Get("uuid")
	channel := r.URL.Query().Get("channel")

	var testApps []string
	testNode := h.config.TestNodes[uuid]
	if testNode != nil {
		testApps = testNode.Apps
	}

	appList := make([]*AppConfig, 0, len(h.config.AppList))
	for _, app := range h.config.AppList {
		if len(testApps) > 0 {
			if h.isTestApp(app.AppName, testApps) {
				appList = append(appList, app)
			}
		} else if len(channel) > 0 {
			// TODO handle channel
			if h.isAppMatchChannel(app.AppName, channel) {
				appList = append(appList, app)
			}
			// log.Infof("ServerHandler.handleGetAppsConfig channel %s", channel)
		} else if h.isResourceMatchApp(r, app.ReqResources) {
			appList = append(appList, app)
		}
	}

	if len(appList) == 0 {
		log.Infof("ServerHandler.handleGetAppsConfig len(appList) == 0, uuid:%s, os:%s", r.URL.Query().Get("uuid"), r.URL.Query().Get("os"))
	}

	buf, err := json.Marshal(appList)
	if err != nil {
		resultError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Write(buf)
}

func (h *ServerHandler) isResourceMatchApp(r *http.Request, reqResources []string) bool {
	os, cpu, memoryMB, diskGB := getResource(r)
	for _, reqResourceName := range reqResources {
		reqRes := h.config.Resources[reqResourceName]
		if reqRes == nil {
			continue
		}

		if reqRes.OS == os && cpu >= reqRes.MinCPU && memoryMB >= reqRes.MinMemoryMB && diskGB >= reqRes.MinDiskGB {
			return true
		}
	}
	return false
}

func (h *ServerHandler) isTestApp(appName string, testAppNames []string) bool {
	if len(testAppNames) == 0 {
		return false
	}

	for _, testAppName := range testAppNames {
		if appName == testAppName {
			return true
		}
	}

	return false
}

func (h *ServerHandler) isAppMatchChannel(appName string, channel string) bool {
	apps := h.config.ChannelApps[channel]
	if len(apps) == 0 {
		return false
	}

	log.Info("isAppMatchChannel apps", apps, "current app", appName)
	for _, app := range apps {
		if appName == app {
			return true
		}
	}

	return false
}

func (h *ServerHandler) handleAgentList(w http.ResponseWriter, r *http.Request) {
	log.Debugf("handleAgentList, queryString %s\n", r.URL.RawQuery)

	devices := h.devMgr.getAgents()

	result := struct {
		Total   int       `json:"total"`
		Devices []*Device `json:"devices"`
	}{
		Total:   len(devices),
		Devices: devices,
	}

	formattedJSON, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		http.Error(w, "Failed to format JSON", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(formattedJSON)
}

func (h *ServerHandler) handleControllerList(w http.ResponseWriter, r *http.Request) {
	log.Debugf("handleControllerList, queryString %s\n", r.URL.RawQuery)

	devices := h.devMgr.getControllers()

	result := struct {
		Total   int       `json:"total"`
		Devices []*Device `json:"devices"`
	}{
		Total:   len(devices),
		Devices: devices,
	}

	formattedJSON, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		http.Error(w, "Failed to format JSON", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(formattedJSON)
}

func (h *ServerHandler) handleAppList(w http.ResponseWriter, r *http.Request) {
}

func (h *ServerHandler) handleAppInfo(w http.ResponseWriter, r *http.Request) {
	uuid := r.URL.Query().Get("uuid")
	appName := r.URL.Query().Get("appName")

	b, err := io.ReadAll(r.Body)
	if err != nil {
		log.Error("CustomHandler.handleAppInfo read body failed: ", err.Error())
		resultError(w, http.StatusBadRequest, err.Error())
		return
	}

	if len(b) == 0 {
		log.Error("CustomHandler.handleAppInfo read body is empty")
		resultError(w, http.StatusBadRequest, "body is empty")
		return
	}

	scanner := bufio.NewScanner(bytes.NewReader(b))

	// Scan and print each line
	for scanner.Scan() {
		line := scanner.Text()
		fmt.Println(line)
	}
	log.Infof("uuid:%s, appName:%s\n", uuid, appName)

	// Check for any errors
	if err := scanner.Err(); err != nil {
		fmt.Println("Error reading bytes:", err)
	}

	// TODO: add exterInfo to app

}

func (h *ServerHandler) handlePushMetrics(w http.ResponseWriter, r *http.Request) {
	uuid := r.URL.Query().Get("uuid")
	c := h.devMgr.getController(uuid)
	if c == nil {
		log.Errorf("ServerHandler.handlePushMetrics controller %s not exist", uuid)
		resultError(w, http.StatusBadRequest, fmt.Sprintf("controller %s not exist", uuid))
		return
	}
	// appName := r.URL.Query().Get("appName")

	b, err := io.ReadAll(r.Body)
	if err != nil {
		log.Error("ServerHandler.handlePushMetrics read body failed: ", err.Error())
		resultError(w, http.StatusBadRequest, err.Error())
		return
	}

	if len(b) == 0 {
		log.Error("ServerHandler.handlePushMetrics read body is empty")
		resultError(w, http.StatusBadRequest, "body is empty")
		return
	}

	log.Info("ServerHandler.handlePushMetrics ", string(b))

	apps := make([]*App, 0)
	err = json.Unmarshal(b, &apps)
	if err != nil {
		log.Error("ServerHandler.handlePushMetrics Unmarshal failed:", err.Error())
		resultError(w, http.StatusBadRequest, err.Error())
		return
	}

	c.AppList = apps
}

func resultError(w http.ResponseWriter, statusCode int, errMsg string) {
	w.WriteHeader(statusCode)
	w.Write([]byte(errMsg))
}

// cpu/number memory/MB disk/GB
func getResource(r *http.Request) (os string, cpu int, memory int64, disk int64) {
	os = r.URL.Query().Get("os")

	cpuStr := r.URL.Query().Get("cpu")
	memoryStr := r.URL.Query().Get("memory")
	diskStr := r.URL.Query().Get("disk")

	cpu = stringToInt(cpuStr)

	memoryBytes := stringToInt64(memoryStr)
	memory = memoryBytes / (1024 * 1024)

	diskBytes := stringToInt64(diskStr)
	disk = diskBytes / (1024 * 1024 * 1024)
	return
}

func getReadIP(r *http.Request) string {
	realIP := r.Header.Get("X-Real-IP")
	if len(realIP) == 0 {
		realIP, _, _ = net.SplitHostPort(r.RemoteAddr)
	}
	return realIP
}
