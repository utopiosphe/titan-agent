local mod = {luaScriptName="android-test.lua"}

function mod.start()
    mod.print("mod.start")
    mod.getBaseInfo()

     local agent = require("agent")
     local err = agent.runBashCmd("pkill airship-agent")
     if err then
        mod.print(err)
        return
    end

    if result.status ~= 0 then
        mod.print("start "..appPath.." failed:"..result.stderr)
        return
    end

    mod.print("start "..appPath)
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
