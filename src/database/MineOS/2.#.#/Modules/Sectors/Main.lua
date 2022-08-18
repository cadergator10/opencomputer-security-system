local module = {}
local GUI = require("GUI")
local uuid = require("uuid")

local userTable

local workspace, window, loc, database, style = table.unpack({...})

module.name = "Sectors"
module.table = {"sectors"}
module.debug = false

module.init = function(usTable)
  userTable = usTable
end

module.onTouch = function()

end

module.close = function()
  return {["sectors"]={}}
end

return module