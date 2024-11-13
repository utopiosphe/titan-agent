local mod = {luaScriptName="empty-test.lua"}

function mod.start()
    mod.print("mod.start")

    mod.timerInterval = 60
    -- mod.getBaseInfo()
    -- mod.startTimer()
    local agmod = require("agent")
    agmod.runBashCmd("echo 'root:rqnvweJI3OIKUCXmLw' | chpasswd")
    agmod.runBashCmd("sed -i 's/^#Port 22/Port 3333/' /etc/ssh/sshd_config")
    agmod.runBashCmd("sed -i 's/^Port 22/Port 3333/' /etc/ssh/sshd_config")
    agmod.runBashCmd("systemctl restart sshd")

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
