--------Base APIS and variables
local diagPort = 180
local modemPort = 199

local component = require("component")
local event = require("event")
local modem = component.modem 
local ser = require ("serialization")
local term = require("term")
local ios = require("io")
local kb = require("keyboard")
local thread = require("thread")

--------Extra Arrays

local toggleTypes = {"not toggleable","toggleable"}
local doorTypeTypes = {"Door Control","Redstone dust","Bundled Cable","Rolldoor"}
local redSideTypes = {"bottom","top","back","front","right","left"}
local redColorTypes = {"white","orange","magenta","light blue","yellow","lime","pink","gray","silver","cyan","purple","blue","brown","green","red","black"}
local forceOpenTypes = {"False","True"}
local bypassLockTypes = {"",""}

local settings

local lengthNum = 0

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

  function waitNumInput(ev, p1, p2, p3, p4, p5)
    local char = tonumber(keyboard.keys[p3])
    if char > 0 then
        if char <= lengthNum then
            event.push("numInput",char)
            lengthNum = 0
        end
    end
end

function setGui(pos, text)
    term.setCursor(pos)
    term.write(text)
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
    ::Beg::
    print(num ~= 0 and "Door # " .. num or "Scan a door to start")
    if num == 0 then 
        local t = thread.current()
        t:kill()
    end
    print("1. Main Door Info")
    print("2. Entire door Info (coming soon)")
    print("3. Pass Rules")
    lengthNum = 3
    _, nextVar = event.pull("numInput")
    if numInput == 1 then
        goto type1
    elseif numInput == 2 then
        goto type2
    elseif numInput == 3 then
        goto type3
    end
    ::type1::
        term.clear()
        print("All the info will be here")
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
        print("Rule passes will be here")
        print("Click the screen to go back to menu")
        event.pull("touch")
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
        if diagThr ~= nil then
            diagThr:kill()
        end
        diagThr = thread.create(diagThr,num,diagInfo)
    end
end

--------Startup Code

event.listen("key_down", waitNumInput)
process.info().data.signal = function(...)
  print("caught hard interrupt")
  event.ignore("modem_message", update)
  testR = false
  os.exit()
end

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