--------Base APIS and variables
local diagPort = 180
local modemPort = 1000
local syncPort = 199

local component = require("component")
local gpu = component.gpu
local event = require("event")
local modem = component.modem 
local ser = require ("serialization")
local term = require("term")
local ios = require("io")
local keyboard = require("keyboard")
local thread = require("thread")
local process = require("process")
local uuid = require("uuid")
local computer = require("computer")

local link

--------Extra Arrays
--TODO: Convert doorType 0 to 3 and table of addresses.
local toggleTypes = {"not toggleable","toggleable"}
local doorTypeTypes = {"Door Control","Redstone dust","Bundled Cable","Rolldoor"}
local newDoorTypes = {"Redstone dust","Bundled Cable","Door/RollDoor Controller"}
local redSideTypes = {"bottom","top","back","front","right","left"}
local redColorTypes = {"white","orange","magenta","light blue","yellow","lime","pink","gray","silver","cyan","purple","blue","brown","green","red","black"}
local forceOpenTypes = {"False","True"}
local passTypes = {["string"]="Regular String",["-string"]="Multi String",["int"]="Level",["-int"]="Group",["bool"]="Bool"}

local supportedVersions = {"4.0.0"}

local randomNameArray = {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"}

local settings
local config

local lengthNum = 0

local pageNum = 1

local versionNum = 1

local diagt = nil
local hassector = false

local experimental = false
--------Base Functions

local function saveTable(  tbl,filename )
    local tableFile = assert(io.open(filename, "w"))
    tableFile:write(ser.serialize(tbl))
    tableFile:close()
end

local function loadTable( sfile )
    local tableFile = io.open(sfile)
    if tableFile ~= nil then
        return ser.unserialize(tableFile:read("*all"))
    else
        return nil
    end
end

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

  local function crypt(str,k,inv)
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

local function sendit(label,port,linker,...)
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

local function deepcopy(orig)
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

local function setGui(pos, text, wrap, color)
    term.setCursor(1,pos)
    term.clearLine()
    if color then gpu.setForeground(color) else gpu.setForeground(0xFFFFFF) end
    if wrap then print(text) else term.write(text) end
end

local function getPassID(command,rules)
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
    for i=1,#settings.data.passSettings.calls,1 do
      if command == settings.data.passSettings.calls[i] then
        return true, i, bill
      end
    end
    return command == "checkstaff" and true or false, command == "checkstaff" and 0 or false
  end

local function pageChange(pos,length,call,...)
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

local function doorDiag(isMain,diagInfo2, diagInfo)
    if isMain == false then
        local diagInfo3 = diagInfo["entireDoor"][diagInfo2[pageNum]]
        diagInfo3["type"] = diagInfo.type
        diagInfo3["version"] = diagInfo.version
        diagInfo3["key"] = diagInfo2[pageNum]
        diagInfo3["num"] = 3
        diagInfo2 = diagInfo3
        print("Page" .. pageNum .. "/" .. diagInfo["entries"])
        print("Use left and right to change pages")
        print("Click the screen to go back to menu")
        print("")
    end
    if isMain == true then
        print("--Main Computer info--")
        print(isMain == true and "door status = " .. diagInfo2["status"] or "***")
        print("door update version = " .. diagInfo2["version"])
        if diagInfo2["status"] ~= "incorrect magreader" then
            print("number of door entries: " .. diagInfo2["entries"])
            print("door's key: " .. diagInfo2["key"])
            print("door name: " .. diagInfo2["name"])
            print("door pass amount: " .. #diagInfo2.cardRead)

            print("-Component Addresses--")
            if #diagInfo2.reader == 1 then print("Reader Address: " .. diagInfo2["reader"][1].uuid .. " : " .. diagInfo2["reader"][1].type) else print("Reader Amount: " .. #diagInfo2["reader"]) end
            if diagInfo2["doorType"] == 3 then
                if #diagInfo2["doorAddress"] == 1 then
                    print("Controller Address: " .. diagInfo2["doorAddress"][1])
                else
                    print("Controller Amount: " .. #diagInfo2["doorAddress"])
                end
            else
                print("***")
            end
            print("----Door Functions----")
            print("Door Type: " .. newDoorTypes[diagInfo2.doorType])
            if diagInfo2.doorType == 2 then
                print("Redstone output side: " .. diagInfo2.redSide)
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
            local works = false
            if hassector == true then
                if diagInfo2.sector == false then
                    print("No Sector")
                else
                    local it = false
                    for _,value in pairs(settings.data.sectors) do
                        if value.uuid == diagInfo2.sector then
                            print("Sector: " .. value.name)
                            it = true
                            break
                        end
                    end
                    if it == false then
                        print("Sector: Error: Incorrect sector uuid")
                    end
                end
            end
        else
            print("number of door entries: " .. diagInfo2["entries"])
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
        print("door update version = " .. diagInfo["version"])
        print("number of door entries: " .. diagInfo["entries"])
        print("door's key: " .. diagInfo2["key"])
        print("door name: " .. diagInfo2["name"])
        print("door pass amount: " .. #diagInfo2.cardRead)

        print("-Component Addresses--")
        if #diagInfo2.reader == 1 then print("Reader Address: " .. diagInfo2["reader"][1].uuid .. " : " .. diagInfo2["reader"][1].type) else print("Reader Amount: " .. #diagInfo2["reader"]) end
        if diagInfo2["doorType"] == 3 then
            if #diagInfo2["doorAddress"] == 1 then
                print("Controller Address: " .. diagInfo2["doorAddress"][1])
            else
                print("Controller Amount: " .. #diagInfo2["doorAddress"])
            end
        else
            print("***")
        end
        
        print("----Door Functions----")
        print("Door Type: " .. newDoorTypes[diagInfo2.doorType])
        if diagInfo2.doorType == 2 then
            print("Redstone output side: " .. diagInfo2.redSide)
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
        if hassector then
            if diagInfo2.sector == false then
                print("No Sector")
            else
                local it = false
                for _,value in pairs(settings.data.sectors) do
                    if value.uuid == diagInfo2.sector then
                        print("Sector: " .. value.name)
                        it = true
                        break
                    end
                end
                if it == false then
                    print("Sector: Error: Incorrect sector uuid")
                end
            end
        end
    end
end

local function scanner(multi,grab)
    local e, text
    if multi then
        local wait = true
        local distable = {}
        while wait do
            e, text = event.pullMultiple("tablet_use","touch")
            computer.beep()
            if e == "touch" then
                return distable
            else
                table.insert(distable,text.analyzed[1].address)
            end
        end
    else
        _, text = event.pull("tablet_use")
        computer.beep()
        return text.analyzed[1].address
    end
end

  --------Program Function

local function accsetup()
    term.clear()
    modem.open(diagPort)
    --local temp = {}
    --temp["analyzer"]=component.isAvailable("barcode_reader")
    sendit(nil,diagPort,false,"accsetup",component.isAvailable("barcode_reader"))
    print("linking...")
    local e, _, from, port, _, msg = event.pull(3, "modem_message")
    if e then
        print("successful link")
        local stayIn = true
        while stayIn do
            local data,text
            e, _, from, port, _, msg, data = event.pull("modem_message")
            if msg == "print" then
                print(data)
            elseif msg == "write" then
                term.write(data)
            elseif msg == "getInput" then
                text = term.read()
                sendit(from,port,false,text:sub(1,-2))
            elseif msg == "clearTerm" then
                term.clear()
            elseif msg == "terminate" then
                stayIn = false
                computer.beep()
                computer.beep()
            elseif msg == "analyzer" then
                print("Scan the device with your tablet")
                sendit(from,port,false,scanner(false,nil))
            elseif msg == "advanalyzer" then
                local wait = true
                local distable = {}
                print("Scan the devices with your tablet. Click the screen when finished to stop")
                while wait do
                    e, text = event.pullMultiple("tablet_use","touch")
                    computer.beep()
                    if e == "touch" then
                        sendit(from,port,false,"finished")
                        wait = false
                    else
                        sendit(from,port,false,text.analyzed[1].address)
                    end
                end
            end
        end
        print("Finished")
        modem.close(diagPort)
    else
        modem.close(diagPort)
        print("failed to link")
    end
    os.exit()
end

local function diagThr(num,diagInfo)
    local nextVar = 0
    local pickle = true
    ::Beg::
    term.clear()
    print(num ~= 0 and "Door # " .. num or "Scan a door to start")
    if num == 0 then
        local t = thread.current()
        t:kill()
    end
    print("1. Main Door Info")
    print("2. Pass Rules")
    print("3. Entire door Info")
    local lengthMe = 3
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
                elseif char == "enter" then --TEST: Double check if identify on diagnostic works?
                    sendit(from,port,false,"identifyMag",ser.serialize(diagInfo[pageNum]))
                end
            end
        end
        goto Beg
    end
    ::passRules::
    do
        term.clear()
        local passChange = function() --Assuming this area is A-OK :)
            term.clear()
            setGui(1,"Page" .. pageNum .. "/" .. #diagInfo.cardRead)
            setGui(2,"Use left and right to change pages")
            setGui(3,"Click the screen to go back to menu")
            setGui(4,"")
            local a, t = getPassID(diagInfo.cardRead[pageNum].call)
            if a then
                setGui(5,t ~= 0 and "Pass name: " .. settings.data.passSettings.label[t] or "Pass name: Staff")
                setGui(6,t ~= 0 and "Pass type: " .. passTypes[settings.data.passSettings.type[t]] or "Pass type: Bool")
                if (settings.data.passSettings.type[t] == "string" or settings.data.passSettings.type[t] == "-string") and t ~= 0 then
                    setGui(6,"Requires exact string: " .. diagInfo.cardRead[pageNum].param)
                elseif (settings.data.passSettings.type[t] == "int" or settings.data.passSettings.type[t] == "-int") and t ~= 0 then
                    if settings.data.passSettings.above[t] == true and settings.data.passSettings.type[t] == "int" then
                        setGui(6,"Requires level above: " .. diagInfo.cardRead[pageNum].param)
                    else
                        if settings.data.passSettings.type[t] == "-int" then
                            setGui(6,"Requires group: " .. settings.data.passSettings.data[t][diagInfo.cardRead[pageNum].param])
                        else
                            setGui(6,"Requires exact level: " .. diagInfo.cardRead[pageNum].param)
                        end
                    end
                elseif settings.data.passSettings.type[t] == "bool" or t == 0 then
                    setGui(6,"No extra parameters")
                end
                setGui(7,"Rule Type: " .. diagInfo.cardRead[pageNum].request)
                if diagInfo.cardRead[pageNum].request == "base" and #diagInfo.cardRead[pageNum].data > 0 then
                    setGui(8,"")
                    setGui(9,"Requires " .. #diagInfo.cardRead[pageNum].data .. " Add passes")
                    for i=1,#diagInfo.cardRead[pageNum].data,1 do
                        local q,p,r = getPassID(diagInfo.cardRead[pageNum].data[i],diagInfo.cardRead)
                        if q then
                            setGui(i + 9,p ~= 0 and settings.data.passSettings.label[p] .. " | " .. passTypes[settings.data.passSettings.type[p]] .. " | " .. diagInfo.cardRead[r].param or "Staff | Bool | " .. diagInfo.cardRead[r].param)
                        else
                            setGui(i + 9,"Error (pass might be missing)")
                        end
                    end
                end
            else
                setGui(5,"Failed before line 518 or so")
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

local function diagnostics()
    term.clear()
    local num = 0
    print("Scan a door to start")
    while true do
        if modem.isOpen(diagPort) == false then
            modem.open(diagPort)
        end

        local _, _, from, port, _, command, msg = event.pull("modem_message")
        local diagInfo = ser.unserialize(msg)
        num = num + 1
        if diagt ~= nil then
            if diagt:status() == "dead" then
                print("There was an exception in the diagnostic thread on that last door: please report to github")
                os.exit()
            end
            diagt:kill()
        end
        diagt = thread.create(diagThr,num,diagInfo)
    end
end

local function doorediting()
    term.clear()
    local canScan = component.isAvailable("barcode_reader")
    setGui(1,"Scan the door you would like to edit")
    setGui(2,"If the door is a multidoor, you can edit all doors connected")
    if modem.isOpen(diagPort) == false then
        modem.open(diagPort)
    end
    local _, _, from, port, _, command, msg = event.pull("modem_message")
    local diagInfo = ser.unserialize(msg)
    local editTable = {}
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
    local pig = true
    local pageChangeAllowed = true
    term.clear()
    local editChange = function()
        setGui(1,"Page" .. pageNum .. "/" .. #editTable)
        setGui(2,"Use left and right to change doors, n to add a door, and r to delete a door")
        setGui(3,"Click the screen to save and submit to door control")
        setGui(4,"")
        setGui(5,"Door Key: " .. editTable[pageNum].key)
        if diagInfo.status == "incorrect magreader" then
            setGui(6,"Notice: magreader swiped isn't linked to any door. If it's supposed to be linked you will have to fix it.")
        end
        setGui(7,"")
        if editTable[pageNum].doorType == 3 then
            if #editTable[pageNum].doorAddress == 1 then
                setGui(16,"Controller Address: " .. editTable[pageNum].doorAddress[1])
            else
                setGui(16,"Controller Amount: " .. #editTable[pageNum].doorAddress)
            end
        elseif editTable[pageNum].doorType == 2 then
            setGui(16,"Bundled redstone color: " .. redColorTypes[editTable[pageNum].redColor + 1] .. " / Red Side: " .. redSideTypes[editTable[pageNum].redSide + 1])
        else
            setGui(16,"Red Side: " .. redSideTypes[editTable[pageNum].redSide + 1])
        end
        setGui(17,#editTable[pageNum].reader == 1 and "Reader Address: " .. editTable[pageNum].reader[1].uuid .. " : " .. editTable[pageNum].reader[1].type or "Reader Amount: " .. #editTable[pageNum].reader)
        setGui(8,"1. Change Door Name: " .. editTable[pageNum].name)
        setGui(9,"2. Change Door type/color/uuid/side")
        setGui(10,"3. Change toggle and delay")
        setGui(11,hassector == false and "4. Unavailable: Sectors disabled" or "4. Change Sector")
        setGui(12,"5. Change passes")
        setGui(13,"6. Change card readers") --LEFTOFF
        setGui(14,"")
        setGui(15,"Door type: " .. newDoorTypes[editTable[pageNum].doorType])
        setGui(18,toggleTypes[editTable[pageNum].toggle + 1] .. " | Delay: " .. editTable[pageNum].delay)
        local pee = "Error: incorrect uuid"
        if hassector then
            if editTable[pageNum].sector ~= false then
                for _,value in pairs(settings.data.sectors) do
                    if value.uuid == editTable[pageNum].sector then
                        pee = value.name
                    end
                end
            end
        end
        setGui(19,hassector == false and "Sectors Disabled" or editTable[pageNum].sector == false and "No Sector Assigned " or "Sector: " .. pee)
        setGui(20,"Amount of passes: " .. #editTable[pageNum].cardRead)
        setGui(21,"----------------------")
        setGui(22,"Press a number to edit those parameters")
        setGui(23,"Press enter to identify a linked magreader")
        setGui(24,"")
    end
    pageChange(1,#editTable,editChange)
    while pig do
        local flush = function()
            for i=22,24,1 do
                setGui(i,"")
            end
        end
        lengthNum = 6
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
                sendit(from,port,false,"identifyMag",ser.serialize(editTable[pageNum]))
                os.sleep(1)
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
                table.insert(editTable,{["key"]=j,["doorType"]=3 ,["redColor"]=0,["redSide"]=0,["reader"]={},["doorAddress"]={"NAN"},["delay"]=5,["cardRead"]={{["uuid"]=uuid.next(),["call"]="checkstaff",["param"]=0,["request"]="supreme",["data"]=false}},["toggle"]=0,["sector"]=false,["name"]="new door"})
                pageChange(pageNum,#editTable,editChange)
            elseif char == "r" then
                pageChangeAllowed = false
                local text
                flush()
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
            flush()
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
                setGui(22,"Door Type? 1= redstone. 2=bundled. 3=door/rolldoor controller. NUMBER ONLY")
                term.setCursor(1,24)
                term.clearLine()
                text = term.read()
                editTable[pageNum].doorType = tonumber(text)
                if editTable[pageNum].doorType == 2 then
                    flush()
                    setGui(22,"What color. Use the Color API wiki provided on the opencomputers wiki, and enter the NUMBER")
                    term.setCursor(1,24)
                    term.clearLine()
                    text = term.read()
                    editTable[pageNum].redColor = tonumber(text)
                    editTable[pageNum].doorAddress = {""}
                    flush()
                    setGui(22,"What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left. NUMBER ONLY")
                    term.setCursor(1,24)
                    term.clearLine()
                    text = term.read()
                    editTable[pageNum].redSide = tonumber(text)
                elseif editTable[pageNum].doorType == 1 then
                    editTable[pageNum].redColor = 0
                    editTable[pageNum].doorAddress = {""}
                    flush()
                    setGui(22,"What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=left. NUMBER ONLY")
                    term.setCursor(1,24)
                    term.clearLine()
                    text = term.read()
                    editTable[pageNum].redSide = tonumber(text)
                else
                    editTable[pageNum].redColor = 0
                    editTable[pageNum].redSide = 0
                    flush()
                    local distable = {}
                    setGui(22,"What is the address for the doorcontrol/rolldoor blocks?")
                    if canScan then
                        setGui(23,"Scan all the controllers you want to add. Click screen to stop")
                        distable = scanner(true)
                    else
                        setGui(23,"Enter uuid as text. Press enter with nothing in it to stop")
                        while wait do
                            term.setCursor(1,24)
                            term.clearLine()
                            text = term.read()
                            text = text:sub(1,-2)
                            if text == "" then
                                wait = false
                            else
                                table.insert(distable,text)
                            end
                        end
                    end
                    editTable[pageNum].doorAddress = distable
                end
            elseif p1 == 3 then
                flush()
                setGui(22,"Should the door be toggleable or not? 0 for autoclose and 1 for toggleable")
                term.setCursor(1,24)
                term.clearLine()
                text = term.read()
                editTable[pageNum].toggle = tonumber(text)
                if editTable[pageNum].toggle == 0 then
                    flush()
                    setGui(22,"How long should the door stay open?")
                    term.setCursor(1,24)
                    term.clearLine()
                    text = term.read()
                    editTable[pageNum].delay = tonumber(text)
                else
                    editTable[pageNum].delay = 0
                end
            elseif p1 == 4 then
                flush()
                if hassector then
                    local nextmsg = "What sector would you like this door to be part of? 0 = no sector"
                    for i=1,#settings.data.sectors,1 do
                        nextmsg = nextmsg .. ", " .. i .. " = " .. settings.data.sectors[i].name
                    end
                    setGui(22,nextmsg,true)
                    term.setCursor(1,24)
                    term.clearLine()
                    text = tonumber(term.read())
                    if text == 0 then
                        editTable[pageNum].sector=false
                    else
                        editTable[pageNum].sector= settings.data.sectors[text].uuid
                    end
                else
                    setGui(22,"Sectors has been disabled (no module on server)")
                    term.setCursor(1,24)
                    term.clearLine()
                    term.read()
                end
            elseif p1 == 5 then
                local readCursor = function()
                    term.setCursor(1,24)
                    term.clearLine()
                    return term.read()
                end
                flush()
                setGui(22,"Would you like to use the simple pass setup or new advanced one? 1 for simple, 2 for advanced", true)
                text = readCursor()
                local savedRead = {}
                if tonumber(text) == 2 then
                    local readLoad = {}
                    flush()
                    setGui(22,"How many add passes do you want to add?")
                    setGui(23,"remember multiple base passes can use the same add pass")
                    readLoad.add = tonumber(readCursor())
                    flush()
                    setGui(22,"How many base passes do you want to add?")
                    setGui(23,"")
                    readLoad.base = tonumber(readCursor())
                    flush()
                    setGui(22,"How many reject passes do you want to add?")
                    setGui(23,"These don't affect supreme passes")
                    readLoad.reject = tonumber(readCursor())
                    flush()
                    setGui(22,"How many supreme passes do you want to add?")
                    setGui(23,"")
                    readLoad.supreme = tonumber(readCursor())
                    local nextmsg = {}
                    nextmsg.beg, nextmsg.mid, nextmsg.back = "What should be read for "," pass number ","? 0 = staff"
                    for i=1,#settings.data.passSettings.var,1 do
                        nextmsg.back = nextmsg.back .. ", " .. i .. " = " .. settings.data.passSettings.label[i]
                    end
                    local passFunc = function(type,num)
                        local newRules = {["uuid"]=uuid.next(),["request"]=type,["data"]=type == "base" and {} or false}
                        flush()
                        setGui(22,nextmsg.beg..type..nextmsg.mid..num..nextmsg.back, true)
                        local text = readCursor()
                        if tonumber(text) == 0 then
                            newRules.call = "checkstaff"
                            newRules.param = 0
                        else
                            newRules["tempint"] = tonumber(text)
                            newRules["call"] = settings.data.passSettings.calls[tonumber(text)]
                            if settings.data.passSettings.type[tonumber(text)] == "string" or settings.data.passSettings.type == "-string" then
                                flush()
                                setGui(22,"What is the string you would like to read? Enter text.")
                                text = readCursor()
                                newRules["param"] = text
                            elseif settings.data.passSettings.type[tonumber(text)] == "bool" then
                                newRules["param"] = 0
                            elseif settings.data.passSettings.type[tonumber(text)] == "int" then
                                flush()
                                if settings.data.passSettings.above[tonumber(text)] == true then
                                    setGui(22,"What level and above should be required?")
                                else
                                    setGui(22,"what level exactly should be required?")
                                end
                                text = readCursor()
                                newRules["param"] = tonumber(text)
                            elseif settings.data.passSettings.type[tonumber(text)] == "-int" then
                                local nextmsg = "What group are you wanting to set?"
                                for i=1,#settings.data.passSettings.data[tonumber(text)],1 do
                                    nextmsg = nextmsg .. ", " .. i .. " = " .. settings.data.passSettings.data[tonumber(text)][i]
                                end
                                flush()
                                setGui(22,nextmsg)
                                text = readCursor()
                                newRules["param"] = tonumber(text)
                            else
                                flush()
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
                        flush()
                        setGui(22,"How many add passes do you want to link?")
                        text = tonumber(readCursor())
                        if text ~= 0 then
                            local nextAdd = "Which pass do you want to add? "
                            for j=1,addNum,1 do
                                nextAdd = nextAdd .. ", " .. j .. " = " .. settings.data.passSettings.label[savedRead[j].tempint]
                            end
                            for j=1,text,1 do
                                flush()
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
                    local nextmsg = "What should be read? 0 = staff"
                    for i=1,#settings.data.passSettings.var,1 do
                        nextmsg = nextmsg .. ", " .. i .. " = " .. settings.data.passSettings.label[i]
                    end
                    flush()
                    setGui(22,nextmsg, true)
                    text = readCursor()
                    savedRead = {{["uuid"]=uuid.next(),["call"]="",["param"]=0,["request"]="supreme",["data"]=false}}
                    if tonumber(text) == 0 then
                        savedRead[1].call = "checkstaff"
                        savedRead[1].param = 0
                    else
                        savedRead[1].call = settings.data.passSettings.calls[tonumber(text)]
                        if settings.data.passSettings.type[tonumber(text)] == "string" or settings.data.passSettings.type[tonumber(text)] == "-string" then
                            flush()
                            setGui(22,"What is the string you would like to read? Enter text.")
                            text = readCursor()
                            savedRead[1].param = text:sub(1,-2)
                        elseif settings.data.passSettings.type[tonumber(text)] == "bool" then
                            savedRead[1].param = 0
                        elseif settings.data.passSettings.type[tonumber(text)] == "int" then
                            flush()
                            if settings.data.passSettings.above[tonumber(text)] == true then
                                setGui(22,"What level and above should be required?")
                            else
                                setGui(22,"what level exactly should be required?")
                            end
                            text = readCursor()
                            savedRead[1].param = tonumber(text)
                        elseif settings.data.passSettings.type[tonumber(text)] == "-int" then
                            local nextmsg = "What group are you wanting to set?"
                            for i=1,#settings.data.passSettings.data[tonumber(text)],1 do
                                nextmsg = nextmsg .. ", " .. i .. " = " .. settings.data.passSettings.data[tonumber(text)][i]
                            end
                            flush()
                            setGui(22,nextmsg)
                            text = readCursor()
                            savedRead[1].param = tonumber(text)
                        else
                            flush()
                            setGui(22,"error in cardRead area for num 2")
                            readCursor()
                            savedRead[1].param = 0
                        end
                    end
                end
                editTable[pageNum].cardRead = savedRead
            elseif p1 == 6 then
                flush()
                local wait = true
                local distable = {}
                setGui(22,"What is the address for the readers?")
                if canScan then
                    setGui(23,"Scan all the readers you want to add. Click screen to stop")
                    distable = scanner(true)
                else
                    setGui(23,"Enter uuid as text. Press enter with nothing in it to stop")
                    while wait do
                        term.setCursor(1,24)
                        term.clearLine()
                        text = term.read()
                        text = text:sub(1,-2)
                        if text == "" then
                            wait = false
                        else
                            table.insert(distable,text)
                        end
                    end
                end
                editTable[pageNum].reader = {}
                for _, value in pairs(distable) do
                    local thisType = component.type(value)
                    if thisType == "os_magreader" then
                        table.insert(editTable[pageNum].reader,{["uuid"]=value,["type"]="swipe"})
                    elseif thisType == "os_biometric" then
                        table.insert(editTable[pageNum].reader,{["uuid"]=value,["type"]="biometric"})
                    elseif thisType == "os_rfidreader" then
                        table.insert(editTable[pageNum].reader,{["uuid"]=value,["type"]="rfid"})
                    end
                end
            end
            pageChange(pageNum,#editTable,editChange)
            pageChangeAllowed = true
        end
    end
    term.clear()
    local poo = {}
    for i=1,#editTable,1 do
        poo[editTable[i].key] = editTable[i]
        poo.key = nil
    end
    sendit(from,diagPort,false,"changeSettings",ser.serialize(poo))
    print("finished")
    os.exit()
end

local function remotecontrol()
    --Settings
    local listAmt = 9
    --setup the list of doors, sorted by list number.
    sendit(nil,modemPort,true,"rcdoors")
    if link == nil then
        modem.open(modemPort)
    else
        modem.close(modemPort)
    end
    local e,_,_,_,_,msg = event.pull(3,"modem_message")
    if e == nil then
        print("No query received. Server might be offline")
        os.exit()
    end
    msg = crypt(msg,config.cryptKey,true)
    local tempPasses = ser.unserialize(msg)
    local passTable = {}
    for key,value in pairs(tempPasses) do
        for keym,valuem in pairs(value.data) do
            table.insert(passTable,{["call"]=value.id,["type"]=value.type,["data"]=valuem,["key"]=keym})
        end
    end
    tempPasses = deepcopy(passTable)
    passTable = {}
    local counter = 1
    for i=1,math.ceil(#tempPasses/9),1 do
        passTable[i] = {}
        for j=1,listAmt,1 do
            if counter <= #tempPasses then
                table.insert(passTable[i],tempPasses[counter])
                counter = counter + 1
            else
                break
            end
        end
    end
    --Screen GUI preparation


    local rcfunc = function(chosen)
        setGui(1,"Page" .. pageNum .. "/" .. #passTable)
        setGui(2,"")
        setGui(3,chosen and "Click screen to go back to door select" or "Click the screen to exit")
        setGui(4,"------------------------------")
        for i=1,listAmt,1 do
            if passTable[pageNum][i] ~= nil then
                setGui(i+4,chosen == nil and i .. ". " .. passTable[pageNum][i].data.name or passTable[pageNum][i].data.name, chosen == i and 0x00FF00 or nil)
            else
                break
            end
        end
        setGui(listAmt+5,"------------------------------") --15
        if chosen ~= nil and chosen ~= false then
            setGui(16,"1. Toggle Open")
            setGui(17,"2. Open for 5 seconds")
            setGui(18,"3. Open for 10 seconds")
            setGui(19,"4. Open for 30 seconds")
            setGui(20,"5. Open for # seconds")
        end
    end

    local pig = true
    pageChange(1,#passTable,rcfunc)
    while pig do
        local flush = function()
            for i=1,24,1 do
                setGui(i,"")
            end
        end
        flush()
        pageChange(pageNum,#passTable,rcfunc)
        lengthNum = #passTable[pageNum]
        local ev, p1, p2, p3 = event.pullMultiple("touch","key_down","numInput")
        if ev == "touch" then
            pig = false
        elseif ev == "key_down" then
            local char = keyboard.keys[p3]
            if char == "left" then
                flush()
                pageChange(false,#passTable,rcfunc)
                os.sleep(1)
            elseif char == "right" then
                flush()
                pageChange(true,#passTable,rcfunc)
                os.sleep(1)
            end
        elseif ev == "numInput" then
            flush()
            pageChange(pageNum,#passTable,rcfunc,p1)
            os.sleep(1)
            lengthNum = 5
            ev, p2 = event.pullMultiple("touch","numInput")
            if ev == "numInput" then
                local send = {["id"]=passTable[pageNum][p1].call,["key"]=passTable[pageNum][p1].key,["type"]="base"}
                if p2 == 1 then
                    send.type = "toggle"
                elseif p2 == 2 then
                    send.type,send.delay = "delay", 5
                elseif p2 == 3 then
                    send.type,send.delay = "delay", 10
                elseif p2 == 4 then
                    send.type,send.delay = "delay", 30
                elseif p2 == 5 then
                    setGui(22,"How long do you want to open door?")
                    term.setCursor(1,23)
                    term.clearLine()
                    local text = term.read()
                    send.type,send.delay = "delay", tonumber(text)
                end
                sendit(send.id,diagPort,false,"remoteControl",ser.serialize(send))
            end
        end
    end
    os.exit()
end

--------Startup Code

term.clear()

config = loadTable("extraConfig.txt")
if config == nil then
    config = {}
    print("Do you want to use the default cryptKey of {1,2,3,4,5}?","1 for yes, 2 for no")
    local text = term.read()
    if tonumber(text) == 2 then
        config.cryptKey = {}
        print("there are 5 parameters, each requiring a number. Recommend doing 1 digit numbers cause I got no idea how this works lol")
        for i=1,5,1 do
            print("enter param " .. i)
            text = term.read()
            config.cryptKey[i] = tonumber(text)
        end
    else
        config.cryptKey = {1,2,3,4,5}
    end
    modem.open(syncPort)
    modem.broadcast(syncPort,"syncport")
    local e,_,_,_,_,msg = event.pull(1,"modem_message")
    modem.close(syncPort)
    if e then
        config.port = tonumber(msg)
    else
        print("What port is the server running off of?")
        local text = term.read()
        config.port = tonumber(text:sub(1,-2))
        term.clear()
    end
    saveTable(config,"extraConfig.txt")
end
modemPort = config.port

if component.isAvailable("tunnel") then
    link = component.tunnel
end

print("Sending query to server...")
if link == nil then
    modem.open(modemPort)
else
    modem.close(modemPort)
end
sendit(nil,modemPort,true,"getquery",ser.serialize({"passSettings","sectors"}))
local e,_,_,_,_,msg = event.pull(3,"modem_message")
modem.close(modemPort)
if e == nil then
    print("No query received. Assuming old server system is in place and will not work")
    os.exit()
else
  print("Query received")
  settings = ser.unserialize(crypt(msg,config.cryptKey,true))
    if settings.data.sectors ~= nil then
        hassector = true
    end
    if settings.num ~= 3 then
        print("Server is not Servertine")
        os.exit()
    end
    for _,value in pairs(supportedVersions) do
        if value == settings.version then
            break
        end
        versionNum = versionNum + 1
    end
    if versionNum > #supportedVersions then
        print("Server version is not supported")
        os.exit()
    end
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
print("4. Remote Control")
lengthNum = 4
_, nextVar = event.pull("numInput")
if nextVar == 1 then
    diagnostics()
elseif nextVar == 2 then
    accsetup()
elseif nextVar == 3 then
    doorediting()
elseif nextVar == 4 then
    remotecontrol()
end
