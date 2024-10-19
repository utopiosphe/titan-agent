local mod = {luaScriptName="empty-test.lua"}

function mod.start()
    mod.print("mod.start test.lua")
    mod.getBaseInfo()
end


function mod.stop()
    mod.print("mod.stop test.lua")
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
    
    print(string.format('time="%s" leve=%s lua=%s msg="%s"', os.date("%Y-%m-%dT%H:%M:%S"), logLeve,mod.luaScriptName, msg))
end

return mod
