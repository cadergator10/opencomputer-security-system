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

--------Extra Arrays

local toggleTypes = {"not toggleable","toggleable"}
local doorTypeTypes = {"Door Control","Redstone dust","Bundled Cable","Rolldoor"}
local redSideTypes = {"bottom","top","back","front","right","left"}
local redColorTypes = {"white","orange","magenta","light blue","yellow","lime","pink","gray","silver","cyan","purple","blue","brown","green","red","black"}
local forceOpenTypes = {"False","True"}
local bypassLockTypes = {"",""}
local passTypes = {["string"]="Inputtable String",["-string"]="Hidden String",["int"]="Level",["-int"]="Group",["bool"]="Bool"}

local supportedVersions = {"2.2.0","2.2.1"}

local settings

lengthNum = 0

local pageNum = 1

local diagt = nil
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
        pageNum = set
    end
    call(...)
end

function doorDiag(isMain,diagInfo2) --TEST: Test if this functions on main and entire door mode.
    if isMain == false then
        local diagInfo3 = diagInfo["entireDoor"][diagInfo2[pageNum]]
        diagInfo3["type"] = extraConfig.type
        diagInfo3["version"] = doorVersion
        diagInfo3["key"] = diagInfo2[pageNum]
        diagInfo3["num"] = 2
        diagInfo2 = diagInfo3
        print("Page" .. pageNum .. "/" .. diagInfo2["entries"])
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
    else
        if diagInfo2["type"] == "multi" then
            print("number of door entries: " .. diagInfo2["entries"])
        else
            print("***")
        end
        print("***")
        print("***")
        print("-Component Addresses--")
        print("***")
        print("***")
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
            elseif msg == "analyzer" then
                print("Scan the device with your tablet")
                _, text = event.pull("tablet_use")
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
    if diagInfo.version == "2.2.1" then print("3. Entire door Info") end
    lengthNum = diagInfo.version == "2.2.1" and 3 or 2
    _, nextVar = event.pull("numInput")
    if nextVar == 1 then
        goto mainInfo
    elseif nextVar == 2 then
        goto passRules
    elseif nextVar == 3 then
        goto allInfo
    end
    ::mainInfo::
        term.clear()
        doorDiag(true,diagInfo)
        print("--------------------")
        print("Click the screen to go back to menu")
        event.pull("touch")
        goto Beg
    ::allInfo::
        local indexed = {}
        for key, _ in pairs(diagInfo["entireDoor"]) do
            table.insert(indexed,key)
        end
        term.clear()
        pageChange(1,#indexed,doorDiag,false,indexed)
        pickle = true
        while pickle do
            local ev, p1, p2, p3 = event.pullMultiple("touch","key_down")
            if ev == "touch" then
                pickle = false
            else
                local char = keyboard.keys[p3]
                if char == "left" then
                    pageChange(false,#indexed,doorDiag,false,indexed)
                    os.sleep(1)
                elseif char == "right" then
                    pageChange(true,#indexed,doorDiag,false,indexed)
                    os.sleep(1)
                end
            end
        end
        goto Beg
    ::passRules::
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
                        local p = getPassID(diagInfo.cardRead[pageNum].data[i],diagInfo.cardRead)
                        setGui(i + 9,settings.data.label[p] .. " | " .. passTypes[settings.data.type[p]])
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

function diagnostics()
    term.clear()
    local num = 0
    diagt = thread.create(diagThr,num)
    while true do
        if modem.isOpen(diagPort) == false then
            modem.open(diagPort)
        end

        local _, _, from, port, _, command, msg = event.pull("modem_message")
        local data = msg
        local diagInfo = ser.unserialize(data)
        local temp
        num = num + 1
        if diagt ~= nil then
            diagt:kill()
        end
        diagt = thread.create(diagThr,num,diagInfo)
    end
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
        if char > 0 then
            if char <= lengthNum then
                event.push("numInput",char)
                lengthNum = 0
            end
        end
    end
end)

term.clear()
local nextVar = 0
print("Which app would you like to run?")
print("1. Diagnostics")
print("2. Accelerated door setup")
lengthNum = 2
_, nextVar = event.pull("numInput")
if nextVar == 1 then
    diagnostics()
elseif nextVar == 2 then
    accsetup()
end