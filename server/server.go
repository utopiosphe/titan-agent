package server

import (
	"context"
	"net/http"
)

// Define a custom multiplexer type
type ServeMux struct {
	routes map[string]http.Handler
}

func NewServerMux(config *Config) *ServeMux {
	handler := ServerHandler{config: config, devMgr: newDevMgr(context.Background())}

	mux := &ServeMux{routes: make(map[string]http.Handler)}
	// /update/lua support old agent
	mux.Handle("/update/lua", http.HandlerFunc(handler.handleLuaUpdate))
	mux.Handle("/config/lua", http.HandlerFunc(handler.handleGetLuaConfig))
	mux.Handle("/config/controller", http.HandlerFunc(handler.handleGetControllerConfig))
	mux.Handle("/config/apps", http.HandlerFunc(handler.handleGetAppsConfig))

	mux.Handle("/device/list", http.HandlerFunc(handler.handleDeviceList))
	mux.Handle("/controller/list", http.HandlerFunc(handler.handleControllerList))
	mux.Handle("/app/list", http.HandlerFunc(handler.handleAppList))
	mux.Handle("/app/info", http.HandlerFunc(handler.handleAppInfo))

	mux.Handle("/push/metrics", http.HandlerFunc(handler.handlePushMetrics))

	return mux
}

// Implement the ServeHTTP method for CustomServeMux
func (mux *ServeMux) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	handler, found := mux.routes[r.URL.Path]
	if found {
		handler.ServeHTTP(w, r)
	} else {
		http.DefaultServeMux.ServeHTTP(w, r)
	}
}

// Register a route with the custom multiplexer
func (mux *ServeMux) Handle(pattern string, handler http.Handler) {
	mux.routes[pattern] = handler
}
