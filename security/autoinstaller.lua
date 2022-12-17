local component = require("component")
local term = require("term")
local io = require("io")
local ser = require("serialization")
local fs = require("filesystem")
local shell = require("shell")
local event = require("event")
local uuid = require("uuid")
local thread = require("thread")
local modem = component.modem
local link
local modemPort = 1000
local syncPort = 199
local diagPort = 180

local program = "ctrl.lua"
local settingFileName = "doorSettings.txt"
local configFileName = "extraConfig.txt"
local doorCode = "https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/security/doorControl.lua"
--local versionHolderCode = "https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/versionHolder.txt"

local settingData = {}
local randomNameArray = {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"}
local commandArray = {"getInput","analyzer","clearTerm","terminate","advanalyzer"}

local query = {["num"]=0}
local editorSettings = {} --Types of variables used in runInstall: type = door type (single or multi) required, num = old or new type (1 or 2) required, times = times to loop through (only edited before entering runInstall if adding more doors to multi) conditional, version = server version "not used yet", accelerate = if using seperate door setup tablet required, scanner = only used if accelerate true and if tablet has analyzer required, key = key of multidoor if editing door depends, edit = if editing. false if new door. required

local function saveTable(table, location)
    --saves a table to a file
    local tableFile = assert(io.open(location, "w"))
    tableFile:write(ser.serialize(table))
    tableFile:close()
end
local function loadTable(location)
    --returns a table stored in a file.
    local tableFile = assert(io.open(location))
    return ser.unserialize(tableFile:read("*all"))
end

local function send(label,port,linker,...)
    if linker and link ~= nil then
        link.send(modem.address,...)
        return
    end
    if label then
        modem.send(label,port,...)
    else
        modem.broadcast(port,...)
    end
end

local function sendMsg(...)
    local arg = table.pack(...)
    for i=1,#arg,1 do
        local argType = type(arg[i])
        if editorSettings.accelerate == true then
            if argType == "string" then
                send(editorSettings.from,editorSettings.port,false,"print",arg[i])
            elseif argType == "number" then
                send(editorSettings.from,editorSettings.port,false,commandArray[arg[i]])
                if arg[i] < 3 then
                    local e, _, _, _, _, text = event.pull("modem_message")
                    return text
                end
                if arg[i] == 4 then
                    print("terminated connection")
                end
                if arg[i] == 5 then
                    local wait = true
                    local distable = {}
                    while wait do
                        local e, _, _, _, _, text = event.pull("modem_message")
                        if text == "finished" then
                            return distable
                        else
                            table.insert(distable,text)
                        end
                    end
                end
            else
                send(editorSettings.from,editorSettings.port,false,"print","potential error in code for sendMsg")
            end
        else
            if argType == "string" then
                print(arg[i])
            elseif argType == "number" then
                if arg[i] == 1 then
                    local text = term.read()
                    return text:sub(1,-2)
                elseif arg[i] == 2 then
                    return "nil"
                elseif arg[i] == 3 then
                    term.clear()
                elseif arg[i] == 4 then
                    print("Finished editing.")
                elseif arg[i] == 5 then
                    local wait = true
                    local distable = {}
                    while wait do
                        local text = term.read()
                        text = text:sub(1,-2)
                        if text == "" then
                            return distable
                        else
                            table.insert(distable,text)
                        end
                    end
                else
                    print("potential error in code for sendMsg")
                end
            end
        end
    end
    return true
end

local function runInstall()
    local tmpTable = {}
    local times = 1
    local text = ""
    editorSettings.x = tonumber(sendMsg("Would you like to use the simple pass setup or new advanced one?","1 for simple, 2 for advanced",1))
    sendMsg(3)
    if editorSettings.single == false then
        if editorSettings.times ~= nil then
            tmpTable = editorSettings.data
            times = editorSettings.times
        elseif editorSettings.key ~= nil then
            times = 1
            tmpTable = editorSettings.data
        else
            text = sendMsg("Read the text carefully. Some of the inputs REQUIRE NUMBERS ONLY! Some require text.","The redSide is always 2, or back of the computer.","How many different doors are there?",1)
            times = tonumber(text)
        end
    else
        times = 1
    end

    local config = {}
    if editorSettings.edit then
        config = loadTable(configFileName)
    end
    config.type = editorSettings.type
    config.num = editorSettings.num
    config.version = editorSettings.version
    if editorSettings.edit == false or editorSettings.edit == nil then
        text = sendMsg("Do you want to use the default cryptKey of {1,2,3,4,5}?","1 for yes, 2 for no",1)
        if tonumber(text) == 2 then
            config.cryptKey = {}
            sendMsg("there are 5 parameters, each requiring a number. Recommend doing 1 digit numbers cause I got no idea how this works lol")
            for i=1,5,1 do
                text = sendMsg("enter param " .. i,1)
                config.cryptKey[i] = tonumber(text)
            end
        else
            config.cryptKey = {1,2,3,4,5}
        end
        config.port = modemPort
    end
    saveTable(config,configFileName)

    for i=1,times,1 do
        local loopArray = {}
        sendMsg(3)
        local j
        if editorSettings.single == false then
            sendMsg("Door # " .. i .. " is being edited:")
            if editorSettings.key == nil then
                local keepLoop = true
                while keepLoop do
                j = randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]
                    keepLoop = false
                    for key,value in pairs(tmpTable) do
                        if key == j then
                            keepLoop = true
                        end
                    end
                end
            else
                j = editorSettings.key
            end
            text = sendMsg("Magnetic card reader?",editorSettings.scanner and "Scan the magnetic card reader with your tablet." or "Enter the uuid of the device in TEXT. When finished, don't type anything and just press enter",5)
            loopArray["reader"] = text
        else
            j = randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]
            local distable = {}
            for key,_ in pairs(component.list("os_magreader")) do
                table.insert(distable,key)
            end
            loopArray["reader"] = distable
        end
        text = sendMsg("What do you want to nickname this door?",1)
        loopArray["name"] = text
        text = sendMsg("Door Type? 1=redstone 2=bundled. 3=door/rolldoor controller. NUMBER ONLY",1)
        loopArray["doorType"] = tonumber(text)
        if loopArray.doorType == 2 then
            text = sendMsg("What color. Use the Color API wiki on the opencomputers wiki, and enter the NUMBER",1)
            loopArray["redColor"] = tonumber(text)
            loopArray["doorAddress"] = {""}
            text = sendMsg("What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left. NUMBER ONLY",1)
            loopArray["redSide"] = tonumber(text)
            if editorSettings.single == false then
                sendMsg("No need to input anything for door address. The setting doesn't require it :)")
            end
        elseif loopArray.doorType == 1 then
            loopArray["redColor"] = 0
            loopArray["doorAddress"] = {""}
            text = sendMsg("No need for redColor! The settings you inputted before don't require it :)","What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left. NUMBER ONLY",1)
            loopArray["redSide"] = tonumber(text)
            if editorSettings.single == false then
                sendMsg("No need to input anything for door address. The setting doesn't require it :)")
            end
        else
            loopArray["redColor"] = 0
            loopArray["redSide"] = 0
            sendMsg("no need to input anything for redColor. The setting doesn't require it :)","no need to input anything for redSide. The setting doesn't require it :)")
            if editorSettings.single == false then
                text = sendMsg("What is the address for the door/rolldoor controller blocks?", editorSettings.scanner and "Scan the blocks with tablet then click screen when done" or "Enter uuids as text then enter with no text and enter",5)
                loopArray["doorAddress"] = text
            else
                loopArray["doorAddress"] = {}
                for key,_ in pairs(component.list("os_rolldoorcontroller","os_doorcontroller")) do
                    table.insert(loopArray["doorAddress"],key)
                end
            end
        end
        text = sendMsg("Should the door be toggleable, or not? 0 for autoclose and 1 for toggleable",1)
        loopArray["toggle"] = tonumber(text)
        if loopArray.toggle == 0 then
            text = sendMsg("How long should the door stay open in seconds? NUMBER ONLY",1)
            loopArray["delay"] = tonumber(text)
        else
            sendMsg("No need to change delay! Previous setting doesn't require it :)")
            loopArray["delay"] = 0
        end
        if editorSettings.x == 2 then
            local readLoad = {}
            sendMsg("Remember how many of each pass you want before you start.","type something and enter to continue",1)
            readLoad.add = tonumber(sendMsg("How many add passes do you want to add?","remember multiple base passes can use the same add pass",1))
            readLoad.base = tonumber(sendMsg("How many base passes do you want to add?",1))
            readLoad.reject = tonumber(sendMsg("How many reject passes do you want to add?","These don't affect supreme passes",1))
            readLoad.supreme = tonumber(sendMsg("How many supreme passes do you want to add?",1))
            loopArray.cardRead = {}
            local nextmsg = {}
            nextmsg.beg, nextmsg.mid, nextmsg.back = "What should be read for "," pass number ","? 0 = staff"
            for i=1,#editorSettings.settings.var,1 do
                nextmsg.back = nextmsg.back .. ", " .. i .. " = " .. editorSettings.settings.label[i]
            end
            local passFunc = function(type,num)
            local newRules = {["uuid"]=uuid.next(),["request"]=type,["data"]=type == "base" and {} or false}
            local text = sendMsg(nextmsg.beg..type..nextmsg.mid..num..nextmsg.back,1)
            if tonumber(text) == 0 then
                newRules.call = "checkstaff"
                newRules.param = 0
                sendMsg("No need for extra parameter. This mode doesn't require it :)")
            else
                newRules["tempint"] = tonumber(text)
                newRules["call"] = editorSettings.settings.calls[tonumber(text)]
                if editorSettings.settings.type[tonumber(text)] == "string" or editorSettings.settings.type == "-string" then
                    text = sendMsg("What is the string you would like to read? Enter text.",1)
                    newRules["param"] = text
                elseif editorSettings.settings.type[tonumber(text)] == "bool" then
                    newRules["param"] = 0
                    sendMsg("No need for extra parameter. This mode doesn't require it :)")
                elseif editorSettings.settings.type[tonumber(text)] == "int" then
                    if editorSettings.settings.above[tonumber(text)] == true then
                        text = sendMsg("What level and above should be required?",1)
                    else
                        text = sendMsg("what level exactly should be required?",1)
                    end
                    newRules["param"] = tonumber(text)
                elseif editorSettings.settings.type[tonumber(text)] == "-int" then
                    local nextmsg = "What group are you wanting to set?"
                    for i=1,#editorSettings.settings.data[tonumber(text)],1 do
                        nextmsg = nextmsg .. ", " .. i .. " = " .. editorSettings.settings.data[tonumber(text)][i]
                    end
                    text = sendMsg(nextmsg,1)
                    newRules["param"] = tonumber(text)
                else
                    sendMsg("error in cardRead area for num 2")
                    newRules["param"] = 0
                end
            end
            return newRules
        end
        for i=1,readLoad.add,1 do
            local rule = passFunc("add",i)
            table.insert(loopArray.cardRead,rule)
        end
        local addNum = #loopArray.cardRead
        for i=1,readLoad.base,1 do
            local rule = passFunc("base",i)
            text = tonumber(sendMsg("How many add passes do you want to link?",1))
            if text ~= 0 then
                local nextAdd = "Which pass do you want to add? "
                for j=1,addNum,1 do
                    nextAdd = nextAdd .. ", " .. j .. " = " .. editorSettings.settings.label[loopArray.cardRead[j].tempint]
                end
                for j=1,text,1 do
                    text = tonumber(sendMsg(nextAdd,1))
                    table.insert(rule.data,loopArray.cardRead[text].uuid)
                end
            end
            table.insert(loopArray.cardRead,rule)
        end
        for i=1,readLoad.reject,1 do
            local rule = passFunc("reject",i)
            table.insert(loopArray.cardRead,rule)
        end
        for i=1,readLoad.supreme,1 do
            local rule = passFunc("supreme",i)
            table.insert(loopArray.cardRead,rule)
        end
    else --{["uuid"]=uuid.next()["call"]=t1,["param"]=t2,["request"]="supreme",["data"]=false}
        local nextmsg = "What should be read? 0 = staff,"
        for i=1,#editorSettings.settings.var,1 do
            nextmsg = nextmsg .. ", " .. i .. " = " .. editorSettings.settings.label[i]
        end
        text = sendMsg(nextmsg,1)
        loopArray["cardRead"] = {{["uuid"]=uuid.next(),["call"]="",["param"]=0,["request"]="supreme",["data"]=false}}
        if tonumber(text) == 0 then
            loopArray["cardRead"][1].call = "checkstaff"
            loopArray["cardRead"][1].param = 0
            sendMsg("No need to set access level. This mode doesn't require it :)")
        else
            loopArray["cardRead"][1].call = editorSettings.settings.calls[tonumber(text)]
            if editorSettings.settings.type[tonumber(text)] == "string" or editorSettings.settings.type[tonumber(text)] == "-string" then
                text = sendMsg("What is the string you would like to read? Enter text.",1)
                loopArray["cardRead"][1].param = text
            elseif editorSettings.settings.type[tonumber(text)] == "bool" then
                loopArray["cardRead"][1].param = 0
                sendMsg("No need to set access level. This mode doesn't require it :)")
            elseif editorSettings.settings.type[tonumber(text)] == "int" then
                if editorSettings.settings.above[tonumber(text)] == true then
                    text = sendMsg("What level and above should be required?",1)
                else
                    text = sendMsg("what level exactly should be required?",1)
                end
                loopArray["cardRead"][1].param = tonumber(text)
            elseif editorSettings.settings.type[tonumber(text)] == "-int" then
                local nextmsg = "What group are you wanting to set?"
                for i=1,#editorSettings.settings.data[tonumber(text)],1 do
                    nextmsg = nextmsg .. ", " .. i .. " = " .. editorSettings.settings.data[tonumber(text)][i]
                end
                text = sendMsg(nextmsg,1)
                loopArray["cardRead"][1].param = tonumber(text)
            else
                sendMsg("error in cardRead area for num 2")
                loopArray["cardRead"][1].param = 0
            end
        end
    end --Sectors beginning
    if editorSettings.hassector then
        local nextmsg = "What sector would you like this door to be part of? 0 = no sector"
        for i=1,#editorSettings.settings.sectors,1 do --Issue
            nextmsg = nextmsg .. ", " .. i .. " = " .. editorSettings.settings.sectors[i].name
        end
        text = tonumber(sendMsg(nextmsg,1))
        if text == 0 then
            loopArray["sector"]=false
        else
            loopArray["sector"]=editorSettings.settings.sectors[text].uuid
        end
    else
        loopArray["sector"] = false
    end
    tmpTable[j] = loopArray
    end
    text = sendMsg("All done with installer!","Would you like to start the computer now?","1 for yes, 2 for no",1)
    editorSettings.start = false
    if tonumber(text) == 1 then
        sendMsg("Ok, will start computer.",4)
        editorSettings.start = true
    else
        sendMsg("Ok, closing out.",4)
    end
    return tmpTable
end

local function oldFiles()
    term.clear()
    local config = loadTable(configFileName)
    if config == nil then
        sendMsg("Error reading config file. Is this an up to date version?","It is recommended to wipe and reinstall at this point",4)
    end
    editorSettings.type = config.type
    editorSettings.single = false
    local text = sendMsg("Old files detected. Please select an option:","1 = wipe all files","2 = update door","3 = change cryptKey","4 = change port",1)
    if tonumber(text) == 1 then
        term.clear()
        sendMsg("Deleting all files...")
        local path = shell.getWorkingDirectory()
        fs.remove(path .. "/" .. program)
        fs.remove(path .. "/" .. settingFileName)
        if config ~= nil then fs.remove(path .. "/" .. configFileName) end
        local fill = io.open(settingFileName)
        if fill~=nil then
            sendMsg("an error occured and some files may not have deleted.",4)
            fill:close()
        else
            sendMsg("all done!",4)
        end
    elseif tonumber(text) == 2 then
        text = sendMsg("Are you sure you want to do this? New updates sometimes require manual changing of config.","1 for continue, 2 for cancel",1)
        if tonumber(text) == 1 then
            os.execute("wget -f " .. doorCode .. " " .. program)
        end
        text = sendMsg("all done! is set to " .. ser.serialize(config.cryptKey),"Would you like to start the computer now?","1 for yes, 2 for no",1)
        if tonumber(text) == 1 then
            sendMsg("Starting...",4)
            os.execute(program)
        else
            sendMsg("Ok, closing out.",4)
        end
    elseif tonumber(text) == 3 then
        sendMsg("there are 5 parameters, each requiring a number. Recommend doing 1 digit numbers cause I got no idea how this works lol")
        for i=1,5,1 do
            text = sendMsg("enter param " .. i,1)
            config.cryptKey[i] = tonumber(text)
        end
        saveTable(config,configFileName)
        text = sendMsg("all done! is set to " .. ser.serialize(config.cryptKey),"Would you like to start the computer now?","1 for yes, 2 for no",1)
        if tonumber(text) == 1 then
            sendMsg("Starting...",4)
            os.execute(program)
        else
            sendMsg("Ok, closing out.",4)
        end
    elseif tonumber(text) == 4 then
        config.port = modemPort
        sendMsg("Port changed to " .. modemPort)
        saveTable(config,configFileName)
    end
    config = nil
end

modem.close()
term.clear()

if component.isAvailable("tunnel") then
    link = component.tunnel
end

modem.open(syncPort)
modem.broadcast(syncPort,"syncport")
local e,_,_,_,_,msg = event.pull(1,"modem_message")
modem.close(syncPort)
if e then
    modemPort = tonumber(msg)
else
    print("What port is the server running off of?")
    local text = term.read()
    modemPort = tonumber(text:sub(1,-2))
    term.clear()
end

print("Sending query to server...")
if link == nil then
    modem.open(modemPort)
end
send(nil,modemPort,true,"getquery",ser.serialize({"passSettings","sectors","&&&crypt"}))
local e,_,from,port,_,msg = event.pull(3,"modem_message")
if e == nil then
    print("No query received. Assuming old server system is in place and will not work.")
    os.exit()
end
print("Query received")
query = ser.unserialize(msg)
if query.num ~= 3 then
    print("Security server is not valid. Must be 3.0.0 and up")
    os.exit()
end
editorSettings.x = 2
editorSettings.num = query.num
editorSettings.version = query.version
editorSettings.hassector = query.data.sectors ~= nil
editorSettings.settings = query.data.passSettings
editorSettings.settings.sectors = query.data.sectors
editorSettings.scanner = false
editorSettings.accelerate = false
editorSettings.single = false
term.clear()
local text = sendMsg("Would you like to use an external device for accelerated setup?","This makes it easier to set up doors without having to move from the door to the pc constantly.","It requires a diagnostic tablet (found on github)","1 for yes, 2 for no",1)
if tonumber(text) == 1 then
    modem.open(diagPort)
    modem.close(modemPort)
    sendMsg("Start up accelerated door setup on your diagnostic tablet","in 60 seconds with no changes the program will close")

    local time = 0
    local timer = function(seconds)
        time = seconds
        for i=1,seconds, 1 do
            os.sleep(1)
            time = time - 1
        end
    end
    local waiter = true
    local e, _, from, port, _, msg, barcode, t
    t = thread.create(timer) --setup incorrect
    while waiter do
        e, _, from, port, _, msg, barcode = event.pull(time, "modem_message")
        if e then
            if msg == "accsetup" then
                waiter = false
            end
        else
            waiter = false
        end
    end

    if e then
        modem.open(modemPort)
        t:kill()
        send(from,port,false,"connected")
        term.clear()
        sendMsg("Connection successful! All prompts will be on the tablet now on.")
        os.sleep(1)
        editorSettings.scanner = barcode
        editorSettings.accelerate = true
        editorSettings.from = from
        editorSettings.port = port
    else
        modem.close(diagPort)
        print("Setup cancelled")
        os.exit()
    end
else
    sendMsg("Normal setup initiating.")
end
term.clear()
sendMsg("Checking files...")
local text
local fill = io.open(program,"r")
if fill~=nil then
    fill:close()
    oldFiles()
else
    term.clear()
    editorSettings.type = "doorsystem"
    os.execute("wget -f " .. doorCode .. " " .. program)
    text = sendMsg("Would you like to use the simplified single door or multi-door?","true for single door of false for regular, multidoor setup",1)
    editorSettings.single = text == "true" and true or false
    settingData = runInstall()
    saveTable(settingData,settingFileName)
    if editorSettings.start == true then
        print("Starting...")
        os.execute(program)
    else
        print("Run " .. program .. " now to start door.")
    end
end
