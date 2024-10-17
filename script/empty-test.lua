local mod = {}

function mod.start()
    print("mod.start test.lua")
    mod.getBaseInfo()
end


function mod.stop()
    print("mod.stop test.lua")
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
