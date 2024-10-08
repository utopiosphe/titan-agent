package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

// Define a custom multiplexer type
type CustomServeMux struct {
	routes map[string]http.Handler
}

func NewCustomServerMux(config *Config) *CustomServeMux {
	handler := CustomHandler{config: config, devMgr: newDevMgr(context.Background())}

	mux := &CustomServeMux{routes: make(map[string]http.Handler)}
	mux.Handle("/update/lua", http.HandlerFunc(handler.handleLuaUpdate))
	mux.Handle("/update/controller", http.HandlerFunc(handler.handleControllerUpdate))
	mux.Handle("/update/apps", http.HandlerFunc(handler.handleAppsUpdate))
	mux.Handle("/device/list", http.HandlerFunc(handler.handleDeviceList))

	return mux
}

// Implement the ServeHTTP method for CustomServeMux
func (mux *CustomServeMux) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	handler, found := mux.routes[r.URL.Path]
	if found {
		handler.ServeHTTP(w, r)
	} else {
		http.DefaultServeMux.ServeHTTP(w, r)
		// http.NotFound(w, r)
	}
}

// Register a route with the custom multiplexer
func (mux *CustomServeMux) Handle(pattern string, handler http.Handler) {
	mux.routes[pattern] = handler
}

type CustomHandler struct {
	// luaDir string
	config *Config
	devMgr *DevMgr
}

func (h *CustomHandler) handleLuaUpdate(w http.ResponseWriter, r *http.Request) {
	fmt.Printf("handleLuaUpdate, queryString %s\n", r.URL.RawQuery)

	d := NewDeviceFromURLQuery(r.URL.Query())
	if d != nil {
		h.devMgr.updateDevice(d)
	}

	version := r.URL.Query().Get("version")

	var file *File = nil
	for _, f := range h.config.LuaFileList {
		if f.Version == version {
			file = f
			break
		}
	}

	if file == nil {
		resultError(w, http.StatusBadRequest, fmt.Sprintf("can not find the version %s script", version))
		return
	}

	buf, err := json.Marshal(file)
	if err != nil {
		resultError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Write(buf)
}

func (h *CustomHandler) handleControllerUpdate(w http.ResponseWriter, r *http.Request) {
	fmt.Printf("handleBusinessUpdate, queryString %s\n", r.URL.RawQuery)

	version := r.URL.Query().Get("version")
	os := r.URL.Query().Get("os")

	var file *File = nil
	for _, f := range h.config.ControllerFileList {
		if f.Version == version && f.OS == os {
			file = f
			break
		}
	}

	if file == nil {
		resultError(w, http.StatusBadRequest, fmt.Sprintf("can not find the version %s script", version))
		return
	}

	buf, err := json.Marshal(file)
	if err != nil {
		resultError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Write(buf)
}

func (h *CustomHandler) handleAppsUpdate(w http.ResponseWriter, r *http.Request) {
	fmt.Printf("handleAppsUpdate, queryString %s\n", r.URL.RawQuery)

	// version := r.URL.Query().Get("version")
	// os := r.URL.Query().Get("os")

	// var file *File = nil
	// for _, f := range h.config.AppFileList {
	// 	if f.Version == version && f.OS == os {
	// 		file = f
	// 		break
	// 	}
	// }

	// if file == nil {
	// 	resultError(w, http.StatusBadRequest, fmt.Sprintf("can not find the version %s script", version))
	// 	return
	// }

	buf, err := json.Marshal(h.config.AppFileList)
	if err != nil {
		resultError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Write(buf)
}

func (h *CustomHandler) handleDeviceList(w http.ResponseWriter, r *http.Request) {
	devices := h.devMgr.getAll()
	buf, err := json.Marshal(devices)
	if err != nil {
		resultError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Write(buf)
}

func resultError(w http.ResponseWriter, statusCode int, errMsg string) {
	w.WriteHeader(statusCode)
	w.Write([]byte(errMsg))
}
