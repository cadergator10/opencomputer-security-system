--------Base APIS and variables
local diagPort = 180
local modemPort = 199

local component = require("component")
local event = require("event")
local modem = component.modem 
local ser = require ("serialization")
local term = require("term")
local ios = require("io")
local keyboard = require("keyboard")
local thread = require("thread")
local process = require("process")
local uuid = require("uuid")

--------Extra Arrays

local toggleTypes = {"not toggleable","toggleable"}
local doorTypeTypes = {"Door Control","Redstone dust","Bundled Cable","Rolldoor"}
local redSideTypes = {"bottom","top","back","front","right","left"}
local redColorTypes = {"white","orange","magenta","light blue","yellow","lime","pink","gray","silver","cyan","purple","blue","brown","green","red","black"}
local forceOpenTypes = {"False","True"}
local passTypes = {["string"]="Inputtable String",["-string"]="Hidden String",["int"]="Level",["-int"]="Group",["bool"]="Bool"}

local supportedVersions = {"2.2.0","2.2.1","2.2.2","2.3.0","2.3.1"}

local randomNameArray = {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"}

local settings

lengthNum = 0

local pageNum = 1

local diagt = nil

local experimental = false
--------Base Functions

local function convert( chars, dist, inv )
    return string.char( ( string.byte( chars ) - 32 + ( inv and -dist or dist ) ) % 95 + 32 )
  end
   
  --// exportstring( string )
  --// returns a "Lua" portable version of the string
  local function exportstring( s )
      s = string.format( "%q",s )
      -- to replace
      s = string.gsub( s,"\\\n","\\n" )
      s = string.gsub( s,"\r","\\r" )
      s = string.gsub( s,string.char(26),"\"..string.char(26)..\"" )
      return s
  end

function deepcopy(orig)
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

function setGui(pos, text)
    term.setCursor(1,pos)
    term.clearLine()
    term.write(text)
end

function getPassID(command,rules)
    local bill
    if rules ~= nil then
      for i=1,#rules,1 do
        if rules[i].uuid == command then
          command = rules[i].call
          bill = i
          break
        end
      end
    end
    for i=1,#settings.data.calls,1 do
      if command == settings.data.calls[i] then
        return true, i, bill
      end
    end
    return command == "checkstaff" and true or false, command == "checkstaff" and 0 or false
  end

function pageChange(pos,length,call,...)
    if type(pos) == "boolean" then
        if pos then
            if pageNum < length then
                pageNum = pageNum + 1
            end
        else
            if pageNum > 1 then
                pageNum = pageNum - 1
            end
        end
    else
        pageNum = pos
    end
    call(...)
end

function doorDiag(isMain,diagInfo2, diagInfo)
    if isMain == false then
        local diagInfo3 = diagInfo["entireDoor"][diagInfo2[pageNum]]
        diagInfo3["type"] = diagInfo.type
        diagInfo3["version"] = diagInfo.version
        diagInfo3["key"] = diagInfo2[pageNum]
        diagInfo3["num"] = 2
        diagInfo2 = diagInfo3
        print("Page" .. pageNum .. "/" .. diagInfo["entries"])
        print("Use left and right to change pages")
        print("Click the screen to go back to menu")
        print("")
    end
    if isMain == true then
        print("--Main Computer info--")
        print(isMain == true and "door status = " .. diagInfo2["status"] or "***")
        print("door type = " .. diagInfo2["type"])
        print("door update version = " .. diagInfo2["version"])
        if diagInfo2["status"] ~= "incorrect magreader" then
            if diagInfo2["type"] == "multi" then
                print("number of door entries: " .. diagInfo2["entries"])
                print("door's key: " .. diagInfo2["key"])
                print("door name: " .. diagInfo2["name"])
            else
                print("***")
                print("***")
                print("door name: " .. diagInfo2["name"])
            end
            print("door pass amount: " .. #diagInfo2.cardRead)
            print("-Component Addresses--")
            if diagInfo2["type"] == "multi" then
                if diagInfo2["doorType"] == 0 then
                    print("Reader Address: " .. diagInfo2["reader"])
                    print("Doorcontrol Address: " .. diagInfo2["doorAddress"])
                elseif diagInfo2["doorType"] == 3 then
                    print("Reader Address: " .. diagInfo2["reader"])
                    print("RollDoor Address: " .. diagInfo2["doorAddress"])
                else
                    print("Reader Address: " .. diagInfo2["reader"])
                    print("***")
                end
            else
                print("***")
                print("***")
            end
            print("----Door Functions----")
            print("Door Type: " .. doorTypeTypes[diagInfo2.doorType + 1])
            if diagInfo2.doorType == 2 then
                print(diagInfo2.type == "single" and "Redstone output side: " .. diagInfo2.redSide or "***")
                print("Redstone output color: " .. diagInfo2.redColor)
            elseif diagInfo2.doorType == 1 then
                print("Redstone output side: " .. diagInfo2.redSide)
                print("***")
            else
                print("***")
                print("***")
            end
            print("Toggleable: " .. toggleTypes[diagInfo2.toggle + 1])
            print(diagInfo2.toggle == 0 and "Delay: " .. diagInfo2.delay or "***")
            print("ForceOpen: " .. forceOpenTypes[diagInfo2.forceOpen + 1])
            print("BypassLock: " .. forceOpenTypes[diagInfo2.bypassLock + 1])
        else
            if diagInfo2["type"] == "multi" then
                print("number of door entries: " .. diagInfo2["entries"])
            else
                print("***")
            end
            print("***")
            print("***")
            print("***")
            print("-Component Addresses--")
            print("***")
            print("***")
            print("----Door Functions----")
            print("***")
            print("***")
            print("***")
            print("***")
            print("***")
            print("***")
        end
    else
        print("--Main Computer info--")
        print(isMain == true and "door status = " .. diagInfo2["status"] or "***")
        print("door type = " .. diagInfo["type"])
        print("door update version = " .. diagInfo["version"])
        if diagInfo["type"] == "multi" then
            print("number of door entries: " .. diagInfo["entries"])
            print("door's key: " .. diagInfo2["key"])
            print("door name: " .. diagInfo2["name"])
        else
            print("***")
            print("***")
            print("door name: " .. diagInfo2["name"])
        end
        print("door pass amount: " .. #diagInfo2.cardRead)
        print("-Component Addresses--")
        if diagInfo["type"] == "multi" then
            if diagInfo2["doorType"] == 0 then
                print("Reader Address: " .. diagInfo2["reader"])
                print("Doorcontrol Address: " .. diagInfo2["doorAddress"])
            elseif diagInfo2["doorType"] == 3 then
                print("Reader Address: " .. diagInfo2["reader"])
                print("RollDoor Address: " .. diagInfo2["doorAddress"])
            else
                print("Reader Address: " .. diagInfo2["reader"])
                print("***")
            end
        else
            print("***")
            print("***")
        end
        print("----Door Functions----")
        print("Door Type: " .. doorTypeTypes[diagInfo2.doorType + 1])
        if diagInfo2.doorType == 2 then
            print(diagInfo.type == "single" and "Redstone output side: " .. diagInfo2.redSide or "***")
            print("Redstone output color: " .. diagInfo2.redColor)
        elseif diagInfo2.doorType == 1 then
            print("Redstone output side: " .. diagInfo2.redSide)
            print("***")
        else
            print("***")
            print("***")
        end
        print("Toggleable: " .. toggleTypes[diagInfo2.toggle + 1])
        print(diagInfo2.toggle == 0 and "Delay: " .. diagInfo2.delay or "***")
        print("ForceOpen: " .. forceOpenTypes[diagInfo2.forceOpen + 1])
        print("BypassLock: " .. forceOpenTypes[diagInfo2.bypassLock + 1])
    end
end

  --------Program Function

function accsetup()
    term.clear()
    print("Enter 4 digit code")
    local text = term.read()
    local code = tonumber(text)
    modem.open(code)
    --local temp = {}
    --temp["analyzer"]=component.isAvailable("barcode_reader")
    modem.broadcast(code,"link",component.isAvailable("barcode_reader"))
    print("linking...")
    local e, _, from, port, _, msg = event.pull(3, "modem_message")
    if e then
        print("successful link")
        local stayIn = true
        while stayIn do
            local data
            e, _, from, port, _, msg, data = event.pull("modem_message")
            if msg == "print" then
                print(data)
            elseif msg == "write" then
                term.write(data)
            elseif msg == "getInput" then
                text = term.read()
                modem.send(from,port,text:sub(1,-2))
            elseif msg == "clearTerm" then
                term.clear()
            elseif msg == "terminate" then
                stayIn = false
                os.beep()
                os.beep()
            elseif msg == "analyzer" then
                print("Scan the device with your tablet")
                _, text = event.pull("tablet_use")
                os.beep()
                modem.send(from,port,text.analyzed[1].address)
            end
        end
        print("Finished")
        modem.close(code)
    else
        modem.close(code)
        print("failed to link")
    end
    os.exit()
end

function diagThr(num,diagInfo)
    local nextVar = 0
    local pickle = true
    ::Beg::
    term.clear()
    print(num ~= 0 and "Door # " .. num or "Scan a door to start")
    if num == 0 then
        local t = thread.current()
        t:kill()
    end
    local works = false
    for i=1,#supportedVersions,1 do
        if supportedVersions[i] == diagInfo.version then
            works = true
        end
    end
    if works == false then
        print("Door is version " .. diagInfo.version .. " which is unsupported")
    end
    print("1. Main Door Info")
    print("2. Pass Rules")
    local lengthMe = 2
    if diagInfo.version ~= "2.2.0" and diagInfo.type == "multi" then
        lengthMe = 3
        print(lengthMe .. ". Entire door Info") 
    end
    lengthNum = lengthMe
    _, nextVar = event.pull("numInput")
    if nextVar == 1 then
        goto mainInfo
    elseif nextVar == 2 then
        goto passRules
    elseif nextVar == 3 then
        goto allInfo
    end
    ::mainInfo::
    do
        term.clear()
        doorDiag(true,diagInfo)
        print("--------------------")
        print("Click the screen to go back to menu")
        event.pull("touch")
        goto Beg
    end
    ::allInfo::
    do
        local indexed = {}
        for key, _ in pairs(diagInfo["entireDoor"]) do
            table.insert(indexed,key)
        end
        term.clear()
        pageChange(1,#indexed,doorDiag,false,indexed, diagInfo)
        pickle = true
        while pickle do
            local ev, p1, p2, p3 = event.pullMultiple("touch","key_down")
            if ev == "touch" then
                pickle = false
            else
                local char = keyboard.keys[p3]
                if char == "left" then
                    term.clear()
                    pageChange(false,#indexed,doorDiag,false,indexed, diagInfo)
                    os.sleep(1)
                elseif char == "right" then
                    term.clear()
                    pageChange(true,#indexed,doorDiag,false,indexed, diagInfo)
                    os.sleep(1)
                end
            end
        end
        goto Beg
    end
    ::passRules::
    do
        term.clear()
        local passChange = function()
            term.clear()
            setGui(1,"Page" .. pageNum .. "/" .. #diagInfo.cardRead)
            setGui(2,"Use left and right to change pages")
            setGui(3,"Click the screen to go back to menu")
            setGui(4,"")
            local a, t = getPassID(diagInfo.cardRead[pageNum].call)
            if a then
                setGui(5,"Pass name: " .. settings.data.label[t])
                setGui(6,"Pass type: " .. passTypes[settings.data.type[t]])
                if settings.data.type[t] == "string" or settings.data.type[t] == "-string" then
                    setGui(6,"Requires exact string: " .. diagInfo.cardRead[pageNum].param)
                elseif settings.data.type[t] == "int" or settings.data.type[t] == "-int" then
                    if settings.data.above[t] == true and settings.data.type[t] == "int" then
                        setGui(6,"Requires level above: " .. diagInfo.cardRead[pageNum].param)
                    else
                        if settings.data.type[t] == "-int" then
                            setGui(6,"Requires group: " .. settings.data.data[t][diagInfo.cardRead[pageNum].param])
                        else
                            setGui(6,"Requires exact level: " .. diagInfo.cardRead[pageNum].param)
                        end
                    end
                elseif settings.data.type[t] == "bool" then
                    setGui(6,"No extra parameters")
                end
                setGui(7,"Rule Type: " .. diagInfo.cardRead[pageNum].request)
                if diagInfo.cardRead[pageNum].request == "base" and #diagInfo.cardRead[pageNum].data > 0 then
                    setGui(8,"")
                    setGui(9,"Requires " .. #diagInfo.cardRead[pageNum].data .. " Add passes")
                    for i=1,#diagInfo.cardRead[pageNum].data,1 do
                        local q,p,r = getPassID(diagInfo.cardRead[pageNum].data[i],diagInfo.cardRead)
                        if q then
                            setGui(i + 9,settings.data.label[p] .. " | " .. passTypes[settings.data.type[p]] .. " | " .. diagInfo.cardRead[r].param)
                        else
                            setGui(i + 9,"Error (pass might be missing)")
                        end
                    end
                end
            else
                setGui(5,"Failed at line 226 or so")
            end
        end
        pageChange(1,#diagInfo.cardRead,passChange)
        pickle = true
        while pickle do
            local ev, p1, p2, p3 = event.pullMultiple("touch","key_down")
            if ev == "touch" then
                pickle = false
            else
                local char = keyboard.keys[p3]
                if char == "left" then
                    pageChange(false,#diagInfo.cardRead,passChange)
                    os.sleep(1)
                elseif char == "right" then
                    pageChange(true,#diagInfo.cardRead,passChange)
                    os.sleep(1)
                end
            end
        end
        goto Beg
    end
end

function diagnostics()
    term.clear()
    local num = 0
    diagt = thread.create(diagThr,num)
    while true do
        if modem.isOpen(diagPort) == false then
            modem.open(diagPort)
        end

        local _, _, from, port, _, command, msg = event.pull("modem_message")
        local diagInfo = ser.unserialize(msg)
        num = num + 1
        if diagt ~= nil then
            diagt:kill()
        end
        diagt = thread.create(diagThr,num,diagInfo)
    end
end

function doorediting() --TEST: Can this edit the doors?
    term.clear()
    setGui(1,"Scan the door you would like to edit")
    setGui(2,"If the door is a multidoor, you can edit all doors connected")
    if modem.isOpen(diagPort) == false then
        modem.open(diagPort)
    end
    local _, _, from, port, _, command, msg = event.pull("modem_message")
    local diagInfo = ser.unserialize(msg)
    local ver = true
    for i=3,#supportedVersions,1 do
        if diagInfo.version == supportedVersions[i] then
            ver = false
            break
        end
    end
    if ver then
        setGui(4,"Door version is not 2.2.2 and above and is unsupported")
        os.exit()
    end
    local editTable = {}
    if diagInfo.type == "single" then
        editTable[1] = deepcopy(diagInfo)
    else
        local num = 2
        if diagInfo.status == "incorrect magreader" then
            diagInfo.key = "unreal"
            num = 1
        else
            editTable[1] = deepcopy(diagInfo.entireDoor[diagInfo.key])
            editTable[1].key = diagInfo.key
        end
        for key,value in pairs(diagInfo.entireDoor) do
            if key ~= diagInfo.key then
                editTable[num] = deepcopy(diagInfo.entireDoor[key])
                editTable[num].key = key
                num = num + 1
            end
        end
    end
    local pig = true
    local pageChangeAllowed = true
    term.clear()
    local editChange = function()
        setGui(1,"Page" .. pageNum .. "/" .. #editTable)
        setGui(2,"Use left and right to change doors, n to add a door, and d to delete a door (if multi door)")
        setGui(3,"Click the screen to save and submit to door control")
        setGui(4,"")
        if diagInfo.type == "single" then
            setGui(16,"***")
        else
            setGui(5,"Door Key: " .. editTable[pageNum].key)
            if diagInfo.status == "incorrect magreader" then
                setGui(6,"Notice: magreader swiped isn't linked to any door. If it's supposed to be linked you will have to fix it.")
            end
            setGui(7,"")
            if editTable[pageNum].doorType == 0 or editTable[pageNum].doorType == 3 then
                setGui(16,"Door Address: " .. editTable[pageNum].doorAddress)
                setGui(17,"Reader Address: " .. editTable[pageNum].reader)
            else
                setGui(16,"***")
                setGui(17,"Reader Address: " .. editTable[pageNum].reader)
            end
        end
        setGui(8,"1. Change Door Name: " .. editTable[pageNum].name)
        setGui(9,diagInfo.type == "multi" and "2. Change Door type/color/uuid" or "2. Change Door type/color/side")
        setGui(10,"3. Change toggle and delay")
        setGui(11,"4. Change force open and bypass lock")
        setGui(12,"5. Change passes")
        setGui(13,diagInfo.type == "multi" and "6. Change card reader uuid" or "")
        setGui(14,"")
        setGui(15,"Door type: " .. doorTypeTypes[editTable[pageNum].doorType + 1])
        setGui(18,toggleTypes[editTable[pageNum].toggle + 1] .. " | Delay: " .. editTable[pageNum].delay)
        setGui(19,"Force open: " .. forceOpenTypes[editTable[pageNum].forceOpen + 1] .. " | bypass lock: " .. forceOpenTypes[editTable[pageNum].bypassLock + 1])
        setGui(20,"Amount of passes: " .. #editTable[pageNum].cardRead)
        setGui(21,"----------------------")
        setGui(22,"Press a number to edit those parameters")
        setGui(23,diagInfo.type == "multi" and "Press enter to identify a linked magreader" or "")
        setGui(24,"")
    end
    pageChange(1,#editTable,editChange)
    while pig do
        lengthNum = diagInfo.type == "single" and 5 or 6
        local ev, p1, p2, p3 = event.pullMultiple("touch","key_down","numInput")
        if ev == "touch" then
            pig = false
        elseif ev == "key_down" and pageChangeAllowed then
            local char = keyboard.keys[p3]
            if char == "left" then
                pageChange(false,#editTable,editChange)
                os.sleep(1)
            elseif char == "right" then
                pageChange(true,#editTable,editChange)
                os.sleep(1)
            elseif char == "enter" then
                if diagInfo.type == "multi" then
                    modem.send(from,port,"identifyMag",ser.serialize(editTable[pageNum]))
                end
            elseif char == "n" then
                local keepLoop = true
                local j
                while keepLoop do
                j = randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]
                    keepLoop = false
                    for key,value in pairs(editTable) do
                        if value.key == j then
                            keepLoop = true
                        end
                    end
                end
                table.insert(editTable,{["key"]=j,["doorType"]=0,["redColor"]=0,["redSide"]=0,["reader"]="NAN",["doorAddress"]="NAN",["delay"]=5,["cardRead"]="checkstaff",["toggle"]=0,["forceOpen"]=1,["bypassLock"]=0})
                pageChange(pageNum,#editTable,editChange)
            elseif char == "r" then
                pageChangeAllowed = false
                local text
                setGui(22,"Are you sure? 1 = yes, 2 = no")
                term.setCursor(1,24)
                term.clearLine()
                text = term.read()
                if tonumber(text) == 1 then
                    table.remove(editTable,pageNum)
                    if pageNum > #editTable then
                        pageNum = #editTable
                    end
                end
                pageChangeAllowed = true
                pageChange(pageNum,#editTable,editChange)
            end
        elseif ev == "numInput" then
            setGui(23,"")
            pageChangeAllowed = false
            local text
            if p1 == 1 then
                setGui(22,"What should the name be set to?")
                term.setCursor(1,24)
                term.clearLine()
                text = term.read()
                editTable[pageNum].name = text:sub(1,-2)
            elseif p1 == 2 then
                setGui(22,diagInfo.type == "multi" and "Door Type? 0= doorcontrol. 2=bundled. 3=rolldoor. NEVER USE 1! NUMBER ONLY" or "Door Type? 0= doorcontrol. 1= redstone 2=bundled. 3=rolldoor. NUMBER ONLY")
                term.setCursor(1,24)
                term.clearLine()
                text = term.read()
                editTable[pageNum].doorType = tonumber(text)
                if editTable[pageNum].doorType == 2 then
                    setGui(22,"What color. Use the Color API wiki provided on the opencomputers wiki, and enter the NUMBER")
                    term.setCursor(1,24)
                    term.clearLine()
                    text = term.read()
                    editTable[pageNum].redColor = tonumber(text)
                    if diagInfo.type == "multi" then
                        editTable[pageNum].doorAddress = ""
                    else
                        setGui(22,"What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left. NUMBER ONLY")
                        term.setCursor(1,24)
                        term.clearLine()
                        text = term.read()
                        editTable[pageNum].redSide = tonumber(text)
                    end
                elseif editTable[pageNum].doorType == 1 then
                    editTable[pageNum].redColor = 0
                    setGui(22,"What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left. NUMBER ONLY")
                    term.setCursor(1,24)
                    term.clearLine()
                    text = term.read()
                    editTable[pageNum].redSide = tonumber(text)
                else
                    editTable[pageNum].redColor = 0
                    if diagInfo.type == "single" then editTable[pageNum].redSide = 0 end
                    if diagInfo.type == "multi" then
                        setGui(22,"What is the address for the doorcontrol/rolldoor block?")
                        setGui(23,"Enter uuid as text")
                        term.setCursor(1,24)
                        term.clearLine()
                        text = term.read()
                        editTable[pageNum].doorAddress = text:sub(1,-2)
                    end
                end
            elseif p1 == 3 then
                setGui(22,"Should the door be toggleable or not? 0 for autoclose and 1 for toggleable")
                term.setCursor(1,24)
                term.clearLine()
                text = term.read()
                editTable[pageNum].toggle = tonumber(text)
                if editTable[pageNum].toggle == 0 then
                    setGui(22,"How long should the door stay open?")
                    term.setCursor(1,24)
                    term.clearLine()
                    text = term.read()
                    editTable[pageNum].delay = tonumber(text)
                else
                    editTable[pageNum].delay = 0
                end
            elseif p1 == 4 then
                setGui(22,"Is this door opened whenever all doors are asked to open?")
                setGui(23,"0 if no, 1 if yes. Default is yes")
                term.setCursor(1,24)
                term.clearLine()
                text = term.read()
                editTable[pageNum].forceOpen = tonumber(text)
                setGui(22,"Is this door immune to lock door?")
                setGui(23,"0 if no, 1 if yes. Default is no")
                term.setCursor(1,24)
                term.clearLine()
                text = term.read()
                editTable[pageNum].bypassLock = tonumber(text)
            elseif p1 == 5 then --TODO: Finish and test
                if experimental then
                    local readCursor = function()
                        term.setCursor(1,24)
                        term.clearLine()
                        return term.read()
                    end
                    setGui(22,"Would you like to use the simple pass setup or new advanced one?","1 for simple, 2 for advanced")
                    text = readCursor()
                    local savedRead = {}
                    if tonumber(text) == 2 then
                        local readLoad = {}
                        setGui(22,"How many add passes do you want to add?")
                        setGui(23,"remember multiple base passes can use the same add pass")
                        readLoad.add = tonumber(readCursor())
                        setGui(22,"How many base passes do you want to add?")
                        setGui(23,"")
                        readLoad.base = tonumber(readCursor())
                        setGui(22,"How many reject passes do you want to add?")
                        setGui(23,"These don't affect supreme passes")
                        readLoad.reject = tonumber(readCursor())
                        setGui(22,"How many supreme passes do you want to add?")
                        setGui(23,"")
                        readLoad.supreme = tonumber(readCursor())
                        local nextmsg = {}
                        nextmsg.beg, nextmsg.mid, nextmsg.back = "What should be read for "," pass number ","? 0 = staff"
                        for i=1,#settings.var,1 do
                            nextmsg.back = nextmsg.back .. ", " .. i .. " = " .. settings.label[i]
                        end
                        local passFunc = function(type,num)
                            local newRules = {["uuid"]=uuid.next(),["request"]=type,["data"]=type == "base" and {} or false}
                            setGui(22,nextmsg.beg..type..nextmsg.mid..num..nextmsg.back)
                            local text = readCursor()
                            if tonumber(text) == 0 then
                                newRules.call = "checkstaff"
                                newRules.param = 0
                            else
                                newRules["tempint"] = tonumber(text)
                                newRules["call"] = settings.calls[tonumber(text)]
                                if settings.type[tonumber(text)] == "string" or settings.type == "-string" then
                                    setGui(22,"What is the string you would like to read? Enter text.")
                                    text = readCursor()
                                    newRules["param"] = text
                                elseif settings.type[tonumber(text)] == "bool" then
                                    newRules["param"] = 0
                                elseif settings.type[tonumber(text)] == "int" then
                                    if settings.above[tonumber(text)] == true then
                                        setGui(22,"What level and above should be required?")
                                    else
                                        setGui(22,"what level exactly should be required?")
                                    end
                                    text = readCursor()
                                    newRules["param"] = tonumber(text)
                                elseif settings.type[tonumber(text)] == "-int" then
                                    local nextmsg = "What group are you wanting to set?"
                                    for i=1,#settings.data[tonumber(text)],1 do
                                        nextmsg = nextmsg .. ", " .. i .. " = " .. settings.data[tonumber(text)][i]
                                    end
                                    setGui(22,nextmsg)
                                    text = readCursor()
                                    newRules["param"] = tonumber(text)
                                else
                                    setGui(22,"error in cardRead area for num 2")
                                    readCursor()
                                    newRules["param"] = 0
                                end
                            end
                            return newRules
                        end
                        for i=1,readLoad.add,1 do
                            local rule = passFunc("add",i)
                            table.insert(savedRead,rule)
                        end
                        local addNum = #savedRead
                        for i=1,readLoad.base,1 do
                            local rule = passFunc("base",i)
                            setGui(22,"How many add passes do you want to link?")
                            text = tonumber(readCursor())
                            if text ~= 0 then
                                local nextAdd = "Which pass do you want to add? "
                                for j=1,addNum,1 do
                                    nextAdd = nextAdd .. ", " .. j .. " = " .. settings.label[savedRead[j].tempint]
                                end
                                for j=1,text,1 do
                                    setGui(22,nextAdd)
                                    text = tonumber(readCursor())
                                    table.insert(rule.data,savedRead[text].uuid)
                                end
                            end
                            table.insert(savedRead,rule)
                        end
                        for i=1,readLoad.reject,1 do
                            local rule = passFunc("reject",i)
                            table.insert(savedRead,rule)
                        end
                        for i=1,readLoad.supreme,1 do
                            local rule = passFunc("supreme",i)
                            table.insert(savedRead,rule)
                        end
                    else
                        local nextmsg = "What should be read? 0 = staff,"
                        for i=1,#settings.var,1 do
                            nextmsg = nextmsg .. ", " .. i .. " = " .. settings.label[i]
                        end
                        setGui(22,nextmsg)
                        text = readCursor()
                        savedRead = {{["uuid"]=uuid.next(),["call"]="",["param"]=0,["request"]="supreme",["data"]=false}}
                        if tonumber(text) == 0 then
                            savedRead[1].call = "checkstaff"
                            savedRead[1].param = 0
                        else
                            savedRead[1].call = settings.calls[tonumber(text)]
                            if settings.type[tonumber(text)] == "string" or settings.type[tonumber(text)] == "-string" then
                                setGui(22,"What is the string you would like to read? Enter text.")
                                text = readCursor()
                                savedRead[1].param = text:sub(1,-2)
                            elseif settings.type[tonumber(text)] == "bool" then
                                savedRead[1].param = 0
                            elseif settings.type[tonumber(text)] == "int" then
                                if settings.above[tonumber(text)] == true then
                                    setGui(22,"What level and above should be required?")
                                else
                                    setGui(22,"what level exactly should be required?")
                                end
                                text = readCursor()
                                savedRead[1].param = tonumber(text)
                            elseif settings.type[tonumber(text)] == "-int" then
                                local nextmsg = "What group are you wanting to set?"
                                for i=1,#settings.data[tonumber(text)],1 do
                                    nextmsg = nextmsg .. ", " .. i .. " = " .. settings.data[tonumber(text)][i]
                                end
                                setGui(22,nextmsg)
                                text = readCursor()
                                savedRead[1].param = tonumber(text)
                            else
                                setGui(22,"error in cardRead area for num 2")
                                readCursor()
                                savedRead[1].param = 0
                            end
                        end
                    end
                    editTable[pageNum].cardRead = savedRead
                else
                    setGui(22,"At the moment, there is no way to edit passes without")
                    setGui(23,"using the autoinstaller to do so.")
                    setGui(24,"Press enter to continue")
                    term.read()
                end
            elseif p1 == 6 then
                setGui(22,"What is the address for the magreader block?")
                setGui(23,"Enter uuid as text")
                term.setCursor(1,24)
                term.clearLine()
                text = term.read()
                editTable[pageNum].reader = text:sub(1,-2)
            end
            pageChange(pageNum,#editTable,editChange)
            pageChangeAllowed = true
        end
    end
    term.clear()
    local poo = {}
    if diagInfo.type == "multi" then
        for i=1,#editTable,1 do
            poo[editTable[i].key] = editTable[i]
            poo.key = nil
        end
    else
        poo = editTable[1]
        poo.status = nil
        poo.type = nil
        poo.version = nil
        poo.num = nil
    end
    modem.send(from,modemPort,"changeSettings",ser.serialize(poo))
    print("finished")
    os.exit()
end

--------Startup Code

term.clear()
print("Sending query to server...")
modem.open(modemPort)
modem.broadcast(modemPort,"autoInstallerQuery")
local e,_,_,_,_,msg = event.pull(3,"modem_message")
modem.close(modemPort)
if e == nil then
    print("No query received. Assuming old server system is in place and will not work")
    os.exit()
else
  print("Query received")
  settings = ser.unserialize(msg)
end

thread.create(function()
    while true do
        local ev, p1, p2, p3, p4, p5 = event.pull("key_down")
        local char = tonumber(keyboard.keys[p3])
        if char ~= nil then
            if char > 0 then
                if char <= lengthNum then
                    event.push("numInput",char)
                    lengthNum = 0
                end
            end
        end
    end
end)
term.clear()
local nextVar = 0
print("Which app would you like to run?")
print("1. Diagnostics")
print("2. Accelerated door setup")
print("3. Door Editing")
lengthNum = 3
_, nextVar = event.pull("numInput")
if nextVar == 1 then
    diagnostics()
elseif nextVar == 2 then
    accsetup()
elseif nextVar == 3 then
    doorediting()
end