local mod = {}

function mod.start()
    print("mod.start windows-test.lua")
    mod.getBaseInfo()
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
