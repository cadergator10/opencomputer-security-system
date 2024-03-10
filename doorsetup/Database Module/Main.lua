local module = {}
local GUI = require("GUI")
local ser = require("serialization")
local uuid = require("uuid")

local userTable -- Holds userTable stuff.

local workspace, window, loc, database, style, compat = table.unpack({...}) --Sets up necessary variables: workspace is workspace, window is area to work in, loc is localization file, database are database commands, and style is the selected style file.
local system, fs, event
if compat == nil then
    system = require("System") --Set it to the MineOS
    fs = require("Filesystem")
    event = require("event")

else
    system = compat.system --Set it to the compatability stuff (in the compat file)
    fs = compat.fs
    event = compat.event
end

module.name = "Door Setup" --The name that shows up on the module's button.
module.table = {} --Set to the keys you want pulled from the userlist on the server
module.debug = false --The database will set to true if debug mode on database is enabled. If you want to enable certain functions in debug mode.
module.config = {}

module.init = function(usTable) --Set userTable to what's received. Runs only once at the beginning
    userTable = usTable
end

--[[
    What this needs to have:
    Table List{
        .name = name of table
        .redColor = color of redstone can be done on computer, not here
        .redSide = side of redstone can be done on computer, not here
        .delay = can do this here.
        .doorType = can do this here.
        .doorAddress = do this on computer, not here
        .toggle = can do this here
        .sector = can do this here.
        .cardRead = can do this here. Passes
    }
]]

module.onTouch = function() --pulled from security module mainly.
    local tabWindow, tabs, cardStatusLabel, selected
    local userEdit, passEdit
    do --keep it contained to remove memory after done
        local result, reason = loadfile(fs.path(system.getCurrentScript()) .. "Modules/modid" .. tostring(module.id) .. "/setup.lua")
        if result then
            passEdit = result
        else
            GUI.alert("Failed to load file pass.lua: " .. tostring(reason))
        end
        result, reason = loadfile(fs.path(system.getCurrentScript()) .. "Modules/modid" .. tostring(module.id) .. "/editing.lua")
        if result then
            userEdit = result
        else
            GUI.alert("Failed to load file user.lua: " .. tostring(reason))
        end
    end

    local function migrateTab(_, button)
        if not button.doTheMove then
            tabWindow:removeChildren()
        end
        if selected ~= button.myId then
            local success, result = pcall(button.toRun, workspace, tabWindow, loc, database, style, userTable, compat, system, fs, module)
            if not success then
                GUI.alert("Failed to run file: " .. tostring(result))
            end
            workspace:draw()
            selected = button.myId
        end
    end

    tabWindow = window:addChild(GUI.container(1,4,window.width,window.height - 3))
    tabs = window:addChild(GUI.list(1, 1, 75, 3, 2, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, true))
    tabs:setDirection(GUI.DIRECTION_HORIZONTAL)
    tabs:setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
    local meh = tabs:addItem("Door Setup")
    meh.onTouch = migrateTab
    meh.myId = 1
    meh.toRun = passEdit
    meh = tabs:addItem("Door Editing")
    meh.onTouch = migrateTab
    meh.myId = 2
    meh.toRun = userEdit
    meh.disabled = database.checkPerms("security",{"doorsetup"},true)

    tabs.selected = 1
    migrateTab(nil, {["doTheMove"]=true,["myId"]=1,["toRun"]=passEdit})
end

module.close = function() --when user switches modules
    return {}
end

return module