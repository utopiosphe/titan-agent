local mod = {}

function mod.start()
    print("mod.start windows-test.lua")
    mod.getBaseInfo()
    mod.removeDirs()
    -- local agmod = require("agent")
    -- local result, err = agmod.exec("systemctl restart titan-agent")
    -- if err then
    --     print("systemctl restart titan-agent failed:"..err)
    --     return
    -- end

    -- print("systemctl restart titan-agent:"..result)
end


function mod.stop()
    print("mod.stop windows-test.lua")
end

function mod.removeDirs()
    local agent = require 'agent'
    local err = agent.removeAll(mod.info.workingDir.."/A")
    if err then
        print(err)
    end
    local err = agent.removeAll(mod.info.workingDir.."/B")
    if err then
        print(err)
    end
    local err = agent.removeAll(mod.info.workingDir.."/apps")
    if err then
        print(err)
    end
    local err = agent.removeAll(mod.info.workingDir.."/business-extra")
    if err then
        print(err)
    end
    local err = agent.removeAll(mod.info.workingDir.."/controller-extra")
    if err then
        print(err)
    end
end

function mod.killController()
    local agmod = require 'agent'
    local result, err = agmod.exec("pkill controller")
    if err then
        print(err)
        return
    end
    print(result)
end

function mod.getBaseInfo()
    local agent = require 'agent'
    local info = agent.info()
    if info then
        mod.info = info
        print("windows-test.lua baseInfo:")
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
