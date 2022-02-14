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

local version = "5.0"

local redstone = {}

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


term.clear()
print("Security server version: " .. version)
print("---------------------------------------------------------------------------")

local userTable = loadTable("userlist.txt")
local doorTable = loadTable("doorlist.txt")
if userTable == nil then
  userTable = {}
end
if doorTable == nil then
  doorTable = {}
end

function getUserName(user)
   for key, value in pairs(userTable) do
    if value.uuid == user then
      return value.name
    end
  end
   return "NilUser"
end

function checkUser(user)
  for key, value in pairs(userTable) do
    if value.uuid == user then
      return true, not value.blocked, tonumber(value.level), value.staff
    end
  end
  return false
end

function checkMtf(user)
  for key, value in pairs(userTable) do
    if value.uuid == user then
      return true, not value.blocked, value.mtf, value.staff
    end
  end
  return false
end

function checkGoi(user)
  for key, value in pairs(userTable) do
    if value.uuid == user then
      return true, not value.blocked, value.goi, value.staff
    end
  end
  return false
end

function checkSec(user)
  for key, value in pairs(userTable) do
    if value.uuid == user then
      return true, not value.blocked, value.sec, value.staff
    end
  end
  return false
end

function checkUserA(user)
  for key, value in pairs(userTable) do
    if value.uuid == user then
      return true, not value.blocked, tonumber(value.armory), value.staff
    end
  end
  return false
end

function checkUserD(user)
  for key, value in pairs(userTable) do
    if value.uuid == user then
      return true, not value.blocked, tonumber(value.department), value.staff
    end
  end
  return false
end

function checkLevel(id)
  for key, value in pairs(doorTable) do
    if key == id then
      return tonumber(value)
    end
  end
  return 0
end

function checkInt(user)
  for key, value in pairs(userTable) do
    if value.uuid == user then
      return true, not value.blocked, value.int, value.staff
    end
  end
  return false
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
  if command == "updatedoors" then
  	
  else
    data = crypt(msg, cryptKey, true)
  end
  local thisUserName = getUserName(data)
  if command == "updatedoors" then
     os.execute("wget -f https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/src/doorcontrols/singleDoor.lua ctrl.lua")
     local filetemp = ios.open("/mnt/b93/ctrl.lua","r")
     local file = filetemp:read("*a")
     data = crypt(tostring(file),cryptKey)
     modem.broadcast(198, "update", data)
     os.execute("wget -f https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/src/doorcontrols/multiDoor.lua ctrlE.lua")
     filetemp = ios.open("/mnt/b93/ctrlE.lua","r")
     file = filetemp:read("*a")
     data = crypt(tostring(file),cryptKey)
     modem.broadcast(197, "update", data)
     term.write("Updating door command received\n")
  elseif command == "updateuser" then
    userTable = ser.unserialize(data)
    term.write("Updated userlist received\n")
    saveTable(userTable, "userlist.txt")
  elseif command == "setlevel" then
    term.write("Received level from door: " .. data .. "\n")
    doorTable[from] = data
    saveTable(doorTable, "doorlist.txt")
  elseif command == "redstoneUpdated" then
        term.write("Redstone has been updated")
        local newRed = ser.unserialize(data)
        if newRed["lock"] ~= redstone["lock"] then
            lockDoors = newRed["lock"]
        else
            
        end
        if newRed["forceopen"] ~= redstone["forceopen"] then
            forceopen = newRed["forceopen"]
            if forceopen == true then
                data = crypt("open",cryptKey)
                modem.broadcast(198,"forceopen",data)
                modem.broadcast(197,"forceopen",data)
            else
                data = crypt("close",cryptKey)
                modem.broadcast(198,"forceopen",data)
                modem.broadcast(197,"forceopen",data)
            end
        else
            
        end
        redstone = newRed
  elseif command == "checkuser" then
    if lockDoors == true and bypassLock ~= 1 then
    	term.write("Doors have been locked. Unable to open door\n")
        data = crypt("locked", cryptKey)
        modem.send(from, port, data)
    else
    term.write("Checking " .. thisUserName .. "'s access level:")
    local cu, isBlocked, level, isStaff = checkUser(data)
    if cu == true then			-- user found
    	if isBlocked == false then
			data = crypt("false", cryptKey)
			term.write(" user is blocked\n")
			modem.send(from, port, data)
      	else
			local cl = checkLevel(from)
			if cl > level then
                if isStaff == true then
                    data = crypt("true", cryptKey)
	  				term.write(" access granted due to staff\n")
	  				modem.send(from, port, data)        
                else
                	data = crypt("false", cryptKey)
	  				term.write(" user level is too low\n")
	  				modem.send(from, port, data)            
                end
			else
	  			data = crypt("true", cryptKey)
	  			term.write(" access granted\n")
	  			modem.send(from, port, data)
			end
      	end
    else
      data = crypt("false", cryptKey)
      term.write(" user not found\n")
      modem.send(from, port, data)
    end
    end
    elseif command == "checkMtf" then
        if lockDoors == true and bypassLock ~= 1 then
    	term.write("Doors have been locked. Unable to open door\n")
        data = crypt("locked", cryptKey)
        modem.send(from, port, data)
    else
        term.write("Checking if user " .. thisUserName .. " is MTF:")
        local cu, isBlocked, isMtf, isStaff = checkMtf(data)
        if cu == true then
            if isBlocked == false then
	        data = crypt("false", cryptKey)
	        term.write(" user is blocked\n")
	        modem.send(from, port, data)
            else
            if isMtf == true then
            data = crypt("true", cryptKey)
			term.write(" access granted\n")
			modem.send(from, port, data)
            else
                if isStaff == true then
                    data = crypt("true", cryptKey)
	  				term.write(" access granted due to staff\n")
	  				modem.send(from, port, data)        
                else
                	data = crypt("false", cryptKey)
					term.write(" access denied\n")
					modem.send(from, port, data)           
                end
         end
         end
                else
      			data = crypt("false", cryptKey)
      			term.write(" user not found\n")
      			modem.send(from, port, data)
         end
      end  
        elseif command == "checkgoi" then
        if lockDoors == true and bypassLock ~= 1 then
    	term.write("Doors have been locked. Unable to open door\n")
        data = crypt("locked", cryptKey)
        modem.send(from, port, data)
    	else
        term.write("Checking if user " .. thisUserName .. " is GOI:")
        local cu, isBlocked, isGoi, isStaff = checkGoi(data)
        if cu == true then
            if isBlocked == false then
	        data = crypt("false", cryptKey)
	        term.write(" user is blocked\n")
	        modem.send(from, port, data)
            else
            if isGoi == true then
            data = crypt("true", cryptKey)
			term.write(" access granted\n")
			modem.send(from, port, data)
            else
            if isStaff == true then
                    data = crypt("true", cryptKey)
	  				term.write(" access granted due to staff\n")
	  				modem.send(from, port, data)        
                else
                	data = crypt("false", cryptKey)
					term.write(" access denied\n")
					modem.send(from, port, data)           
                end
         end
         end
                else
      			data = crypt("false", cryptKey)
      			term.write(" user not found\n")
      			modem.send(from, port, data)
         end
      end  
    elseif command == "checksec" then
        if lockDoors == true and bypassLock ~= 1 then
    		term.write("Doors have been locked. Unable to open door\n")
        	data = crypt("locked", cryptKey)
        	modem.send(from, port, data)
    	else
            term.write("Checking if user " .. thisUserName .. " has Security pass:")
        	local cu, isBlocked, isSec, isStaff = checkSec(data)
        	if cu == true then
            	if isBlocked == false then
	        		data = crypt("false", cryptKey)
	        		term.write(" user is blocked\n")
	        		modem.send(from, port, data)
            	else
            		if isSec == true then
            			data = crypt("true", cryptKey)
						term.write(" access granted\n")
						modem.send(from, port, data)
            		else
            			if isStaff == true then
                    data = crypt("true", cryptKey)
	  				term.write(" access granted due to staff\n")
	  				modem.send(from, port, data)        
                else
                	data = crypt("false", cryptKey)
					term.write(" access denied\n")
					modem.send(from, port, data)           
                end
         			end
            	end
         	else
      			data = crypt("false", cryptKey)
      			term.write(" user not found\n")
      			modem.send(from, port, data)
        	end
    	end  
    elseif command == "checkarmor" then
        if lockDoors == true and bypassLock ~= 1 then
    	term.write("Doors have been locked. Unable to open door\n")
        data = crypt("locked", cryptKey)
        modem.send(from, port, data)
    else
    term.write("Checking " .. thisUserName .. "'s armory level:")
    local cu, isBlocked, level, isStaff = checkUserA(data)
    if cu == true then			-- user found
      if isBlocked == false then
	data = crypt("false", cryptKey)
	term.write(" user is blocked\n")
	modem.send(from, port, data)
      else
	local cl = checkLevel(from)
	if cl > level then
				if isStaff == true then
                    data = crypt("true", cryptKey)
	  				term.write(" access granted due to staff\n")
	  				modem.send(from, port, data)        
                else
                	data = crypt("false", cryptKey)
	  				term.write(" users level too low\n")
	  				modem.send(from, port, data)         
                end
	else
	  data = crypt("true", cryptKey)
	  term.write(" access granted\n")
	  modem.send(from, port, data)
	end
      end
    else
      data = crypt("false", cryptKey)
      term.write(" user not found\n")
      modem.send(from, port, data)
    end
    end
    elseif command == "checkdepartment" then
        if lockDoors == true and bypassLock ~= 1 then
    	term.write("Doors have been locked. Unable to open door\n")
        data = crypt("locked", cryptKey)
        modem.send(from, port, data)
    else
    term.write("Checking " .. thisUserName .. "'s department:")
    local cu, isBlocked, level, isStaff = checkUserD(data)
    if cu == true then			-- user found
      if isBlocked == false then
	data = crypt("false", cryptKey)
	term.write(" user is blocked\n")
	modem.send(from, port, data)
      else
	local cl = checkLevel(from)
	if cl ~= level and level ~= 5 then
      if isStaff == true then
                    data = crypt("true", cryptKey)
	  				term.write(" access granted due to staff\n")
	  				modem.send(from, port, data)        
                else
                	data = crypt("false", cryptKey)
	  				term.write(" incorrect department\n")
	  				modem.send(from, port, data)    
                end
	else
	  data = crypt("true", cryptKey)
      if cl == 5 then
	  	term.write(" O5 clearance granted\n")
	  	modem.send(from, port, data)
      else
        term.write(" access granted\n")
	  	modem.send(from, port, data)                
      end
	end
      end
    else
      data = crypt("false", cryptKey)
      term.write(" user not found\n")
      modem.send(from, port, data)
    end
   end
       elseif command == "checkint" then
        if false == true and bypassLock ~= 1 then
    	term.write("Doors have been locked. Unable to open door\n")
    	else
        term.write("Checking if user " .. thisUserName .. " has Intercom pass:")
        local cu, isBlocked, isInt, isStaff = checkInt(data)
        if cu == true then
            if isBlocked == false then
	        data = crypt("false", cryptKey)
	        term.write(" user is blocked\n")
	        modem.send(from, port, data)
            else
            if isInt == true then
            data = crypt("true", cryptKey)
			term.write(" access granted\n")
			modem.send(from, port, data)
            else
                if isStaff == true then
                    data = crypt("true", cryptKey)
	  				term.write(" access granted due to staff\n")
	  				modem.send(from, port, data)        
                else
                	data = crypt("false", cryptKey)
					term.write(" access denied\n")
					modem.send(from, port, data)
                end
         end
         end
                else
      			data = crypt("false", cryptKey)
      			term.write(" user not found\n")
      			modem.send(from, port, data)
         end
      end  
      elseif command == "checkstaff" then
        if false == true then
    	term.write("WHY DOES THIS RUN??? IM SAD :(\n")
        data = crypt("locked", cryptKey)
        modem.send(from, port, data)
    	else
        term.write("Checking if user " .. thisUserName .. " is Staff:")
        local cu, isBlocked, isStaff = checkStaff(data)
        if cu == true then
            if isBlocked == false then
	        data = crypt("false", cryptKey)
	        term.write(" user is blocked\n")
	        modem.send(from, port, data)
            else
                if isStaff == true then
                    data = crypt("true", cryptKey)
	  				term.write(" access granted\n")
	  				modem.send(from, port, data)        
                else
                	data = crypt("false", cryptKey)
					term.write(" access denied\n")
					modem.send(from, port, data)
                end
         end
                else
      			data = crypt("false", cryptKey)
      			term.write(" user not found\n")
      			modem.send(from, port, data)
         end
      end  
	elseif command == "checkLinked" then
        if false == true then
    	term.write("DONT RUN or i b sad ;-;\n")
    	else
        term.write("Checking test tablet is linked to a user:")
        local cu, isBlocked, thisName = checkLink(data)
        local dis = {}
        if cu == true then
            if isBlocked == false then
            dis["status"] = false
            dis["reason"] = 2
	        data = crypt(ser.serialize(dis), cryptKey)
	        term.write(" user " .. thisName .. "is blocked\n")
	        modem.send(from, port, data)
            else
            dis["status"] = true
            dis["name"] = thisName
            data = crypt(ser.serialize(dis), cryptKey)
			term.write(" tablet is connected to " .. thisName .. "\n")
			modem.send(from, port, data)
         end
                else
                dis["status"] = false
                dis["reason"] = 1
      			data = crypt(ser.serialize(dis), cryptKey)
      			term.write(" tablet not linked\n")
      			modem.send(from, port, data)
         end
      end
   end
end