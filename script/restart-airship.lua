local mod = {luaScriptName="remove-airship.lua"}

function mod.start()
    mod.print("mod.start")
    mod.appName = "airship-agent"
    mod.timerInterval = 60
    mod.getBaseInfo()


    -- mod.pkillAirship()
    local rebootInterval = 24 * 60 * 60
    local diff = os.difftime(os.time(), mod.info.bootTime)
    if diff > rebootInterval then
        mod.print("reboot, lastTime"..mod.info.bootTime.." diff "..diff)
        mod.rebootDevice()
    else 
        mod.print("insufficient time to reboot")
    end

    mod.startTimer()
end


function mod.stop()
    mod.print("mod.stop")
end


function mod.rebootDevice()
    local agent = require("agent")
    local result, err = agent.runBashCmd("reboot")
    if err then
       return "rebootDevice error:"..err
    end

   if result.status ~= 0 then
        return "rebootDevice status:"..result.status
   end

   if result.stderr and result.stderr ~= "" then
        return " rebootDevice output:"..result.stderr
   end
  
   if result.stdout and result.stdout ~= "" then
        return " rebootDevice output:"..result.stdout
   end
end

function mod.startTimer()
    local tmod = require("timer")
    tmod.createTimer('monitor', mod.timerInterval, 'onTimerMonitor')
end


function mod.onTimerMonitor()
    mod.print("mod.onTimerMonitor")
    if mod.monitorLastActivitTime then
        if os.difftime(os.time(), mod.monitorLastActivitTime) < mod.timerInterval then
            mod.print("insufficient time to monitor")
            return
        end
    end
    mod.monitorLastActivitTime = os.time()

    local rebootInterval = 24 * 60 * 60
    local diff = os.difftime(os.time(), mod.info.bootTime)
    if diff > rebootInterval then
        mod.print("reboot, lastTime"..mod.info.bootTime.." diff "..diff)
        mod.rebootDevice()
    else 
        mod.print("insufficient time to reboot")
    end

    local metric = {reboot=mod.info.bootTime}
    mod.sendMetrics(metric)
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
