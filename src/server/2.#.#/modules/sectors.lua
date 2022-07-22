local userTable = {}
local doorTable = {}
local modemPort = 199

local component = require("component")
local modem = component.modem
local ser = require("serialization")

module = {}
module.name = "sectors"
module.commands = {"sectorupdate","doorsector","doorsecupdate"}
module.skipcrypt = {"sectorupdate"}
module.debug = false

function module.init() --Called when server is first started

end

function module.setup(setit ,doors) --Called when userlist is updated or server is first started
  userTable = setit
  doorTable = doors
  if module.debug then print("Received " .. #userTable.settings.sectors .. " Sectors\n") end
  return "getSectorList",ser.serialize(userTable.settings.sectors)
end

function module.message(command,datar) --Called when a command goes past all default commands and into modules.
  local data = ser.unserialize(datar)
  if command == "sectorupdate" then
    userTable.settings.sectors = data
    return true,"Sector data changed",nil,userTable,false,"checkSector",ser.serialize(data)
  elseif command == "doorsector" then
    for i=1,#userTable.settings.sectors,1 do
      if userTable.settings.sectors[i].uuid == data.sector then
        if userTable.settings.sectors[i].status == 1 then
          return true,nil,nil,nil, true,"true"
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
            return false, "Sector check failed: User Not Found\n"
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
              return true, "Cannot bypass open sectors", nil, nil, true,"false"
            end
            if userTable.settings.sectors[i].type == 1 then
              return true, nil,nil,nil,true,"openbypass"
            else
              return true, nil,nil,nil,true,"lockbypass"
            end
          else
            return true, "User " .. data.name .. " failed sector check\n",nil,nil,true,"false"
          end
        end
      end
    end
  elseif command == "doorsecupdate" then
    for i=1,#userTable.settings.sectors,1 do
      if userTable.settings.sectors[i].uuid == datar then
        userTable.settings.sectors[i].status = 1
        return true,"Sector Lockdown lifted",nil,userTable
      end
    end
  else

  end
  return false
end

return module