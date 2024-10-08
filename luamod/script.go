package luamod

type Script interface {
	PushEvent(event ScriptEvent)
	HasLuaFunction(string) bool
}

type ScriptEvent interface {
	EventType() string
}
