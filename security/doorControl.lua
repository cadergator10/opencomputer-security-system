--Redone doorControl to fix all bugs.

local doorVersion = "4.0.3"
local doorContinue = true --if changes have been made, set to false. Used to reset the door after changes made
--advanced will be only one used from now on.
local safeMode = false --if true, in safe mode and disables some stuff

local lightThread, doorThread --threads used to run doorControl and light controls

local readerLights = {} --Table of all magReaders IDs used for lights {["new"]=0,["old"]=-1,["check"]=0}

local keypadHolder = {} --Holds states for keypads

--RFID Stuff
local rfidBlock = false --Disables RFID readers
local rfidFound = false --If RFID readers exist, is true. Will change counters in reader light timer since this adds an extra tick to the waiter.
local rfidReaders = {} --Table full of all RFID Readers id's, which a thread uses. {["uuid"]="reader id",["buffer"]=card buffers,["key"]='door key',["size"]=5}
local rfidDoorList = {} --keys of doors for rfid to detect door changes.
local rfidBuffer = {} --Buffer for RFID cards detected. [uuid] = {["timer"]=2,["allowed"]=""}
local rfidInt = 1 --Counter for rfid readers. DO NOT CHANGE
local rfidWait = 2 --Amount of time to hold a door open after a rfid card leaves the range

local doorControls = {} --Holds data about states all doors should be in. {["swipe"]=false,["rfid"]=false,["lock"]=0,["memory"]=false} memory is current state & lock is sector lockdown state.

local sector --sector stuff

local adminCard = "admincard"

local modemPort = 1000 --Ports: 180 = diagPort, 199 = sync port, 198 = reserved, 1000-9999 = valid ports
local diagPort = 180

local component = require("component")
local event = require("event")
local ser = require("serialization")
local term = require("term")
local thread = require("thread")
local process = require("process")
local fs = require("filesystem")
local computer = component.computer

local magReader
local modem = component.modem
local link

local enableSectors = true --Whether sectors are a module on the server

local settingData = {} --All door data
local extraConfig = {} --Important saved data and stuff

local osVersion = false --Whether the magreaders support their lights being changed.

local safeMode = false --If a crash occurs, run safe mode which allows admin diagnostic card to run.

--CORE FUNCTIONS
local function convert( chars, dist, inv ) --For CRYPT
    return string.char( ( string.byte( chars ) - 32 + ( inv and -dist or dist ) ) % 95 + 32 )
end

local function crypt(str,k,inv) --(en/de)crypt data sent or received
    local enc= "";
    for i=1,#str do
        if(#str-k[5] >= i or not inv)then
            for inc=0,3 do
                if(i%4 == inc)then
                    enc = enc .. convert(string.sub(str,i,i),k[inc+1],inv);
                    break;
                end
            end
        end
    end
    if(not inv)then
        for i=1,k[5] do
            enc = enc .. string.char(math.random(32,126));
        end
    end
    return enc;
end

local function deepcopy(orig) --copy table completely with no references to the original
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function saveTable(  tbl,filename ) --duh
    local tableFile = assert(io.open(filename, "w"))
    tableFile:write(ser.serialize(tbl))
    tableFile:close()
end

local function loadTable( sfile ) --DUH
    local tableFile = io.open(sfile)
    if tableFile ~= nil then
        return ser.unserialize(tableFile:read("*all"))
    else
        return nil
    end
end

local function send(port,linker,...) --Sends a message through either the modem or linking card
    if linker and link ~= nil then --if true linking card exists
        link.send(modem.address,...)
        return
    end
    modem.broadcast(port,...) --otherwise, linking card didnt exist or user doesn't want to use it, therefore send over modem.
end

--MAGREADER CARD CHANGING
local function colorupdate() --Runs the color logic behind the magreaders as well as sets up the keypads.
    if osVersion then --Make sure version is up to this date.
        --Set up readerLights list.
        readerLights = {}
        for key,_ in pairs(component.list("os_magreader")) do
            if component.proxy(key).swipeIndicator ~= nil then component.proxy(key).swipeIndicator(false) end
            readerLights[key] = {["new"]=0,["old"]=-1,["check"]=0}
        end
        for key,_ in pairs(component.list("os_keypad")) do --Set up the Keypad display.
            local customButtons = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "#"}
            local customButtonColor = {7, 7, 7, 7, 7, 7, 7, 7, 7, 6, 7, 10}
            component.proxy(key).setDisplay("locked", 14)
            component.proxy(key).setKey(customButtons, customButtonColor)
            keypadHolder[key] = ""
        end
        while true do
            for key, value in pairs(readerLights) do --Check every reader listed here
                if type(value.new) == "table" then --Timed door closing
                    if #value.new == 0 then --no more lights to change, so reverting to regular static one.
                        readerLights[key].new = readerLights[key].check --check is what it should look like after finished changing light.
                    else
                        if value.new[1].status == nil then --List isn't prepped yet (no timer)
                            readerLights[key].new[1].status = true --Set up
                            if component.proxy(key).setLightState ~= nil then component.proxy(key).setLightState(value.new[1].color) end --Change light state
                            readerLights[key].old = readerLights[key].new[1].color
                        else --Is prepped, so add delay
                            readerLights[key].new[1].delay = readerLights[key].new[1].delay - 0.05 --decrease by a tick.
                            if readerLights[key].new[1].delay <= 0 then --Timer expired, change to next one.
                                table.remove(readerLights[key].new,1) --remove this light state from list
                                if #value.new == 0 then --no more lights to change
                                    if component.proxy(key).setLightState ~= nil then component.proxy(key).setLightState(value.check) end
                                end
                            end
                        end
                    end
                elseif value.new ~= value.old then
                    if value.new == -1 then --Fix the .new if wrong int
                        value.new = value.check
                    end
                    if component.proxy(key).setLightState ~= nil then component.proxy(key).setLightState(value.new) end
                    readerLights[key].old = readerLights[key].new
                end
            end
            --RFID stuff used to exist here. In doorthread now to lower complexity hopefully.
            os.sleep(0.05)
        end
    end
end
--Function used to change data in the readerLights list
local function colorLink(key, var, check) --{["color"]=0,["delay"]=1} or just a number
    local chech = function(key) --actual logic. Stuff below it simply runs it for every reader uuid.
        if component.proxy(key) ~= nil then --reader actually exists.
            if(osVersion and component.proxy(key).swipeIndicator ~= nil) then --can change reader's lights.
                if readerLights[key] ~= nil then
                    if check then readerLights[key].check = check end
                    readerLights[key].new = deepcopy(var)
                    --Used to set up reader if it didn't exist. Removed that since on door setting change, it will restart services anyway.
                end
            end
        end
    end
    if type(key) == "table" then --multiple readers in one door
        for i=1,#key,1 do
            if key[i].type == "swipe" then chech(key[i].uuid) end
        end
    else --one reader, so only do that one
        chech(key)
    end
end
--END OF MAGREADER CARD CHANGING

--BEGINNING OF DOORTHREAD
local function doorupdate() --A seperate thread that handles the doors & RFID Readers.
    local extraDelay = 0.05 --Delay to use to accomodate ticks used by opening/shutting doors & scanning the rfid readers.
    --Door Setup
    doorControls = {} --clear table in case of reset
    keypadHolder = {} --clear table in case of reset.
    rfidReaders = {} --clear table in case of reset.
    rfidDoorList = {} --you know the drill
    rfidBuffer = {} --why you still here?
    for key,value in pairs(settingData) do --Go through all currently setup doors.
        doorControls[key] = {["swipe"]=false,["rfid"]=false,["lock"]=0,["memory"]=false}
        for _,value2 in pairs(value.reader) do
            if(component.proxy(value2.uuid) ~= nil) then --make sure it exists.
                if rfidBlock == false then
                    if value2.type == "rfid" then --Set up its RFID Data.
                        if(rfidFound == false) then
                            rfidFound = true --An RFID exists.
                            extraDelay = 0.1 --Accomodate tick used by RFID Reader
                        end
                        table.insert(rfidReaders,{["uuid"]=value2.uuid,["buffer"]={},["key"]=key,["size"]=5})
                    end
                end
            end
        end
    end
    --Go through all doorcontrollers set up on the system.
    for key,_ in pairs(component.list("os_doorcontroller")) do
        component.proxy(key).close()
    end
    for key,_ in pairs(component.list("os_rolldoorcontroller")) do
        component.proxy(key).close()
    end
    --For older versions of opensecurity
    for key,_ in pairs(component.list("os_doorcontrol")) do
        component.proxy(key).close()
    end
    for key,_ in pairs(component.list("os_rolldoorcontrol")) do
        component.proxy(key).close()
    end
    --TODO: Reset all redstone on doorcontroller so its all false.
    while true do
        local thisDelay = extraDelay
        extraDelay = rfidFound and 0.1 or 0.05
        local shouldContinue = true --If true, it means this should continue to check through array. If false, it waits to be invoked by a card swipe or something of that sort. (has been locked to true due to rfid reader stuff being in here.
        --BEGINNING OF RFID SECTION
        if rfidFound then
            local reader = component.proxy(rfidReaders[rfidInt].uuid).scan(rfidReaders[rfidInt].size) --scan and perform checks on new cards found
            for _,value in pairs(reader) do --go through all cards found in range
                local data = value.data ~= nil and ser.unserialize(crypt(value.data,extraConfig.cryptKey,true)) or nil --get data off card
                if data ~= nil then
                    if rfidReaders[rfidInt].buffer[data.uuid] == nil then --if there is data and crypt is correct
                        event.push("rfidSuccess",rfidReaders[rfidInt].uuid,nil,data) --push to main thread to check if allowed or not
                        local e, status = event.pull(5,"rfidRequest") --receive results
                        rfidReaders[rfidInt].buffer[data.uuid] = {["timer"]=rfidWait,["allowed"]=status} --add new user to buffer
                    else
                        rfidReaders[rfidInt].buffer[data.uuid].timer = rfidWait --Update timer back to max as they are still in range
                    end
                end
            end
        end
        local doorList = {} --This part goes through all readers listed and checks users in buffer if their timers ran out. Also checks if door should be opened or not
        for i=1, #rfidReaders, 1 do --go through all readers
            doorList[rfidReaders[i].key] = doorList[rfidReaders[i].key] ~= nil and doorList[rfidReaders[i].key] or false --Set the current key to false
            for key, value in pairs(rfidReaders[i].buffer) do --go through every card in buffer
                rfidReaders[i].buffer[key].timer = rfidReaders[i].buffer[key].timer - thisDelay
                if value.timer <= 0 and i == rfidInt then --remove cards if they run out of time and the current door that just scanned didn't see them
                    rfidReaders[i].buffer[key] = nil
                elseif value.allowed == true then
                    doorList[rfidReaders[i].key] = true
                end
            end
        end
        for key,value in pairs(doorList) do --This goes through the list made in the last section to see if any changes were made (need to open or close again)
            if value ~= rfidDoorList[key] then --there was a change in a door
                rfidDoorList[key] = value
                doorControls[key].rfid = value --update actual door table that opens/closes stuff
            end
        end
        if rfidInt >= #rfidReaders then --This checks if its gone through every rfidreader. If it has, reset to beginning. Otherwise it increments the rfidint
            rfidInt = 1
        else
            rfidInt = rfidInt + 1
        end
        --END OF RFID SECTION
        for key, value in pairs(doorControls) do
            local isOpen = false --Will be set to whether the door should be opened or closed. Compared to memory (what it is set to)
            if value.lock == 0 or value.lock == 1 then --sector lockdown is clear. OR LOCKDOWN. TEST IF THIS WORKS
                if type(value.swipe) == "number" then --number is the delay until it shuts again
                    shouldContinue = true --will keep running the loop to ensure the delay counts down
                    doorControls[key].swipe = value.swipe - thisDelay --decrease counter by delay
                    if value.swipe <= 0 then --timer ran out so close
                        doorControls[key].swipe = false
                    else
                        isOpen = true --should be open
                    end
                else
                    isOpen = value.swipe
                end
            elseif value.lock == 2 then --sector lockdown is open
                isOpen = true --TODO: Check if this still works if lockdown is on and user has lockdown bypass. May have to remove check if lock is 0 (if used)
            end --if value.lock == 1 then isOpen is equal to false (already set) sector lockdown is locked.
            if isOpen ~= value.memory then --there has been a door change.
                doorControls[key].memory = isOpen --Update memory to what the door should now be
                if settingData[key].doorType == 3 then --rolldoor/doorcontrol type
                    for _, value2 in pairs(settingData[key].doorAddress) do
                        if component.proxy(value2) ~= nil then
                            if isOpen then
                                component.proxy(value2).open()
                            else
                                component.proxy(value2).close()
                            end
                            extraDelay = extraDelay + 0.05
                        end
                    end
                elseif settingData[key].doorType == 2 then --bundled redstone
                    component.redstone.setBundledOutput(settingData[key].redSide, { [settingData[key].redColor] = isOpen and 255 or 0 } )
                    extraDelay = extraDelay + 0.05
                elseif settingData[key].doorType == 1 then --Regular redstone
                    component.redstone.setOutput(settingData[key].redSide,isOpen and 15 or 0)
                    extraDelay = extraDelay + 0.05
                end
                if isOpen then --Open door or don't.
                    colorLink(settingData[key].reader,{{["color"]=4,["delay"]=2},{["color"]=0,["delay"]=0}})
                else
                    colorLink(settingData[key].reader,-1) --TODO: Check if -1 works right and resets it to check.
                end
            end
        end
        if shouldContinue then
            os.sleep(0.05) --Wait a tick before relooping
        else
            event.pull(5, "doorchange") --Pause for 5 seconds OR until event received
        end
    end
end

local function doorLink(key, var) --Changes doorControls array if any changes detected
    if doorControls[key] ~= nil then --Make sure it exists
        if type(var) == "number" then --Delay for how long it should be open
            doorControls[key].swipe = var
        elseif type(doorControls[key].swipe) == "number" or doorControls[key].swipe == false then --It's a toggle, so simply flip the true/false (number is always true since open)
            doorControls[key].swipe = true
        else
            doorControls[key].swipe = false
        end
        --event.push("doorChange") --Tell door thread to begin checking doors again.
    end
end
--END OF DOORTHREAD

--BEGINNING OF SECTOR STUFF
local function sectorfresh(data)
    if enableSectors then
        for dk,value in pairs(settingData) do --Go through all doors
            if value.sector ~= false then --Door has a sector
                for key,value2 in pairs(data) do --Go through every sector sent out
                    if key == value.sector then --This is the sector it was sent to.
                        doorControls[dk].lock = value2 - 1 --Set lock mode to the sector status
                        local openFunc = {doorControls[dk].swipe, false, true}
                        doorLink(dk, openFunc[value2])
                        if osVersion then --Reader lights can be changed
                            if value2 == 1 then --clear
                                colorLink(value.reader,0,0)
                            elseif value2 == 2 then --lock
                                colorLink(value.reader,1,1)
                            elseif value2 == 3 then --open
                                colorLink(value.reader,4,4)
                            end
                        end
                        break
                    end
                end
            end
        end
        --event.push("doorChange")
    end
end
--END OF SECTOR STUFF

--BEGINNING OF SYSTEM SETUP

local function resetProgram()
    if doorThread ~= nil and doorThread:status() == "running" then --kill thread if exists
        doorThread:kill()
        doorThread = nil
    else
        print("Door thread is already dead")
    end
    if lightThread ~= nil and lightThread:status() == "running" then --kill thread if exists
        lightThread:kill()
        lightThread = nil
    else
        print("Light thread is already dead")
    end
    for key,_ in pairs(component.list("os_keypad")) do
        component.proxy(key).setDisplay("inactive", 6)
    end
    if osVersion then
        for key,_ in pairs(component.list("os_magreader")) do
            if(component.proxy(key).setLightState ~= nil) then
                component.proxy(key).setLightState(7) --to show system is off
            end
        end
    end
end

local function setup()
    if component.isAvailable("tunnel") then --Check if linking card is connected.
        link = component.tunnel
    end
    term.clear()
    local fill = io.open("doorSettings.txt", "r")
    if fill~=nil then --doorSettings file exists
        io.close(fill)
    else
        print("No doorSettings.txt detected. Reinstall door control")
        os.exit()
    end
    fill = io.open("extraConfig.txt","r")
    if fill ~= nil then --extraConfig file exists
        io.close(fill)
    else
        print("No config detected. Reinstall door control")
    end
    extraConfig = loadTable("extraConfig.txt")
    settingData = loadTable("doorSettings.txt")
    extraConfig.version = doorVersion --Make sure version is right
    if extraConfig.port == nil then --make sure port exists
        extraConfig.port = 1000
    end
    extraConfig.type = "doorsystem" --Make these settings right
    extraConfig.num = 3
    saveTable(extraConfig,"extraConfig.txt") --save changes
    modemPort = extraConfig.port --update port

    if modem.isOpen(modemPort) == false and link == nil then --open port if linking card is not installed
        modem.open(modemPort)
    elseif link ~= nil then --if link exists, make sure port is closed.
        modem.close(modemPort)
    end
    if component.isAvailable("os_magreader") then --check if a magreader exists (since one is recommended for admincard diagnostics)
        magReader = component.os_magreader
        if magReader.swipeIndicator ~= nil then
            osVersion = true
        end
    else
        print("A Magreader is recommended to be connected at least if you plan on ever using the Diagnostic tablet (admin card)")
    end

    local checkBool = false --var if true, save the table (after loop) if false, don't save. Loop removes any nonexistent passes from the doors.
    send(modemPort,true,"getquery",ser.serialize({"passSettings","sectorStatus"})) --get query
    local e,_,_,_,_,query = event.pull(3,"modem_message") --pull message
    query = crypt(query,extraConfig.cryptKey,true) --decrypt message
    query = ser.unserialize(query) --turn it into a table
    if e ~= nil then --message received
        for key,_ in pairs(settingData) do --changing stuff in doorTable if older system.
            if type(settingData[key].doorAddress) == "string" then --convert old door type: doorAddress is now a list
                settingData[key].doorAddress = {settingData[key].doorAddress}
                checkBool = true
            end
            if settingData[key].doorType == 0 then --convert old door type: doorcontroller and rolldoor controller are now both 3
                settingData[key].doorType = 3
                checkBool = true
            end
            if type(settingData[key].reader) == "string" then --convert old door type: reader is now list of strings.
                settingData[key].reader = {settingData[key].reader}
                checkBool = true
            end
            if settingData[key].redSide == nil then --convert old door type: all doors can have a redSide now for regular redstone.
                settingData[key].redSide = 2
                checkBool = true
            end
            if type(settingData[key].reader[1]) == "string" then --convert old door type: lot more data than a list of strings now.
                for key2, value in pairs(settingData[key].reader) do
                    settingData[key].reader[key2] = {["type"]="swipe",["uuid"]=value}
                end
                checkBool = true
            end
        end
    else
        print("Failed to receive confirmation from server")
        os.exit()
    end
    if checkBool then
        saveTable(settingData,"doorSettings.txt")
    end
    checkBool = nil
    --adding device to server's files
    fill = {}
    fill["type"] = extraConfig.type
    fill["data"] = settingData
    send(modemPort,true,"setdevice",crypt(ser.serialize(fill),extraConfig.cryptKey))
    local got, _, _, _, _, _ = event.pull(2, "modem_message")
    if got == false then
        print("Failed to receive confirmation from server")
        os.exit()
    end
    fill = nil
    got = nil

    if query.data.sectorStatus == nil then --enable/disable sectors
        enableSectors = false
    end

    --Starting threads
    lightThread = thread.create(colorupdate)
    doorThread = thread.create(doorupdate)

    sectorfresh(query.data.sectorStatus) --

    process.info().data.signal = function(...) --making sure stuff is done after system is stopped.
        print("caught hard interrupt")
        resetProgram()
        os.exit()
    end
    modem.open(diagPort)

    --Print out the stuff on top of screen
    print("Security Door Control terminal")
    print("---------------------------------------------------------------------------")
end
--END OF SYSTEM SETUP

--BEGINNING OF SUB PROGRAMS (split types of stuff into functions)
local function modemMessage(_, localAddress, remoteAddress, port, distance, msg, data)
    if msg == "checkSector" and safeMode == false then --Changes to Sector
        data = ser.unserialize(data)
        sectorfresh(data) --Update doors to sector changes
    elseif msg == "remoteControl" and safeMode == false then --remotely open a door
        data = ser.unserialize(data)
        if data.id == modem.address then
            term.write("RemoteControl request received for " .. settingData[data.key].name)
            term.write("\n")
            send(modemPort,true,"loginfo",ser.serialize({{["text"]="Remote control open: ",["color"]=0xFFFF80},{["text"]=settingData[data.key].name,["color"]=0xFFFFFF}}))
            if data.type == "base" then --Simply open door according to how the door is set up
                doorLink(data.key,settingData[data.key].toggle == 1 and true or settingData[data.key].delay)
            elseif data.type == "toggle" then --toggle door
                doorLink(data.key,true)
            elseif data.type == "delay" then --open for delay seconds
                doorLink(data.key,data.delay)
            end
        end
    elseif msg == "changeSettings" then --Updated door settings from runtime door editing.
        doorContinue = false --door will reset after this code below this is run.
        resetProgram() --close out all threads.
        data = ser.unserialize(data)
        settingData = data
        os.execute("copy -f doorSettings.txt dsBackup.txt") --save backup just in case
        saveTable(settingData,"doorSettings.txt") --save new data
        print("New settings received")
        os.sleep(1)
        local fill = {}
        fill["type"] = extraConfig.type
        fill["data"] = settingData
        send(modemPort,true,"setdevice",crypt(ser.serialize(fill),extraConfig.cryptKey)) --update server with new data
        local got, _, _, _, _, _ = event.pull(2, "modem_message")
        if got == false then
            print("Failed to receive confirmation from server")
            os.exit()
        end
    elseif msg == "identifyMag" and safeMode == false then --show magreaders that are linked by the lights.
        local lightShow = function(data)
            for i=1,5,1 do
                for j=1,3,1 do
                    colorLink(data.reader,j~=3 and j or 4)
                    os.sleep(0.3)
                end
            end
            colorLink(data.reader,-1)
        end
        if osVersion then thread.create(lightShow,ser.unserialize(data)) end
    elseif msg == "deviceCheck" then  --server is checking if this device exists
        send(modemPort,true,"true")
    elseif msg == "UUIDCheck" then --Diagnostic tablet asking the door computer whether the components exist & what type they are.
        data = ser.unserialize(crypt(data, extraConfig.cryptKey, true))
        if(data ~= nil) then
            local tabe = {}
            for _, value in pairs(data) do
                tabe[value] = component.type(value)
            end
            modem.send(remoteAddress, diagPort, crypt(ser.serialize(tabe),extraConfig.cryptKey)) --Return type of the devices
        end
    elseif msg == "threadUpdate" then
        modem.send(remoteAddress, diagPort, "door: " .. doorThread:status() .. " light: " .. lightThread:status())
    end
end

local function readerReturn(address)
    local keyed = nil
    for key, valuedd in pairs(settingData) do
        for i=1,#valuedd.reader,1 do
            if(valuedd.reader[i].uuid == address) then
                keyed = key
                break
            end
        end
        if keyed ~= nil then
            break
        end
    end
    return keyed
end

local bypassallowed = false --for if bypassing lockdown
local function enterCheck(data, whereTo, type, keyed)
    send(modemPort, true, whereTo, data)
    local e, _, from, port, _, msg = event.pull(1, "modem_message")
    if e then
        data = crypt(msg, extraConfig.cryptKey, true)
        if data == "true" then
            term.write("Access granted\n")
            computer.beep()
            if type == "rfidSuccess" then
                event.push("rfidRequest",true)
            else
                doorLink(keyed,settingData[keyed].toggle == 1 and true or settingData[keyed].delay)
            end
        elseif data == "false" then
            term.write("Access denied\n")
            if type == "rfidSuccess" then
                event.push("rfidRequest",false)
            end
            if osVersion then
                colorLink(settingData[keyed].reader,{{["color"]=1,["delay"]=1},{["color"]=0,["delay"]=0}})
            end
            computer.beep()
            computer.beep()
        elseif data == "bypass" then
            if type ~= "rfidSuccess" then
                if bypassallowed then
                    term.write("Bypass succeeded: lockdown lifted\n")
                    if osVersion then
                        colorLink(settingData[keyed].reader,{{["color"]=4,["delay"]=0.5},{["color"]=0,["delay"]=0.5},{["color"]=4,["delay"]=0.5},{["color"]=0,["delay"]=0.5}})
                    end
                    data = crypt(settingData[keyed].sector,extraConfig.cryptKey)
                    send(modemPort,true, "doorsecupdate", data)
                    computer.beep()
                    computer.beep()
                    computer.beep()
                else
                    bypassallowed = true
                    thread.create(function()
                        os.sleep(3)
                        bypassallowed = false
                    end)
                    term.write("Requesting bypass\n")
                    if osVersion then
                        colorLink(settingData[keyed].reader,{{["color"]=3,["delay"]=0.5},{["color"]=0,["delay"]=0.5},{["color"]=3,["delay"]=0.5},{["color"]=0,["delay"]=0.5},{["color"]=3,["delay"]=0.5},{["color"]=0,["delay"]=0.5}})
                    end
                end
            else
                event.push("rfidRequest",false)
            end
        else
            term.write("Unknown command\n")
        end
    else
        term.write("server timeout\n")
        if osVersion then
            colorLink(settingData[keyed].reader,{{["color"]=5,["delay"]=1},{["color"]=0,["delay"]=0}})
        end
    end
end

local function keypadProgram(_, address, user, str, uuid, data)
    if str == "C" then --clear data
        keypadHolder[address] = ""
        component.proxy(address).setDisplay("locked", 14)
    elseif string.len(keypadHolder[address]) < 4 then --make sure count is less than 4
        keypadHolder[address] = keypadHolder[address] .. str
        str = ""
        for i=1,string.len(keypadHolder[address]),1 do
            str = str .. "*"
        end
        component.proxy(address).setDisplay(str, 7)
    elseif str == "#" then
        local keyed = readerReturn(address)
        if keyed == nil then
            print("KEYPAD IS NOT FOUND LINKED TO ANY DOOR! Exiting to safe mode")
            error("No keypad found")
        end
        local tmpTable = {["uuid"]=address,["pass"]=keypadHolder[address]}
        tmpTable["type"] = extraConfig.type
        tmpTable["key"] = keyed
        tmpTable["sector"] = sector
        local data = crypt(ser.serialize(tmpTable), extraConfig.cryptKey)
        send(modemPort,true,"checkKeypad",data)
        keypadHolder[address] = ""
        component.proxy(address).setDisplay("locked", 14)
        enterCheck(data, "checkKeypad", "keypad")
    end --TODO: Finish logic for normal door cards
end

local function miscReaderProgram(ev, address, user, str, uuid, data)
    local keyed = readerReturn(address)
    if keyed == nil then
        print("READER IS NOT FOUND LINKED TO ANY DOOR! Exiting to safe mode")
        error("No reader found")
    end
    local data
    if ev == "bioReader" then
        data = user
    else
        data = str
    end
    if(data ~= adminCard) then
        local tmpTable
        if ev == "rfidSuccess" then
            tmpTable = data
            if tmpTable == nil then
                term.write("Card failed to read. it may not have been written to right or cryptkey may be incorrect.")
                if osVersion then colorLink(settingData[keyed].reader,{{["color"]=3,["delay"]=3},{["color"]=0,["delay"]=1}}) end
                return
            end
            tmpTable.isRFID = true
            term.write(tmpTable["name"] .. ":")
        else
            tmpTable = {["isBio"] = true,["uuid"] = user}
            term.write("UUID " .. user .. ":")
        end
        tmpTable["type"] = extraConfig.type
        tmpTable["key"] = keyed
        tmpTable["sector"] = sector
        data = crypt(ser.serialize(tmpTable), extraConfig.cryptKey)
        enterCheck(data, "checkRules", ev, keyed)
        return
    end
    print("DO NOT HAVE ADMIN CARD AS RFID")
end

local function  magReaderProgram(ev, address, user, str, uuid, data)
    if osVersion then colorLink(address,2) end
    local isOk = "incorrect magreader"
    local keyed = readerReturn(address)
    if keyed == nil then
        print("READER IS NOT FOUND LINKED TO ANY DOOR! Exiting to safe mode")
        if crypt(str, extraConfig.cryptKey, true) ~= adminCard then error("No reader found") end
    end
    local data = crypt(str, extraConfig.cryptKey, true)
    if data == adminCard then
        term.write("Admin card swiped. Sending diagnostics\n")
        modem.open(diagPort)
        local diagData = deepcopy(settingData[keyed])
        if diagData == nil then
            diagData = {}
        end
        diagData["status"] = isOk
        diagData["version"] = doorVersion
        diagData["key"] = keyed or nil
        diagData["num"] = 3
        diagData["entireDoor"] = deepcopy(settingData)
        local counter = 0
        for index in pairs(settingData) do
            counter = counter + 1
        end
        diagData["entries"] = counter
        data = ser.serialize(diagData)
        send(diagPort,false, "diag", data)
        if osVersion then
            colorLink(settingData[keyed].reader,{{["color"]=1,["delay"]=0.3},{["color"]=2,["delay"]=0.3},{["color"]=4,["delay"]=0.3},{["color"]=0,["delay"]=0}})
        end
    else
        local tmpTable = ser.unserialize(data)
        if tmpTable == nil then
            term.write("Card failed to read. it may not have been written to right or cryptkey may be incorrect.")
            if osVersion then colorLink(settingData[keyed].reader,{{["color"]=3,["delay"]=3},{["color"]=0,["delay"]=1}}) end
            return
        end
        term.write(tmpTable["name"] .. ":")
        tmpTable["type"] = extraConfig.type
        tmpTable["key"] = keyed
        tmpTable["sector"] = sector
        data = crypt(ser.serialize(tmpTable), extraConfig.cryptKey)
        enterCheck(data, "checkRules", ev, keyed)
    end
end

--END OF SUB PROGRAMS

--MAIN PROGRAM
while true do
    if pcall(function()
        setup() --Start the setup for the base system.
        doorContinue = true --if changes have been made, set to false.
        while doorContinue do
            local ev, address, user, str, uuid, data, data2 = event.pullMultiple("magData","bioReader","rfidSuccess","keypad","modem_message") --for keypad, address is its address, user is button id, str is button label.
            if ev == "modem_message" then
                modemMessage(ev, address, user, str, uuid, data, data2)
            elseif ev == "keypad" then
                keypadProgram(ev, address, user, str, uuid, data, data2)
            elseif ev == "rfidSuccess" or ev == "bioReader" then
                miscReaderProgram(ev, address, user, str, uuid, data, data2)
            elseif ev == "magData" then
                magReaderProgram(ev, address, user, str, uuid, data, data2)
            end
        end

    end) then
        --do nothing since it worked well.
    else --program crashed. run in safe mode
        resetProgram() --reset any remaining tasks
        doorContinue = true
        print("An error has occurred, likely with a misconfigured magreader, and has opened in safe mode.")
        print("Limited features are available (admincard, doorediting, and such.)")
        print("Click screen or use runtime door editing to exit safe mode")
        while doorContinue do
            local ev, address, user, str, uuid, data = event.pullMultiple("magData","modem_message","touch")
            if ev == "modem_message" then
                modemMessage(ev, address, user, str, uuid, data)
            elseif ev == "magData" then --admin card only
                local data = crypt(str, extraConfig.cryptKey, true)
                if data == adminCard then
                    local isOk = "safe mode"
                    term.write("Admin card swiped. Sending diagnostics\n")
                    modem.open(diagPort)
                    local diagData = {}
                    diagData["status"] = isOk
                    diagData["version"] = doorVersion
                    diagData["num"] = 3
                    diagData["entireDoor"] = deepcopy(settingData)
                    local counter = 0
                    for index in pairs(settingData) do
                        counter = counter + 1
                    end
                    diagData["entries"] = counter
                    data = ser.serialize(diagData)
                    send(diagPort,false, "diag", data)
                    if osVersion then
                        colorLink(address,{{["color"]=1,["delay"]=0.3},{["color"]=2,["delay"]=0.3},{["color"]=4,["delay"]=0.3},{["color"]=0,["delay"]=0}})
                    end
                end
            else
                doorContinue = false
            end
        end
    end
end