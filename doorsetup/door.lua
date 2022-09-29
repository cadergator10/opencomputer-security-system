local module = {}
local GUI = require("GUI")

local userTable -- Holds userTable stuff.

local workspace, window, loc, database, style, permissions = table.unpack({...}) --Sets up necessary variables: workspace is workspace, window is area to work in, loc is localization file, database are database commands, and style is the selected style file.

module.name = "Door Setup" --The name that shows up on the module's button.
module.table = {} --Set to the keys you want pulled from the userlist on the server
module.debug = false --The database will set to true if debug mode on database is enabled. If you want to enable certain functions in debug mode.
module.version = "" --Version of the module. If different from version on global module file, it will alert database.
module.id = 1113 --id of module according to modules.txt global file.

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

module.onTouch = function() --Runs when the module's button is clicked. Set up the workspace here.
    local doorList, listPageLabel, listUpButton, listDownButton, doorName, doorType, doorDelay, doorToggle, doorSector
    local varEditWindow

    local doors = {}

    local editPage = 1

    local pageMult = 10
    local listPageNumber = 0
    local previousPage = 0
    
    local function doorListCallback()
        if editPage == 1 then

        end
    end

    local function updateList()
        local selectedId = doorList.selectedItem
        doorList:removeChildren()
        local temp = pageMult * listPageNumber
        for i = temp + 1, temp + pageMult, 1 do
            if doors[i] == nil then

            else
                doorList:addItem(doors[i].name).onTouch = doorListCallback()
            end
        end
        if (previousPage == listPageNumber) then
            doorList.selectedItem = selectedId
        else
            previousPage = listPageNumber
        end
    end

    local function pageCallback(workspace,button)
        local function canFresh()
            updateList()
            userListCallback()
        end
        if button.isPos then
            if listPageNumber < #userTable.passes/pageMult - 1 then
                listPageNumber = listPageNumber + 1
                canFresh()
            end
        else
            if listPageNumber > 0 then
                listPageNumber = listPageNumber - 1
                canFresh()
            end
        end
    end
    
    local function addDoor()

    end
    local function removeDoor()

    end

    local function setDoorType()
        local selected = pageMult * listPageNumber + doorList.selectedItem
        doors[selected].doorType = doorType.selectedItem - 2
        updateList()
        doorListCallback()
    end
    local function setDoorToggle()
        local selected = pageMult * listPageNumber + doorList.selectedItem
        doors[selected].toggle = doorToggle.selectedItem - 2
        updateList()
        doorListCallback()
    end
    local function setDoorName()
        local selected = pageMult * listPageNumber + doorList.selectedItem
        doors[selected].name = doorName.text
        updateList()
        doorListCallback()
    end
    local function setDoorDelay()
        local selected = pageMult * listPageNumber + doorList.selectedItem
        doors[selected].delay = doorDelay.text ~= "" and tonumber(doorDelay.text) or -1
        updateList()
        doorListCallback()
    end
    local function setDoorSector()
        local selected = pageMult * listPageNumber + doorList.selectedItem
        --LEFT OFF
        updateList()
        doorListCallback()
    end

    local function pageSetup()
        varEditWindow:removeChildren()
        if page == 1 then
            doorName = varEditWindow:addChild(GUI.input(64,12,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputname))
            doorName.onInputFinished = setDoorName
            doorName.disabled = true
            doorType = varEditWindow:addChild(GUI.comboBox(64,14,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
            doorType:addItem("Unidentified").onTouch = setDoorType
            doorType:addItem("Door Control").onTouch = setDoorType
            doorType:addItem("Redstone").onTouch = setDoorType
            doorType:addItem("Bundled Redstone").onTouch = setDoorType
            doorType:addItem("RollDoor Control").onTouch = setDoorType
            doorToggle = varEditWindow:addChild(GUI.comboBox(64,16,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
            doorToggle:addItem("Unidentified").onTouch = setDoorToggle
            doorToggle:addItem("Delay").onTouch = setDoorToggle
            doorToggle:addItem("Toggle").onTouch = setDoorToggle
            doorDelay = varEditWindow:addChild(GUI.input(64,18,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", "input number"))
            doorDelay.disabled = true
            doorDelay.onTouch = setDoorDelay
            if userTable.sectors then
                doorSector = varEditWindow:addChild(GUI.comboBox(64,20,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
                doorSector:addItem("Unidentified").onTouch = setDoorSector
                doorSector:addItem("No Sector").onTouch = setDoorSector
                for i=1,#userTable.sectors,1 do
                    doorSector:addItem(userTable.sectors[i].name).onTouch = setDoorSector
                end
            end
        end
    end

    if database.checkPerms("security",{"doorsetup"},true) then
        window:addChild(GUI.label(2,16,3,3,style.passNameLabel,"You do not have permissions to do this"))
        return
    end

    doorList = window:addChild(GUI.list(2, 2, 35, 31, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
    
    varEditWindow = window:addChild(GUI.container(1,1,window.width,window.height))

    listPageLabel = window:addChild(GUI.label(2,33,3,3,style.listPageLabel,tostring(listPageNumber + 1)))
    listUpButton = window:addChild(GUI.button(8,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "+"))
    listUpButton.onTouch, listUpButton.isPos = pageCallback,true
    listDownButton = window:addChild(GUI.button(12,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "-"))
    listDownButton.onTouch, listDownButton.isPos = pageCallback,false
end

module.close = function()
  return {} --Return table of what you want the database to auto save (if enabled) of the keys used by this module
end

return module