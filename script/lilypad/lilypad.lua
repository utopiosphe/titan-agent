local mod = {luaScriptName="lilypad.lua"}

function mod.start()
    print("mod.start painetos")
    mod.timerInterval = 60

    mod.getBaseInfo()

    mod.fetchAndPrepareLilypadInstallScript()

    local err = mod.installPainetos()
    if err then
        print("install painetos "..err)
    end

    mod.startTimer()
end


function mod.stop()
    print("mod.stop")
end

function mod.getBaseInfo()
    local dev = require 'agent'
    local info = dev.info()
    if info then
        mod.info = info
        mod.printTable(info)
    end
end

function mod.fetchAndPrepareLilypadInstallScript()
    local scriptName = "install-lilypad.sh"
    local scriptURL = "https://agent.titannet.io/install-lilypad.sh"
    local scriptPath = mod.info.appDir .."/"..scriptName
    local err = mod.downloadScript(scriptURL, scriptPath)
    if err then
        print("get script error "..err)
        return 
    end
    local agmod = require("agent")
    local err = agmod.chmod(scriptPath, "0755")
    if err then
        print("chmod failed "..err)
        return
    end
    
    mod.installLilypadScriptPath = scriptPath
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
    print("mod.onTimerMonitor painetos.lua")
    print("onTimerMonitor")
    if mod.monitorLastActivitTime then
        if os.difftime(os.time(), mod.monitorLastActivitTime) < mod.timerInterval then
            print("insufficient time to monitor")
            return
        end
    end
    mod.monitorLastActivitTime = os.time()

    local exit = mod.isPainetosExist()
    if not exit then
        mod.installPainetos()
    else
        if mod.isPainetosShutdown() then
            mod.startPainetos()
        else
            print("Painet os is running")
            -- get qrcode
            local result,err = mod.getQrcode()
            if err then
                print("getQrcode failed:"..err)
                return
            end
            print("getQrcode:"..result)
            local err = mod.postQrcode(result)
            if err then
                print("postQrcode "..err)
                return
            end
        end
    end
end

function mod.isPainetosExist()
    local agmod = require("agent")
    local command = "/usr/bin/virsh domstate Painet";
    local result, err = agmod.exec(command)
    if err then
        print("exec command "..command.." error:"..err)
        return false
    end

    if result.status ~= 0 then
        print("exec command "..command.." failed:"..result.stderr)
        return false
    end

    if result.stdout then
        print("virsh domstate Painet:"..result.stdout)
    end

    return true
end

function mod.isPainetosShutdown()
    local agmod = require("agent")
    local command = "/usr/bin/virsh domstate Painet"
    local result, err = agmod.exec(command)
    if err then
        print("exec command "..command.." error:"..err)
        return false
    end

    if result.status ~= 0 then
        print("exec command "..command.." failed:"..result.stderr)
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
        print("exec command "..command.." error:"..err)
        return false
    end

    if result.status ~= 0 then
        print("exec command "..command.." failed:"..result.stderr)
        return false
    end

    if result.stdout then
        print(result.stdout)
    end

    return true
end

function mod.installPainetos()
    local agmod = require("agent")
    local result, err = agmod.exec(mod.installPainetOSScriptPath,300)
    if err then
        return err
    end

    
    if result.status ~= 0 then
        return "status "..result.status.." error "..result.stderr
    end

    if result.stdout then
        print(result.stdout)
    end

    if result.stderr then
        print(result.stderr)
    end 
    return nil
end

function mod.getQrcode()
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
    
    print("postQrcode"..result.body)
    return nil
    
end


function mod.printTable(t)
    if not t then
        print(t)
        return
    end

    for key, value in pairs(t) do
        print(key, value)
    end
end


return mod
