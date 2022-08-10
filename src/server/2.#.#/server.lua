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

local commands = {"setdevice","signIn","updateuserlist","loginfo","getuserlist"}
local skipcrypt = {"getuserlist","loginfo"}

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

--------Server Functions

local function msgToModule(type,command, data) --Sends message to modules and returns the data.
  if type == "message" then
    for _,value in pairs(modules) do --p1 is true/false if program received command, p2 is data to send back to other device (nil if nothing is sent back), p3 is what to log on server (nil if nothing to log), p4 is color of logged text (nil if staying white or nothing to log), p5 is a change to userTable that must be saved & updated.
      local p1, p2, p3, p4, p5, p6, p7 = value.message(command,data)
      if p1 then
        return p1, p2, p3, p4, p5, p6, p7
      end
    end
    return false
  else
    for _,value in pairs(modules) do --p1 is true/false if program received command, p2 is data to send back to other device (nil if nothing is sent back), p3 is what to log on server (nil if nothing to log), p4 is color of logged text (nil if staying white or nothing to log), p5 is a change to userTable that must be saved & updated.
      value.piggyback(command,data)
    end
  end
end

local bing,add,from,port
local function bdcst(address,port,data,data2)
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
local function modulebdcst(direct,data,data2)
  bdcst(direct and from or nil,modemPort,data,data2)
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

local logUsers = loadTable("users.txt")
if logUsers == nil then
  logUsers = {}
  saveTable(logUsers,"users.txt")
end
local settingTable = loadTable("settings.txt")
if settingTable == nil then
  settingTable = {["cryptKey"]={1,2,3,4,5},["pass"]=false}
  saveTable(settingTable,"settings.txt")
end

term.clear()
local doorTable = loadTable("devicelist.txt")
if doorTable == nil then
  doorTable = {}
end
print("Checking all devices saved in devicelist...")
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

advWrite("Servertine version: " .. version,0xFFFFFF,false,true,1,true)
advWrite(#modules .. " modules loaded",nil,false,true,2,true)
advWrite("---------------------------------------------------------------------------",0xFFFFFF,false,true,3,true)
advWrite("---------------------------------------------------------------------------",0xFFFFFF,false,true,#viewhistory + 4,true)

settingTable = loadTable("settings.txt")
local userTable = loadTable("userlist.txt")

if userTable == nil then
  userTable = {["settings"]={["var"]={"level"},["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false},["sectors"]={{["name"]="Placeholder Sector",["uuid"]=uuid.next(),["type"]=1,["pass"]={},["status"]=1}}}} --sets up setting var with one setting to start with.
  --New Sectors system will be linked to the userTable settings arrays. name = display name; uuid = linking id to get this pass; type = lockdown bypass type: 1 = open door anyway, 2 = disable lockdown; pass = pass uuids that link with type to disable lockdown or enter anyways; status = sector status: 1 = normal operations, 2 = lockdown, 3 = lock open
  saveTable(userTable,"userlist.txt")
else
  if userTable.refactored ~= true then
    if userTable.settings ~= nil then
      userTable.passSettings = userTable.settings
      userTable.settings = nil
    end
    if #userTable > 0 then
      userTable.passes = {}
      for i=1,#userTable,1 do
        table.insert(userTable.passes,userTable[1])
        table.remove(userTable,1)
      end
    end
    if userTable.passSettings.sectors ~= nil then
      userTable.sectors = userTable.passSettings.sectors
      userTable.passSettings.sectors = nil
    end
    userTable.refactored = true
  end
end
if settingTable.pass == nil then
  settingTable.pass = false
  saveTable(settingTable,"settings.txt")
end

local server = {["crypt"] = function(str,reverse) return crypt(str,settingTable.cryptKey,reverse) end,["copy"] = deepcopy,["send"]=modulebdcst}

for _,value in pairs(modules) do
  addcommands(value.commands,value.skipcrypt,value.table)
  value.debug = debug
  value.init(userTable, doorTable, server)
  value.setup()
  for keyed,valued in pairs(value.table) do
    if userTable[keyed] == nil then
      userTable[keyed] = deepcopy(valued)
    end
  end
end

server = nil

--------Main Loop & Program

while true do
  if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
  end

  bing,add = false, false
  local command, msg
  _, _, from, port, _, command, msg = event.pull("modem_message")
  add = from
  if command == "rebroadcast" then --Checking if message is from range extender
    bing = true
    msg = ser.unserialize(msg)
    command = msg.command
    add = msg.uuid
    msg = msg.data
  end

  local data = msg
  local go = false

  for _,value in pairs(commands) do --Checking if a correct command from module or base server
    if command == value then
      go = true
      break
    end
  end

  if go then
    for _,value in pairs(skipcrypt) do --Checking if the command's data is unencrypted or crypted.
      if command == value then
        go = false
        break
      end
    end

    if go then data = crypt(msg, settingTable.cryptKey, true) end

    if command == "updateuserlist" then
      for key,value in pairs(ser.unserialize(data)) do
        userTable[key] = value
      end
      local goboi = false
      if settingTable.pass == false then
        goboi = true
      end
      historyUpdate("Updated userlist received",0x0000C0,false,true)
      saveTable(userTable, "userlist.txt")
      for _,value in pairs(modules) do
        value.setup()
      end
    elseif command == "signIn" then
      data = ser.unserialize(data)
      if data.command == "signIn" then --TODO: Finish sign in stuff
        if crypt(logUsers[data.user].pass,settingTable.cryptKey,true) == data.pass then
          bdcst(from,port,crypt("true",settingTable.cryptKey),crypt(ser.serialize(logUsers[data.user].perm),settingTable.cryptKey))
        else
          bdcst(from,port,crypt("false",settingTable.cryptKey))
        end
      elseif data.command == "add" then
        logUsers[data.user] = data.data
      elseif data.command == "del" then
        logUsers[data.user] = nil
      elseif data.command == "grab" then
        local check = false
        for _,value in pairs(logUsers[data.user].perm) do
          if value == "all" or value == "dev.usermanagement" then
            check = true
            break
          end
        end
        if check then
          bdcst(from,port,crypt("true",settingTable.cryptKey),crypt(ser.serialize(logUsers),settingTable.cryptKey))
        else
          bdcst(from,port,crypt("false",settingTable.cryptKey))
        end
      end
    elseif command == "setdevice" then
      historyUpdate("Received device parameters from id: " .. add,0xFFFF80,false,true)
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
      saveTable(doorTable, "devicelist.txt")
      for _,value in pairs(modules) do
        value.setup()
      end
    elseif command == "loginfo" then
      data = ser.unserialize(data) --Array of arrays. Each array has text and color (color optional)
      historyUpdate(data[1].text,data[1].color or 0xFFFFFF,false,true)
      for i=2,#data,1 do
        historyUpdate(data[i].text,data[i].color or 0xFFFFFF,false,false)
      end
    elseif command == "getquery" then
      local wait = ser.unserialize(data)
      local docrypt = true
      data = {}
      if data ~= nil then
        for i=1,#wait,1 do
          if wait[i] ~= "&&&crypt" then
            data.data[wait[i]] = userTable[i]
          else
            docrypt = false
          end
        end
      end
      data.num = 2
      data.version = version
      data = ser.serialize(data)
      data = docrypt and crypt(data,settingTable.cryptKey) or data
      bdcst(from, port, data)
    else
      local p1,p2,p3,p4,p5,p6,p7 = msgToModule("message",command,data)
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
          saveTable(userTable, "userlist.txt")
          for _,value in pairs(modules) do
            value.setup()
          end
        end
      end
    end
    msgToModule("piggyback",command,data)
  end
   gpu.setForeground(0xFFFFFF)
end
