local version = "3.0.0"
--testR = true

local serp = {}

local modemPort = 1000
local syncPort = 199
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

local modem = component.modem
local link

local varSettings = {}

local query

local extraConfig = {}

--------TableToFile

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

--------Base Functions

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
  
  local function splitString(str, sep)
          local sep, fields = sep or ":", {}
          local pattern = string.format("([^%s]+)", sep)
          str:gsub(pattern, function(c) fields[#fields+1] = c end)
          return fields
  end

local function send(label,port,linker,...) --Pingme
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

  --------Called Functions

local function update(_, localAddress, remoteAddress, port, distance, msg, data)
  if msg == "doorCheck" then
    send(modemPort,true,"true")
  end
end

  function serp.setup(doorTable,queryTable)
    local e
    local fill = io.open("extraConfig.txt", "r")
    if fill ~= nil then
      io.close(fill)
    else
      local config = {}
      config.cryptKey = {}
      term.clear()
      print("First Time Config Setup: Would you like to use default cryptKey? 1 for yes, 2 for no")
      local text = term.read()
      if tonumber(text) == 2 then
        print("there are 5 parameters, each requiring a number. Recommend doing 1 digit numbers")
        for i=1,5,1 do
          print("enter param " .. i)
          text = term.read()
          config.cryptKey[i] = tonumber(text)
        end
      else
        config.cryptKey = {1,2,3,4,5}
      end
      config.type = "single"
      config.num = 2
      config.version = version
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
    extraConfig = loadTable("extraConfig.txt")
    modemPort = extraConfig.port
    if component.isAvailable("tunnel") then
      link = component.tunnel
      modem.close(modemPort)
    else
      modem.open(modemPort)
    end
    send(nil,modemPort,true,"getquery",ser.serialize(queryTable))
    e,_,_,_,_,query = event.pull(3,"modem_message")
    if e == nil then
      print("Failed query. Is the server on?")
      os.exit()
    end
    query = ser.unserialize(crypt(query,extraConfig.cryptKey,true))
    if query.num ~= 3 then
      print("Server is not 3.0.0 and up")
      os.exit()
    end
    term.clear()
    fill = doorTable
    fill["type"] = doorTable.type or "custom"
    send(nil,modemPort,true,"setDoor",crypt(ser.serialize(fill),extraConfig.cryptKey))
    local got, _, _, _, _, fill = event.pull(2, "modem_message")
    if got then
      varSettings = ser.unserialize(crypt(fill,extraConfig.cryptKey,true))
    else
      print("Failed to receive confirmation from server")
      os.exit()
    end
    got = nil
    event.listen("modem_message", update)
    process.info().data.signal = function(...)
      print("caught hard interrupt")
      event.ignore("modem_message", update)
      os.exit()
    end
    return query
  end

function serp.crypt(str,reverse)
  return true,crypt(str,extraConfig.cryptKey,reverse)
end

function serp.save(table,location)
    saveTable(table,location)
end
function serp.load(location)
    return loadTable(location)
end

function serp.send(wait,...)
  send(nil,modemPort,true,...)
  if wait then
    local e, _, _, _, _, msg,msg2 = event.pull(3, "modem_message")
    if e then
      return true,msg,msg2
    else
      return false,"timed out"
    end
  else
    return true,"no return requested"
  end
  return false, "unknown error"
end

return serp