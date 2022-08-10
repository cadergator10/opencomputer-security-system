local userTable = {}
local doorTable = {}
local server = {}
local modemPort = 199

local component = require("component")
local modem = component.modem
local ser = require("serialization")

module = {}
module.name = "passes"
module.commands = {"rcdoors","checkLinked","getvar","setvar","checkRules"}
module.skipcrypt = {"autoInstallerQuery","rcdoors"}
module.table = {["passes"]={},["passSettings"]={["var"]={"level"},["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false}}}
module.debug = false

function module.init(setit ,doors, serverCommands) --Called when server is first started
    userTable = setit
    doorTable = doors
    server = serverCommands
    if module.debug then print("Received Stuff for passes!") end
end

function module.setup() --Called when userlist is updated or server is first started
    if module.debug then print("Received Stuff for passes!") end
end

function module.message(command,datar) --Called when a command goes past all default commands and into modules.
    local data = ser.unserialize(datar) --TODO: Move certain functions from oldserver to here.
    if command == "sectorupdate" then

    else

    end
    return false
end
--TODO: Change all programs here to new system of userTable and such.
function module.piggyback(command,data) --Called after a command is passed. Passed to all modules which return nothing.
    if command == "setdevice" then
        server.send(true,server.crypt(ser.serialize({["settings"]=userTable.passSettings,["sectors"]=userTable.sectors})))
    end
end

return module