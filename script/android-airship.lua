local mod = {}

function mod.start()
    print("mod.start android-airship.lua")
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
    print("mod.stop android-airship.lua")
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
    local appPath = mod.info.appDir .."/"..mod.appName
    local err = mod.fetchAirshipApp(mod.downloadURL, appPath)
    if err then
        print("fetchAirshipApp failed:"..err)
        return
    end

    local md5, err = mod.fetchAirshipAppMd5(mod.md5URL)
    if err then
        print("fetchAirshipAppMd5 failed:"..err)
        return
    end

    print("mod.installAirship, origin file md5 "..md5)

    local agmod = require("agent")
    local fileMD5 = agmod.fileMD5(appPath)
    if fileMD5 ~= md5 then
        print("mod.installAirship, install app failed: origin file md5 "..md5..", get file md5 "..fileMD5)
        return
    end

    local err = agmod.chmod(appPath, "0755")
    if err then
        print("chmod failed "..err)
        return
    end
end

function mod.isAirshipStart()
    local agent = require("agent")
    local result = agent.exec("pgrep "..mod.appName)
    if result and result ~= "" then
        return true
    end
    return false
end

function mod.startAirship()
    if not mod.isAirshipExist() then
        return
    end

    local agent = require("agent")
    local goos = require("goos")

    local airshipWorksapce = mod.info.appDir .."/workspace"
    local err = goos.mkdir_all(airshipWorksapce)
    if err then
        print(err)
        return
    end

    local appPath = mod.info.appDir .."/"..mod.appName
    local command = appPath.." serve --workspace "..airshipWorksapce.." --class box --supplier-id "..mod.supplierID.." --supplier-device-id "..mod.info.androidSerialNumber
    local result = agent.exec(command)
    if result and result ~= "" then
        return true
    end
    return false

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
    print("mod.onTimerMonitor android-airship.lua")
    if mod.monitorLastActivitTime then
        if os.difftime(os.time(), mod.monitorLastActivitTime) < mod.timerInterval then
            print("insufficient time to monitor")
            return
        end
    end
    mod.monitorLastActivitTime = os.time()

    
    if not mod.isAirshipExist() then
        mod.installAirship()
    end

    if not mod.isAirshipStart() then
        mod.startAirship()
    end 
end

function mod.getBaseInfo()
    local agent = require 'agent'
    local info = agent.info()
    if info then
        mod.info = info
        print("test.lua baseInfo:")
        mod.printTable(info)
    end
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
