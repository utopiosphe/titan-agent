local mod = {}

function mod.start()
    mod.timerInterval = 60
    mod.processName = "controller"
    mod.serverURL = "http://agent.titannet.io/update/controller"
    mod.appsRequestURL = "http://agent.titannet.io/update/apps"
    mod.downloadPackageName = "controller.zip"
    mod.extraControllerDir = "controller-extra"
    mod.isUpdate = false
    -- init base info
    mod.getBaseInfo()


    if mod.info.os == "windows" then
        mod.processName = "controller.exe"
    end


    mod.loadLocal()

    local checkUpdate = function(isUpdating)
        if not isUpdating then
            mod.isUpdate = false
            mod.startBusinessJob()
        end
    end

    mod.isUpdate = true
    mod.updateFromServer(checkUpdate)

    -- mod.startBusinessJob()

    mod.startTimer()

end


function mod.stop()
    mod.stopBusinessJob()
end

function mod.getBaseInfo()
    local agent = require 'agent'
    local info = agent.info()
    if info then
        mod.info = info
        mod.printTable(info)
    end
end

function mod.loadLocal()
    local agmod = require("agent")
    local processAPath = mod.info.workingDir .."/A/"..mod.processName
    local processA = mod.loadprocessInfo(processAPath)
    if processA then
        local downloadPackagePath = mod.info.workingDir .."/A/"..mod.downloadPackageName
        processA.md5 = agmod.fileMD5(downloadPackagePath)
        processA.ab = "A"
        processA.dir = mod.info.workingDir .."/A"
    end

    local processBPath = mod.info.workingDir .."/B/"..mod.processName
    local processB = mod.loadprocessInfo(processAPath)
    if progresB then
        local downloadPackagePath = mod.info.workingDir .."/B/"..mod.downloadPackageName
        processA.md5 = agmod.fileMD5(downloadPackagePath)
        processB.ab = "B"
        processA.dir = mod.info.workingDir .."/B"
    end

    if processA and processB then
        if mod.compareVersion(processA, processB) >= 0 then 
            mod.process = processA
        else
            mod.process = processB
        end 

    elseif processA then
        mod.process = processA
    elseif progresB then
        mod.process = processB
    end

    -- mod.printTable(mod.process)
end

function mod.loadprocessInfo(filePath)
    local goos = require("goos")
    local stat, err = goos.stat(filePath)
    if err then
        return nil
    end


    local process = {}
    process.filePath = filePath
    process.name = mod.processName

    local agmod = require("agent")
    local command = filePath.." version"
    local result, err = agmod.exec(command)
    if err then
        print("get version failed "..err)
        return process
    end

    if result.status ~= 0 then
        print("get version failed "..result.stderr)
        return process
    end

    if result.stdout then
        local strings = require("strings")
        local version = strings.trim_suffix(result.stdout, "\n")
        print("mod.loadprocessInfo version "..version)
        process.version = version
    end
    return process
end

-- return 1 if prgressA.version > progresB.version
-- return 0 if prgressA.version == progresB.version
-- return -1 if prgressA.version < progresB.version
function mod.compareVersion(processA, processB)
    if processA.version == processB.version then
        return 0
    end

    if processA.version == "" then
        return -1
    end

    if processB.version == "" then
        return 1
    end

    local strings = require("strings")
    local resultA = strings.split(processA.version, ".")
    local resultB = strings.split(processB.version, ".")

    for i = 1, 3 do
        if resultA[i] > resultB[i] then
            return processA
        elseif resultA[i] < resultB[i] then
            return processB
        end
    end
    
end

function mod.startBusinessJob()
    if not mod.process then
        print("start process "..mod.processName.." not exit")
        return
    end

    local process = require("process")
    local filePath = mod.process.filePath
    local cmdString = filePath.." run --working-dir "..mod.info.workingDir.." --server-url "..mod.appsRequestURL.." --uuid "..mod.info.uuid.." --script-interval 60"
    print("cmdString "..cmdString)
    local err = process.createProcess(mod.processName, cmdString)
    if err then
        print("start "..filePath.." failed "..err)
        -- TODO: if A rollback to B, or A
        return
    end

    print("start "..filePath.." success")
end

function mod.stopBusinessJob()
    if not mod.process then
        print("stop process "..mod.processName.." not exit")
        return
    end


    local process = require("process")
    local p = process.getProcess(mod.processName)
    if p then
        local agmod = require("agent")
        local result =""
        local err = ""
        if mod.info.os == "windows" then
            result, err = agmod.exec("taskkill /PID "..p.pid.." /F")
        else
            result, err = agmod.exec("kill "..p.pid)
        end

        if err then
            print("kill "..mod.processName.." failed:"..err)
        else 
            print("stop process "..mod.processName)
        end
    end
end

function mod.startTimer()
    local tmod = require("timer")
    tmod.createTimer('monitor', mod.timerInterval, 'onTimerMonitor')
    tmod.createTimer('update', mod.timerInterval, 'onTimerUpdate')
end

-- function mod.restartBusinessJob()
--     mod.stopBusinessJob()
--     mod.startBusinessJob()
-- end

function mod.onTimerMonitor()
    print("onTimerMonitor")
    if mod.monitorLastActivitTime then
        if os.difftime(os.time(), mod.monitorLastActivitTime) < mod.timerInterval then
            print("insufficient time to monitor")
            return
        end
    end
    mod.monitorLastActivitTime = os.time()
    

    local process = require("process")
    if not mod.process then 
        print("mod.onTimerMonitor process not load")
        return
    end

    local p = process.getProcess(mod.processName)
    if p then
        print("process "..p.name.." "..p.pid.." running")

        local agmod = require("agent")
        local command = mod.process.filePath.." version"

        print("command "..command)
        local result, err = agmod.exec(command)
        if err then
            print("check version error "..err)
        else 
            if result.status ~= 0 then
                print("check version err "..result.stderr)
            else
                local strings = require("strings")
                local version = strings.trim_suffix(result.stdout, "\n")
                print("version "..version)
            end
        end
    else 
        print("mod.onTimerMonitor process not start, start it")
        mod.startBusinessJob()
    end

    local process = require("process")
end


function mod.onTimerUpdate()
    print("onTimerUpdate")
    if mod.updateLastActivitTime then
        if os.difftime(os.time(), mod.updateLastActivitTime) < mod.timerInterval then
            print("insufficient time to update")
            return
        end
    end
    mod.updateLastActivitTime= os.time()

    if mod.isUpdate then
        print("is updating")
        return
    end

    
    local checkUpdate = function(isUpdating)
        if not isUpdating then
            mod.isUpdate = false
        end
    end

    mod.isUpdate = true
    mod.updateFromServer(checkUpdate)
end

function mod.updateFromServer(callback)
    local result, err = mod.getUpdateConfig()
    if err then
        print("mod.updateFromServer get controller update config from server "..err)
        callback(false)
        return
    end

    if mod.process and mod.process.md5 == result.md5 then
        print("mod.updateFromServer process already update")
        callback(false)
        return
    end

    mod.updateFileMD5 = result.md5 

    local filePath = mod.info.workingDir.."/"..mod.downloadPackageName
    local dmod = require 'downloader'
    local err = dmod.createDownloader("update", filePath, result.url, 'onDownloadCallback', 20)
    if err then
        print("create downloader failed "..err)
        callback(false)
        return
    end
    print("create downloader")
    callback(true)
end

function mod.getUpdateConfig() 
    local http = require("http")
    local client = http.client({timeout= 10})

    local url = mod.serverURL.."?version="..mod.info.version.."&os="..mod.info.os.."&uuid="..mod.info.uuid
    local request = http.request("GET", url)
    local result, err = client:do_request(request)
    if err then
        return nil, err
    end

    if not (result.code == 200) then
        return nil, "status code "..result.code..", url:"..url
    end

    local json = require("json")
    local result, err = json.decode(result.body)
    if err then
        return nil, err
    end

    return result, nil
end


-- unzip file
-- move file to A or B
-- update mod.process
-- restart businessJob
function mod.onDownloadCallback(result)
    print("onDownloadCallback, result:")

    mod.printTable(result)

    if not result then
        mod.isUpdate = false
        print("result == nil")
        return
    end

    if result.err ~= "" then
        mod.isUpdate = false
        print(result.err)
        return
    end

    if result.md5 ~= mod.updateFileMD5 then
        print("download update file md5 not match")
        mod.isUpdate = false
        return
    end

    mod.updateProcess(result)
    print("update process to new:")
    mod.printTable(mod.process)
    mod.stopBusinessJob()

    mod.isUpdate = false
end

function mod.updateProcess(downloadResult)
    local agmod = require("agent")
    local goos = require("goos")

    local outputDir = mod.info.workingDir.."/"..mod.extraControllerDir
    local err = agmod.removeAll(outputDir)
    if err then
        print("mod.updateProcess, removeAll failed "..err)
        return
    end

    -- extractZip will create outputDir if not exist
    local err agmod.extractZip(downloadResult.filePath, outputDir)
    if err then
        print("extractZip "..err)
        return
    end

    if not mod.process or mod.process.ab == "B" then
        local dest = mod.info.workingDir.."/A"
        local err = agmod.removeAll(dest)
        if err then
            print("remove dir "..dest.." failed "..err)
            return
        end

        -- copyDir will create dest dir if not exist 
        local err = agmod.copyDir(outputDir, dest)
        if err then
            print("copy "..outputDir.." to "..dest.." failed "..err)
            return
        end


        local filePath = dest.."/"..mod.downloadPackageName
        local ok, err = os.rename(downloadResult.filePath, filePath)
        if err then
            print("rename failed "..err)
            return
        end

        local processPath = dest.."/"..mod.processName
        local processA = mod.loadprocessInfo(processPath)
        if not processA then
            print("file "..processPath.." not exist")
            return
        end
        processA.md5 = downloadResult.md5
        processA.ab = "A"
        processA.dir = dest
        processA.filePath = processPath
        mod.process = processA
    else 
        local dest = mod.info.workingDir.."/B"
        local err = agmod.removeAll(dest)
        if err then
            print("remove dir "..dest.." failed "..err)
            return
        end

        -- copyDir will create dest dir if not exist 
        local err = agmod.copyDir(outputDir, dest)
        if err then
            print("copy "..outputDir.." to "..dest.." failed "..err)
            return
        end

        local filePath = dest.."/"..mod.downloadPackageName
        local ok, err = os.rename(downloadResult.filePath, filePath)
        if err then
            print("rename failed "..err)
        end

        local processPath = dest.."/"..mod.processName
        local processB = mod.loadprocessInfo(processPath)
        if not processB then
            print("file "..processPath.." not exist")
            return
        end
        processB.md5 = downloadResult.md5
        processB.ab = "B"
        processB.dir = dest
        processB.filePath = processPath
        mod.process = processB
    end

    local err = agmod.chmod(mod.process.filePath, "0755")
    if err then
        print("chmod failed "..err)
    end

    err = agmod.removeAll(outputDir)
    if err then
        print("remove failed "..err)
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
