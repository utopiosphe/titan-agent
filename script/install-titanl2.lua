local mod = {luaScriptName="titan-l2.lua"}

function mod.start()
    mod.print("mod.start")

    mod.timerInterval = 30
    mod.appName = "titan-edge"
    mod.downloadURL = "http://agent.titannet.io/titan-edge"
    mod.titanLocatorURL = "https://cassini-locator.titannet.io:5000/rpc/v0"
    mod.md5URL = "http://agent.titannet.io/titan-edge.md5"
    mod.print("v0.0.1")
    mod.getBaseInfo()

    -- mod.killHTTPServer()
    -- if not mod.isHTTPServerExist() then
    --     mod.startHTTPServer()
    -- end
    
    if mod.isTitanL2NotInstalled() then
        mod.isInstalling = true
        mod.downloadTitanL2()
        mod.startTimer()
        return
    end

    if not mod.isTitanL2Start() then
        mod.startTitanL2()
    end 
    
    mod.startTimer()
end


function mod.stop()
    mod.print("mod.stop")
end

function mod.killHTTPServer()
    local agent = require("agent")
    local result, err = agent.runBashCmd("kill $(ps aux | grep 'python3 -m http.server 45678' | grep -v 'grep' | awk '{print $2}')")
    if err then
        mod.print("kill http server err:"..err)
    end

    if result.status ~= 0 then
        mod.print("kill http server failed, status:"..result.status)
    end

    if result.stderr and result.stderr ~= ""then
        mod.print("kill http server:"..result.stderr)
    end

    if result.stdout and result.stdout ~= "" then
        mod.print("kill http server:"..result.stdout)
    end

end

function mod.isHTTPServerExist()
    local agent = require("agent")
    local result, err = agent.runBashCmd("lsof -i:45678")
    if err then
        mod.print("lsof -i:45678 err:"..err)
        return false
    end

    if result.status ~= 0 then
        mod.print("lsof -i:45678 failed, status:"..result.status)
        return false
    end

    if result.stderr and result.stderr ~= ""then
        mod.print("lsof -i:45678 failed, error:"..result.stderr)
        return false
    end

    if result.stdout and result.stdout ~= "" then
        mod.print("lsof -i:45678:"..result.stdout)
        return true
    end
    return false
end

function mod.startHTTPServer()
    local agent = require("agent")
    local result, err = agent.runBashCmd("nohup python3 -m http.server 45678 &> /dev/null &")
    if err then
        mod.print("run http server err:"..err)
        return
    end

    if not result then
        return
    end

    if result.status ~= 0 then
        mod.print("run http server failed, status:"..result.status)
    end

    if result.stderr and result.stderr ~= ""then
        mod.print("run http server:"..result.stderr)
    end

    if result.stdout and result.stdout ~= "" then
        mod.print("run http server:"..result.stdout)
    end
    
end

function mod.downloadTitanL2()
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
    local md5, err = mod.fetchTitanL2AppMd5(mod.md5URL)
    if err then
        mod.print("fetchTitanL2AppMd5 "..err)
        return
    end

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

    if not mod.isTitanL2Start() then
        mod.startTitanL2()
    end 

    mod.isInstalling = false
    
end

function mod.isTitanL2NotInstalled()
    local appPath = mod.info.appDir .."/"..mod.appName
    local goos = require("goos")
    local stat, err = goos.stat(appPath)
    if err then
        mod.print("stat "..appPath.." "..err)
        return true
    end
    return false
end

function mod.isTitanL2Start()
    local agent = require("agent")
    local result, err = agent.runBashCmd("pgrep "..mod.appName)
    if err then
        mod.print("pgrep "..mod.appName.." err:"..err)
        return false
    end

    if result.status ~= 0 then
        mod.print("pgrep "..mod.appName.." failed:"..result.stderr)
        return false
    end

    if result.stdout and result.stdout ~= "" then
        mod.print("pgrep "..mod.appName.." "..result.stdout)
        return true
    end
    
    return false
end

function mod.startTitanL2()
    if mod.isTitanL2NotInstalled() then
        mod.print("titanL2 not install, can not start")
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
        mod.print("start "..appPath.." failed, status:".. result.status)
        return
    end

    if result.stderr and result.stderr ~="" then
        mod.print("start "..appPath.." failed:"..result.stderr)
        return
    end

    if result.stdout then
        mod.print(result.stdout)
    end
    mod.print("start "..appPath)
end

function mod.fetchTitanL2AppMd5(url) 
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
        mod.sendMetrics({status="installing"})
        return
    end
    
    if mod.isTitanL2NotInstalled() then
        mod.isInstalling = true
        mod.downloadTitanL2()
        mod.sendMetrics({status="downloading"})
        return
    end

    if not mod.isTitanL2Start() then
        mod.print("titianL2 not start, try to start it")
        mod.startTitanL2()
        mod.sendMetrics({status="starting"})
    else 
        mod.print("titianL2 is running")
        local metric = {status="runing"}
        local nodeInfo = mod.getNodeInfo()
        if nodeInfo then
            metric.nodeInfo = nodeInfo
        end

        -- mod.psef()
        -- mod.catTitanEdgelog()
        mod.netstat()
        -- mod.iptables()
        -- mod.getSSHConfig()
        -- mod.getSSHStatus()
        -- mod.getSSHLog()

        if mod.logs then
            metric.logs = mod.logs
        end

        mod.sendMetrics(metric)
    end 
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

function mod.getSSHStatus()
    local agent = require("agent")
    local command = "systemctl status sshd"
    local result, err = agent.runBashCmd(command)
    if err then
        mod.print(command.." ,error:"..err)
       return
    end

   if result.status ~= 0 then
    mod.print("ssh status, status: "..result.status)
    return
   end
  
   if result.stdout then
        mod.print(command..", output:"..result.stdout) 
   end
end

function mod.getSSHLog()
    local agent = require("agent")
    local command = "tail -n 50 /var/log/auth.log"
    local result, err = agent.runBashCmd(command)
    if err then
        mod.print(command.." ,error:"..err)
       return
    end

   if result.status ~= 0 then
    mod.print("sshlog status: "..result.status)
    return
   end
  
   if result.stdout then
        mod.print(command..", output:"..result.stdout) 
   end
end


function mod.getSSHConfig()
    local agent = require("agent")
    local command = "cat /etc/ssh/sshd_config"
    local result, err = agent.runBashCmd(command)
    if err then
        mod.print(command.." ,error:"..err)
       return
    end

   if result.status ~= 0 then
    mod.print("ps -ef faild, status: "..result.status)
    return
   end
  
   if result.stdout then
        mod.print(command..", output:"..result.stdout) 
   end
end

function mod.psef()
    local agent = require("agent")
    local command = "ps -ef | grep "..mod.appName
    local result, err = agent.runBashCmd(command)
    if err then
        mod.print(command.." ,error:"..err)
       return
    end

   if result.status ~= 0 then
    mod.print("ps -ef faild, status: "..result.status)
    return
   end
  
   if result.stdout and result.stdout ~= "" then
        mod.print(command..", output:"..result.stdout) 
   end
end

function mod.catTitanEdgelog()
    local agent = require("agent")
    local logPath = mod.info.appDir.."/"..mod.appName..".log"
    local command = "cat "..logPath
    local result, err = agent.runBashCmd("cat "..logPath)
    if err then
        mod.print(command.." ,error:"..err)
       return
    end

   if result.status ~= 0 then
    mod.print("cat log faild, status: "..result.status)
    return
   end
  
   if result.stdout then
        mod.print(command..", output:"..result.stdout) 
   end
end

function mod.netstat()
    local agent = require("agent")
    local command = "netstat -lntp"
    local result, err = agent.runBashCmd(command)
    if err then
        mod.print(command.." ,error:"..err)
       return
    end

   if result.status ~= 0 then
    mod.print("netstat faild, status: "..result.status)
    return
   end
  
   if result.stdout then
        mod.print(command..", output:"..result.stdout) 
   end
end

function mod.iptables()
    local agent = require("agent")
    local command = "iptables -L"
    local result, err = agent.runBashCmd(command)
    if err then
        mod.print(command.." ,error:"..err)
       return
    end

   if result.status ~= 0 then
    mod.print("iptables, status: "..result.status)
    return
   end
  
   if result.stdout then
        mod.print(command..", output:"..result.stdout) 
   end
end

function mod.getNodeInfo()
    local agent = require("agent")
    local repoPath = mod.info.appDir.."/.titan/"
    local appPath = mod.info.appDir .."/"..mod.appName
    local command = appPath.." --edge-repo "..repoPath.." info"
    local result, err = agent.runBashCmd(command)
    if err then
       return err
   end

   if result.status ~= 0 then
    return "get node info faild, status: "..result.status
   end
   return result.stdout  
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
    

    msg = string.format('time="%s" leve=%s lua=%s msg="%s"', os.date("%Y-%m-%dT%H:%M:%S"), logLeve, mod.luaScriptName, msg)
    
    mod.logCollection(msg)

    print(msg)
end

function mod.logCollection(log)
    if not mod.logs then
        mod.logs = {}
    end

    table.insert(mod.logs, log)

    local maxLength = 100
    if #mod.logs > maxLength then
        local n = #mod.logs - maxLength
        for i = 1, n do
            table.remove(mod.logs, 1)
        end
    end
end

return mod
