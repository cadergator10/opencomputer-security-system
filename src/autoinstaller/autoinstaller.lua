local component = require("component")
local term = require("term")
local io = require("io")
local ser = require("serialization")
local fs = require("filesystem")
local shell = require("shell")
local event = require("event")
local uuid = require("uuid")
local modem = component.modem
local modemPort = 199

local program = "ctrl.lua"
local tableToFileName = "tableToFile.lua"
local settingFileName = "doorSettings.txt"
local configFileName = "extraConfig.txt"
local tableToFileCode = "https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/src/libraries/tableToFile.lua"
local singleCode = {"https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/doorcontrols/1.%23.%23/singleDoor.lua","https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/doorcontrols/2.%23.%23/doorControl.lua"}
local multiCode = {"https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/doorcontrols/1.%23.%23/multiDoor.lua","https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/doorcontrols/2.%23.%23/doorControl.lua"}
local versionHolderCode = "https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/versionHolder.txt"

local settingData = {}
local randomNameArray = {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"}
local commandArray = {"getInput","analyzer","clearTerm","terminate"}

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

local function sendMsg(...)
    local arg = table.pack(...)
    for i=1,#arg,1 do
        local argType = type(arg[i])
        if editorSettings.accelerate == true then
            if argType == "string" then
                modem.send(editorSettings.from,editorSettings.port,"print",arg[i])
            elseif argType == "number" then
                modem.send(editorSettings.from,editorSettings.port,commandArray[arg[i]])
                if arg[i] < 3 then
                    local e, _, _, _, _, text = event.pull("modem_message")
                    return text
                end
                if arg[i] == 4 then
                    print("terminated connection")
                end
            else
                modem.send(editorSettings.from,editorSettings.port,"print","potential error in code for sendMsg")
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
    if editorSettings.num == 2 then editorSettings.x = tonumber(sendMsg("NOTICE! Pass overhaul for 2.#.# systems. Please refer to wiki on github","as I should have put a how to there.","Would you like to use the simple pass setup or new advanced one?","1 for simple, 2 for advanced",1)) end
    sendMsg(3)
    if editorSettings.type == "multi" then
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
    end
    os.execute("wget -f " .. tableToFileCode .. " " .. tableToFileName)

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
    end
    saveTable(config,configFileName)

    for i=1,times,1 do
        local loopArray = {}
        sendMsg(3)
        local j
        if editorSettings.type == "multi" then
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
            text = sendMsg("Magnetic card reader?",editorSettings.scanner and "Scan the magnetic card reader with your tablet" or "Enter the uuid of the device in TEXT",editorSettings.scanner and 2 or 1)
            loopArray["reader"] = text
        end
        text = sendMsg("What do you want to nickname this door? This will show up on the server (if it's the 2.#.# version)",1)
        loopArray["name"] = text
        text = sendMsg(editorSettings.type == "multi" and "Door Type? 0= doorcontrol. 2=bundled. 3=rolldoor. NEVER USE 1! NUMBER ONLY" or "Door Type? 0= doorcontrol. 1= redstone 2=bundled. 3=rolldoor. NUMBER ONLY",1)
        loopArray["doorType"] = tonumber(text)
        if loopArray.doorType == 2 then
            text = sendMsg("What color. Use the Color API wiki on the opencomputers wiki, and enter the NUMBER",1)
            loopArray["redColor"] = tonumber(text)
            if editorSettings.type == "multi" then
                sendMsg("No need to input anything for door address. The setting doesn't require it :)")
                loopArray["doorAddress"] = ""
            else
                text = sendMsg("What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left. NUMBER ONLY",1)
                loopArray["redSide"] = tonumber(text)
            end
        elseif loopArray.doorType == 1 then
            loopArray["redColor"] = 0
            text = sendMsg("No need for redColor! The settings you inputted before don't require it :)","What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left. NUMBER ONLY",1)
            loopArray["redSide"] = tonumber(text)
        else
            loopArray["redColor"] = 0
            if editorSettings.type == "single" then loopArray["redSide"] = 0 end
            sendMsg("no need to input anything for redColor. The setting doesn't require it :)",editorSettings.type == "single" and "no need to input anything for redSide. The setting doesn't require it :)" or nil)
            if editorSettings.type == "multi" then
                text = sendMsg("What is the address for the doorcontrol/rolldoor block?", editorSettings.scanner and "Scan the block with tablet" or "Enter uuid as text",editorSettings.scanner and 2 or 1)
                loopArray["doorAddress"] = text
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
        if editorSettings.num == 1 then
            text = sendMsg("What should be read? 0 = level; 1 = armory level; 2 = MTF;","3 = GOI; 4 = Security; 5 = Department; 6 = Intercom; 7 = Staff",1)
            loopArray["cardRead"] = tonumber(text)
            if loopArray.cardRead <= 1 or loopArray.cardRead == 5 then
                text = sendMsg("Access Level of what should be read? NUMBER ONLY",loopArray.cardRead ~= 5 and "level or armory level: enter the level that it should be." or "Department: 1=SD, 2=ScD, 3=MD, 4=E&T, 5=O5",1)
                loopArray["accessLevel"] = tonumber(text)
            else
                loopArray["accessLevel"] = 0
                sendMsg("No need to set access level. This mode doesn't require it :)")
            end
        else --BEGINNING OF 2.0.0 -----------------------------------------------------
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
        end --END OF 2.0.0 -----------------------------------------------------
        text = sendMsg("Is this door opened whenever all doors are asked to open? Not necessary if this is not Site 91","0 if no, 1 if yes. Default is yes",1)
        loopArray["forceOpen"] = tonumber(text)
        text = sendMsg("Is this door immune to lock door? Not necessary if this is not Site 91","0 if no, 1 if yes. Default is no",1)
        loopArray["bypassLock"] = tonumber(text)
        if editorSettings.type == "multi" then tmpTable[j] = loopArray else tmpTable = loopArray end
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
    local text = sendMsg("Old files detected. Please select an option:","1 = wipe all files","2 = add more doors)","3 = delete a door","4 = change a door","5 = update door","6 = change cryptKey",1)
    if tonumber(text) == 1 then
        term.clear()
        sendMsg("Deleting all files...")
        local path = shell.getWorkingDirectory()
        fs.remove(path .. "/" .. program)
        fs.remove(path .. "/" .. tableToFileName)
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
        if config.type == "single" then
            sendMsg("you cannot add more doors as this is a single door. If you want to swap to a multidoor,","wipe all files and reinstall as a multidoor.",4)
            os.exit()
        elseif config.type == "multi" then
            settingData = loadTable(settingFileName)
            text = sendMsg("how many doors would you like to add?",1)
            local num = tonumber(text)
            editorSettings.times = num
            editorSettings.data = settingData
            settingData = runInstall()
            editorSettings.data = settingData
            saveTable(settingData,settingFileName)
            sendMsg("Added the doors. It is recommended you check if it worked, as this is experimental.")
        else
            sendMsg("error reading config file",4)
            os.exit()
        end
        if editorSettings.start == true then
            sendMsg("Starting...",4)
            os.execute(program)
        else
            sendMsg(4)
        end
    elseif tonumber(text) == 3 then
        if config.type == "single" then
            sendMsg("You cannot remove a door as this is a single door. This only works on a multidoor.","If this is meant to be a multidoor, wipe all files and reinstall as a multidoor.",4)
            os.exit()
        elseif config.type == "multi" then
            settingData = loadTable(settingFileName)
            text = sendMsg("What is the key for the door?",1)
            settingData[text] = nil
            saveTable(settingData,settingFileName)
            sendMsg("Removed the door. It is recommended you check if it worked, as this is experimental.")
        else
            sendMsg("error reading config file",4)
            os.exit()
        end
        if editorSettings.start == true then
            sendMsg("Starting...",4)
            os.execute(program)
        else
            sendMsg(4)
        end
    elseif tonumber(text) == 4 then
        if config.type == "single" then
            sendMsg("starting single door editing...")
            editorSettings.edit = true
            settingData = runInstall()
            sendMsg("Old config should be overwritten. It is recommended to double check if it worked.")
        else
            text = sendMsg("What is the key for the door you want to edit?",1)
            editorSettings.key = text
            editorSettings.edit = true
            editorSettings.data = loadTable(settingFileName)
            sendMsg("Starting multi door editing on " .. editorSettings.key .. "...")
            settingData = runInstall()
            sendMsg("Door should have been edited. It is recommended to double check if it worked.")
        end
        saveTable(settingData,settingFileName)
        if editorSettings.start == true then
            sendMsg("Starting...",4)
            os.execute(program)
        else
            sendMsg(4)
        end
    elseif tonumber(text) == 5 then
        text = sendMsg("Are you sure you want to do this? New updates sometimes require manual changing of config.","1 for continue, 2 for cancel",1)
        if tonumber(text) == 1 then
            if config.type == "single" then
                sendMsg("downloading...")
                if config.num == 1 then
                    os.execute("wget -f " .. singleCode[1] .. " " .. program)
                else
                    os.execute("wget -f " .. singleCode[2] .. " " .. program)
                end
            elseif config.type == "multi" then
                sendMsg("downloading...")
                if config.num == 1 then
                    os.execute("wget -f " .. multiCode[1] .. " " .. program)
                else
                    os.execute("wget -f " .. multiCode[2] .. " " .. program)
                end
            else

            end
        end
        text = sendMsg("all done! is set to " .. ser.serialize(config.cryptKey),"Would you like to start the computer now?","1 for yes, 2 for no",1)
        if tonumber(text) == 1 then
            sendMsg("Starting...",4)
            os.execute(program)
        else
            sendMsg("Ok, closing out.",4)
        end
    elseif tonumber(text) == 6 then
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
    end
    config = nil
end

modem.close()
term.clear()
print("Sending query to server...")
modem.open(modemPort)
modem.broadcast(modemPort,"autoInstallerQuery")
local e,_,from,port,_,msg = event.pull(3,"modem_message")
if e == nil then
    print("Failed. Is the server on?")
    os.exit()
end
print("Query received")
query = ser.unserialize(msg)
editorSettings.x = 2
editorSettings.num = query.num
editorSettings.version = query.version
if editorSettings.num == 2 then editorSettings.settings = query.data end
editorSettings.scanner = false
editorSettings.accelerate = false
term.clear()
local text = sendMsg("Would you like to use an external device for accelerated setup?","This makes it easier to set up doors without having to move from the door to the pc constantly.","It requires the program here to be set up on a tablet with a modem: https://github.com/cadergator10/opensecurity-scp-security-system/blob/main/src/extras/acceleratedDoorSetup.lua","1 for yes, 2 for no",1)
if tonumber(text) == 1 then
    local code = math.floor(math.random(1000,9999))
    modem.open(code)
    sendMsg("Code is:  " .. tostring(code),"Enter the code into the door setup tablet. In 60 seconds setup will cancel.")
    local e, _, from, port, _, msg, barcode = event.pull(60, "modem_message")
    if e then
        modem.send(from,port,"connected")
        term.clear()
        sendMsg("Connection successful! All prompts will be on the tablet now on.")
        os.sleep(1)
        editorSettings.scanner = barcode
        editorSettings.accelerate = true
        editorSettings.from = from
        editorSettings.port = port
    else
        modem.close(code)
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
    text = sendMsg("What kind of door do you want? 1 for single, 2 for multi",1)
    if tonumber(text) == 1 then
        editorSettings.type = "single"
        os.execute("wget -f " .. singleCode[editorSettings.num] .. " " .. program)
    elseif tonumber(text) == 2 then
        editorSettings.type = "multi"
        os.execute("wget -f " .. multiCode[editorSettings.num] .. " " .. program)
    else
        term.clear()
        sendMsg("Not an answer:" .. text)
        os.exit()
    end
    settingData = runInstall()
    saveTable(settingData,settingFileName)
    if editorSettings.start == true then
        print("Starting...")
        os.execute(program)
    else
        print("Run " .. program .. " now to start door.")
    end
end
