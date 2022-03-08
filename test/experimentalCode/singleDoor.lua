--Library for saving/loading table for all this code. all the settings below are saved in it.
local ttf=require("tableToFile")
local doorVersion = "2.1.0"
local testR = true
--0 = doorcontrol block. 1 = redstone. 2 = bundled redstone. 3 = rolldoor
local doorType = 0
--if door type is 1 or 2, set this to a num between 0 and 5 for which side.
--bottom = 0; top = 1; back = 2 front = 3 right = 4 left = 5
local redSide = 0
--if doortype =2, set this to the color you want to output in.
local redColor = 0
--Delay before the door closes again
local delay = 5
--Which term you want to have the door read.
--0 = level; 1 = armory level; 2 = MTF; 3 = GOI; 4 = Security; 5 = Department
local cardRead = 0;

--If cardRead = 0, then it is the card level.
--If cardRead = 1, then it is the armory level.
--If cardRead = 5, then it is the department. 1=SD, 2=ScD, 3=MD, 4=E&T, 5=O5 (any department door)
local accessLevel = 2

--toggle=0: it will automatically close after being opened.
--toggle=1: it will stay open/closed when opened.
local toggle = 0
local bypassLock = 0
local forceOpen = 1

--Labels for admin security cards, which are cards that make the security system send diagnostic info of the door.
local adminCard = "admincard"

local cryptKey = {1, 2, 3, 4, 5}
local modemPort = 199
local diagPort = 180
  
local component = require("component")
local gpu = component.gpu
local event = require("event")
local ser = require("serialization")
local term = require("term")
local process = require("process")
local computer = component.computer
 
local magReader = component.os_magreader
 
local modem = component.modem 
 
local baseVariables = {"name","uuid","date","link","blocked","staff"}
local varSettings = {}

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
    if(testR == true) then
        data = crypt(data, cryptKey, true)
        if msg == "forceopen" and forceOpen ~= 0 then
            if data == "open" then
                if(doorType == 0)then
                    component.os_doorcontroller.open()
                elseif(doorType == 1)then
                    if(component.redstone.getOutput(redSide) == 0) then
                        component.redstone.setOutput(redSide,15)
                    else
                        component.redstone.setOutput(redSide,0)
                    end
                elseif(doorType == 2)then
                    if(component.redstone.getBundledOutput(redSide, redColor) == 0) then
                        component.redstone.setBundledOutput(redSide, { [redColor] = 255 } )
                    else
                        component.redstone.setBundledOutput(redSide, { [redColor] = 0 } )
                    end
                else
                    component.os_rolldoorcontroller.open()
                end
            else
                if(doorType == 0)then
                    component.os_doorcontroller.close()
                elseif(doorType == 1)then
                    if(component.redstone.getOutput(redSide) == 0) then
                        component.redstone.setOutput(redSide,15)
                    else
                        component.redstone.setOutput(redSide,0)
                    end
                elseif(doorType == 2)then
                    if(component.redstone.getBundledOutput(redSide, redColor) == 0) then
                        component.redstone.setBundledOutput(redSide, { [redColor] = 255 } )
                    else
                        component.redstone.setBundledOutput(redSide, { [redColor] = 0 } )
                    end
                else
                    component.os_rolldoorcontroller.close()
                end
            end
        elseif msg == "remoteControl" then
            data = ser.unserialize(data)
            if data.id == component.list("modem")[1] then
                if data.type == "base" then
                    openDoor()
                elseif data.type == "toggle" then
                    openDoor(true,1)
                elseif data.type == "delay" then
                    openDoor(true,0,data.delay)
                end
            end
        end
    end
end

function openDoor(override,datas) --TODO: update this more.
    local delay2 = delay
    local toggle2 = toggle
    if override then
       delay2 = datas.delay
       toggle2 = datas.toggle 
    end
    if(toggle2 == 0) then
        if(doorType == 0)then
            component.os_doorcontroller.toggle()
            os.sleep(delay2)
            component.os_doorcontroller.toggle()
        elseif(doorType == 1)then
            component.redstone.setOutput(redSide,15)
            os.sleep(delay2)
            component.redstone.setOutput(redSide,0)
        elseif(doorType == 2)then
            component.redstone.setBundledOutput(redSide, { [redColor] = 255 } )
            os.sleep(delay2)
            component.redstone.setBundledOutput(redSide, { [redColor] = 0 } )
        else
            component.os_rolldoorcontroller.toggle()
            os.sleep(delay2)
            component.os_rolldoorcontroller.toggle()
        end
    else
        if(doorType == 0)then
            component.os_doorcontroller.toggle()
        elseif(doorType == 1)then
            if(component.redstone.getOutput(redSide) == 0) then
                component.redstone.setOutput(redSide,15)
            else
                component.redstone.setOutput(redSide,0)
            end
        elseif(doorType == 2)then
            if(component.redstone.getBundledOutput(redSide, redColor) == 0) then
                component.redstone.setBundledOutput(redSide, { [redColor] = 255 } )
            else
                component.redstone.setBundledOutput(redSide, { [redColor] = 0 } )
            end
        else
            component.os_rolldoorcontroller.toggle()
        end
    end
 end

term.clear()
local fill = io.open("doorSettings.txt", "r")
if fill~=nil then 
    io.close(fill)
else 
    settingData["name"] = "single door placeholder"
	settingData["doorType"] = 0
    settingData["redSide"] = 0
    settingData["redColor"] = 0
    settingData["delay"] = 5
    settingData["cardRead"] = 0
    settingData["accessLevel"] = 1
    settingData["toggle"] = 1
    settingData["forceOpen"] = 1
    settingData["bypassLock"] = 0
    ttf.save(settingData,"doorSettings.txt")
end
	settingData = ttf.load("doorSettings.txt")

    if modem.isOpen(modemPort) == false then
        modem.open(modemPort)
    end

    fill = {}
    fill["type"] = "single"
    fill["data"] = settingData
    modem.broadcast(modemPort,"setDoor",crypt(ser.serialize(fill),cryptKey))
    local got, _, _, _, _, fill = event.pull(2, "modem_message")
    if got then
        varSettings = ser.unserialize(crypt(fill,cryptKey,true))
    else
        print("Failed to receive confirmation from server")
        os.exit()
    end
	
	doorType = settingData.doorType
	redSide = settingData.redSide
	redColor = settingData.redColor
	delay = settingData.delay
	cardRead = settingData.cardRead
	accessLevel = settingData.accessLevel
	toggle = settingData.toggle
	forceOpen = settingData.forceOpen
	bypassLock = settingData.bypassLock

if cardRead <= #baseVariables then
    if cardRead == 6 then
        print("STAFF ONLY")
        print("")
    else
        print("Code is either broken or config not set up right")
        os.exit()
    end
else
    local cardRead2 = cardRead - #baseVariables
    print("Checking: " .. varSettings.var[cardRead2])
    if varSettings.type[cardRead2] == "string" or varSettings.type[cardRead2] == "-string" then
        print("Must be exactly " .. accessLevel)
    elseif varSettings.type[cardRead2] == "int" then
        if varSettings.above[cardRead2] == true then
            print("Level " .. tostring(accessLevel) .. " or above required")
        else
            print("Level " .. tostring(accessLevel) .. " exactly required")
        end
    elseif varSettings.type[cardRead2] == "-int" then
        print("Must be group " .. varSettings.data[cardRead2][accessLevel] .. " to enter")
    elseif varSettings.type[cardRead2] == "bool" then
        print("Must have pass to enter")
    end
end
print("---------------------------------------------------------------------------")
 
if modem.isOpen(modemPort) == false then
  modem.open(modemPort)
end
event.listen("modem_message", update)
process.info().data.signal = function(...)
  print("caught hard interrupt")
  event.ignore("modem_message", update)
  testR = false
  os.exit()
end    

while true do --TODO: test this program.
  if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
  end
  ev, _, user, str, uuid, data = event.pull("magData")
  term.write(str .. "\n")
  local data = crypt(str, cryptKey, true)
  if ev then
    if (data == adminCard) then
        term.write("Admin card swiped. Sending diagnostics\n")
        modem.open(diagPort)
        local diagData = settingData
        diagData["status"] = "ok"
        diagData["type"] = "single"
        diagData["version"] = doorVersion
        diagData["key"] = "NAN"
        data = crypt(ser.serialize(diagData),cryptKey)
        modem.broadcast(diagPort, "diag", data)
    else
        local tmpTable = ser.unserialize(data)
        term.write(tmpTable["name"] .. ":")
        if modem.isOpen(modemPort) == false then
            modem.open(modemPort)
        end
    tmpTable["type"] = "single"
    tmpTable["key"] = "none"
    if cardRead == 6 then
        data = crypt(ser.serialize(tmpTable), cryptKey)
    	modem.broadcast(modemPort, "checkstaff", data, bypassLock)
    else
        data = crypt(ser.serialize(tmpTable), cryptKey)
        modem.broadcast(modemPort, varSettings.calls[cardRead - #baseVariables], data, bypassLock)
    end
            
    local e, _, from, port, _, msg = event.pull(1, "modem_message")
    if e then
      data = crypt(msg, cryptKey, true)
--    print(data)
      if data == "true" then
    term.write("Access granted\n")
    computer.beep()
    openDoor()
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