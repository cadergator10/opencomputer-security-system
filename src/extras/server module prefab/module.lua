local settingstable = {}
local doortable = {}

module = {}
module.name = "module test"
module.commands = {"test"}
module.skipcrypt = {"test"}
module.debug = false

function module.init() --Called when server is first started

end

function module.setup(settings, doors) --Called when userlist is updated or server is first started
  settingstable = settings
  doortable = doors
end

function module.message(command,data) --Called when a command goes past all default commands and into modules.
  if command == "test" then
    return true, "It worked!", 0xFFFFFF,nil,"true"
  else

  end
  return false
end

return module