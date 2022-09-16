local version = "3.0.0"
--testR = true

local security = {}

local cardRead = {};

local adminCard = "admincard"

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

local magReader = component.os_magreader
local modem = component.modem
local link

local baseVariables = {"name","uuid","date","link","blocked","staff"}
local varSettings = {}

local query
 
local settingData = {}
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

  function security.setup()
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
    send(nil,modemPort,true,"getquery",ser.serialize({"passSettings"}))
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
    fill = io.open("securitySettings.txt")
    if fill ~= nil then
      io.close(fill)
    else
        term.clear()
        settingData = {}
        print("First time pass setup")
        print("Would you like to use the simple pass setup or new advanced one? 1 for simple, 2 for advanced")
        local text = term.read()
        settingData.name = "Test Security API"
        if tonumber(text) == 1 then
          local nextmsg = "What should be read? 0 = staff,"
          for i=1,#query.data.passSettings.var,1 do
            nextmsg = nextmsg .. ", " .. i .. " = " .. query.data.passSettings.label[i]
          end
          print(nextmsg)
          text = term.read()
          settingData.cardRead = {{["uuid"]=uuid.next(),["call"]="",["param"]=0,["request"]="supreme",["data"]=false}}
          if tonumber(text) == 0 then
            settingData.cardRead[1].call = "checkstaff"
            settingData.cardRead[1].param = 0
            print("No need to set access level. This mode doesn't require it :)")
          else
            settingData.cardRead[1].call = query.data.passSettings.calls[tonumber(text)]
            if query.data.passSettings.type[tonumber(text)] == "string" or query.data.passSettings.type[tonumber(text)] == "-string" then
              print("What is the string you would like to read? Enter text.")
              text = term.read()
              settingData.cardRead[1].param = text:sub(1,-2)
            elseif query.data.passSettings.type[tonumber(text)] == "bool" then
              settingData.cardRead[1].param = 0
              print("No need to set access level. This mode doesn't require it :)")
            elseif query.data.passSettings.type[tonumber(text)] == "int" then
              if query.data.passSettings.above[tonumber(text)] == true then
                print("What level and above should be required?")
              else
                print("what level exactly should be required?")
              end
              text = term.read()
              settingData.cardRead[1].param = tonumber(text)
            elseif query.data.passSettings.type[tonumber(text)] == "-int" then
              local nextmsg = "What group are you wanting to set?"
              for i=1,#query.data.passSettings.data[tonumber(text)],1 do
                nextmsg = nextmsg .. ", " .. i .. " = " .. query.data.passSettings.data[tonumber(text)][i]
              end
              print(nextmsg)
              text = term.read()
              settingData.cardRead[1].param = tonumber(text)
            else
              print("error in cardRead area for num 2")
              settingData.cardRead[1].param = 0
            end
          end
        else
          local readLoad = {}
          print("Remember how many of each pass you want before you start.","Press enter to continue")
          term.read()
          print("How many add passes do you want to add?","remember multiple base passes can use the same add pass")
          readLoad.add = tonumber(term.read())
          print("How many base passes do you want to add?")
          readLoad.base = tonumber(term.read())
          print("How many reject passes do you want to add?","These don't affect supreme passes")
          readLoad.reject = tonumber(term.read())
          print("How many supreme passes do you want to add?")
          readLoad.supreme = tonumber(term.read())
          settingData.cardRead = {}
          local nextmsg = {}
          nextmsg.beg, nextmsg.mid, nextmsg.back = "What should be read for "," pass number ","? 0 = staff"
          for i=1,#query.data.passSettings.var,1 do
            nextmsg.back = nextmsg.back .. ", " .. i .. " = " .. query.data.passSettings.label[i]
          end
          local passFunc = function(type,num)
            local newRules = {["uuid"]=uuid.next(),["request"]=type,["data"]=type == "base" and {} or false}
            print(nextmsg.beg..type..nextmsg.mid..num..nextmsg.back)
            text = term.read()
            if tonumber(text) == 0 then
              newRules.call = "checkstaff"
              newRules.param = 0
              print("No need for extra parameter. This mode doesn't require it :)")
            else
              newRules["tempint"] = tonumber(text)
              newRules["call"] = query.data.passSettings.calls[tonumber(text)]
              if query.data.passSettings.type[tonumber(text)] == "string" or query.data.passSettings.type == "-string" then
                print("What is the string you would like to read? Enter text.")
                text = term.read()
                newRules["param"] = text:sub(1,-2)
              elseif query.data.passSettings.type[tonumber(text)] == "bool" then
                newRules["param"] = 0
                print("No need for extra parameter. This mode doesn't require it :)")
              elseif query.data.passSettings.type[tonumber(text)] == "int" then
                if query.data.passSettings.above[tonumber(text)] == true then
                  print("What level and above should be required?")
                else
                  print("what level exactly should be required?")
                end
                text = term.read()
                newRules["param"] = tonumber(text)
              elseif query.data.passSettings.type[tonumber(text)] == "-int" then
                local nextmsg = "What group are you wanting to set?"
                for i=1,#query.data.passSettings.data[tonumber(text)],1 do
                  nextmsg = nextmsg .. ", " .. i .. " = " .. query.data.passSettings.data[tonumber(text)][i]
                end
                print(nextmsg)
                text = term.read()
                newRules["param"] = tonumber(text)
              else
                print("error in cardRead area for num 2")
                newRules["param"] = 0
              end
            end
            return newRules
          end
          for i=1,readLoad.add,1 do
            local rule = passFunc("add",i)
            table.insert(settingData.cardRead,rule)
          end
          local addNum = #settingData.cardRead
          for i=1,readLoad.base,1 do
            local rule = passFunc("base",i)
            print("How many add passes do you want to link?")
            text = tonumber(term.read())
            if text ~= 0 then
              local nextAdd = "Which pass do you want to add? "
              for j=1,addNum,1 do
                nextAdd = nextAdd .. ", " .. j .. " = " .. query.data.passSettings.label[settingData.cardRead[j].tempint]
              end
              for j=1,text,1 do
                print(nextAdd)
                text = tonumber(term.read())
                table.insert(rule.data,settingData.cardRead[text].uuid)
              end
            end
            table.insert(settingData.cardRead,rule)
          end
          for i=1,readLoad.reject,1 do
            local rule = passFunc("reject",i)
            table.insert(settingData.cardRead,rule)
          end
          for i=1,readLoad.supreme,1 do
            local rule = passFunc("supreme",i)
            table.insert(settingData.cardRead,rule)
          end
        end
        saveTable(settingData,"securitySettings.txt")
    end
    term.clear()
    settingData = loadTable("securitySettings.txt")
    fill = {}
    fill["type"] = "customdoor"
    fill["data"] = settingData
    send(nil,modemPort,true,"setdevice",crypt(ser.serialize(fill),extraConfig.cryptKey))
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
  end

  function security.checkPass(str,loc) --FIXME: Find out why this all is breaking the server
    local data = crypt(str,extraConfig.cryptKey,true)
    local tmpTable = ser.unserialize(data)
    tmpTable["type"] = "customdoor"
    data = crypt(ser.serialize(tmpTable), extraConfig.cryptKey)
    if loc ~= nil then
        send(loc,modemPort,true,"checkRules",data,true)
    else
        send(nil,modemPort,true,"checkRules",data,true)
    end
    local e, _, from, port, _, msg = event.pull(3, "modem_message")
    if e then
        data = crypt(msg, extraConfig.cryptKey, true)
        if data == "true" then
            return true, true
        else
            return true, false
        end
    else
      return false, "timed out"
    end
  end

  function security.getVar(str,var,loc)
    local data = crypt(str,extraConfig.cryptKey,true)
    data = ser.unserialize(data)
    if type(var) == "boolean" then
      var = settingData.cardRead[1].call
      for i=1,#query.data.passSettings.calls, 1 do
        if var == query.data.passSettings.calls[i] then
          var = query.data.passSettings.var[i]
          break
        end
      end
    end
    data.var = var
    data = crypt(ser.serialize(data),extraConfig.cryptKey)  
    if loc ~= nil then
      send(loc,modemPort,true,"getvar",data)
    else
      send(nil,modemPort,true,"getvar",data)
    end
    local e, _, from, port, _, msg = event.pull(3, "modem_message")
    if e then
      data = crypt(msg, extraConfig.cryptKey, true)
      
      return true, ser.unserialize(data) or data
    else
      return false, "timed out or user not found"
    end
  end
  function security.setVar(str,var,it,loc)
    local data = crypt(str,extraConfig.cryptKey,true)
    data = ser.unserialize(data)
    if type(var) == "boolean" then
      var = settingData.cardRead[1].call
      for i=1,#query.data.passSettings.calls, 1 do
        if var == query.data.passSettings.calls[i] then
          var = query.data.passSettings.var[i]
          break
        end
      end
    end
    data.var = var
    data.data = it
    data = crypt(ser.serialize(data),extraConfig.cryptKey)
    if loc ~= nil then
      send(loc,modemPort,true,"setvar",data)
    else
      send(nil,modemPort,true,"setvar",data)
    end
    local e, _, from, port, _, msg = event.pull(3, "modem_message")
    if e then
      return true, "no error"
    else
      return false, "timed out"
    end
  end

function security.crypt(str,reverse)
  return true,crypt(str,extraConfig.cryptKey,reverse)
end

function security.save(table,location)
  saveTable(table,location)
end
function security.load(location)
  return loadTable(location)
end

function security.send(wait,...)
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

return security

