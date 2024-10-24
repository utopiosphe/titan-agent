local mod = {luaScriptName="android-test.lua"}

function mod.start()
    mod.print("mod.start")
    mod.getBaseInfo()
end


function mod.stop()
    mod.print("mod.stop")
end

function mod.removeDirs()
    local agent = require 'agent'
    local err = agent.removeAll(mod.info.workingDir.."/A")
    if err then
        mod.print(err)
    end
    local err = agent.removeAll(mod.info.workingDir.."/B")
    if err then
        mod.print(err)
    end
    local err = agent.removeAll(mod.info.workingDir.."/apps")
    if err then
        mod.print(err)
    end
    local err = agent.removeAll(mod.info.workingDir.."/business-extra")
    if err then
        mod.print(err)
    end
    local err = agent.removeAll(mod.info.workingDir.."/controller-extra")
    if err then
        mod.print(err)
    end
end

function mod.killController()
    local agmod = require 'agent'
    local result, err = agmod.exec("pkill controller")
    if err then
        mod.print(err)
        return
    end
    mod.print(result)
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
