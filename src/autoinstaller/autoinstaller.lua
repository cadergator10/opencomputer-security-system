local component = require("component")
local term = require("term")
local io = require("io")
local ser = require("serialization")
local fs = require("filesystem")
local shell = require("shell")
local event = require("event")
local modem = component.modem
local modemPort = 199

local program = "ctrl.lua"
local tableToFileName = "tableToFile.lua"
local settingFileName = "doorSettings.txt"
local configFileName = "extraConfig.txt"
local tableToFileCode = "https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/src/libraries/tableToFile.lua"
local singleCode = {"https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/doorcontrols/1.%23.%23/singleDoor.lua","https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/doorcontrols/2.%23.%23/singleDoor.lua"}
local multiCode = {"https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/doorcontrols/1.%23.%23/multiDoor.lua","https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/doorcontrols/2.%23.%23/multiDoor.lua"}
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
    if editorSettings.type == "multi" then
        os.execute("wget -f " .. multiCode[editorSettings.num] .. " " .. program)
        if editorSettings.times ~= nil then
            tmpTable = editorSettings.data --TEST: if runInstall times gets the previous array if needed
            times = editorSettings.times
        elseif editorSettings.key ~= nil then
            times = 1
            tmpTable = editorSettings.data
        else
            text = sendMsg("Read the text carefully. Some of the inputs REQUIRE NUMBERS ONLY! Some require text.","The redSide is always 2, or back of the computer.","How many different doors are there?",1)
            times = tonumber(text)
        end
    else
        os.execute("wget -f " .. singleCode[editorSettings.num] .. " " .. program)
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
            text = sendMsg("What color. Use the Color API wiki provided in discord, and enter the NUMBER",1)
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
        else
            --TEST: Will new autoinstaller work with new 2.#.# system
            local nextmsg = "What should be read? 0 = staff,"
            for i=1,#editorSettings.settings.var,1 do
                nextmsg = nextmsg .. ", " .. i .. " = " .. editorSettings.settings.label[i]
            end
            text = sendMsg("What should be read?" .. nextmsg,1)
            if tonumber(text) == 0 then
                loopArray["cardRead"] = 6
                loopArray["accessLevel"] = 0
                sendMsg("No need to set access level. This mode doesn't require it :)")
            else
                loopArray["cardRead"] = tonumber(text) + 6
                if editorSettings.settings.type[loopArray.cardRead - 6] == "string" or editorSettings.settings.type == "-string" then
                    text = sendMsg("What is the string you would like to read? Enter text.",1)
                    loopArray["accessLevel"] = text
                elseif editorSettings.settings.type[loopArray.cardRead - 6] == "bool" then
                    loopArray["accessLevel"] = 0
                    sendMsg("No need to set access level. This mode doesn't require it :)")
                elseif editorSettings.settings.type[loopArray.cardRead - 6] == "int" then
                    if editorSettings.settings.above[loopArray.cardRead - 6] == true then
                        text = sendMsg("What level and above should be required?",1)
                    else
                        text = sendMsg("what level exactly should be required?",1)
                    end
                    loopArray["accessLevel"] = tonumber(text)
                elseif editorSettings.settings.type[loopArray.cardRead - 6] == "-int" then
                    local nextmsg = "What group are you wanting to set?"
                    for i=1,#editorSettings.settings.data[loopArray.cardRead - 6],1 do --TEST: Does grabbing loopArray again work as int
                        nextmsg = nextmsg .. ", " .. i .. " = " .. editorSettings.settings.data[loopArray.cardRead - 6][i]
                    end
                    text = sendMsg(nextmsg,1)
                    loopArray["accessLevel"] = tonumber(text)
                else
                    sendMsg("error in cardRead area for num 2")
                    loopArray["accessLevel"] = 0
                end
            end
        end
        text = sendMsg("Is this door opened whenever all doors are asked to open? Not necessary if this is not Site 91","0 if no, 1 if yes. Default is yes",1)
        loopArray["forceOpen"] = tonumber(text)
        text = sendMsg("Is this door immune to lock door? Not necessary if this is not Site 91","0 if no, 1 if yes. Default is no",1)
        loopArray["bypassLock"] = tonumber(text)
        if editorSettings.type == "multi" then tmpTable[j] = loopArray else tmpTable = loopArray end
    end
    sendMsg("All done with installer!",4)

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
            sendMsg("Added the doors. It is recommended you check if it worked, as this is experimental.",4)
        else
            sendMsg("error reading config file",4)
            os.exit()
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
            sendMsg("Removed the door. It is recommended you check if it worked, as this is experimental.",4)
        else
            sendMsg("error reading config file",4)
            os.exit()
        end
    elseif tonumber(text) == 4 then --TEST: MultiDoor editing works now and doesn't erase it.
        if config.type == "single" then
            sendMsg("starting single door editing...")
            editorSettings.edit = true
            settingData = runInstall()
            sendMsg("Old config should be overwritten. It is recommended to double check if it worked.",4)
        else
            text = sendMsg("What is the key for the door you want to edit?",1)
            editorSettings.key = text
            editorSettings.edit = true
            editorSettings.data = loadTable(settingFileName)
            sendMsg("Starting multi door editing on " .. editorSettings.key .. "...")
            settingData = runInstall()
            sendMsg("Door should have been edited. It is recommended to double check if it worked.",4)
        end
        saveTable(settingData,settingFileName)
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
        sendMsg(4)
    elseif tonumber(text) == 6 then
        sendMsg("there are 5 parameters, each requiring a number. Recommend doing 1 digit numbers cause I got no idea how this works lol")
        for i=1,5,1 do
            text = sendMsg("enter param " .. i,1)
            config.cryptKey[i] = tonumber(text)
        end
        saveTable(config,configFileName)
        sendMsg("all done! is set to " .. ser.serialize(config.cryptKey),4)
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
editorSettings.num = query.num
editorSettings.version = query.version
if editorSettings.num == 2 then editorSettings.settings = query.data end
editorSettings.scanner = false
editorSettings.accelerate = false
term.clear()
text = sendMsg("Would you like to use an external device for accelerated setup?","This makes it easier to set up doors without having to move from the door to the pc constantly.","It requires the program here to be set up on a tablet with a modem: https://github.com/cadergator10/opensecurity-scp-security-system/blob/main/src/extras/acceleratedDoorSetup.lua","1 for yes, 2 for no",1) --TEST: does accelerated door setup work?
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
    elseif tonumber(text) == 2 then
        editorSettings.type = "multi"
    else
        term.clear()
        sendMsg("Not an answer:" .. text)
        os.exit()
    end
    settingData = runInstall()
    saveTable(settingData,settingFileName)
    print("Run " .. program .. " now to start door.")
end
