local modemPort = 199

local lockDoors = false
local forceOpen = false

local component = require("component")
local event = require("event")
local modem = component.modem 
local ser = require ("serialization")
local term = require("term")
local ios = require("io")
local gpu = component.gpu
local fs = require("filesystem")
local shell = require("shell")
local process = require("process")
local uuid = require("uuid")

local version = "2.4.0"

local redstone = {}
local commands = {"updateuserlist","autoInstallerQuery","setDoor","loginfo","rcdoors","redstoneUpdated","checkLinked","getuserlist","getvar","setvar","checkRules"}
local skipcrypt = {"autoInstallerQuery","rcdoors","getuserlist","loginfo"}

local modules = {}
local modulepath = "/modules"

local viewport = 0
local viewhistory = {}
local dohistory = true

local debug = false

--------Main Functions

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
--// The Save Function
local function saveTable(  tbl,filename )
	local tableFile = assert(io.open(filename, "w"))
  tableFile:write(ser.serialize(tbl))
  tableFile:close()
end
 
--// The Load Function
local function loadTable( sfile )
	local tableFile = io.open(sfile)
    if tableFile ~= nil then
  		return ser.unserialize(tableFile:read("*all"))
    else
        return nil
    end
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

local function addcommands(tabler,crypttable)
  for _,value in pairs(tabler) do
    table.insert(commands,value)
  end
  for _,value in pairs(crypttable) do
    table.insert(skipcrypt,value)
  end
end

local function advWrite(text,color,wrap,clear,pos,bypass)
  if dohistory or bypass then
    if pos then term.setCursor(1,pos) end
    if clear then term.clearLine() end
    gpu.setForeground(color or gpu.getForeground())
    term.write(text,wrap or true)
  end
end
local function historyUpdate(text,color,wrap,newline,rewrite)
    if rewrite then
      dohistory = true
      for i=1,#viewhistory,1 do
        advWrite("",nil,false,true,i+3)
        for j=1,#viewhistory[i],2 do
          advWrite(viewhistory[i][j],viewhistory[i][j+1],false)
        end
      end
    elseif newline then
      for i=2,#viewhistory,1 do
        advWrite("",nil,false,true,i+2)
        for j=1,#viewhistory[i],2 do
          advWrite(viewhistory[i][j],viewhistory[i][j+1],false)
        end
        viewhistory[i-1] = viewhistory[i]
      end
      viewhistory[#viewhistory] = {}
      advWrite("",0xFFFFFF,false,true,#viewhistory + 3)
    end
  table.insert(viewhistory[#viewhistory],text)
  table.insert(viewhistory[#viewhistory],color)
  advWrite("",0xFFFFFF,wrap,true,#viewhistory + 3)
  for i=1,#viewhistory[#viewhistory],2 do
    advWrite(viewhistory[#viewhistory][i],viewhistory[#viewhistory][i+1],wrap)
  end
end
--------Getting tables and setting up terminal
term.clear()
_,viewport = term.getViewport()
for i=1,viewport - 5,1 do
  viewhistory[i] = {"",0xFFFFFF}
end
modulepath = fs.path(shell.resolve(process.info().path)).. "/modules"
if fs.exists(modulepath) == false then
  os.execute("mkdir modules")
  print("Downloading default modules...")
  os.execute("wget -f https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/server/2.%23.%23/modules/sectors.lua modules/sectors.lua")
  term.clear()
end

for file in fs.list(modulepath .. "/") do
  local result, reason = loadfile(modulepath .. "/" .. file)
  if result then
    local success, result = pcall(result)
    if success then
      table.insert(modules,result)
    end
  end
end

local settingTable = loadTable("settings.txt")
if settingTable == nil then
  settingTable = {["cryptKey"]={1,2,3,4,5},["pass"]=false}
  saveTable(settingTable,"settings.txt")
end

term.clear()
local doorTable = loadTable("doorlist.txt")
if doorTable == nil then
  doorTable = {}
end
print("Checking all doors saved in doorlist...")
if modem.isOpen(modemPort) == false then
  modem.open(modemPort)
end
local count = 1
local check = false
for _,value in pairs(doorTable) do
  if value["repeat"] ~= false then
    modem.send(value["repeat"],modemPort,"rebroadcast",ser.serialize({["uuid"]=value.id,["data"]="doorCheck"}))
  else
    modem.send(value.id,modemPort,"doorCheck")
  end
  local e, _, from, port, _, command, msg = event.pull(1,"modem_message")
  if e then

  else
    table.remove(doorTable,count)
    check = true
  end
  count = count + 1
end
if check then
  saveTable(doorTable,"doorlist.txt")
end


advWrite("Security server version: " .. version,0xFFFFFF,false,true,1,true)
advWrite(#modules .. " modules loaded",nil,false,true,2,true)
advWrite("---------------------------------------------------------------------------",0xFFFFFF,false,true,3,true)
advWrite("---------------------------------------------------------------------------",0xFFFFFF,false,true,#viewhistory + 4,true)


settingTable = loadTable("settings.txt")
local userTable = loadTable("userlist.txt")
local baseVariables = {"name","uuid","date","link","blocked","staff"}
if userTable == nil then
  userTable = {["settings"]={["var"]={"level"},["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false},["sectors"]={{["name"]="Placeholder Sector",["uuid"]=uuid.next(),["type"]=1,["pass"]={},["status"]=1}}}} --sets up setting var with one setting to start with.
  --New Sectors system will be linked to the userTable settings arrays. name = display name; uuid = linking id to get this pass; type = lockdown bypass type: 1 = open door anyway, 2 = disable lockdown; pass = pass uuids that link with type to disable lockdown or enter anyways; status = sector status: 1 = normal operations, 2 = lockdown, 3 = lock open
  saveTable(userTable,"userlist.txt")
end
if userTable.settings.sectors == nil then
  userTable.settings.sectors = {{["name"]="",["uuid"]=uuid.next(),["type"]=1,["pass"]={},["status"]=1}}
  saveTable(userTable,"userlist.txt")
end
if settingTable.pass == nil then
  settingTable.pass = false
  saveTable(settingTable,"settings.txt")
end

for _,value in pairs(modules) do
  addcommands(value.commands,value.skipcrypt)
  value.debug = debug
  value.init()
  value.setup(userTable, doorTable)
end

--------account functions

local function getPassID(command,rules)
  local bill
  if rules ~= nil then
    for i=1,#rules,1 do
      if rules[i].uuid == command then
        command = rules[i].call
        bill = i
        break
      end
    end
  end
  for i=1,#userTable.settings.calls,1 do
    if command == userTable.settings.calls[i] then
      return true, i, bill
    end
  end
  return command == "checkstaff" and true or false, command == "checkstaff" and 0 or false
end

local function getVar(var,user)
   for key, value in pairs(userTable) do
    if value.uuid == user then
      return value[var]
    end
  end
   return "Nil "..var
end

local function checkVar(rule,user,index)
  if index ~= 0 then
    if userTable.settings.type[index] == "string" or userTable.settings.type[index] == "-string" then
      return user[userTable.settings.var[index]] == rule.param
    elseif userTable.settings.type[index] == "int" or userTable.settings.type[index] == "-int" then
      if userTable.settings.above[index] == false or userTable.settings.type[index] == "-int" then
        return user[userTable.settings.var[index]] == rule.param
      else
        return user[userTable.settings.var[index]] >= rule.param
      end
    elseif userTable.settings.type[index] == "bool" then
      return user[userTable.settings.var[index]]
    end
  else
    return user.staff
  end
  return false
end
--return true, not value.blocked, value[var], value.staff
local function checkAdvVar(user,rules) --{["uuid"]=uuid.next()["call"]=t1,["param"]=t2,["request"]="supreme",["data"]=false}
  local label,color = "will be set",0x000000
  local foundOne = false
  for key, value in pairs(userTable) do
    if value.uuid == user then
      foundOne = true
      local skipBase = false
      for i=1,#rules,1 do
        if rules[i].request == "reject" then
          local e, call = getPassID(rules[i].call)
          if e then
            local good = checkVar(rules[i],value,call)
            if good then
              label,color = call ~= 0 and "Denied: var " .. userTable.settings.label[call] .. " is rejected" or "Denied: var staff" .. " is rejected", 0xFF0000
              skipBase = true
              break
            end
          end
        end
      end
      if skipBase == false then
        for i=1,#rules,1 do
          if rules[i].request == "base" then
            local e, call = getPassID(rules[i].call)
            if e then
              local good = checkVar(rules[i],value,call)
              if good then
                label,color = call ~= 0 and "Accepted by base var " .. userTable.settings.label[call] or "Accepted by base var" .. "staff", 0x00B600
                local isGood = true
                for j=1,#rules[i].data,1 do
                  local bill
                  e, call, bill = getPassID(rules[i].data[j],rules)
                  if e then
                    good = checkVar(rules[bill],value,call)
                    if good == false then
                      isGood = false
                      label,color = "Denied: did not meet base requirements", 0xFF0000
                      break
                    end
                  end
                end
                if isGood then
                  return true, not value.blocked, true, value.staff,label,color
                end
              end
            end
          end
        end
      end
      for i=1,#rules,1 do
        if rules[i].request == "supreme" then
          local e,call = getPassID(rules[i].call)
          if e then
            local good = checkVar(rules[i],value,call)
            if good then
              label,color = call ~= 0 and "Accepted by supreme var " .. userTable.settings.label[call] or "Accepted by supreme var " .. "staff", 0x00FF00
              return true, not value.blocked, true, value.staff,label,color
            end
          end
        end
      end
      if foundOne then
        if label == "will be set" then
          label,color = "Denied: does not have any required passes",0xFF0000
        end
        return true, not value.blocked, false, value.staff,label,color
      end
    end
  end
  return false
end

local function getDoorInfo(type,id,key)
  if type == "multi" then
    for i=1,#doorTable,1 do --doorTable[i] = {type="single or multi",id="computer's modem uuid",data={door's setting table}}
      if doorTable[i].id == id then
        if doorTable[i].data[key]~=nil then
          return {["read"]=doorTable[i].data[key].cardRead,["name"]=doorTable[i].data[key].name}
        end
      end
    end
  elseif type == "single" or type == "custom" then
    for i=1,#doorTable,1 do --doorTable[i] = {type="single or multi",id="computer's modem uuid",data={door's setting table}}
      if doorTable[i].id == id then
        return {["read"]=doorTable[i].data.cardRead,["name"]=doorTable[i].data.name}
      end
    end
  end
  return nil
end

local function checkLink(user)
  for key, value in pairs(userTable) do
    if value.link == user then
      return true, not value.blocked, value.name
    end
  end
  return false
end

local function msgToModule(command, data) --Sends message to modules and returns the data.
  for _,value in pairs(modules) do --p1 is true/false if program received command, p2 is data to send back to other device (nil if nothing is sent back), p3 is what to log on server (nil if nothing to log), p4 is color of logged text (nil if staying white or nothing to log), p5 is a change to userTable that must be saved & updated.
    local p1, p2, p3, p4, p5, p6, p7 = value.message(command,data)
    if p1 then
      return p1, p2, p3, p4, p5, p6, p7
    end
  end
  return false
end
redstone = {}
redstone["lock"] = false
redstone["forceopen"] = false
while true do
  if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
  end
  local bing,add = false, false
  local _, _, from, port, _, command, msg = event.pull("modem_message")
  add = from
  if command == "rebroadcast" then
    bing = true
    msg = ser.unserialize(msg)
    command = msg.command
    add = msg.uuid
    msg = msg.data
  end
  local data = msg
  local go = false
  for _,value in pairs(commands) do
    if command == value then
      go = true
      break
    end
  end
  if go then
    for _,value in pairs(skipcrypt) do
      if command == value then
        go = false
        break
      end
    end
    if go then data = crypt(msg, settingTable.cryptKey, true) end
    local thisUserName = false
    local bdcst = function(address,port,data,data2)
      if bing then
        modem.send(address,port,"rebroadcast",ser.serialize({["uuid"]=add,["data"]=data,["data2"]=data2}))
      else
        if address then
          modem.send(address,port,data,data2)
        else
          modem.broadcast(port,data,data2)
        end
      end
    end
    if command == "setvar" or command == "getvar" or command == "checkRules" then
      data = ser.unserialize(data)
      thisUserName = getVar("name",data.uuid)
    end
    if command == "updateuserlist" then
      userTable = ser.unserialize(data)
      local goboi = false
      if settingTable.pass == false then
        goboi = true
      end
      historyUpdate("Updated userlist received",0x0000C0,false,true)
      saveTable(userTable, "userlist.txt")
      for _,value in pairs(modules) do
        value.setup(userTable, doorTable)
      end
    elseif command == "autoInstallerQuery" then
      data = {}
      data.num = 2
      data.version = version
      data.data = userTable.settings
      bdcst(from,port,ser.serialize(data))
    elseif command == "setDoor" then
      historyUpdate("Received door parameters from id: " .. add,0xFFFF80,false,true)
      local tmpTable = ser.unserialize(data)
      tmpTable["id"] = add
      tmpTable["repeat"] = bing == true and from or false
      local isInAlready = false
      for i=1,#doorTable,1 do
        if doorTable[i].id == add then
          isInAlready = true
          doorTable[i] = tmpTable
          break
        end
      end
      if isInAlready == false then table.insert(doorTable,tmpTable) end
      saveTable(doorTable, "doorlist.txt")
      bdcst(from,port,crypt(ser.serialize(userTable.settings),settingTable.cryptKey))
      for _,value in pairs(modules) do
        value.setup(userTable, doorTable)
      end
    elseif command == "loginfo" then
      data = ser.unserialize(data) --Array of arrays. Each array has text and color (color optional)
      historyUpdate(data[1].text,data[1].color or 0xFFFFFF,false,true)
      for i=2,#data,1 do
        historyUpdate(data[i].text,data[i].color or 0xFFFFFF,false,false)
      end
    elseif command == "rcdoors" then --Cant send entire doorTable. Too big. Reduce to minimum required.
      local sendTable = {}
      for _,value in pairs(doorTable) do
        local datar
        if value.type == "multi" then
          datar = {}
          for key,pal in pairs(value.data) do
            datar[key] = {["name"]=pal.name}
          end
        else
          datar = {["name"]=value.data.name}
        end
        table.insert(sendTable,{["id"]=value.id,["type"]=value.type,["data"]=datar})
      end
      bdcst(from,port,ser.serialize(sendTable))
    elseif command == "checkLinked" then
      if false == true then
        gpu.setForeground(0xFF0000)
        term.write("DONT RUN or i b sad ;-;\n")
      else
        historyUpdate("-Checking if device is linked to a user:",0xFFFF80,false,true)
        local cu, isBlocked, thisName = checkLink(data)
        local dis = {}
        if cu == true then
          if isBlocked == false then
            dis["status"] = false
            dis["reason"] = 2
            data = crypt(ser.serialize(dis), settingTable.cryptKey)
            historyUpdate(" user " .. thisName .. "is blocked",0xFF0000,false,true)
            bdcst(from, port, data)
          else
            dis["status"] = true
            dis["name"] = thisName
            data = crypt(ser.serialize(dis), settingTable.cryptKey)
            historyUpdate(" tablet is connected to " .. thisName,0x00FF00,false,true)
            bdcst(from, port, data)
          end
        else
          dis["status"] = false
          dis["reason"] = 1
          data = crypt(ser.serialize(dis), settingTable.cryptKey)
          historyUpdate(" tablet not linked\n",0x990000,false,true)
          bdcst(from, port, data)
        end--IMPORTANT: Hello
      end
    elseif command == "getuserlist" then
      data = ser.serialize(userTable)
      data = crypt(data,settingTable.cryptKey)
      bdcst(from, port, data)
    elseif command == "getvar" then
      local worked = false
      for key, value in pairs(userTable) do
        if value.uuid == data.uuid then
          worked = true
          bdcst(from,port, crypt(value[data.var],settingTable.cryptKey))
        end
      end
    elseif command == "setvar" then
      local worked = false
      local counter = 1
      for key, value in pairs(userTable) do
        if value.uuid == data.uuid then
          worked = true
          userTable[counter][data.var] = data.data
          bdcst(from,port, crypt("true",settingTable.cryptKey))
        else
          counter = counter + 1
        end
      end
    elseif command == "checkRules" then
      local currentDoor = getDoorInfo(data.type,add,data.key)
      local enter = true
      if data.sector ~= false then
        local a,c,_,_,b = msgToModule("doorsector",ser.serialize(data))
        if a then
          if b ~= "true" and b ~= "openbypass" then
            enter = false
            if b == "false" then
              bdcst(from, port, crypt("false", settingTable.cryptKey))
              if c then
                historyUpdate(c[1].text,c[1].color or 0xFFFFFF,false,true)
                for i=2,#c,1 do
                  historyUpdate(c[i].text,c[i].color or 0xFFFFFF,false,c[i].line or false)
                end
              end
            elseif b == "lockbypass" then
              bdcst(from, port, crypt("bypass", settingTable.cryptKey))
              if c then
                historyUpdate(c[1].text,c[1].color or 0xFFFFFF,false,true)
                for i=2,#c,1 do
                  historyUpdate(c[i].text,c[i].color or 0xFFFFFF,false,c[i].line or false)
                end
              end
            end
          end
        end
      end
      if enter then
        historyUpdate("-Checking user " .. thisUserName .. "'s credentials on " .. currentDoor.name .. ":",0xFFFF80,true,true)
        local cu, isBlocked, varCheck, isStaff,label,color = checkAdvVar(data.uuid,currentDoor.read)
        if cu then
          if isBlocked then
            if varCheck then
              data = crypt("true", settingTable.cryptKey)
              historyUpdate(label, color,false,true)
              bdcst(from, port, data)
            else
              if isStaff then
                data = crypt("true", settingTable.cryptKey)
                historyUpdate("access granted due to staff",0xFF00FF,false,true)
                bdcst(from, port, data)
              else
                data = crypt("false", settingTable.cryptKey)
                historyUpdate(label,color,false,true)
                bdcst(from, port, data)
              end
            end
          else
            data = crypt("false", settingTable.cryptKey)
            historyUpdate("user is blocked",0xFF0000,false,true)
            bdcst(from, port, data)
          end
        else
          data = crypt("false", settingTable.cryptKey)
          historyUpdate("user not found",0x990000,false,true)
          bdcst(from, port, data)
        end
      end
    else
      local p1,p2,p3,p4,p5,p6,p7 = msgToModule(command,data)
      if p1 then
        if p4 ~= nil then
          if p4 == false then
            bdcst(nil,port,p5,p6)
          else
            bdcst(from, port, p5,p6)
          end
        end
        if p2 then --holdup
          historyUpdate(p2[1].text,p2[1].color or 0xFFFFFF,false,true)
          for i=2,#p2,1 do
            historyUpdate(p2[i].text,p2[i].color or 0xFFFFFF,false,p2[i].line or false)
          end
        end
        if p3 then
          saveTable(userTable,"backupuserlist.txt")
          userTable = p3
          saveTable(userTable, "userlist.txt")
          for _,value in pairs(modules) do
            value.setup(userTable, doorTable)
          end
        end
      end
    end
  end
   gpu.setForeground(0xFFFFFF)
end
