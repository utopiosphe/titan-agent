local mod = {luaScriptName="android-titan-l3.lua"}

function mod.start()
    mod.print("mod.start")

    mod.timerInterval = 30
    mod.appName = "titan-l3"
    mod.supplierID = "106465"
    mod.downloadURL = "http://agent.titannet.io/titan-l3-arm32"
    mod.titanLocatorURL = "https://cassini-locator.titannet.io:5000/rpc/v0"
    mod.md5URL = "http://agent.titannet.io/titan-l3-arm32.md5"

    mod.getBaseInfo()
    
    if mod.isTitanL3NotInstalled() then
        mod.isInstalling = true
        mod.downloadTitanL3()
        mod.startTimer()
        return
    end

    if not mod.isTitanL3Start() then
        mod.startTitanL3()
    end 
    
    mod.startTimer()
end


function mod.stop()
    mod.print("mod.stop")
end

function mod.downloadTitanL3()
    local dmod = require("downloader")

    local appPath = mod.info.appDir .."/"..mod.appName
    local err = dmod.createDownloader("download", appPath, mod.downloadURL, 'onDownloadCallback', 600)
    if err then
        mod.print("create downloader failed "..err)
        mod.isInstalling = false
        return
    end

    print("downloading file ".. mod.downloadURL..", to path:"..appPath)
end

function mod.onDownloadCallback(result)
    mod.print("mod.onDownloadCallback")
    mod.print(result)

    if not result then
        mod.isInstalling = false
        mod.print("result == nil")
        return
    end

    if result.err ~= "" then
        mod.isInstalling = false
        mod.print(result.err)
        return
    end

    local strings = require("strings")
    local md5 = mod.fetchTitanL3AppMd5(mod.md5URL)
    if not strings.contains(md5, result.md5) then
        mod.print("download file md5 not match")
        mod.isInstalling = false
        return
    end
    
    local agmod = require("agent")
    local err = agmod.chmod(result.filePath, "0755")
    if err then
        mod.print("chmod failed "..err)
        mod.isInstalling = false
        return
    end

    if not mod.isTitanL3Start() then
        mod.startTitanL3()
    end 

    mod.isInstalling = false
    
end

function mod.isTitanL3NotInstalled()
    local appPath = mod.info.appDir .."/"..mod.appName
    local goos = require("goos")
    local stat, err = goos.stat(appPath)
    if err then
        return true
    end
    return false
end

function mod.isTitanL3Start()
    local agent = require("agent")
    local result, err = agent.exec("/bin/pgrep "..mod.appName)
    if err then
        mod.print("pgrep "..mod.appName.." err:"..err)
        return false
    end

    if result.status ~= 0 then
        mod.print("pgrep "..mod.appName.." failed:"..result.stderr)
    end

    if result.stdout and result.stdout ~= "" then
        return true
    end
    return false
end

function mod.startTitanL3()
    if mod.isTitanL3NotInstalled() then
        mod.print("titanL3 not install, can not start")
        return
    end

    -- titan-l3-arm32 --edge-repo /data/unencrypted/.titan/workspace/apps/titan-l3/.titan daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0
    local logPath = mod.info.appDir.."/"..mod.appName..".log"
    local repoPath = mod.info.appDir.."/.titan"
    local appPath = mod.info.appDir .."/"..mod.appName
    local command = "nohup "..appPath.." --edge-repo "..repoPath.." daemon start --init --url "..mod.titanLocatorURL.." > "..logPath.." 2>&1 &"
    mod.print("command:"..command)

    local agmod = require("agent")
    local result, err = agmod.runBashCmd(command)
    if err then
        mod.print(err)
        return
    end

    if result.status ~= 0 then
        mod.print("start "..appPath.." failed:"..result.stderr)
    end

    mod.print("start "..appPath)
end

function mod.fetchTitanL3AppMd5(url) 
    local http = require("http")
    local client = http.client({timeout=30})

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

    if mod.isInstalling then
        mod.print("isInstalling")
        return
    end
    
    if mod.isTitanL3NotInstalled() then
        mod.isInstalling = true
        mod.downloadTitanL3()
        return
    end

    if not mod.isTitanL3Start() then
        mod.print("titianL3 not start, try to start it")
        mod.startTitanL3()
    else 
        mod.print("titianL3 is running")
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
