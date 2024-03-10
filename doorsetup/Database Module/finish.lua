--The program installed on a drive by the doorsetup module to finish up setup on the pc
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

local settingData = {}
local randomNameArray = {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"}
local commandArray = {"getInput","analyzer","clearTerm","terminate","advanalyzer"}

local query = {["num"]=0}
local editorSettings = {}

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

term.clear()
if component.internet == nil then
    print("No internet card installed!")
    os.exit()
end

print("Checking for finishing file...")
local finishTable = loadTable("finishSettings.txt")
if finishTable == nil then
    print("Error getting table")
    os.exit()
end
print("Success...")
modemPort = finishTable.config.port
modem.close()
if component.isAvailable("tunnel") then
    link = component.tunnel
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
        if link == nil then
            modem.open(modemPort)
        end
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
    print("normal setup initiating")
end
editorSettings.type = "doorsystem"
os.execute("wget -f " .. doorCode .. " " .. program)
--TODO: Check if file managed to download, otherwise cancel setup
editorSettings.x = tonumber(sendMsg("Would you like to use the simple pass setup or new advanced one?","1 for simple, 2 for advanced",1))

local config = {}
config.type = editorSettings.type
config.num = editorSettings.num
config.version = editorSettings.version
config.cryptKey = finishTable.config.cryptKey
config.port = modemPort
saveTable(config,configFileName)

editorSettings.single = #finishTable == 1 and true or false

settingData = {}
for i=1,#finishTable,1 do
    local loopArray = {}
    sendMsg(3)
    local j
    if editorSettings.single == false then
        sendMsg("Door # " .. i .. " out of " .. #finishTable .. " is being edited: " .. finishTable[i].name.data)
        local keepLoop = true
        while keepLoop do
            j = randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]
            keepLoop = false
            for key,value in pairs(settingData) do
                if key == j then
                    keepLoop = true
                end
            end
        end
        text = sendMsg("Magnetic card reader?",editorSettings.scanner and "Scan the magnetic card reader with your tablet." or "Enter the uuid of the device in TEXT. When finished, don't type anything and just press enter",5)
        loopArray["reader"] = {}
        local hasPad = false
        for _, value in pairs(text) do
            local thisType = component.type(value)
            if thisType == "os_magreader" then
                table.insert(loopArray["reader"],{["uuid"]=value,["type"]="swipe"})
            elseif thisType == "os_biometric" then
                table.insert(loopArray["reader"],{["uuid"]=value,["type"]="biometric"})
            elseif thisType == "os_rfidreader" then
                table.insert(loopArray["reader"],{["uuid"]=value,["type"]="rfid"})
            elseif thisType == "os_keypad" then
                hasPad = true
                component.proxy(value).setDisplay("inactive", 6)
                table.insert(loopArray["reader"],{["uuid"]=value,["type"]="keypad",["global"]=false,["pass"]="1111"})
            end
        end
        if hasPad then
            text = sendMsg("Keypads detected: Would you like to use a global or local password?","global passwords are set by the database. local are set and saved on this door computer","1 for global, 2 for local",1)
            if text == "1" then
                text = sendMsg("What is the key for that keypad variable?",1)
            else
                hasPad = false
                text = sendMsg("What is the pin for the keypad to need to allow you in?","4 or less numbers (4 recommended)",1)
            end
            for key, value in pairs(loopArray["reader"]) do
                if value.type == "keypad" then
                    loopArray["reader"][key].global = hasPad
                    loopArray["reader"][key].pass = text
                end
            end
        end
    else
        local hasPad = false
        j = randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]
        local distable = {}
        for key,_ in pairs(component.list("os_magreader")) do
            table.insert(distable,{["uuid"]=key,["type"]="swipe"})
        end
        for key,_ in pairs(component.list("os_biometric")) do
            table.insert(distable,{["uuid"]=key,["type"]="biometric"})
        end
        for key,_ in pairs(component.list("os_rfidreader")) do
            table.insert(distable,{["uuid"]=key,["type"]="rfid"})
        end
        for key,_ in pairs(component.list("os_keypad")) do
            hasPad = true
            component.proxy(key).setDisplay("inactive", 6)
            table.insert(distable,{["uuid"]=key,["type"]="keypad",["global"]=false,["pass"]="1111"})
        end
        if hasPad then
            text = sendMsg("Keypads detected: Would you like to use a global or local password?","global passwords are set by the database. local are set and saved on this door computer","1 for global, 2 for local",1)
            if text == "1" then
                text = sendMsg("What is the key for that keypad variable?",1)
            else
                hasPad = false
                text = sendMsg("What is the pin for the keypad to need to allow you in?","4 or less numbers (4 recommended)",1)
            end
            for key, value in pairs(distable) do
                if value.type == "keypad" then
                    distable[key].global = hasPad
                    distable[key].pass = text
                end
            end
        end
        loopArray["reader"] = distable
    end
    loopArray["name"] = finishTable[i].name.data
    --Door Type/RedColor/Address/RedSide Area
    if finishTable[i].doorType.finished == true then
        loopArray["doorType"] = finishTable[i].doorType.data
    else
        text = sendMsg("Door Type? 1=redstone. 2=bundled. 3=door/rolldoor. NUMBER ONLY",1)
        loopArray["doorType"] = tonumber(text)
    end
    if loopArray.doorType == 2 then
        text = sendMsg("What color. Use the Color API wiki on the opencomputers wiki, and enter the NUMBER",1)
        loopArray["redColor"] = tonumber(text)
        loopArray["doorAddress"] = {}
        text = sendMsg("What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left. NUMBER ONLY",1)
        loopArray["redSide"] = tonumber(text)
        if editorSettings.single == false then
            sendMsg("No need to input anything for door address. The setting doesn't require it :)")
        end
    elseif loopArray.doorType == 1 then
        loopArray["redColor"] = 0
        loopArray["doorAddress"] = {}
        text = sendMsg("No need for redColor! The settings you inputted before don't require it :)","What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left. NUMBER ONLY",1)
        loopArray["redSide"] = tonumber(text)
        if editorSettings.single == false then
            sendMsg("No need to input anything for door address. The setting doesn't require it :)")
        end
    else
        loopArray["redColor"] = 0
        loopArray["redSide"] = 0
        sendMsg("no need to input anything for redColor. The setting doesn't require it :)","no need to input anything for redSide. The setting doesn't require it :)")
        loopArray["doorAddress"] = {}
        if editorSettings.single == false then
            text = sendMsg("What is the address for the doorcontrol/rolldoor block?", editorSettings.scanner and "Scan the blocks with tablet" or "Enter uuids as text",5)
            loopArray["doorAddress"] = text
        else
            loopArray["doorAddress"] = {}
            for key,_ in pairs(component.list("os_rolldoorcontroller")) do
                table.insert(loopArray["doorAddress"],key)
            end
            for key,_ in pairs(component.list("os_doorcontroller")) do
                table.insert(loopArray["doorAddress"],key)
            end
            --For older versions of OpenSecurity
            for key,_ in pairs(component.list("os_rolldoorcontrol")) do
                table.insert(loopArray["doorAddress"],key)
            end
            for key,_ in pairs(component.list("os_doorcontrol")) do
                table.insert(loopArray["doorAddress"],key)
            end
        end
    end
    --Toggle/Delay Area
    if finishTable[i].toggle.finished == true then
        sendMsg("Toggle has already been preset")
        loopArray["toggle"] = finishTable[i].toggle.data
    else
        text = sendMsg("Should the door be toggleable, or not? 0 for autoclose and 1 for toggleable",1)
        loopArray["toggle"] = tonumber(text)
    end
    if loopArray.toggle == 0 then
        if finishTable[i].delay.finished == true then
            sendMsg("Delay has already been preset")
            loopArray["delay"] = finishTable[i].delay.data
        else
            text = sendMsg("How long should the door stay open in seconds? NUMBER ONLY",1)
            loopArray["delay"] = tonumber(text)
        end
    else
        sendMsg("No need to change delay! Previous setting doesn't require it :)")
        loopArray["delay"] = 0
    end
    --Card Read Area (Beeg area)
    if finishTable[i].cardRead.finished == true then
        sendMsg("Door Passes have already been preset")
        loopArray["cardRead"] = finishTable[i].cardRead.data
    else
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
        end
    end
    --Sectors Area
    if editorSettings.hassector then
        if finishTable[i].sector.finished == true then
            sendMsg("Sector has already been preset")
            loopArray["sector"] = finishTable[i].sector.data
        else
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
        end
    else
        loopArray["sector"] = false
    end
    --End of Loop
    settingData[j] = loopArray
end

text = sendMsg("All done with installer!","Would you like to start the computer now?","1 for yes, 2 for no",1)
editorSettings.start = false
if tonumber(text) == 1 then
    sendMsg("Ok, will start computer.",4)
    editorSettings.start = true
else
    sendMsg("Ok, closing out.",4)
end
saveTable(settingData,settingFileName)
if editorSettings.start == true then
    print("Starting...")
    os.execute(program)
else
    print("Run " .. program .. " now to start door.")
end
os.execute("del finishSettings.txt")
os.execute("del finish.lua")