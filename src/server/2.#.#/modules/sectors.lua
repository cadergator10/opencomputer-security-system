local settings = {}
local modemPort = 199

local component = require("component")
local modem = component.modem

module = {}
module.name = "sectors"
module.commands = {"sectorupdate"}
module.skipcrypt = {"sectorupdate"}

function module.init(debug) --Called when server is first started

end

function module.setup(setit) --Called when userlist is updated or server is first started
  settings = setit
  if module.debug then print("Received " .. #settings.sectors .. " Sectors")
end

function module.message(command,data) --Called when a command goes past all default commands and into modules.
  if command == "sectorupdate" then
    modem.broadcast(modemPort,"checkSector")
  else

  end
  return false
end

return module