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

local supportedVersions = {"2.2.0","2.2.1","2.3.0"}

local settings

lengthNum = 0

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

function diagThr(num,diagInfo) --TODO: When there are no doors, it prints nothing. FIX IT FIX IT FIX IT
    local nextVar = 0
    ::Beg::
    term.clear()
    print("Door # " .. num)
    if num == 0 then
        print("Scan a door to start")
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
    print("2. Entire door Info (coming soon)")
    print("3. Pass Rules")
    lengthNum = 3
    _, nextVar = event.pull("numInput")
    if nextVar == 1 then
        goto type1
    elseif nextVar == 2 then
        goto type2
    elseif nextVar == 3 then
        goto type3
    end
    ::type1::
        term.clear()
        print("--Main Computer info--")
        print("door status = " .. diagInfo["status"])
        print("door type = " .. diagInfo["type"])
        print("door update version = " .. diagInfo["version"])
        if diagInfo["status"] ~= "incorrect magreader" then
            if diagInfo["type"] == "multi" then
                print("number of door entries: " .. diagInfo["entries"])
                print("door's key: " .. diagInfo["key"])
                print("door name: " .. diagInfo["name"])
            else
                print("***")
                print("***")
                print("door name: " .. diagInfo["name"])
            end
            print("-Component Addresses--")
            if diagInfo["type"] == "multi" then
                if diagInfo["doorType"] == 0 then
                    print("Reader Address: " .. diagInfo["reader"])
                    print("Doorcontrol Address: " .. diagInfo["doorAddress"])
                elseif diagInfo["doorType"] == 3 then
                    print("Reader Address: " .. diagInfo["reader"])
                    print("RollDoor Address: " .. diagInfo["doorAddress"])
                else
				    print("Reader Address: " .. diagInfo["reader"])
           		    print("***")
                end
            else
                print("***")
                print("***")
            end
        else
            if diagInfo["type"] == "multi" then
                print("number of door entries: " .. diagInfo["entries"])
            else
                print("***")
            end
            print("***")
            print("***")
            print("-Component Addresses--")
            print("***")
            print("***")
        end
        print("--------------------")
        print("Click the screen to go back to menu")
        event.pull("touch")
        goto Beg
    ::type2::
        term.clear()
        print("Entire door will be here")
        print("Click the screen to go back to menu")
        event.pull("touch")
        goto Beg
    ::type3::
        term.clear()
        local num = 1
        local pageChange = function(set,pos)
            if set == false then
                if pos then
                    if num < #diagInfo.cardRead then
                        num = num + 1
                    end
                else
                    if num > 1 then
                        num = num - 1
                    end
                end
            else
                num = set
            end
            term.clear()
            setGui(1,"Page" .. num .. "/" .. #diagInfo.cardRead)
            setGui(2,"Use left and right to change pages")
            setGui(3,"Click the screen to go back to menu")
            setGui(4,"")
            local a, t = getPassID(diagInfo.cardRead[num].call)
            if a then
                setGui(5,"Pass name: " .. settings.data.label[t])
                setGui(6,"Pass type: " .. passTypes[settings.data.type[t]])
                if settings.data.type[t] == "string" or settings.data.type[t] == "-string" then
                    setGui(6,"Requires exact string: " .. diagInfo.cardRead[num].param)
                elseif settings.data.type[t] == "int" or settings.data.type[t] == "-int" then
                    if settings.data.above[t] == true and settings.data.type[t] == "int" then
                        setGui(6,"Requires level above: " .. diagInfo.cardRead[num].param)
                    else
                        if settings.data.type[t] == "-int" then
                            setGui(6,"Requires group: " .. settings.data.data[t][diagInfo.cardRead[num].param])
                        else
                            setGui(6,"Requires exact level: " .. diagInfo.cardRead[num].param)
                        end
                    end
                elseif settings.data.type[t] == "bool" then
                    setGui(6,"No extra parameters")
                end
                setGui(7,"Rule Type: " .. diagInfo.cardRead[num].request)
                if diagInfo.cardRead[num].request == "base" and #diagInfo.cardRead[num].data > 0 then --FIXME: Shows base variable, not all the add variables
                    setGui(8,"")
                    setGui(9,"Requires " .. #diagInfo.cardRead[num].data .. " Add passes")
                    for i=1,#diagInfo.cardRead[num].data,1 do
                        local p = getPassID(diagInfo.cardRead[num].data[i],diagInfo.cardRead)
                        setGui(i + 9,settings.data.label[t] .. " | " .. passTypes[settings.data.type[t]])
                    end
                end
            else
                setGui(5,"Failed at line 226 or so")
            end
        end
        pageChange(1)
        local pickle = true
        while pickle do
            local ev, p1, p2, p3 = event.pullMultiple("touch","key_down")
            if ev == "touch" then
                pickle = false
            else
                local char = keyboard.keys[p3]
                if char == "left" then
                    pageChange(false,false)
                    os.sleep(1)
                elseif char == "right" then
                    pageChange(false,true)
                    os.sleep(1)
                end
            end
        end
        goto Beg
end

function diagnostics()
    term.clear()
    local num = 0
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