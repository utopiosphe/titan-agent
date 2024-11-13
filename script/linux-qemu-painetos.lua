local mod = {luaScriptName="painetos.lua"}

function mod.start()
    mod.print("mod.start painetos")
    mod.timerInterval = 60

    mod.getBaseInfo()

    local err = mod.installPainetos()
    if err then
        mod.print("install painetos "..err)
    end

    mod.startTimer()
end


function mod.stop()
    mod.print("mod.stop painetos")
end

function mod.getBaseInfo()
    local dev = require 'agent'
    local info = dev.info()
    if info then
        mod.info = info
        mod.print(info)
    end
end

function mod.fetchAndPreparePainetInstallScript()
    local scriptName = "install-painetos.sh"
    local scriptURL = "https://agent.titannet.io/install-painetos.sh"
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
    
    mod.installPainetOSScriptPath = scriptPath
end

function mod.fetchAndPrepareQrcodeScript()
    local scriptName = "qrcode.sh"
    local scriptURL = "https://agent.titannet.io/qrcode.sh"
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
    
    mod.qrcodeScriptPath = scriptPath
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
    mod.print("mod.onTimerMonitor painetos.lua")
    mod.print("onTimerMonitor")
    if mod.monitorLastActivitTime then
        if os.difftime(os.time(), mod.monitorLastActivitTime) < mod.timerInterval then
            mod.print("insufficient time to monitor")
            return
        end
    end
    mod.monitorLastActivitTime = os.time()

    local exit = mod.isPainetosExist()
    if not exit then
        local metric = {status="installing"}
        local err = mod.installPainetos()
        if err then
            metric.status = "installedFailed"
            metric.err = err
            mod.print("Install painetos failed:", err)
        end
        mod.sendMetrics(metric)
    else
        if mod.isPainetosShutdown() then
            mod.sendMetrics({status="shutdown"})
            mod.startPainetos()
        else
            mod.print("Painet os is running")
            -- get qrcode
            local result,err = mod.getQrcode()
            if err then
                mod.print("getQrcode failed:"..err)
                mod.sendMetrics({status="running", err=err})
                return
            end
            mod.print("getQrcode:"..result)
            local err = mod.postQrcode(result)
            if err then
                mod.print("postQrcode "..err)
                mod.sendMetrics({status="running", err=err})
                return
            end
            mod.sendMetrics({status="running"})
        end
    end
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

function mod.isPainetosShutdown()
    local agmod = require("agent")
    local command = "/usr/bin/virsh domstate Painet"
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
        local strings = require("strings")
        if strings.contains(result.stdout, "running") then
            return false
        end
        return true
    end

    return false
end

function mod.startPainetos()
    local agmod = require("agent")
    local command = "/usr/bin/virsh start Painet"
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
        mod.print(result.stdout)
    end

    return true
end

function mod.installPainetos()
    local agmod = require("agent")
    local goos = require("goos")

    if not mod.installPainetOSScriptPath then 
        mod.fetchAndPreparePainetInstallScript()
    end


    local imageDir = mod.info.workingDir.."/images"
    local err = goos.mkdir_all(imageDir)
    if err then
        mod.print("mkdir failed:"..err)
        return err
    end

    -- /var/lib/libvirt/images/Painet.qcow2
    local imagePath = imageDir.."/Painet.qcow2"
    local command = mod.installPainetOSScriptPath.." "..imagePath
    local result, err = agmod.exec(command,300)
    if err then
        return err
    end
    
    if result.status ~= 0 then
        return "status "..result.status.." error "..result.stderr
    end

    if result.stderr and result.stderr ~= "" then
        return result.stderr
    end 

    if result.stdout then
        mod.print(result.stdout)
    end

    return nil
end

function mod.getQrcode()
    if not mod.qrcodeScriptPath then
        mod.fetchAndPrepareQrcodeScript()
    end

    local agmod = require("agent")
    local result, err = agmod.exec(mod.qrcodeScriptPath,30)
    if err then
        return nil, err
    end

    
    if result.status ~= 0 then
        return nil, "status "..result.status.." error "..result.stderr
    end

    if result.stderr and result.stderr ~= "" then
        return nil, result.stderr
    end

    return result.stdout, nil
end

function mod.postQrcode(qrcode)
    local url = "https://agent.titannet.io/app/info?uuid="..mod.info.uuid.."&appName=painetos"
    local http = require("http")
    local client = http.client()
    local request = http.request("POST", url, qrcode)
    local result, err = client:do_request(request)
    if err then
        return err
    end

    if not (result.code == 200) then
        return "status code ", result.code
    end
    
    mod.print("postQrcode"..result.body)
    return nil
    
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
    
    print(string.format('time="%s" leve=%s lua=%s msg="%s"', os.date("%Y-%m-%dT%H:%M:%S"), logLeve, mod.luaScriptName, msg))
end


return mod
