local mod = {luaScriptName="remove-airship.lua"}

function mod.start()
    mod.print("mod.start")
    mod.appName = "airship-agent"
    mod.timerInterval = 60
    -- mod.getBaseInfo()

    mod.pkillAirship()
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
    if mod.monitorLastActivitTime then
        if os.difftime(os.time(), mod.monitorLastActivitTime) < mod.timerInterval then
            mod.print("insufficient time to monitor")
            return
        end
    end
    mod.monitorLastActivitTime = os.time()



    local metric = {}
    if mod.isAirshipStart() then
        mod.print("airship start, try to kill it")
        mod.pkillAirship()
        metric.status="removing"
    else 
        mod.print("airship is running")
        metric.status="stop"
    end 

    if mod.isAirshipExist() then
        local removeInfo = mod.removeAirship()
        if removeInfo then
            metric.removeInfo = removeInfo
        end
    
    end

    local removeInfo2 = mod.removeAirship2()
    if removeInfo2 then
        metric.removeInfo2 = removeInfo2
    end
    
    local psInfo = mod.psAirship()
    if psInfo then
        metric.psInfo = psInfo
    end

    local lsAppsDir = mod.lsAppsDir()
    if lsAppsDir then
        metric.lsAppsDir = lsAppsDir
    end
    mod.print(metric)
    mod.sendMetrics(metric)
end

function mod.isAirshipExist()
    local appPath = "/data/unencrypted/.titan/workspace/apps/airship"
    local goos = require("goos")
    local stat, err = goos.stat(appPath)
    if err then
        return false
    end
    return true
end

function mod.removeAirship()
    local agent = require("agent")
    local appPath = "/data/unencrypted/.titan/workspace/apps/airship"
    local command = "rm -rf "..appPath
    local result, err = agent.runBashCmd(command)
    if err then
       return command.." ,error:"..err
    end

   if result.status ~= 0 then
        return command..", output status:"..result.status
   end

   if result.stderr and result.stderr ~= "" then
        return command..", output:"..result.stderr
   end
  
   if result.stdout and result.stdout ~= "" then
        return command..", output:"..result.stdout
   end
end

function mod.removeAirship2()
    local agent = require("agent")
    local appPath = "/data/.airship"
    local command = "rm -rf "..appPath
    local result, err = agent.runBashCmd(command)
    if err then
       return command.." ,error:"..err
    end

   if result.status ~= 0 then
        return command..", output status:"..result.status
   end

   if result.stderr and result.stderr ~= "" then
        return command..", output:"..result.stderr
   end
  
   if result.stdout and result.stdout ~= "" then
        return command..", output:"..result.stdout
   end
end

function mod.psAirship()
    local agent = require("agent")
    local command = "ps -ef | grep "..mod.appName
    local result, err = agent.runBashCmd(command)
    if err then
       return command.." ,error:"..err
    end

   if result.status ~= 0 then
        return "ps -ef faild, status: "..result.status
   end

   if result.stderr and result.stderr ~= "" then
        return command..", output:"..result.stderr
   end
  
   if result.stdout and result.stdout ~= "" then
        return command..", output:"..result.stdout
   end
end

function mod.lsAppsDir()
    local agent = require("agent")
    local command = "ls /data/unencrypted/.titan/workspace/apps"
    local result, err = agent.runBashCmd(command)
    if err then
       return command.." ,error:"..err
    end

   if result.status ~= 0 then
        return "ps -ef faild, status: "..result.status
   end

   if result.stderr and result.stderr ~= "" then
        return command..", output:"..result.stderr
   end
  
   if result.stdout and result.stdout ~= "" then
        return command..", output:"..result.stdout
   end
end

function mod.pkillAirship()
    local agent = require("agent")
    local result, err = agent.runBashCmd("pkill "..mod.appName)
    if err then
        mod.print("pkill "..mod.appName.." err:"..err)
        return false
    end

    if result.status ~= 0 then
        mod.print("pkill "..mod.appName.." failed, status:"..result.status..", err:"..result.stderr)
        return false
    end

    if result.stdout and result.stdout ~= "" then
        return true
    end
    return false
end

function mod.isAirshipStart()
    local agent = require("agent")
    local result, err = agent.runBashCmd("pgrep "..mod.appName)
    if err then
        mod.print("pgrep "..mod.appName.." err:"..err)
        return false
    end

    if result.status ~= 0 then
        mod.print("pgrep "..mod.appName.." failed, status:"..result.status..", err:"..result.stderr)
        return false
    end

    if result.stdout and result.stdout ~= "" then
        return true
    end
    return false
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
