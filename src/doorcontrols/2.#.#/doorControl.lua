--Experimental, combined door control with ability to be a multi or single door.

--Library for saving/loading table for all this code. all the settings below are saved in it.
local ttf=require("tableToFile")
local doorVersion = "2.3.0"
local testR = true
local saveRefresh = true

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
--Changed heavilly to table of passes. Info in singleDoor
local cardRead = {};

local forceOpen = 1
local bypassLock = 0

local doorAddress = ""

local toggle = 0

local adminCard = "admincard"

local modemPort = 199
local diagPort = 180

local component = require("component")
local gpu = component.gpu
local event = require("event")
local ser = require("serialization")
local term = require("term")
local thread = require("thread")
local process = require("process")
local uuid = require("uuid")
local computer = component.computer

local magReader = component.os_magreader
local modem = component.modem 

local baseVariables = {"name","uuid","date","link","blocked","staff"}
local varSettings = {}
 
local settingData = {}
local extraConfig = {}

local osVersion = false

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

  local function colorLink(key, var) --{["color"]=0,["delay"]=1} or just a number
    if type(var) == "table" then
      thread.create(function(args)
        for i=1,#args,1 do
          component.proxy(key).setLightState(args[i].color)
          os.sleep(args[i].delay)
        end
      end, var)
    else
      component.proxy(key).setLightState(var)
    end
  end
  
  local function openDoor(delayH, redColorH, doorAddressH, toggleH, doorTypeH, redSideH,key)
    if(toggleH == 0) then
      if osVersion then colorLink(key,4) end
      if(doorTypeH == 0 or doorTypeH == 3)then
        if doorAddressH ~= true then
          component.proxy(doorAddressH).open()
          os.sleep(delayH)
          component.proxy(doorAddressH).close()
        else
          if doorTypeH == 0 then
            component.os_doorcontroller.open()
            os.sleep(delayH)
            component.os_doorcontroller.close()
          else
            component.os_rolldoorcontroller.open()
            os.sleep(delayH)
            component.os_rolldoorcontroller.close()
          end
        end
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
      if osVersion then colorLink(key,0) end
    else
      if osVersion then colorLink(key,{{["color"]=4,["delay"]=2},{["color"]=0,["delay"]=0}}) end
      if(doorTypeH == 0 or doorTypeH == 3)then
        if doorAddressH ~= true then
          component.proxy(doorAddressH).toggle()
        else
          if doorTypeH == 0 then
            component.os_doorcontroller.toggle()
          else
            component.os_rolldoorcontroller.toggle()
          end
        end
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
  end

  local function update(_, localAddress, remoteAddress, port, distance, msg, data)
    if (testR == true) then
      if msg == "forceopen" then
        data = crypt(data, extraConfig.cryptKey, true)
        if extraConfig.type == "single" then
          if(doorType == 0)then
            if data == "open" then
              component.os_doorcontroller.open()
            else
              component.os_doorcontroller.close()
            end
          elseif(doorType == 1)then
            component.redstone.setOutput(redSide,data == "open" and 15 or 0)
          elseif(doorType == 2)then
            component.redstone.setBundledOutput(redSide, { [redColor] = data == "open" and 255 or 0 } )
          else
            if data == "open" then
              component.os_rolldoorcontroller.open()
            else
              component.os_rolldoorcontroller.close()
            end
          end
        else
          local keyed = nil
          if data == "open" then
            for key, valued in pairs(settingData) do
              if valued.forceOpen ~= 0 then
                if valued.doorType == 0 then
                  component.proxy(valued.doorAddress).open()
                elseif valued.doorType == 1 then
                  print("potentially broken door at key " .. key .. ": set to redstone")
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
                  print("potentially broken door at key " .. key .. ": set to redstone")
                elseif valued.doorType == 2 then
                  component.redstone.setBundledOutput(redSide, { [valued.redColor] = 0})
                elseif valued.doorType == 3 then
                  component.proxy(valued.doorAddress).close()
                end
              end
            end
          end
        end
      elseif msg == "remoteControl" then --needs to receive {["id"]="modem id",["key"]="door key if multi",["type"]="type of door change",extras like delay and toggle}
        data = ser.unserialize(data)
        if data.id == component.modem.address then
          term.write("RemoteControl request received for ")
          term.write(data.type == "single" and settingData.name or settingData[data.key].name)
          modem.broadcast(modemPort,"loginfo",ser.serialize({{["text"]="Remote control open: ",["color"]=0xFFFF80},{["text"]=data.type == "single" and settingData.name or settingData[data.key].name,["color"]=0xFFFFFF},{["text"]="\n"}}))
          if extraConfig.type == "single" then
            if data.type == "base" then
              openDoor(delay,redColor,doorType == 0 and true or doorType == 3 and true or nil,toggle,doorType,redSide,magReader.address)
            elseif data.type == "toggle" then
              openDoor(delay,redColor,doorType == 0 and true or doorType == 3 and true or nil,1,doorType,redSide,magReader.address)
            elseif data.type == "delay" then
              openDoor(data.delay,redColor,doorType == 0 and true or doorType == 3 and true or nil,0,doorType,redSide,magReader.address)
            end
          else
            if data.type == "base" then
              thread.create(openDoor, settingData[data.key].delay, settingData[data.key].redColor, settingData[data.key].doorAddress, settingData[data.key].toggle, settingData[data.key].doorType, settingData[data.key].redSide,settingData[data.key].reader)
            elseif data.type == "toggle" then
              thread.create(openDoor, settingData[data.key].delay, settingData[data.key].redColor, settingData[data.key].doorAddress, 1, settingData[data.key].doorType, settingData[data.key].redSide,settingData[data.key].reader)
            elseif data.type == "delay" then
              thread.create(openDoor, data.delay, settingData[data.key].redColor, settingData[data.key].doorAddress, 0, settingData[data.key].doorType, settingData[data.key].redSide,settingData[data.key].reader)
            end
          end
        end
      elseif msg == "changeSettings" then
        if saveRefresh then
          saveRefresh = false
          thread.create(function()
            os.sleep(5)
            saveRefresh = true
          end)
          data = ser.unserialize(data)
          settingData = data
          os.execute("copy -f doorSettings.txt dsBackup.txt")
          ttf.save(settingData,"doorSettings.txt")
          print("New settings received")
          local fill = {}
          fill["type"] = extraConfig.type
          fill["data"] = settingData
          modem.broadcast(modemPort,"setDoor",crypt(ser.serialize(fill),extraConfig.cryptKey))
          local got, _, _, _, _, fill = event.pull(2, "modem_message")
          if got then
            varSettings = ser.unserialize(crypt(fill,extraConfig.cryptKey,true))
            if extraConfig.type == "single" then
              doorType = settingData.doorType
              redSide = settingData.redSide
              redColor = settingData.redColor
              delay = settingData.delay
              cardRead = settingData.cardRead
              toggle = settingData.toggle
              forceOpen = settingData.forceOpen
              bypassLock = settingData.bypassLock
            end
          else
            print("Failed to receive confirmation from server")
            os.exit()
          end
        end
      elseif msg == "identifyMag" then
        local lightShow = function(data)
          if osVersion == true then
            for i=1,5,1 do
              for j=1,3,1 do
                colorLink(data.reader,j~=3 and j or 4)
                os.sleep(0.3)
              end
            end
            colorLink(data.reader,0)
          else
            if data.doorType == 2 then
              for i=1,5,1 do
                component.redstone.setBundledOutput(redSide,{ [data.redColor] = 255 })
                os.sleep(0.5)
                component.redstone.setBundledOutput(redSide,{ [data.redColor] = 0 })
                os.sleep(0.5)
              end
            else
              for i=1,10,1 do
                component.proxy(data.doorAddress).toggle()
                os.sleep(0.5)
              end
            end
          end
        end
        thread.create(lightShow,ser.unserialize(data))
      end
    end
  end

term.clear()
local fill = io.open("doorSettings.txt", "r")
if fill~=nil then 
  io.close(fill) 
else 
  print("No doorSettings.txt detected. Reinstall door control")
  os.exit()
end
fill = io.open("extraConfig.txt","r")
if fill ~= nil then
  io.close(fill)
else
  print("No config detected. Reinstall door control")
end

extraConfig = ttf.load("extraConfig.txt")
settingData = ttf.load("doorSettings.txt")
extraConfig.version = version
ttf.save(extraConfig,"extraConfig.txt")

if modem.isOpen(modemPort) == false then
  modem.open(modemPort)
end
if magReader.swipeIndicator ~= nil then
  osVersion = true
end

local checkBool = false
modem.broadcast(modemPort,"autoInstallerQuery")
local e,_,_,_,_,query = event.pull(3,"modem_message")
query = ser.unserialize(query)
if e ~= nil then
  if extraConfig.type == "single" then
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
  else
    for key, value in pairs(settingData) do
      if type(value.cardRead) == "number" then
        checkBool = true
        if value.cardRead ~= 6 then
          settingData[key].cardRead = query.data.calls[settingData[key].cardRead - #baseVariables]
        else
          settingData[key].cardRead = "checkstaff"
        end
      end
      if type(value.cardRead) ~= "table" then
        checkBool = true
        local t1, t2 = settingData[key].cardRead, settingData[key].accessLevel
          settingData[key].accessLevel = nil
          settingData[key].cardRead = {}
          settingData[key].cardRead[1] = {["uuid"]=uuid.next(),["call"]=t1,["param"]=t2,["request"]="supreme",["data"]=false}
      end
    end
    if checkBool == true then
      ttf.save(settingData,"doorSettings.txt")
    end
  end
end
checkBool = nil

fill = {}
fill["type"] = extraConfig.type
fill["data"] = settingData
modem.broadcast(modemPort,"setDoor",crypt(ser.serialize(fill),extraConfig.cryptKey))
local got, _, _, _, _, fill = event.pull(2, "modem_message")
if got then
  varSettings = ser.unserialize(crypt(fill,extraConfig.cryptKey,true))
else
  print("Failed to receive confirmation from server")
  os.exit()
end
got = nil

if osVersion then
  for key,_ in pairs(component.list("os_magreader")) do
    component.proxy(key).swipeIndicator(false)
    colorLink(key,0)
  end
  for key,_ in pairs(component.list("os_doorcontrol")) do
    component.proxy(key).close()
  end
  for key,_ in pairs(component.list("os_rolldoorcontrol")) do
    component.proxy(key).close()
  end
end

if extraConfig.type == "single" then
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
          print("Must be exactly " .. cardRead[1].param)
        elseif varSettings.type[cardRead2] == "int" then
          if varSettings.above[cardRead2] == true then
            print("Level " .. tostring(cardRead[1].param) .. " or above required")
          else
            print("Level " .. tostring(cardRead[1].param) .. " exactly required")
          end
        elseif varSettings.type[cardRead2] == "-int" then
          print("Must be group " .. varSettings.data[cardRead2][cardRead[1].param] .. " to enter")
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
else
  print("Multi-Door Control terminal")
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

while true do
  if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
  end
  local ev, address, user, str, uuid, data = event.pull("magData")
  if osVersion then colorLink(address,2) end
  local isOk = "ok"
  local keyed = nil
  if extraConfig.type == "multi" then
    for key, valuedd in pairs(settingData) do
      if(valuedd.reader == address) then
        keyed = key
      end
    end
    isOk = "incorrect magreader"
    if(keyed ~= nil)then
      redColor = settingData[keyed].redColor
      delay = settingData[keyed].delay
      cardRead = settingData[keyed].cardRead
      doorType = settingData[keyed].doorType
      doorAddress = settingData[keyed].doorAddress
      toggle = settingData[keyed].toggle
      forceOpen = settingData[keyed].forceOpen
      bypassLock = settingData[keyed].bypassLock
      isOk = "ok"
    else
      print("MAG READER IS NOT SET UP! PLEASE FIX")
      if crypt(str, extraConfig.cryptKey, true) ~= adminCard then
        if osVersion then colorLink(address,{{["color"]=3,["delay"]=3},{["color"]=0,["delay"]=1}}) end
        os.exit()
      end
      end
  end
  local data = crypt(str, extraConfig.cryptKey, true)
  if ev then
    if (data == adminCard) then
      term.write("Admin card swiped. Sending diagnostics\n")
      modem.open(diagPort)
      local diagData = extraConfig.type == "multi" and deepcopy(settingData[keyed]) or deepcopy(settingData)
      if diagData == nil then
        diagData = {}
      end
      diagData["status"] = isOk
      diagData["type"] = extraConfig.type
      diagData["version"] = doorVersion
      diagData["key"] = extraConfig.type == "multi" and keyed or nil
      diagData["num"] = 2
      diagData["entireDoor"] = extraConfig.type == "multi" and deepcopy(settingData) or nil
      local counter = 0
      if extraConfig.type == "multi" then
        for index in pairs(settingData) do
          counter = counter + 1
        end
        diagData["entries"] = counter
      end
      data = ser.serialize(diagData)
      modem.broadcast(diagPort, "diag", data)
      if osVersion then
        colorLink(address,{{["color"]=1,["delay"]=0.3},{["color"]=2,["delay"]=0.3},{["color"]=4,["delay"]=0.3},{["color"]=0,["delay"]=0}})
      end
    else
      if keyed == nil and extraConfig.type == "multi" then
        os.exit()
      end
      local tmpTable = ser.unserialize(data)
      if tmpTable == nil then
        term.write("Card failed to read. it may not have been written to right or cryptkey may be incorrect.")
        if osVersion then colorLink(address,{{["color"]=3,["delay"]=3},{["color"]=0,["delay"]=1}}) end
        os.exit()
      end
      term.write(tmpTable["name"] .. ":")
      if modem.isOpen(modemPort) == false then
        modem.open(modemPort)
      end
      tmpTable["type"] = extraConfig.type
      tmpTable["key"] = extraConfig.type == "multi" and keyed or nil
      data = crypt(ser.serialize(tmpTable), extraConfig.cryptKey)
      modem.broadcast(modemPort, "checkRules", data, bypassLock)
      local e, _, from, port, _, msg = event.pull(1, "modem_message")
      if e then
        data = crypt(msg, extraConfig.cryptKey, true)
        if data == "true" then
          term.write("Access granted\n")
          computer.beep()
          if extraConfig.type == "single" then
            openDoor(delay,redColor,true,toggle,doorType,redSide,address)
          else
            thread.create(openDoor, delay, redColor, doorAddress, toggle, doorType, redSide,address)
          end
        elseif data == "false" then
          term.write("Access denied\n")
          if osVersion then
            colorLink(address,{{["color"]=1,["delay"]=1},{["color"]=0,["delay"]=0}})
          end
          computer.beep()
          computer.beep()
        elseif data == "locked" then
          term.write("Doors have been locked\n")
          if osVersion then
            colorLink(address,{{["color"]=1,["delay"]=0.5},{["color"]=0,["delay"]=0.5},{["color"]=1,["delay"]=0.5},{["color"]=0,["delay"]=0.5}})
          end
          computer.beep()
          computer.beep()
          computer.beep()
        else
          term.write("Unknown command\n")
        end
      else
        term.write("server timeout\n")
        if osVersion then
          colorLink(address,{{["color"]=5,["delay"]=1},{["color"]=0,["delay"]=0}})
        end
      end
    end
  end
end