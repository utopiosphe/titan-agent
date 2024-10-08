package controller

type ControllerEvent interface {
	Type() string
}

type UpdateEvent struct {
	appConfig AppConfig
}

func (ue *UpdateEvent) Type() string {
	return "update"
}

type StopEvent struct {
}

func (se *StopEvent) Type() string {
	return "stop"
}

type AppEvent interface {
}
