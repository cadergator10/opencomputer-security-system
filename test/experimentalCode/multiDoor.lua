--Library for saving/loading table for all this code. all the settings below are saved in it.
local ttf=require("tableToFile")
local doorVersion = "2.1.0"
testR = true

--0 = doorcontrol block. 1 = redstone. 2 = bundled redstone. Always bundled redstone with this version of the code.
local doorType = 2
--if door type is 1 or 2, set this to a num between 0 and 5 for which side.
--bottom = 0; top = 1; back = 2 front = 3 right = 4 left = 5. Should always be 2 for back.
local redSide = 2
--if doortype =2, set this to the color you want to output in.
local redColor = 0
--Delay before the door closes again
local delay = 5
--Which term you want to have the door read.
--0 = level; 1 = armory level; 2 = MTF; 3 = GOI; 4 = Security
local cardRead = 0;

local accessLevel = 2

local forceOpen = 1
local bypassLock = 0

local doorAddress = ""

local toggle = 0

local adminCard = "admincard"


local cryptKey = {1, 2, 3, 4, 5}
local modemPort = 199
local updatePort = 197
local diagPort = 180

local serverSend = {"checkuser","checkarmor","checkMtf","checkgoi","checksec","checkdepartment","checkint","checkstaff"}
  
local component = require("component")
local gpu = component.gpu
local event = require("event")
local ser = require("serialization")
local term = require("term")
local thread = require("thread")
local process = require("process")
local computer = component.computer
 
local magReader = component.os_magreader
 
local modem = component.modem 
 
local settingData = {}
 
local function convert( chars, dist, inv )
  return string.char( ( string.byte( chars ) - 32 + ( inv and -dist or dist ) ) % 95 + 32 )
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
 
 
function splitString(str, sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        str:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

local function update(msg, localAddress, remoteAddress, port, distance, msg, data)
    	if(port == updatePort and testR == true) then
        data = crypt(data, cryptKey, true)
        if msg == "update" then
        term.write("Updating door")
        local fileReceiveFinal = io.open("ctrl.lua","w")
  		fileReceiveFinal:write(data)
  		fileReceiveFinal:flush()
  		fileReceiveFinal:close()
        event.ignore("modem_message", update)
    	os.execute("ctrl")
        os.exit()
        elseif msg == "forceopen" then
            local keyed = nil
            if data == "open" then
  				for key, valued in pairs(settingData) do
                    if valued.forceOpen ~= 0 then
        			if valued.doorType == 0 then
                        component.proxy(valued.doorAddress).open()
                    elseif valued.doorType == 1 then
                        
                    elseif valued.doorType == 2 then
                        component.redstone.setBundledOutput(redSide, { [valued.redColor] = 255})
                    elseif valued.doorType == 3 then
                        component.proxy(valued.doorAddress).open()
                    end
                    end
  				end
            else
                for key, valued in pairs(settingData) do
                    if valued.forceOpen ~= 0 then
        			if valued.doorType == 0 then
                        component.proxy(valued.doorAddress).close()
                    elseif valued.doorType == 1 then
                        
                    elseif valued.doorType == 2 then
                        component.redstone.setBundledOutput(redSide, { [valued.redColor] = 0})
                    elseif valued.doorType == 3 then
                        component.proxy(valued.doorAddress).close()
                    end
                    end
  				end
            end
        end
        end
end

function openDoor()
    local delayH = delay
    local redColorH = redColor
    local doorAddressH = doorAddress
    local toggleH = toggle
    if(toggleH == 0) then
        if(doorType == 0 or doorType == 3)then
        	component.proxy(doorAddressH).toggle()
        	os.sleep(delayH)
        	component.proxy(doorAddressH).toggle()
    	elseif(doorType == 1)then
        	component.redstone.setOutput(redSide,15)
    		os.sleep(delayH)
    		component.redstone.setOutput(redSide,0)
    	elseif(doorType == 2)then
        	component.redstone.setBundledOutput(redSide, { [redColorH] = 255 } )
        	os.sleep(delayH)
        	component.redstone.setBundledOutput(redSide, { [redColorH] = 0 } )
    	else
        	os.sleep(1)
    	end
    else
        if(doorType == 0 or doorType == 3)then
        	component.proxy(doorAddressH).toggle()
    	elseif(doorType == 1)then
        	if(component.redstone.getOutput(redSide) == 0) then
            	component.redstone.setOutput(redSide,15)
        	else
            	component.redstone.setOutput(redSide,0)
        	end
    	elseif(doorType == 2)then
        	if(component.redstone.getBundledOutput(redSide, redColorH) == 0) then
            component.redstone.setBundledOutput(redSide, { [redColorH] = 255 } )
        else
            component.redstone.setBundledOutput(redSide, { [redColorH] = 0 } )
        end
    	else
        	os.sleep(1)
    	end
    end
 end

term.clear()
local fill = io.open("doorSettings.txt", "r")
if fill~=nil then 
    io.close(fill) 
else 
    settingData["q"] = {}
    settingData["w"] = {}
    settingData["q"]["reader"] = ""
    settingData["q"]["redColor"] = 0
    settingData["q"]["delay"] = 5
    settingData["q"]["cardRead"] = 0
    settingData["q"]["accessLevel"] = 1
    settingData["q"]["doorType"] = 2
    settingData["q"]["doorAddress"] = ""
    settingData["q"]["toggle"] = 0
    settingData["q"]["forceOpen"] = 1
    settingData["q"]["bypassLock"] = 0
    settingData["w"]["reader"] = ""
    settingData["w"]["redColor"] = 0
    settingData["w"]["delay"] = 5
    settingData["w"]["cardRead"] = 0
    settingData["w"]["accessLevel"] = 1
    settingData["w"]["doorType"] = 2
    settingData["w"]["doorAddress"] = ""
    settingData["w"]["toggle"] = 0
    settingData["w"]["forceOpen"] = 1
    settingData["w"]["bypassLock"] = 0
    ttf.save(settingData,"doorSettings.txt")
end

	settingData = ttf.load("doorSettings.txt")

print("Multi-Door Control terminal")
print("---------------------------------------------------------------------------")
 
if modem.isOpen(modemPort) == false then
  modem.open(modemPort)
end
if modem.isOpen(updatePort) == false then
  modem.open(updatePort)
end
event.listen("modem_message", update)
process.info().data.signal = function(...)
  print("caught hard interrupt")
  event.ignore("modem_message", update)
  testR = false
  os.exit()
end
    
while true do
  if modem.isOpen(updatePort) == false then
  modem.open(updatePort)
  end
  ev, address, user, str, uuid, data = event.pull("magData")
  term.write(str .. "\n")
    
  local keyed = nil
  for key, valuedd in pairs(settingData) do
        if(valuedd.reader == address) then
            keyed = key
      end
  end
  local isOk = "incorrect magreader"
   if(keyed ~= nil)then
        term.write(settingData[keyed].redColor)
      	redColor = settingData[keyed].redColor
        delay = settingData[keyed].delay 
        cardRead = settingData[keyed].cardRead
        accessLevel = settingData[keyed].accessLevel
        doorType = settingData[keyed].doorType
        doorAddress = settingData[keyed].doorAddress
        toggle = settingData[keyed].toggle
        forceOpen = settingData[keyed].forceOpen
        bypassLock = settingData[keyed].bypassLock
        isOk = "ok"
   else
        print("MAG READER IS NOT SET UP! PLEASE FIX")
   end
    
  local data = crypt(str, cryptKey, true)
  if ev then
    if (data == adminCard) then
            term.write("Admin card swiped. Sending diagnostics\n")
            modem.open(diagPort)
            local diagData = settingData[keyed]
            if diagData == nil then 
                diagData = {}
            end
            diagData["status"] = isOk
            diagData["type"] = "multi"
            diagData["version"] = doorVersion
            diagData["key"] = keyed
            local counter = 0
            for index in pairs(settingData) do
                counter = counter + 1
            end
            diagData["entries"] = counter
            data = crypt(ser.serialize(diagData),cryptKey)
            modem.broadcast(diagPort, "temp", data)
    else
    local tmpTable = ser.unserialize(data)
    term.write(tmpTable["name"] .. ":")
    if modem.isOpen(modemPort) == false then
      modem.open(modemPort)
    end
    if modem.isOpen(updatePort) == false then
  		modem.open(updatePort)
  	end
    if (cardRead == 0 or cardRead == 1 or cardRead == 5) then
        data = crypt(tostring(accessLevel), cryptKey)
        modem.broadcast(modemPort, "setlevel", data)
        data = crypt
        (tmpTable["uuid"], cryptKey)
        modem.broadcast(modemPort, serverSend[(cardRead + 1)], data, bypassLock)                
    elseif (cardRead == 2 or cardRead == 3 or cardRead == 4 or cardRead == 6 or cardRead == 7) then
        data = crypt
        (tmpTable["uuid"], cryptKey)
        modem.broadcast(modemPort, serverSend[(cardRead + 1)], data, bypassLock)            
    end
    local e, _, from, port, _, msg = event.pull(1, "modem_message")
    if e then
      data = crypt(msg, cryptKey, true)
--    print(data)
      if data == "true" then
    term.write("Access granted\n")
    computer.beep()
    thread.create(function(delayH, redColorH, doorAddressH, toggleH, doorTypeH, redSideH)
        if(toggleH == 0) then
            if(doorTypeH == 0 or doorTypeH == 3)then
                component.proxy(doorAddressH).toggle()
                os.sleep(delayH)
                component.proxy(doorAddressH).toggle()
            elseif(doorTypeH == 1)then
                component.redstone.setOutput(redSideH,15)
                os.sleep(delayH)
                component.redstone.setOutput(redSideH,0)
            elseif(doorTypeH == 2)then
                component.redstone.setBundledOutput(redSideH, { [redColorH] = 255 } )
                os.sleep(delayH)
                component.redstone.setBundledOutput(redSideH, { [redColorH] = 0 } )
            else
                os.sleep(1)
            end
        else
            if(doorTypeH == 0 or doorTypeH == 3)then
                component.proxy(doorAddressH).toggle()
            elseif(doorTypeH == 1)then
                if(component.redstone.getOutput(redSideH) == 0) then
                    component.redstone.setOutput(redSideH,15)
                else
                    component.redstone.setOutput(redSideH,0)
                end
            elseif(doorTypeH == 2)then
                if(component.redstone.getBundledOutput(redSideH, redColorH) == 0) then
                component.redstone.setBundledOutput(redSideH, { [redColorH] = 255 } )
            else
                component.redstone.setBundledOutput(redSideH, { [redColorH] = 0 } )
            end
            else
                os.sleep(1)
            end
        end
    end, delay, redColor, doorAddress, toggle, doorType, redSide)
      elseif data == "false" then
    term.write("Access denied\n")
    computer.beep()
    computer.beep()
      elseif data == "locked" then
    term.write("Doors have been locked\n")
    computer.beep()
    computer.beep()
    computer.beep()
      else
    term.write("Unknown command\n")
      end
    else
      term.write("server timeout\n")
    end
    end
  end
end