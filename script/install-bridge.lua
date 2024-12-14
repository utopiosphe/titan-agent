local mod = {luaScriptName="install-bridge.lua"}

function mod.start()
    mod.print("mod.start")
    mod.timerInterval=60
    mod.getBaseInfo()

    mod.fetchInstallBridgeScript()
    
    local err = mod.installBridge()
    if err then
        print(err)
        mod.installLog = err
    end

    mod.startTimer()
end


function mod.stop()
    mod.print("mod.stop")
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

function mod.installBridge()
    if not mod.installBridgeScriptPath then
        return "installBridgeScript not exist"
    end

     local agent = require("agent")
     local command = mod.installBridgeScriptPath.." "..mod.info.workingDir.."/images"
     local result, err = agent.runBashCmd(command, 180)
     if err then
        mod.print("install failed:"..err)
        return err
    end

    if result.status ~= 0 then
        if result.stderr then
            mod.print("install failed, status:"..result.status..",err:"..result.stderr)
            return "install failed, status:"..result.status..",err:"..result.stderr
        end
        return "install failed, status:"..result.status
    end

    if result.stdout then
        mod.print(result.stdout)
        mod.installLog=result.stdout
    end

    return nil
end

function mod.fetchInstallBridgeScript()
    local scriptName = "install-bridge.sh"
    local scriptURL = "https://agent.titannet.io/install-bridge.sh"
    local scriptPath = mod.info.appDir .."/"..scriptName
    local err = mod.downloadScript(scriptURL, scriptPath)
    if err then
        mod.print("get script error "..err)
        return 
    end
    local agmod = require("agent")
    local err = agmod.chmod(scriptPath, "0755")
    if err then
        mod.print("chmod failed "..err)
        return
    end
    
    mod.installBridgeScriptPath = scriptPath
end

function mod.downloadScript(url, filePath) 
    local http = require("http")
    local client = http.client({timeout= 10})

    -- local url = mod.serverURL.."?version="..mod.info.version.."&os="..mod.info.os.."&uuid="..mod.info.uuid
    local request = http.request("GET", url)
    local result, err = client:do_request(request)
    if err then
        return err
    end

    if not (result.code == 200) then
        return "status code "..result.code..", url:"..url
    end

    local ioutil = require("ioutil")
    local err = ioutil.write_file(filePath, result.body)
    if err then 
        return err
    end

    return nil
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
    if not mod.installBridgeScriptPath then
        metric.status="Script-downloading"
        mod.fetchInstallBridgeScript()

        local err = mod.installBridge()
        if err then
            metric.status="installFailed"
            metric.err = err
            print(err)
        end
    else 
        metric.status="running"
         local info = mod.getNetworkInfo()
         if info then
            metric.network=info
         end
         
         local ifconfig = mod.ifconfig()
         if ifconfig then
            metric.ifconfig=ifconfig
         end

         if mod.installLog then
            metric.installLog = mod.installLog
         end
    end
    
    mod.sendMetrics(metric)
end

function mod.sendMetrics(metrics)
    local metric = require("metric")
    local json = require("json")
    local jsonString, err = json.encode(metrics)
    if err then
        mod.print("encode metrics  failed:"..err)
        return
    end

    metric.send(jsonString)

end

function mod.getNetworkInfo()
    local agent = require("agent")
    local result, err = agent.runBashCmd("arp -a", 60)
    if err then
       mod.print("arp -a:"..err)
       return err
   end

   if result.status ~= 0 then
    return "arp -a status "..result.status
   end
   return result.stdout  
end


function mod.ifconfig()
    local agent = require("agent")
    local result, err = agent.runBashCmd("ifconfig", 60)
    if err then
       mod.print("ifconfig:"..err)
       return err
   end

   if result.status ~= 0 then
    return "ifconfig status:"..result.status
   end
   return result.stdout  
end

function mod.printTable(t)
    if not t then
        mod.print(t)
        return
    end

    for key, value in pairs(t) do
        mod.print(key, value)
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
