local mod = {luaScriptName="remove-painetos.lua"}

function mod.start()
    mod.print("mod.start")

    mod.timerInterval = 60
    mod.getBaseInfo()

    if mod.isPainetosExist() then
        mod.removePainet()
    end

    mod.startTimer()
end


function mod.stop()
    mod.print("mod.stop")
end

function mod.startTimer()
    local tmod = require("timer")
    tmod.createTimer('monitor', mod.timerInterval, 'onTimerMonitor')
end

function mod.onTimerMonitor()
    mod.print("mod.onTimerMonitor")

    mod.print("mod.onTimerMonitor painetos.lua")
    mod.print("onTimerMonitor")
    if mod.monitorLastActivitTime then
        if os.difftime(os.time(), mod.monitorLastActivitTime) < mod.timerInterval then
            mod.print("insufficient time to monitor")
            return
        end
    end
    mod.monitorLastActivitTime = os.time()

    local metric = {status="unkown"}
    if mod.isPainetosExist() then
        local err = mod.removePainet()
        if err then
            mod.print("removing painet")
             metric.status="removeFaied"
             metric.err=err
        else 
            metric.status="removed"
            mod.print("removed painet")
        end
    else  
        metric.status="uninstall"
        mod.print("painet uninstall")
    end

    mod.sendMetrics(metric)
end




function mod.isPainetosExist()
    local agmod = require("agent")
    local command = "/usr/bin/virsh domstate Painet";
    local result, err = agmod.exec(command)
    if err then
        mod.print("exec command "..command.." error:"..err)
        return false
    end

    if result.status ~= 0 then
        mod.print("exec command "..command.." failed:"..result.stderr)
        return false
    end

    if result.stdout then
        mod.print("virsh domstate Painet:"..result.stdout)
    end

    return true
end

function mod.removePainet()
    local agmod = require("agent")
    local command = "virsh destroy Painet && virsh undefine Painet";
    local result, err = agmod.runBashCmd(command)
    if err then
        return "exec command "..command.." error:"..err
    end

    if result.status ~= 0 then
        return "exec command "..command.." failed, status:"..result.status
    end

    if result.stdout then
        mod.print("virsh domstate Painet:"..result.stdout)
    end

    return nil
end


function mod.sendMetrics(metrics)
    local metric = require("metric")
    local json = require("json")
    local jsonString, err = json.encode(metrics)
    if err then
        mod.print("encode metrics failed:"..err)
        return
    end

    metric.send(jsonString)

end

function mod.getBaseInfo()
    local agent = require 'agent'
    local info = agent.info()
    if info then
        mod.info = info
        mod.print("baseInfo:")
        mod.print(info)
    end
end

function mod.print(msg)
    local logLeve = "info"
    if type(msg) == "table" then
        local tableMsg = "{\n"
        for key, value in pairs(msg) do
            tableMsg = string.format("%s %s:%s\n", tableMsg, key, value)
        end
        msg = string.format("%s %s", tableMsg,"}")
    end
    
    print(string.format('time="%s" leve=%s lua=%s msg="%s"', os.date("%Y-%m-%dT%H:%M:%S"), logLeve,mod.luaScriptName, msg))
end

return mod
