--Experimental, combined door control with ability to be a multi or single door.

--Library for saving/loading table for all this code. all the settings below are saved in it.
local ttf=require("tableToFile")
local doorVersion = "2.2.0"
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
  
  function openDoor(delayH, redColorH, doorAddressH, toggleH, doorTypeH, redSideH)
    if(toggleH == 0) then
      if(doorTypeH == 0 or doorTypeH == 3)then
        component.proxy(doorAddressH).open()
        os.sleep(delayH)
        component.proxy(doorAddressH).close()
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
  end

  local function update(msg, localAddress, remoteAddress, port, distance, msg, data) --TODO: Move code from all door types here & make it work as single or multi door.
    if testR == true then
      data = crypt(data, extraConfig.cryptKey, true)
      if msg == "forceopen" then
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
      elseif msg == "remoteControl" then --needs to receive {["id"]="modem id",["key"]="door key if multi",["type"]="type of door change",extras like delay and toggle}
        data = ser.unserialize(data)
        if data.id == component.list("modem")[1] then
          if data.type == "base" then
            thread.create(openDoor, settingData[data.key].delay, settingData[data.key].redColor, settingData[data.key].doorAddress, settingData[data.key].toggle, settingData[data.key].doorType, settingData[data.key].redSide)
          elseif data.type == "toggle" then
            thread.create(openDoor, settingData[data.key].delay, settingData[data.key].redColor, settingData[data.key].doorAddress, 1, settingData[data.key].doorType, settingData[data.key].redSide)
          elseif data.type == "delay" then
            thread.create(openDoor, data.delay, settingData[data.key].redColor, settingData[data.key].doorAddress, 0, settingData[data.key].doorType, settingData[data.key].redSide)
          end
        end
      end
    end
  end