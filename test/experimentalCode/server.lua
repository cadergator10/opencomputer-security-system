local cryptKey = {1, 2, 3, 4, 5}
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

local version = "2.1.0"

local redstone = {}

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
function saveTable(  tbl,filename )
	local tableFile = assert(io.open(filename, "w"))
  tableFile:write(ser.serialize(tbl))
  tableFile:close()
end
 
--// The Load Function
function loadTable( sfile )
	local tableFile = io.open(sfile)
    if tableFile ~= nil then
  		return ser.unserialize(tableFile:read("*all"))
    else
        return nil
    end
end

function advWrite(text,color,wrap)
  gpu.setForeground(color or gpu.getForeground())
  term.write(text,wrap or true)
end
--------Getting tables and setting up terminal

term.clear()
local serverSettings = loadTable("serversettings.txt")
if serverSettings == nil then
  print("Security server requires settings to be set")
  print("...")
  print("Nothing is to be set yet as there is no settings currently.")
  --TODO: add some settings
  serverSettings = {}
  saveTable(serverSettings,"serversettings.txt")
end

term.clear()
advWrite("Security server version: " .. version .. "\n",0xFFFFFF)
advWrite("---------------------------------------------------------------------------\n")

local serverSettings = loadTable("serversettings.txt")
local userTable = loadTable("userlist.txt")
local doorTable = loadTable("doorlist.txt")
local baseVariables = {"name","uuid","date","link","blocked","staff"}
if userTable == nil then
  userTable = {["settings"]={["var"]="level",["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false}}} --sets up setting var with one setting to start with.
end
if doorTable == nil then
  doorTable = {}
end

--------account functions

function getVar(var,user)
   for key, value in pairs(userTable) do
    if value.uuid == user then
      return value[var]
    end
  end
   return "Nil "..var
end

function checkVar(var,user)
  for key, value in pairs(userTable) do
    if value.uuid == user then
      return true, not value.blocked, value[var], value.staff
    end
  end
  return false
end

function getDoorInfo(type,id,key)
  if type == "multi" then
    for i=1,#doorTable,1 do --doorTable[i] = {type="single or multi",id="computer's modem uuid",data={door's setting table}}
      if doorTable[i].id == id then
        if doorTable[i].data[key]~=nil then
          return {["read"]=doorTable[i].data[key].cardRead,["level"]=doorTable[i].data[key].accessLevel}
        end
      end
    end
  else
    for i=1,#doorTable,1 do --doorTable[i] = {type="single or multi",id="computer's modem uuid",data={door's setting table}}
      if doorTable[i].id == id then
        return {["read"]=doorTable[i].data.cardRead,["level"]=doorTable[i].data.accessLevel}
      end
    end
  end
  return nil
end

function checkStaff(user)
  for key, value in pairs(userTable) do
    if value.uuid == user then
      return true, not value.blocked, value.staff
    end
  end
  return false
end

function checkLink(user)
  for key, value in pairs(userTable) do
    if value.link == user then
      return true, not value.blocked, value.name
    end
  end
  return false
end

  if modem.isOpen(198) == false then
    modem.open(198)
  end
  if modem.isOpen(197) == false then
    modem.open(197)
  end
redstone = {}
redstone["lock"] = false
redstone["forceopen"] = false
while true do
  if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
  end

  local _, _, from, port, _, command, msg, bypassLock = event.pull("modem_message")
  local data = msg
  data = crypt(msg, cryptKey, true)
  local thisUserName = false
  if command ~= "updateuserlist" and command ~= "setDoor" and command ~= "redstoneUpdated" and command ~= "checkLinked" then
    data = ser.unserialize(data)
    thisUserName = getVar("name",data.uuid)
  end
  if command == "updateuserlist" then
    userTable = ser.unserialize(data)
    advWrite("Updated userlist received\n",0x0000C0)
    saveTable(userTable, "userlist.txt")
  elseif command == "setDoor" then
    advWrite("Received door parameters from id: " .. from .. "\n",0xFFFF80)
    local tmpTable = ser.unserialize(data)
    tmpTable["id"] = from
    local isInAlready = false
    for i=1,#doorTable,1 do
      if doorTable[i].id == from then
        isInAlready = true
        doorTable[i] = tmpTable
        break
      end
    end
    if isInAlready == false then table.insert(doorTable,tmpTable) end
    saveTable(doorTable, "doorlist.txt")
    modem.send(from,port,crypt(ser.serialize(UserTable.settings),cryptKey))
  elseif command == "remoteControl" then
    advWrite("Coming soon?\n",0xFF0000) --TODO: allow remote control pc sometime in future
  elseif command == "redstoneUpdated" then
        advWrite("Redstone has been updated\n",0x0000C0)
        local newRed = ser.unserialize(data)
        if newRed["lock"] ~= redstone["lock"] then
            lockDoors = newRed["lock"]
        end
        if newRed["forceopen"] ~= redstone["forceopen"] then
            forceopen = newRed["forceopen"]
            if forceopen == true then
                data = crypt("open",cryptKey)
                modem.broadcast(199,"forceopen",data)
            else
                data = crypt("close",cryptKey)
                modem.broadcast(199,"forceopen",data)
            end
        end
        redstone = newRed   
      elseif command == "checkstaff" then
        if false == true then
          advWrite("WHY DOES THIS RUN??? IM SAD :(\n",0xFF0000)
          data = crypt("locked", cryptKey)
          modem.send(from, port, data)
    	  else
          advWrite("Checking if user " .. thisUserName .. " is Staff:",0xFFFF80)
          local cu, isBlocked, isStaff = checkStaff(data.uuid)
          if cu == true then
            if isBlocked == false then
              data = crypt("false", cryptKey)
              advWrite(" user is blocked\n",0xFF0000)
              modem.send(from, port, data)
            else
              if isStaff == true then
                data = crypt("true", cryptKey)
                advWrite(" access granted\n",0x00FF00)
                modem.send(from, port, data)        
              else
                data = crypt("false", cryptKey)
                advWrite(" access denied\n",0xFF0000)
                modem.send(from, port, data)
              end
            end
          else
      			data = crypt("false", cryptKey)
            advWrite(" user not found\n",0x990000)
      			modem.send(from, port, data)
          end
        end  
	    elseif command == "checkLinked" then
        if false == true then
          gpu.setForeground(0xFF0000)
    	    term.write("DONT RUN or i b sad ;-;\n")
    	  else
          advWrite(" Checking if device is linked to a user:\n",0xFFFF80)
          local cu, isBlocked, thisName = checkLink(data)
          local dis = {}
          if cu == true then
            if isBlocked == false then
              dis["status"] = false
              dis["reason"] = 2
  	          data = crypt(ser.serialize(dis), cryptKey)
              advWrite(" user " .. thisName .. "is blocked\n",0xFF0000)
	            modem.send(from, port, data)
            else
              dis["status"] = true
              dis["name"] = thisName
              data = crypt(ser.serialize(dis), cryptKey)
              advWrite(" tablet is connected to " .. thisName .. "\n",0x00FF00)
			        modem.send(from, port, data)
            end
          else
            dis["status"] = false
            dis["reason"] = 1
      			data = crypt(ser.serialize(dis), cryptKey)
            advWrite(" tablet not linked\n",0x990000)
      			modem.send(from, port, data)
          end
        end
      else
        local bool isRealCommand = false --TODO: verify this all functions maybe please??????
        for i=1,#userTable.settings.calls,1 do
          if command == userTable.settings.calls[i] then
            if lockDoors == true and bypassLock ~= 1 then
              advWrite("Doors have been locked. Unable to open door\n",0xFF0000)
              data = crypt("locked", cryptKey)
              modem.send(from, port, data)
            else
            advWrite("Checking if user " .. thisUserName,0xFFFF80)
            isRealCommand = true
            local cu, isBlocked, varCheck, isStaff checkVar(userTable.settings.var[i],data.uuid)
            if cu == true then
              if isBlocked == false then
                data = crypt("false", cryptKey)
                advWrite(" user is blocked\n",0xFF0000)
                modem.send(from, port, data)
              else
                if userTable.settings.type[i] == "string" or userTable.settings.type[i] == "-string" then
                  local currentDoor = getDoorInfo(data.type,from,data.key)
                  if currentDoor ~= nil then
                    term.write(" is exactly " .. currentDoor.level .. " in var " .. userTable.settings.var[i] .. " :")
                    if currentDoor.level ~= varCheck then
                      if isStaff == true then
                        data = crypt("true", cryptKey)
                        advWrite(" access granted due to staff\n",0xFF00FF)
                        modem.send(from, port, data)  
                      else
                        data = crypt("false", cryptKey)
                        advWrite(" incorrect entry\n",0xFF0000)
                        modem.send(from, port, data)   
                      end
                    else
                      data = crypt("true", cryptKey)
                      advWrite(" access granted\n",0x00FF00)
                      modem.send(from, port, data)
                    end
                  else
                    advWrite(" error getting door\n",0xFF0000)
                  end 
                elseif userTable.settings.type[i] == "int" then
                  local currentDoor = getDoorInfo(data.type,from,data.key)
                  if currentDoor ~= nil then
                    if userTable.settings.above[i] then
                      term.write(" is above " .. tostring(currentDoor.level) .. " in var " .. userTable.settings.var[i] .. " :")
                      if currentDoor.level > varCheck then
                        if isStaff == true then
                          data = crypt("true", cryptKey)
                          advWrite(" access granted due to staff\n",0xFF00FF)
                          modem.send(from, port, data)  
                        else
                          data = crypt("false", cryptKey)
                          advWrite(" level is too low\n",0xFF0000)
                          modem.send(from, port, data)   
                        end
                      else --TODO: check if this functions later after thing is written. It should be complete.
                        data = crypt("true", cryptKey)
                        advWrite(" access granted\n",0x00FF00)
                        modem.send(from, port, data)
                      end
                    else
                      term.write(" is exactly " .. tostring(currentDoor.level) .. " in var " .. userTable.settings.var[i] .. " :")
                      if currentDoor.level ~= varCheck then
                        if isStaff == true then
                          data = crypt("true", cryptKey)
                          advWrite(" access granted due to staff\n",0xFF00FF)
                          modem.send(from, port, data)  
                        else
                          data = crypt("false", cryptKey)
                          advWrite(" level is incorrect\n",0xFF0000)
                          modem.send(from, port, data)   
                        end
                      else
                        data = crypt("true", cryptKey)
                        advWrite(" access granted\n",0x00FF00)
                        modem.send(from, port, data)
                      end
                    end
                  else
                    advWrite(" error getting door\n",0xFF0000)
                  end
                elseif userTable.settings.type[i] == "-int" then
                  local currentDoor = getDoorInfo(data.type,from,data.key)
                  if currentDoor ~= nil then
                    term.write(" is in group " .. userTable.settings.data[currentDoor.level] .. " in var " .. userTable.settings.var[i] .. " :")
                    if currentDoor.level ~= varCheck then
                      if isStaff == true then
                        data = crypt("true", cryptKey)
                        advWrite(" access granted due to staff\n",0xFF00FF)
                        modem.send(from, port, data)  
                      else
                        data = crypt("false", cryptKey)
                        advWrite(" incorrect group\n",0xFF0000)
                        modem.send(from, port, data)   
                      end
                    else
                      data = crypt("true", cryptKey)
                      advWrite(" access granted\n",0x00FF00)
                      modem.send(from, port, data)
                    end
                  else
                    advWrite(" error getting door\n",0xFF0000)
                  end
                elseif userTable.settings.type[i] == "bool" then
                  term.write(" is " .. userTable.settings.var[i] .. " :")
                  if varCheck == true then
                    data = crypt("true", cryptKey)
                    advWrite(" access granted\n",0x00FF00)
                    modem.send(from, port, data)
                  else
                    if isStaff == true then
                      data = crypt("true", cryptKey)
                      advWrite(" access granted due to staff\n",0xFF00FF)
                      modem.send(from, port, data)  
                    else
                      data = crypt("false", cryptKey)
                      advWrite(" access denied\n",0xFF0000)
                      modem.send(from, port, data)   
                    end
                  end
                end
              end
            else
              data = crypt("false", cryptKey)
              advWrite(" user not found\n",0x990000)
              modem.send(from, port, data)
            end
          end
        end
      end
      if isRealCommand == false then
        advWrite("Not a real command: " .. command .. "\n",0xFF0000)
      else

      end
   end
   gpu.setForeground(0xFFFFFF)
end