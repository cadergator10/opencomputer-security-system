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
module.table = {["sectors"] = {{["name"]="Placeholder Sector",["uuid"]=uuid.next(),["type"]=1,["pass"]={}}}}
module.table.sectorStatus = {[module.table.sectors[1].uuid]=1}
module.debug = false
module.version = "3.0.1"
module.id = 1112

function module.init(setit ,doors, serverCommands) --Called when server is first started. Passes userTable and doorTable.
  userTable = setit
  doorTable = doors
  server = serverCommands
  if module.debug then server.print("Received " .. #userTable.sectors .. " Sectors\n") end
end

function module.setup() --Called when userlist is updated or server is first started
  if module.debug then server.print("Received " .. #userTable.sectors .. " Sectors\n") end
  for key,_ in pairs(userTable.sectorStatus) do
    local good = false
    for i=1,#userTable.sectors,1 do
      if userTable.sectors[i].uuid == key then
        good = true
        break
      end
    end
    if good == false then
      userTable.sectorStatus[key] = nil
    end
  end
  for i=1,#userTable.sectors,1 do
    if userTable.sectorStatus[userTable.sectors[i].uuid] == nil then
      userTable.sectorStatus[userTable.sectors[i].uuid] = 1
    end
  end
  server.send(false,"getSectorList",ser.serialize({["sectors"]=userTable.sectors,["sectorStatus"]=userTable.sectorStatus}))
end

function module.message(command,datar) --Called when a command goes past all default commands and into modules.
  local data
  if datar ~= nil then
    data = ser.unserialize(datar)
  end
  if command == "sectorupdate" then
    userTable.sectorStatus = data
    return true,{{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]="Sector data changed",["color"]=nil,["line"]=false}},true,false,"checkSector",ser.serialize(data)
  elseif command == "doorsector" then
    for i=1,#userTable.sectors,1 do
      if userTable.sectors[i].uuid == data.sector then
        if userTable.sectorStatus[userTable.sectors[i].uuid] == 1 then
          return true,nil,false,true,"true"
        else
          local passed = false
          local user = false
          for j=1,#userTable.passes,1 do
            if userTable.passes[j].uuid == data.uuid then
              user = j
              break
            end
          end
          if user == false then
            return false, {{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]="Sector check failed: User Not Found",["color"]=nil,["line"]=false}}
          end
          local printText = "User " .. data.name .. " failed sector check of " .. userTable.sectors[i].name
          for p=1,5,1 do
            for _,value in pairs(userTable.sectors[i].pass) do
              if value.priority == p then
                if value.uuid ~= "checkstaff" then
                  for j=1,#userTable.passSettings.calls,1 do
                    if userTable.passSettings.calls[j] == value.uuid then
                      local check = function(rule)
                        if userTable.passSettings.type[j] == "string" then
                          return userTable.passes[user][userTable.passSettings.var[j]] == rule
                        elseif userTable.passSettings.type[j] == "-string" then
                          for z=1,#userTable.passes[user][userTable.passSettings.var[j]],1 do
                            if userTable.passes[user][userTable.passSettings.var[j]][z] == rule then
                              return true
                            end
                          end
                          return false
                        elseif userTable.passSettings.type[j] == "int" or userTable.passSettings.type[j] == "-int" then
                          if userTable.passSettings.above[j] == false or userTable.passSettings.type[j] == "-int" then
                            return userTable.passes[user][userTable.passSettings.var[j]] == tonumber(rule)
                          else
                            return userTable.passes[user][userTable.passSettings.var[j]] >= tonumber(rule)
                          end
                        elseif userTable.passSettings.type[j] == "bool" then
                          return userTable.passes[user][userTable.passSettings.var[j]]
                        end
                      end
                      passed = check(value.data)
                      break
                    end
                  end
                else
                  if userTable.passes[user].staff then
                    passed = true
                  end
                end
                if passed then
                  if userTable.sectorStatus[userTable.sectors[i].uuid] == 3 and value.lock == 1 then
                    printText = "Cannot bypass open sector " .. userTable.sectors[i].name
                  end
                  if value.lock == 1 then
                    return true,nil,nil,true,"openbypass"
                  else
                    return true, {{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]="User " .. data.name .. " requested a bypass of " .. userTable.sectors[i].name,["color"]=0xFF0000,["line"]=false}},false,true,"lockbypass"
                  end
                end
              end
            end
          end
          return true, {{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]=printText,["color"]=nil,["line"]=false}},false,true,"false"
        end
      end
    end
  elseif command == "doorsecupdate" then
    for i=1,#userTable.sectors,1 do
      if userTable.sectors[i].uuid == datar then
        userTable.sectorStatus[userTable.sectors[i].uuid] = 1
        return true,{{["text"]="Sectors: ",["color"]=0x9924C0},{["text"]="Sector Lockdown lifted of " .. userTable.sectors[i].name,["color"]=nil,["line"]=false}},true,false,"checkSector",ser.serialize(userTable.sectorStatus)
      end
    end
  else

  end
  return false
end

function module.piggyback(command,data) --Called after a command is passed. Passed to all modules which return nothing.

end

return module