local version = "2.3.0"
--testR = true

local security = {}

local cardRead = {};

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

  --------Called Functions

  function security.setup()
    modem.open(modemPort)
    modem.broadcast(modemPort,"autoInstallerQuery")
    local e
    e,_,_,_,_,query = event.pull(3,"modem_message")
    if e == nil then
      print("Failed query. Is the server on?")
      os.exit()
    end
    query = ser.unserialize(query)
    if query.num == 1 then
      print("Server is a 1.#.# version, which isn't supported!")
      os.exit()
    end
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
      saveTable(config,"extraConfig.txt")
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
        for i=1,#query.data.var,1 do
          nextmsg = nextmsg .. ", " .. i .. " = " .. query.data.label[i]
        end
        print(nextmsg)
        text = term.read()
        settingData.cardRead = {{["uuid"]=uuid.next(),["call"]="",["param"]=0,["request"]="supreme",["data"]=false}}
        if tonumber(text) == 0 then
          settingData.cardRead[1].call = "checkstaff"
          settingData.cardRead[1].param = 0
          print("No need to set access level. This mode doesn't require it :)")
        else
          settingData.cardRead[1].call = query.data.calls[tonumber(text)]
          if query.data.type[tonumber(text)] == "string" or query.data.type[tonumber(text)] == "-string" then
            print("What is the string you would like to read? Enter text.")
            text = term.read()
            settingData.cardRead[1].param = text:sub(1,-2)
          elseif query.data.type[tonumber(text)] == "bool" then
            settingData.cardRead[1].param = 0
            print("No need to set access level. This mode doesn't require it :)")
          elseif query.data.type[tonumber(text)] == "int" then
            if query.data.above[tonumber(text)] == true then
              print("What level and above should be required?")
            else
              print("what level exactly should be required?")
            end
            text = term.read()
            settingData.cardRead[1].param = tonumber(text)
          elseif query.data.type[tonumber(text)] == "-int" then
            local nextmsg = "What group are you wanting to set?"
            for i=1,#query.data.data[tonumber(text)],1 do
              nextmsg = nextmsg .. ", " .. i .. " = " .. query.data.data[tonumber(text)][i]
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
        for i=1,#query.data.var,1 do
          nextmsg.back = nextmsg.back .. ", " .. i .. " = " .. query.data.label[i]
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
          newRules["call"] = query.data.calls[tonumber(text)]
          if query.data.type[tonumber(text)] == "string" or query.data.type == "-string" then
            print("What is the string you would like to read? Enter text.")
            text = term.read()
            newRules["param"] = text:sub(1,-2)
          elseif query.data.type[tonumber(text)] == "bool" then
            newRules["param"] = 0
            print("No need for extra parameter. This mode doesn't require it :)")
          elseif query.data.type[tonumber(text)] == "int" then
            if query.data.above[tonumber(text)] == true then
              print("What level and above should be required?")
            else
              print("what level exactly should be required?")
            end
            text = term.read()
            newRules["param"] = tonumber(text)
          elseif query.data.type[tonumber(text)] == "-int" then
            local nextmsg = "What group are you wanting to set?"
            for i=1,#query.data.data[tonumber(text)],1 do
              nextmsg = nextmsg .. ", " .. i .. " = " .. query.data.data[tonumber(text)][i]
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
                    nextAdd = nextAdd .. ", " .. j .. " = " .. query.data.label[settingData.cardRead[j].tempint]
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
    extraConfig = loadTable("extraConfig.txt")
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
    got = nil
  end

  function security.checkPass(str,loc)
    local data = crypt(str,extraConfig.cryptKey,true)
    local tmpTable = ser.unserialize(data)
    tmpTable["type"] = "single"
    data = crypt(ser.serialize(tmpTable), extraConfig.cryptKey)
    if loc ~= nil then
        modem.send(loc,modemPort,"checkRules",data,true)
    else
        modem.broadcast(modemPort,"checkRules",data,true)
    end
    modem.open(modemPort)
    local e, _, from, port, _, msg = event.pull(1, "modem_message")
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
      for i=1,#query.data.calls, 1 do
        if var == query.data.calls[i] then
          var = query.data.var[i]
          break
        end
      end
    end
    data.var = var
    data = crypt(ser.serialize(data),extraConfig.cryptKey)  
    if loc ~= nil then
      modem.send(loc,modemPort,"getvar",data)
    else
      modem.broadcast(modemPort,"getvar",data)
    end
    modem.open(modemPort)
    local e, _, from, port, _, msg = event.pull(1, "modem_message")
    if e then
      data = crypt(msg, extraConfig.cryptKey, true)
      return true, data
    else
      return false, "timed out or user not found"
    end
  end
  function security.setVar(str,var,it,loc)
    local data = crypt(str,extraConfig.cryptKey,true)
    data = ser.unserialize(data)
    if type(var) == "boolean" then
      var = settingData.cardRead[1].call
      for i=1,#query.data.calls, 1 do
        if var == query.data.calls[i] then
          var = query.data.var[i]
          break
        end
      end
    end
    data.var = var
    data.data = it
    data = crypt(ser.serialize(data),extraConfig.cryptKey)
    if loc ~= nil then
      modem.send(loc,modemPort,"setvar",data)
    else
      modem.broadcast(modemPort,"setvar",data)
    end
    modem.open(modemPort)
    local e, _, from, port, _, msg = event.pull(1, "modem_message")
    if e then
      return true, "no error"
    else
      return false, "timed out"
    end
  end

return security

