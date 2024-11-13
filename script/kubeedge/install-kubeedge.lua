local mod = {luaScriptName="install-kubeedge.lua"}

function mod.start()
    mod.print("mod.start")

    mod.timerInterval = 60
    mod.getBaseInfo()

    if not mod.isInstallKubeedge() and mod.isRoot() then
        -- install kube
        mod.print("install kubeedge..")
        local err = mod.installKubeedge()
        if err then
            mod.print("installKubeedge error "..err)
        end
    end

    if not mod.isKubeedgeStart() then
        mod.startKubeAndJoinCluster()
    end

    mod.startTimer()
end

function mod.isInstallKubeedge()
    local agmod = require("agent")
    local result, err = agmod.runBashCmd("which containerd")
    if err then
        mod.print("which containerd:"..err)
        return false
    end

    if result.status ~= 0 then
        mod.print("which containerd:"..result.stderr)
        return false
    end

    if result.stdout =="" then
        return false
    end

    local result, err = agmod.runBashCmd("which keadm")
    if err then
        mod.print("which keadm:"..err)
        return false
    end

    if result.status ~= 0 then
        mod.print("which keadm:"..result.stderr)
        return false
    end

    if result.stdout =="" then
        return false
    end
    return true
end

function mod.isRoot()
    local agmod = require("agent")
    local result, err = agmod.runBashCmd("whoami")
    if err then
        mod.print("whoami:"..err)
        return false
    end
    if result.status ~= 0 then
        mod.print("whoami:"..result.stderr)
        return false
    end

    print("user:", result.stdout)

    local strings = require("strings")
    local user = strings.trim_suffix(result.stdout, "\n")
    if user == "root" then
        return true
    end
    return false
end

function mod.installKubeedge()
    if not mod.installKubeedgeScriptPath then
        mod.fetchInstallKubeedgeScript()
    end

    if not mod.installKubeedgeScriptPath then
        return
    end

    local agmod = require("agent")
    local result, err = agmod.exec(mod.installKubeedgeScriptPath,300)
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

function mod.fetchInstallKubeedgeScript()
    local scriptName = "install-kubeedge.sh"
    local scriptURL = "https://agent.titannet.io/install-kubeedge.sh"
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
    
    mod.installKubeedgeScriptPath = scriptPath
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

function mod.isKubeedgeStart()
    local agent = require("agent")
    local result, err = agent.runBashCmd("pgrep keadm")
    if err then
        mod.print("pgrep keadm err:"..err)
        return false
    end

    if result.status ~= 0 then
        mod.print("pgrep keadm failed:"..result.stderr)
    end

    if result.stdout and result.stdout ~= "" then
        return true
    end
    return false
end

function mod.startKubeAndJoinCluster()
    local command = "sudo keadm join --kubeedge-version=1.13.1 --cloudcore-ipport=8.218.162.82:10000 --quicport 10001 --certport 10002 --tunnelport 10004 --edgenode-name $(uuid) --token 00a4692cfe5f24b1d9bf065d30de210238b9258dda25d05443518fbd2806b854.eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MzA3MzczMDN9.WPHaNGYNoUrEKGvdcMTxzQ5JkKJP8H8vT3iWaiT6sQc"
    local agmod = require("agent")
    local result, err = agmod.runBashCmd(command)
    if err then
        mod.print(err)
        return
    end

    if result.status ~= 0 then
        mod.print("start kube failed:"..result.stderr)
        return
    end

    mod.print("start kube successed")
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
    if not mod.isInstallKubeedge() and mod.isRoot() then
        -- install kube
        local err = mod.installKubeedge()
        if err then
            mot.print("installKubeedge error "..err)
        end
    end

    if not mod.isKubeedgeStart() then
        mod.startKubeAndJoinCluster()
    end

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
