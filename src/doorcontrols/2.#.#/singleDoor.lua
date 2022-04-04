--Library for saving/loading table for all this code. all the settings below are saved in it.
local ttf=require("tableToFile")
local doorVersion = "2.2.0"
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
--is an array of calls. Info way below
local cardRead = "";

--toggle=0: it will automatically close after being opened.
--toggle=1: it will stay open/closed when opened.
local toggle = 0
local bypassLock = 0
local forceOpen = 1

--Labels for admin security cards, which are cards that make the security system send diagnostic info of the door.
local adminCard = "admincard"

local modemPort = 199
local diagPort = 180
  
local component = require("component")
local gpu = component.gpu
local event = require("event")
local ser = require("serialization")
local term = require("term")
local process = require("process")
local computer = component.computer
local uuid = require("uuid")
 
local magReader = component.os_magreader
 
local modem = component.modem 
 
local baseVariables = {"name","uuid","date","link","blocked","staff"}
local varSettings = {}

local settingData = {}
local extraConfig = {}
 
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
        data = crypt(data, extraConfig.cryptKey, true)
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

function openDoor(override,datas) --REVIEW: Update more
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
    print("No doorSettings.txt detected. Reinstall")
    os.exit()
end
fill = io.open("extraConfig.txt","r")
if fill ~= nil then
  io.close(fill)
else
  extraConfig["cryptKey"]={1,2,3,4,5}
  extraConfig["type"]="single"
  extraConfig["num"]=2
  extraConfig["version"]=version
  ttf.save(extraConfig,"extraConfig.txt")
end

    extraConfig = ttf.load("extraConfig.txt")
	settingData = ttf.load("doorSettings.txt")
    extraConfig.version = version
    ttf.save(extraConfig,"extraConfig.txt")

    if type(settingData.cardRead) == "number" then
        modem.broadcast(modemPort,"autoInstallerQuery")
        local e,_,from,port,_,query = event.pull(3,"modem_message")
        query = ser.unserialize(query)
        if e ~= nil then
            settingData.cardRead = settingData.cardRead == 6 and "checkstaff" or query.data.calls[settingData.cardRead - #baseVariables]
        end
        ttf.save(settingData,"doorSettings.txt")
    end
    if type(settingData.cardRead) ~= "table" then
        local t1, t2 = settingData.cardRead, settingData.accessLevel
        settingData.accessLevel = nil
        settingData.cardRead = {}
        settingData.cardRead[1] = {["uuid"]=uuid.next(),["call"]=t1,["param"]=t2,["request"]="supreme",["data"]=false}
        ttf.save(settingData,"doorSettings.txt")
    end
    --[[
        New cardRead will be able to handle multiple passes and distinguish between them
        uuid is the identifier for that pos (alt to index), call is the old cardRead, param is the old accessLevel, and request is the call type. Data is extra info along with request
        supreme = having this lets you in no matter what (like staff) nothing for data. reject will do nothing if they have a pass that is supreme.
        reject = passes not allowed to ever enter through the door (unless staff of course or they have a supreme pass) nothing for data.
        add = must have this as well as qualify for another pass. multiple base variables can use the same add. nothing for data.
        base = like supreme, except it links to add passes. data is an array with the uuids for the passes that add to it. (there doesnt have to be any adds if not needed, as base is affected by reject)
    ]]

    if modem.isOpen(modemPort) == false then
        modem.open(modemPort)
    end

    fill = {}
    fill["type"] = "single"
    fill["data"] = settingData
    modem.broadcast(modemPort,"setDoor",crypt(ser.serialize(fill),extraConfig.cryptKey))
    local got, _, _, _, _, fill = event.pull(2, "modem_message")
    if got then
        varSettings = ser.unserialize(crypt(fill,extraConfig.cryptKey,true))
    else
        print("Failed to receive confirmation from server")
        os.exit()
    end
	
	doorType = settingData.doorType
	redSide = settingData.redSide
	redColor = settingData.redColor
	delay = settingData.delay
	cardRead = settingData.cardRead
	toggle = settingData.toggle
	forceOpen = settingData.forceOpen
	bypassLock = settingData.bypassLock

    if #cardRead == 1 then
        if cardRead[1].call == "checkstaff" then
            print("STAFF ONLY")
            print("")
        else
            local cardRead2 = 0
            for i=1,#varSettings.calls,1 do
                if varSettings.calls[i] == cardRead[1].call then
                    cardRead2 = i
                    break
                end
            end
            if cardRead2 ~= 0 then
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
            else
                print("Code is either broken or config not set up right")
                os.exit()
            end
        end
    else
        print("Multi-Pass Single Door")
        print("Length: " .. #cardRead)
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

while true do --TEST: test if this functions well
  if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
  end
  ev, _, user, str, uuid, data = event.pull("magData")
  term.write(str .. "\n")
  local data = crypt(str, extraConfig.cryptKey, true)
  if ev then
    if (data == adminCard) then
        term.write("Admin card swiped. Sending diagnostics\n")
        modem.open(diagPort)
        local diagData = settingData
        diagData["status"] = "ok"
        diagData["type"] = "single"
        diagData["version"] = doorVersion
        diagData["key"] = "NAN"
        diagData["num"] = 2
        data = ser.serialize(diagData)
        modem.broadcast(diagPort, "diag", data)
    else
        local tmpTable = ser.unserialize(data)
        term.write(tmpTable["name"] .. ":")
        if modem.isOpen(modemPort) == false then
            modem.open(modemPort)
        end
    tmpTable["type"] = "single"
    tmpTable["key"] = "none"
    data = crypt(ser.serialize(tmpTable), extraConfig.cryptKey)
    modem.broadcast(modemPort, "checkRules", data, bypassLock)
    local e, _, from, port, _, msg = event.pull(1, "modem_message")
    if e then
      data = crypt(msg, extraConfig.cryptKey, true)
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