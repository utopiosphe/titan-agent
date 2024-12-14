package server

import (
	"agent/redis"
	"context"
	"net/http"
)

const APIErrCode = 1

type APIResult struct {
	ErrCode int
	ErrMsg  string
	Data    interface{}
}

// Define a custom multiplexer type
type Server struct {
	routes map[string]http.Handler
}

func NewServer(config *Config) *Server {
	redis := redis.NewRedis(config.RedisAddr)
	handler := newServerHandler(config, newDevMgr(context.Background(), redis), redis)

	s := &Server{routes: make(map[string]http.Handler)}
	// /update/lua support old agent
	s.handle("/update/lua", http.HandlerFunc(handler.handleLuaUpdate))
	s.handle("/config/lua", http.HandlerFunc(handler.handleGetLuaConfig))
	s.handle("/config/controller", http.HandlerFunc(handler.handleGetControllerConfig))
	s.handle("/config/apps", http.HandlerFunc(handler.handleGetAppsConfig))

	s.handle("/agent/list", http.HandlerFunc(handler.handleAgentList))
	s.handle("/controller/list", http.HandlerFunc(handler.handleControllerList))

	s.handle("/api/applist", http.HandlerFunc(handler.handleGetAppList))
	s.handle("/api/appinfo", http.HandlerFunc(handler.handleGetAppInfo))

	s.handle("/push/metrics", http.HandlerFunc(handler.handlePushMetrics))
	s.handle("/push/appinfo", http.HandlerFunc(handler.handlePushAppInfo))

	return s
}

// Implement the ServeHTTP method for CustomServeMux
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	handler, found := s.routes[r.URL.Path]
	if found {
		handler.ServeHTTP(w, r)
	} else {
		http.DefaultServeMux.ServeHTTP(w, r)
	}
}

// Register a route with the custom multiplexer
func (s *Server) handle(pattern string, handler http.Handler) {
	s.routes[pattern] = handler
}
