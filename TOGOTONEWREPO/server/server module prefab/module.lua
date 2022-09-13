local settingstable = {}
local doortable = {}
local server = {}

module = {}
module.name = "module test"
module.commands = {"test"}
module.skipcrypt = {"test"}
module.table = {}
module.debug = false
module.version = "" --Version of module. If different from version on global module.txt file, it will alert server.
module.id = 1234 --ID of module according to modules.txt global file.

function module.init(settings, doors, serverCommands) --Called when server is first started
  settingstable = settings
  doortable = doors
  server = serverCommands --Sends certain functions for module to use. crypt lets you crypt/decrypt files with the saved cryptKey on the server, send lets you send the message to the device (only available in message and piggyback functions), modulemsg lets you send a command and message through all the modules, and copy is a simple deepcopy function for tables to use if needed.
end

function module.setup() --Called when userlist is updated or server is first started

end

function module.message(command,data) --Called when a command goes past all default commands and into modules.
  if command == "test" then
    return true, {{["text"]="It worked!",["color"]=0xFFFFFF,["line"]=false}},false,true,"true" --Check WIKI for info on returns.
  else

  end
  return false
end

function module.piggyback(command,data) --Called after a command is passed. Passed to all modules which return nothing.

end

return module