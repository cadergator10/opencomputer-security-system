local settingstable = {}
local doortable = {}
local server = {}
--A server module simply for getting all door data.
local module = {}

local component = require("component")
local ser = require("serialization")
local modem = component.modem

module.name = "door setup"
module.commands = {"getdoornames","getdoordata"}
module.skipcrypt = {}
module.table = {}
module.debug = false
function module.init(settings, doors, serverCommands) --Called when server is first started
    settingstable = settings
    doortable = doors
    server = serverCommands --Sends certain functions for module to use. crypt lets you crypt/decrypt files with the saved cryptKey on the server, send lets you send the message to the device (only available in message and piggyback functions), modulemsg lets you send a command and message through all the modules, and copy is a simple deepcopy function for tables to use if needed.
end

function module.setup() --Called when userlist is updated or server is first started

end

function module.message(command,data) --Called when a command goes past all default commands and into modules.
    if command == "getdoornames" then --get names of all doors
        local allDoors = {}
        for _, value2 in pairs(doortable) do
            if value2.type == "doorsystem" then
                for key, value in pairs(value2.data) do
                    if allDoors[value.name] == nil then
                        allDoors[value.name] = {["key"]=key, ["id"] = value2.id}
                    else
                        allDoors[value.name .. ":" .. key] = {["key"]=key, ["id"] = value2.id} --just in case they have duplicated names
                    end
                end
            end
        end
        return true, nil, false, true, server.crypt(ser.serialize(allDoors))
    elseif command == "getdoordata" then --get door info from server
        --data = key & id of door
        data = ser.unserialize(data)
        if data ~= nil then
            for _, value2 in pairs(doortable) do
                if value2.type == "doorsystem" and value2.id == data.id then
                    for key, value in pairs(value2.data) do
                        if key == data.key then
                            return true, nil, false, true, server.crypt(ser.serialize(value))
                        end
                    end
                end
            end
        end
        return true, nil, false, true, server.crypt("false")
    elseif command == "setdoordata" then
        data = ser.unserialize(data)
        if data ~= nil then
            local broadTable = {}
            for _, value in pairs(data) do
                for _, value2 in pairs(doortable) do
                    if value.id == value2.id then
                        for key, value3 in pairs(value2.data) do
                            if key == value.key then
                                if broadTable[value2.id] == nil then
                                    broadTable[value2.id] = {["repeat"] = value3["repeat"]}
                                end
                                broadTable[value2.id][value.key] = value.data
                            end
                        end
                    end
                end
            end
            for key, value in pairs(broadTable) do
                server.advsend(key, value["repeat"] ~= false and value["repeat"] or nil, nil, ser.serialize(value))
            end
            return true, nil, false, true, server.crypt("true")
        end
    end
    return false
end

function module.piggyback(command,data) --Called after a command is passed. Passed to all modules which return nothing.

end

return module