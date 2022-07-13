local settings = {}

module = {}
module.name = "sectors"
module.commands = {"sectorupdate"}
module.skipcrypt = {"sectorupdate"}

function module.init() --Called when server is first started

end

function module.setup(setit) --Called when userlist is updated or server is first started
  settings = setit
end

function module.message(command,data) --Called when a command goes past all default commands and into modules.
  if command == "sectorupdate" then
    return true, "true", "All goes according to plan", 0xFFFFFF
  else

  end
  return false
end

return module