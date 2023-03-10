--Experimental, combined door control with ability to be a multi or single door.

local doorVersion = "4.0.0"
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
local cardRead = {};

local readerLights = {} --Table full of all reader id's, which a thread uses. {["new"]=0,["old"]=-1,["check"]=0}

local rfidBlock = false
local rfidReaders = {} --Table full of all RFID Readers id's, which a thread uses. {["uuid"]="reader id",["buffer"]=card buffers,["key"]='door key',["size"]=5,["last"]=whether rfid has opened/closed before}
local rfidDoorList = {} --keys of doors for rfid
local rfidBuffer = {} --Buffer for RFID cards detected. [uuid] = {["timer"]=2,["allowed"]=""}
local rfidInt = 1
local rfidTimer = 0
local rfidWait = 2

local doorControls = {} --Test to control doors the same way we do with readerLights. {["swipe"]=false,["rfid"]=false,["lock"]=0,["memory"]=false}

local sector

local doorAddress = ""

local toggle = 0

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

local magReader = component.os_magreader
local modem = component.modem
local link

local baseVariables = {"name","uuid","date","link","blocked","staff"}
local varSettings = {}
local enableSectors = true

local settingData = {}
local extraConfig = {}

--RFID default delay per scan: 1 second. Can lower, but every tick it should scan

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

local function send(port,linker,...)
  if linker and link ~= nil then
    link.send(modem.address,...)
    return
  end
  modem.broadcast(port,...)
end
local function modemadd()
  if link then
    return link.address
  else
    return modem.address
  end
end

  local function colorupdate() --A seperate thread that reads a table of readers and can control their lights. ALSO SCANS WITH RFID READER
    while true do --FIXME: Fix delay doors in lockdown mode losing their red light
      --Change reader lights
      for key,value in pairs(readerLights) do
        if type(value.new) == "table" then
          if #value.new == 0 then
            readerLights[key].new = readerLights[key].old
          else
            if value.new[1].status == nil then
              readerLights[key].new[1].status = true
              component.proxy(key).setLightState(value.new[1].color)
              readerLights[key].old = readerLights[key].new[1].color
            else
              readerLights[key].new[1].delay = readerLights[key].new[1].delay - 0.05
              if readerLights[key].new[1].delay <= 0 then
                table.remove(readerLights[key].new,1)
                if #value.new == 0 then
                  component.proxy(key).setLightState(value.check)
                end
              end
            end
          end
        elseif value.new ~= value.old then
          if value.new == -1 then
            value.new = value.check
          end
          component.proxy(key).setLightState(value.new)
          readerLights[key].old = readerLights[key].new
        end
      end
      --rfid stuff
      if #rfidReaders > 0 and rfidBlock == false then --if rfid is enabled and there are readers
        if rfidTimer <= 0 then --if delay isn't still going

          local reader = component.proxy(rfidReaders[rfidInt].uuid).scan(rfidReaders[rfidInt].size) --scan and perform checks on new cards found
          for _,value in pairs(reader) do
            local data = value.data ~= nil and ser.unserialize(crypt(value.data,extraConfig.cryptKey)) or nil --get data off card
            if data ~= nil then
              if rfidReaders[rfidInt].buffer[data.uuid] ~= nil then --if there is data and crypt is correct
              event.push("rfidSuccess",nil,nil,data) --push to main thread to check if allowed or not
              local e, status = event.pull("rfidRequest") --receive results
              rfidReaders[rfidInt].buffer[data.uuid] = {["timer"]=rfidWait,["allowed"]=status} --add new user to buffer
              else
                rfidReaders[rfidInt].buffer[data.uuid].timer = rfidWait --Update timer back to max as they are still in range
              end
            end
          end

          local doorList = {} --This part goes through all readers listed and checks users in buffer if their timers ran out. Also checks if door should be opened or not
          for i=1, #rfidReaders, 1 do --go through all readers
            doorList[rfidReaders[i].key] = doorList[rfidReaders[i].key] ~= nil and doorList[rfidReaders[i].key] or false --Set the current key to false
            for key, value in pairs(rfidReaders[i].buffer) do --go through every card in buffer
              if value.timer <= 0 and i == rfidInt then --remove cards if they run out of time and the current door that just scanned didn't see them
                rfidReaders[i].buffer[key] = nil
              elseif value.allowed == true then
                doorList[rfidReaders[i].key] = true
              end
            end
          end

          local doorChange = false --If true, it pushes an event causing the doorcontrol thread to perform checks and changes
          for key,value in pairs(doorList) do --This goes through the list made in the last section to see if any changes were made (need to open or close again)
            if value ~= rfidDoorList[key] then --there was a change in a door
              doorChange = true
              rfidDoorList[key] = value
              doorControls[key].rfid = value --update actual door table that opens/closes stuff
            end
          end
          if doorChange then event.push("doorChange") end

          if rfidInt >= #rfidReaders then --This checks if its gone through every rfidreader. If it has, wait a second before continuing. Otherwise it increments the rfidint
            rfidInt = 1
            rfidTimer = 1
          else
            rfidInt = rfidInt + 1
          end
        else --rfidTimer is still not at 0, so just decrement and wait
          rfidTimer = rfidTimer - 0.05
          os.sleep(0.05)
        end
      else --No rfidReaders or it is blocked manually
        os.sleep(0.05)
      end
    end
  end

  local function colorLink(key, var, check) --{["color"]=0,["delay"]=1} or just a number
    local chech = function(key)
      if readerLights[key] == nil then
        component.proxy(key).swipeIndicator(false)
        readerLights[key] = {["new"]=0,["old"]=-1,["check"]=0}
      end
      readerLights[key].new = deepcopy(var)
      if check then readerLights[key].check = check end
    end
    if type(key) == "table" then
      for i=1,#key,1 do
        if key[i].type == "swipe" then chech(key[i].uuid) end
      end
    else
      chech(key)
    end
  end

  local function doorLink(key, var)
    if doorControls[key] == nil then
      doorControls[key] = {["swipe"]=false,["rfid"]=false,["lock"]=0,["memory"]=false}
    end
    if type(var) == "number" then
      doorControls[key].swipe = var
    elseif type(doorControls[key].swipe) == "number" or doorControls[key].swipe == false then
      doorControls[key].swipe = true
    else
      doorControls[key].swipe = false
    end
    event.push("doorChange")
  end

  local function doorupdate() --A seperate thread that reads a table of door addresses and redstone stuff and can control them.
    while true do
      local shouldContinue = false
      for key, value in pairs(doorControls) do
        local isOpen = false
        if value.lock == 0 then
          if type(value.swipe) == "number" then
            shouldContinue = true
            doorControls[key].swipe = value.swipe - 0.05
            if value.swipe <= 0 then
              doorControls[key].swipe = false
            else
              isOpen = true
            end
          else
            isOpen = value.swipe
          end
          if value.rfid then
            isOpen = true
          end
        elseif value.lock == 2 then
          isOpen = true
        end
        if isOpen ~= value.memory then
          doorControls[key].memory = isOpen
          if settingData[key].doorType == 3 then
            for _, value2 in pairs(settingData[key].doorAddress) do
              if isOpen then
                component.proxy(value2).open()
              else
                component.proxy(value2).close()
              end
            end
          elseif settingData[key].doorType == 2 then
            component.redstone.setBundledOutput(settingData[key].redSide, { [settingData[key].redColor] = isOpen and 255 or 0 } )
          elseif settingData[key].doorType == 1 then
            component.redstone.setOutput(settingData[key].redSide,isOpen and 15 or 0)
          end
          if isOpen then
            colorLink(settingData[key].reader,{{["color"]=4,["delay"]=2},{["color"]=0,["delay"]=0}})
          else
            colorLink(settingData[key].reader,0)
          end
        end
      end
      if shouldContinue then
        os.sleep()
      else
        event.pull(5,"doorChange") --to attempt to save system resources: Only runs if 1. Some values in the door system require it to wait a certain amount of time, 2. An event is pushed called doorChange, and 3. The timeout of x seconds is reached (in case it happens to miss a door change, it WILL do it.)
      end
    end
  end
  
  local function openDoor(delayH, redColorH, doorAddressH, toggleH, doorTypeH, redSideH,key)
    if(toggleH == 0) then
      if osVersion then colorLink(key,4) end
      if(doorTypeH == 3)then
        for _,value in pairs(doorAddressH) do
          component.proxy(value).open()
        end
        os.sleep(delayH)
        for _,value in pairs(doorAddressH) do
          component.proxy(value).close()
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
      if osVersion then colorLink(key,-1) end
    else
      if osVersion then colorLink(key,{{["color"]=4,["delay"]=2},{["color"]=0,["delay"]=0}}) end
      if(doorTypeH == 3)then
        for _,value in pairs(doorAddressH) do
          component.proxy(value).toggle()
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

  local function sectorfresh(data)
    if enableSectors then
      for dk,value in pairs(settingData) do
        if value.sector ~= false then
          for key,value2 in pairs(data) do
            if key == value.sector then
              doorControls[dk].lock = value2 - 1
              if osVersion then
                if value2 == 1 then
                  colorLink(value.reader,0,0)
                elseif value2 == 2 then
                  colorLink(value.reader,1,1)
                elseif value2 == 3 then
                  colorLink(value.reader,4,4)
                end
              end
              --[[if value2 == 1 then
                if value.doorType == 3 then
                  for _,value2 in pairs(value.doorAddress) do
                    component.proxy(value2).close()
                  end
                elseif value.doorType == 2 then
                  component.redstone.setBundledOutput(value.redSide, { [value.redColor] = 0 } )
                elseif value.doorType == 1 then
                  component.redstone.setOutput(value.redSide,0)
                end
                if osVersion then
                  colorLink(value.reader,0,0)
                end
              elseif value2 == 2 then
                if value.doorType == 3 then
                  for _,value2 in pairs(value.doorAddress) do
                    component.proxy(value2).close()
                  end
                elseif value.doorType == 2 then
                  component.redstone.setBundledOutput(value.redSide, { [value.redColor] = 0 } )
                elseif value.doorType == 1 then
                  component.redstone.setOutput(value.redSide,0)
                end
                if osVersion then
                  colorLink(value.reader,1,1)
                end
              elseif value2 == 3 then
                if value.doorType == 3 then
                  for _,value2 in pairs(value.doorAddress) do
                    component.proxy(value2).open()
                  end
                elseif value.doorType == 2 then
                  component.redstone.setBundledOutput(value.redSide, { [value.redColor] = 255 } )
                elseif value.doorType == 1 then
                  component.redstone.setOutput(value.redSide,15)
                end
                if osVersion then
                  colorLink(value.reader,4,4)
                end
              end]]
              break
            end
          end
        end
      end
      event.push("doorChange")
    end
  end

  local function update(_, localAddress, remoteAddress, port, distance, msg, data)
    if (testR == true) then
      if msg == "checkSector" then --Making forceopen obselete.
        data = ser.unserialize(data)
        sectorfresh(data)
      elseif msg == "remoteControl" then --needs to receive {["id"]="modem id",["key"]="door key if multi",["type"]="type of door change",extras like delay and toggle}
        data = ser.unserialize(data)
        if data.id == modem.address then
          term.write("RemoteControl request received for " .. settingData[data.key].name)
          term.write("\n")
          send(modemPort,true,"loginfo",ser.serialize({{["text"]="Remote control open: ",["color"]=0xFFFF80},{["text"]=settingData[data.key].name,["color"]=0xFFFFFF}}))
          if data.type == "base" then
            doorLink(data.key,settingData[data.key].toggle == true and true or settingData[data.key].delay)
            --thread.create(openDoor, settingData[data.key].delay, settingData[data.key].redColor, settingData[data.key].doorAddress, settingData[data.key].toggle, settingData[data.key].doorType, settingData[data.key].redSide,settingData[data.key].reader)
          elseif data.type == "toggle" then
            doorLink(data.key,true)
            --thread.create(openDoor, settingData[data.key].delay, settingData[data.key].redColor, settingData[data.key].doorAddress, 1, settingData[data.key].doorType, settingData[data.key].redSide,settingData[data.key].reader)
          elseif data.type == "delay" then
            doorLink(data.key,data.delay)
            --thread.create(openDoor, data.delay, settingData[data.key].redColor, settingData[data.key].doorAddress, 0, settingData[data.key].doorType, settingData[data.key].redSide,settingData[data.key].reader)
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
          saveTable(settingData,"doorSettings.txt")
          print("New settings received")
          local fill = {}
          fill["type"] = extraConfig.type
          fill["data"] = settingData
          send(modemPort,true,"setdevice",crypt(ser.serialize(fill),extraConfig.cryptKey))
          local got, _, _, _, _, fill = event.pull(2, "modem_message")
          if got then
            varSettings = ser.unserialize(crypt(fill,extraConfig.cryptKey,true))
            doorControls = {}
            for key,_ in pairs(settingData) do
              doorControls[key] = {["swipe"]=false,["rfid"]=false,["lock"]=0,["memory"]=false}
            end
            --sectorfresh(query.data.sectorStatus)
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
            colorLink(data.reader,-1)
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
                for _,value in pairs(data.doorAddress) do
                  component.proxy(value).toggle()
                end
                os.sleep(0.5)
              end
            end
          end
        end
        thread.create(lightShow,ser.unserialize(data))
      elseif msg == "deviceCheck" then
        send(modemPort,true,"true")
      end
    end
  end

if component.isAvailable("tunnel") then
  link = component.tunnel
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

extraConfig = loadTable("extraConfig.txt")
settingData = loadTable("doorSettings.txt")
extraConfig.version = doorVersion
if extraConfig.port == nil then
  extraConfig.port = 1000
end
saveTable(extraConfig,"extraConfig.txt")
modemPort = extraConfig.port

if modem.isOpen(modemPort) == false and link == nil then
  modem.open(modemPort)
elseif link ~= nil then
  modem.close(modemPort)
end
if magReader.swipeIndicator ~= nil then
  osVersion = true
end

local checkBool = false
send(modemPort,true,"getquery",ser.serialize({"passSettings","sectorStatus"}))
local e,_,_,_,_,query = event.pull(3,"modem_message")
query = crypt(query,extraConfig.cryptKey,true)
query = ser.unserialize(query)
if e ~= nil then
  for key,_ in pairs(settingData) do
    if type(settingData[key].doorAddress) == "string" then
      settingData[key].doorAddress = {settingData[key].doorAddress}
      checkBool = true
    end
    if settingData[key].doorType == 0 then
      settingData[key].doorType = 3
      checkBool = true
    end
    if type(settingData[key].reader[1]) == "string" then
      for key2, value in pairs(settingData[key].reader) do
        settingData[key].reader[key2] = {["type"]="swipe",["uuid"]=value}
      end
      checkBool = true
    end
  end
end
if checkBool then
  saveTable(settingData,"doorSettings.txt")
end
checkBool = nil

fill = {}
fill["type"] = extraConfig.type
fill["data"] = settingData
send(modemPort,true,"setdevice",crypt(ser.serialize(fill),extraConfig.cryptKey))
local got, _, _, _, _, fill = event.pull(2, "modem_message")
if got then
  varSettings = ser.unserialize(crypt(fill,extraConfig.cryptKey,true))
else
  print("Failed to receive confirmation from server")
  os.exit()
end
got = nil

if osVersion then
  readerLights = {}
  for key,_ in pairs(component.list("os_magreader")) do
    component.proxy(key).swipeIndicator(false)
    colorLink(key,-1)
    readerLights[key] = {["new"]=0,["old"]=-1,["check"]=0}
  end
  thread.create(colorupdate)
  thread.create(doorupdate)
end
for key,_ in pairs(settingData) do
  doorControls[key] = {["swipe"]=false,["rfid"]=false,["lock"]=0,["memory"]=false}
end
for key,_ in pairs(component.list("os_doorcontroller")) do
  component.proxy(key).close()
end
for key,_ in pairs(component.list("os_rolldoorcontroller")) do
  component.proxy(key).close()
end
if query.data.sectorStatus == nil then
  enableSectors = false
end
sectorfresh(query.data.sectorStatus)

print("Security Door Control terminal")
print("---------------------------------------------------------------------------")

event.listen("modem_message", update)
process.info().data.signal = function(...)
  print("caught hard interrupt")
  event.ignore("modem_message", update)
  testR = false
  os.exit()
end
modem.open(diagPort)
local bypassallowed = false

while true do
  local ev, address, user, str, uuid, data = event.pullMultiple("magData","bioReader","rfidSuccess","rfidClear")
  if ev == "magData" then
    if osVersion then colorLink(address,2) end
  end
  local isOk = "ok"
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
  isOk = "incorrect magreader"
  if(keyed ~= nil)then
    redColor = settingData[keyed].redColor
    redSide = settingData[keyed].redSide
    delay = settingData[keyed].delay
    cardRead = settingData[keyed].cardRead
    doorType = settingData[keyed].doorType
    doorAddress = settingData[keyed].doorAddress
    toggle = settingData[keyed].toggle
    sector = settingData[keyed].sector
    isOk = "ok"
  else
    print("MAG READER IS NOT SET UP! PLEASE FIX")
    if crypt(str, extraConfig.cryptKey, true) ~= adminCard then
      if osVersion then colorLink(address,{{["color"]=3,["delay"]=3}},0) end
      os.exit()
    end
  end
  local data
  if ev == "bioReader" then --TODO: Find all occurances and fix the pull
    data = user
  else
    data = crypt(str, extraConfig.cryptKey, true)
  end
  if ev then
    if (data == adminCard) then
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
      if keyed == nil then
        os.exit()
      end
      local tmpTable
      if ev ~= "bioReader" then
        tmpTable = ser.unserialize(data)
        if tmpTable == nil then
          term.write("Card failed to read. it may not have been written to right or cryptkey may be incorrect.")
          if osVersion then colorLink(settingData[keyed].reader,{{["color"]=3,["delay"]=3},{["color"]=0,["delay"]=1}}) end
          os.exit()
        end
        term.write(tmpTable["name"] .. ":")
      else
        tmpTable = {["isBio"] = true,["uuid"] = user}
        term.write("UUID " .. user .. ":")
      end
      tmpTable["type"] = extraConfig.type
      tmpTable["key"] = keyed
      tmpTable["sector"] = sector
      data = crypt(ser.serialize(tmpTable), extraConfig.cryptKey)
      send(modemPort,true, "checkRules", data)
      local e, _, from, port, _, msg = event.pull(1, "modem_message")
      if e then
        data = crypt(msg, extraConfig.cryptKey, true)
        if data == "true" then
          term.write("Access granted\n")
          computer.beep()
          doorLink(keyed,toggle == true and true or delay)
          --thread.create(openDoor, delay, redColor, doorAddress, toggle, doorType, redSide,settingData[keyed].reader)
        elseif data == "false" then
          term.write("Access denied\n")
          if osVersion then
            colorLink(settingData[keyed].reader,{{["color"]=1,["delay"]=1},{["color"]=0,["delay"]=0}})
          end
          computer.beep()
          computer.beep()
        elseif data == "bypass" then
          if bypassallowed then
            term.write("Bypass succeeded: lockdown lifted\n")
            if osVersion then
              colorLink(settingData[keyed].reader,{{["color"]=4,["delay"]=0.5},{["color"]=0,["delay"]=0.5},{["color"]=4,["delay"]=0.5},{["color"]=0,["delay"]=0.5}})
            end
            data = crypt(tmpTable.sector,extraConfig.cryptKey)
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
          term.write("Unknown command\n")
        end
      else
        term.write("server timeout\n")
        if osVersion then
          colorLink(settingData[keyed].reader,{{["color"]=5,["delay"]=1},{["color"]=0,["delay"]=0}})
        end
      end
    end
  end
end