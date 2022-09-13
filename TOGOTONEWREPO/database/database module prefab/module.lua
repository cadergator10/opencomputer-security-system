local module = {}
local GUI = require("GUI")

local userTable -- Holds userTable stuff.

local workspace, window, loc, database, style = table.unpack({...}) --Sets up necessary variables: workspace is workspace, window is area to work in, loc is localization file, database are database commands, and style is the selected style file.

module.name = "Example" --The name that shows up on the module's button.
module.table = {"testmod","testmod2"} --Set to the keys you want pulled from the userlist on the server,
module.debug = false --The database will set to true if debug mode on database is enabled. If you want to enable certain functions in debug mode.
module.version = "" --Version of the module. If different from version on global module file, it will alert database.
module.id = 1234 --id of module according to modules.txt global file.

module.init = function(usTable) --Set userTable to what's received. Runs only once at the beginning
  userTable = usTable
end

module.onTouch = function() --Runs when the module's button is clicked. Set up the workspace here.
  
end

module.close = function()
  return {"testmod","testmod2"} --Return table of what you want the database to auto save (if enabled) of the keys used by this module
end

return module