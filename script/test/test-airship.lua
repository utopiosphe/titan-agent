local mod = {luaScriptName="android-airship.lua"}

function mod.start()
    mod.print("mod.start")

    mod.timerInterval = 30
    mod.appName = "airship-agent"
    mod.supplierID = "106465"
    mod.downloadURL = "https://iaas.ppfs.io/airship/airship-agent-android-arm-latest"
    mod.md5URL = "https://iaas.ppfs.io/airship/airship-agent-android-arm-latest.md5"

    mod.getBaseInfo()
    
    if not mod.isAirshipExist() then
        mod.installAirship()
    end

    if not mod.isAirshipStart() then
        mod.startAirship()
    end 
    
    mod.startTimer()
end


function mod.stop()
    mod.print("mod.stop")
end


function mod.isAirshipExist()
    local appPath = mod.info.appDir .."/"..mod.appName
    local goos = require("goos")
    local stat, err = goos.stat(appPath)
    if err then
        return false
    end
    return true
end

function mod.installAirship()
    local agmod = require("agent")
    local strings = require("strings")

    local appPath = mod.info.appDir .."/"..mod.appName
    local err = mod.fetchAirshipApp(mod.downloadURL, appPath)
    if err then
        mod.print("fetchAirshipApp failed:"..err)
        return
    end

    local md5, err = mod.fetchAirshipAppMd5(mod.md5URL)
    if err then
        mod.print("fetchAirshipAppMd5 failed:"..err)
        agmod.removeAll(appPath)
        return
    end

    mod.print("mod.installAirship, origin file md5 ["..md5.."]")

    local fileMD5 = agmod.fileMD5(appPath)
    if not strings.contains(md5, fileMD5) then
        mod.print("mod.installAirship, install app failed: origin file md5 "..md5..", get file md5 "..fileMD5)
        agmod.removeAll(appPath)
        return
    end

    local err = agmod.chmod(appPath, "0755")
    if err then
        mod.print("chmod failed "..err)
        return
    end
end

function mod.isAirshipStart()
    local agent = require("agent")
    local result, err = agent.exec("/bin/pgrep "..mod.appName)
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

function mod.startAirship()
    if not mod.isAirshipExist() then
        mod.print("startAirship failed, airship not exist")
        return
    end

    local agent = require("agent")
    local goos = require("goos")

    local airshipWorksapce = mod.info.appDir .."/workspace"
    local err = goos.mkdir_all(airshipWorksapce)
    if err then
        mod.print(err)
        return
    end

    local appPath = mod.info.appDir .."/"..mod.appName
    local command = appPath.." serve --workspace "..airshipWorksapce.." --class box --supplier-id "..mod.supplierID.." --supplier-device-id "..mod.info.androidSerialNumber
    local result, err = agent.exec(command)
    if err then
        mod.print(err)
        return
    end

    if result.status ~= 0 then
        mod.print("start "..appPath.." failed:"..result.stderr)
    end

    mod.print("start "..appPath)
end

function mod.fetchAirshipApp(url, filePath) 
    local http = require("http")
    local client = http.client({timeout=300})

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

function mod.fetchAirshipAppMd5(url) 
    local http = require("http")
    local client = http.client({timeout=300})

    local request = http.request("GET", url)
    local result, err = client:do_request(request)
    if err then
        return nil, err
    end

    if not (result.code == 200) then
        return nil, "status code "..result.code..", url:"..url
    end

    return result.body, nil
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

    
    if not mod.isAirshipExist() then
        mod.print("airship not install, try to install it")
        mod.installAirship()
    end

    if not mod.isAirshipStart() then
        mod.print("airship not start, try to start it")
        mod.startAirship()
    else 
        mod.print("airship is running")
    end 
end

function mod.getBaseInfo()
    local agent = require 'agent'
    local info = agent.info()
    if info then
        mod.info = info
        mod.print("test.lua baseInfo:")
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
    
    print(string.format('time="%s" leve=%s lua=%s msg="%s"', os.date("%Y-%m-%dT%H:%M:%S"), logLeve, mod.luaScriptName, msg))
end

return mod
