local module = {}

local userTable

local layout, localization, database = table.unpack({...})

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