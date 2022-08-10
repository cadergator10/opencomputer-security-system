local userTable = {}
local doorTable = {}
local server = {}
local modemPort = 199

local component = require("component")
local modem = component.modem
local ser = require("serialization")
local uuid = require("uuid")

module = {}
module.name = "sectors"
module.commands = {"sectorupdate","doorsector","doorsecupdate"}
module.skipcrypt = {"sectorupdate"}
module.table = {["sectors"] = {{["name"]="Placeholder Sector",["uuid"]=uuid.next(),["type"]=1,["pass"]={},["status"]=1}}}
module.debug = false

function module.init(setit ,doors, serverCommands) --Called when server is first started. Passes userTable and doorTable.
  userTable = setit
  doorTable = doors
  server = serverCommands
  if module.debug then print("Received " .. #userTable.settings.sectors .. " Sectors\n") end
  return "getSectorList",ser.serialize(userTable.settings.sectors)
end

function module.setup() --Called when userlist is updated or server is first started
  if module.debug then print("Received " .. #userTable.settings.sectors .. " Sectors\n") end
  return "getSectorList",ser.serialize(userTable.settings.sectors)
end

function module.message(command,datar) --Called when a command goes past all default commands and into modules.
  local data = ser.unserialize(datar)
  if command == "sectorupdate" then
    userTable.settings.sectors = data
    return true,{{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]="Sector data changed",["color"]=nil,["line"]=false}},true,false,"checkSector",ser.serialize(data)
  elseif command == "doorsector" then
    for i=1,#userTable.settings.sectors,1 do
      if userTable.settings.sectors[i].uuid == data.sector then
        if userTable.settings.sectors[i].status == 1 then
          return true,nil,false,true,"true"
        else
          local passed = false
          local user = false
          for j=1,#userTable,1 do
            if userTable[j].uuid == data.uuid then
              user = j
              break
            end
          end
          if user == false then
            return false, {{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]="Sector check failed: User Not Found",["color"]=nil,["line"]=false}}
          end
          for _,value in pairs(userTable.settings.sectors[i].pass) do
            for j=1,#userTable.settings.calls,1 do
              if userTable.settings.calls[j] == value.uuid then
                local check = function(rule)
                  if userTable.settings.type[j] == "string" or userTable.settings.type[j] == "-string" then
                    return userTable[user][userTable.settings.var[j]] == rule
                  elseif userTable.settings.type[j] == "int" or userTable.settings.type[j] == "-int" then
                    if userTable.settings.above[j] == false or userTable.settings.type[j] == "-int" then
                      return userTable[user][userTable.settings.var[j]] == tonumber(rule)
                    else
                      return userTable[user][userTable.settings.var[j]] >= tonumber(rule)
                    end
                  elseif userTable.settings.type[j] == "bool" then
                    return userTable[user][userTable.settings.var[j]]
                  end
                end
                passed = check(value.data)
                break
              end
            end
            if passed then
              break
            end
          end
          if passed then
            if userTable.settings.sectors[i].status == 3 and userTable.settings.sectors[i].type == 1 then
              return true, {{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]="Cannot bypass open sector " .. userTable.settings.sectors[i].name,["color"]=nil,["line"]=false}},false, true,"false"
            end
            if userTable.settings.sectors[i].type == 1 then
              return true,nil,nil,true,"openbypass"
            else
              return true, {{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]="User " .. data.name .. " requested a bypass of " .. userTable.settings.sectors[i].name,["color"]=0xFF0000,["line"]=false}},false,true,"lockbypass"
            end
          else
            return true, {{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]="User " .. data.name .. " failed sector check of " .. userTable.settings.sectors[i].name,["color"]=nil,["line"]=false}},false,true,"false"
          end
        end
      end
    end
  elseif command == "doorsecupdate" then
    for i=1,#userTable.settings.sectors,1 do
      if userTable.settings.sectors[i].uuid == datar then
        userTable.settings.sectors[i].status = 1
        return true,{{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]="Sector Lockdown lifted of " .. userTable.settings.sectors[i].name,["color"]=nil,["line"]=false}},true,"checkSector",ser.serialize(userTable.settings.sectors)
      end
    end
  else

  end
  return false
end

function module.piggyback(command,data) --Called after a command is passed. Passed to all modules which return nothing.

end

return module