package controller

import (
	"agent/dev"
	"agent/luamod"

	log "github.com/sirupsen/logrus"
	libs "github.com/vadv/gopher-lua-libs"
	lua "github.com/yuin/gopher-lua"
)

type Script struct {
	appDir  string
	fileMD5 string

	eventsChan chan luamod.ScriptEvent

	state *lua.LState

	modTable *lua.LTable

	timerModule *luamod.TimerModule

	downloadModule *luamod.DownloadModule

	processModule *luamod.ProcessModule
}

func (s *Script) events() <-chan luamod.ScriptEvent {
	return s.eventsChan
}

func (s *Script) PushEvent(event luamod.ScriptEvent) {
	s.eventsChan <- event
}

func (s *Script) handleEvent(evt luamod.ScriptEvent) {
	switch evt.EventType() {
	case "timer":
		e := evt.(*luamod.TimerEvent)
		if e != nil && s.timerModule.HasTimer(e.Tag()) {
			s.callModFunction1(e.Callback(), lua.LString(e.Tag()))
		}
	case "download":
		e := evt.(*luamod.DownloadEvent)
		if e != nil {
			s.downloadModule.Delete(e.Tag())
			t := s.state.NewTable()
			t.RawSet(lua.LString("tag"), lua.LString(e.Tag()))
			t.RawSet(lua.LString("filePath"), lua.LString(e.FilePath()))
			t.RawSet(lua.LString("md5"), lua.LString(e.Md5()))
			t.RawSet(lua.LString("err"), lua.LString(e.Err()))
			s.callModFunction1(e.Callback(), t)
		}
	case "process":
		e := evt.(*luamod.ProcessEvent)
		if e != nil {
			s.processModule.Delete(e.Name())
		}

	}
}

func newScript(appDir string, scriptFileMD5 string, fileContent []byte) *Script {
	s := &Script{
		appDir:     appDir,
		fileMD5:    scriptFileMD5,
		eventsChan: make(chan luamod.ScriptEvent, 64),
	}

	s.state = lua.NewState()

	if len(fileContent) > 0 {
		s.load(fileContent)
	}

	return s
}

func (s *Script) start() {
	ls := s.state

	s.timerModule = luamod.NewTimerModule(s)
	ls.PreloadModule("timer", s.timerModule.Loader)

	s.downloadModule = luamod.NewDownloaderModule(s)
	ls.PreloadModule("downloader", s.downloadModule.Loader)

	s.processModule = luamod.NewProcessModule(s)
	ls.PreloadModule("process", s.processModule.Loader)

	ls.PreloadModule("agent", luamod.NewAgentModule().Loader)

	libs.Preload(ls)

	s.setInfoModule()

	if s.modTable != nil {
		// exec 'start' funciton in lua mod
		s.callModFunction0("start")
	}
}

func (s *Script) HasLuaFunction(funcName string) bool {
	if s.modTable != nil {
		fn := s.state.GetField(s.modTable, funcName)
		return fn != nil
	}

	return false
}

func (s *Script) callModFunction0(funcName string) {
	ls := s.state
	fn := ls.GetField(s.modTable, funcName)
	if fn != nil {
		ls.Push(fn)
		err := ls.PCall(0, lua.MultRet, nil)
		if err != nil {
			log.Errorf("callModFunction0 %s failed:%v", funcName, err)
		}
	}
}

func (s *Script) callModFunction1(funcName string, param0 lua.LValue) {
	ls := s.state
	fn := ls.GetField(s.modTable, funcName)
	if fn != nil {
		ls.Push(fn)
		ls.Push(param0)
		err := ls.PCall(1, lua.MultRet, nil)
		if err != nil {
			log.Errorf("callModFunction1 %s failed:%v", funcName, err)
		}
	}
}

func (s *Script) stop() {
	ls := s.state
	if s.modTable != nil {
		// exec 'stop' funciton in lua mod
		s.callModFunction0("stop")
	}

	ls.Close()
	s.state = nil
	s.modTable = nil
	s.timerModule.Clear()
	s.timerModule = nil
	s.downloadModule.Clear()
	s.downloadModule = nil
	s.processModule.Clear()
	s.processModule = nil
}

func (s *Script) load(fileContent []byte) {
	ls := s.state
	fn, err := ls.LoadString(string(fileContent))
	if err != nil {
		log.Errorf("lstate load string failed:%v", err)
		return
	}

	ls.Push(fn)
	err = ls.PCall(0, lua.MultRet, nil)
	if err != nil {
		log.Errorf("lstate PCall failed:%v", err)
		return
	}

	s.modTable = ls.ToTable(-1)
}

func (s *Script) setInfoModule() {
	ls := s.state

	devInfo := dev.GetDevInfo()
	infoTable := devInfo.ToLuaTable(ls)
	infoTable.RawSet(lua.LString("appDir"), lua.LString(s.appDir))
	ls.PreloadModule("dev", luamod.NewInfoModule(infoTable).Loader)

}
