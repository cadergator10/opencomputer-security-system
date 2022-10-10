local module = {}
local GUI = require("GUI")
local ser = require("serialization")
local internet = require("Internet")

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
    local doorPassList, listPageLabel2, listUpButton2, listDownButton2, doorPassSelf, doorPassData, doorPassAddSelector, doorPassCreate, doorPassDelete, doorPassEdit
    local newDoor, delDoor, exportDoor, doorPathSelector, finishPath, cancelPath, roller
    local varEditWindow

    local finishLink = "https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/doorsetup/finish.lua"

    local doors = {}

    local editPage = 1

    local pageMult = 10
    local listPageNumber = 0
    local previousPage = 0

    local pageMultPass = 4
    local listPageNumberPass = 0
    local previousPagePass = 0

    --TODO: Create buttons for new/del door and function/button for exportDoor
    local function doorListCallback()
        local selected = pageMult * listPageNumber + doorList.selectedItem
        if editPage == 1 then
            doorName = doors[selected].name
            doorType.selectedItem = doors[selected].doorType + 2
            doorDelay.text = doors[selected].delay == -1 and "" or tostring(doors[selected].delay)
            doorToggle.selectedItem = doors[selected].toggle + 2
            if userTable.sector then
                if doors[selected].sector == -1 then
                    doorSector.selectedItem = 1
                elseif doors[selected].sector == false then
                    doorSector.selectedItem = 2
                else
                    for i=1,#userTable.sector,1 do
                        if userTable.sector[i].uuid == doors[selected].sector then
                            doorSector.selectedItem = i + 2
                            break
                        end
                    end
                end
            end
        end
    end

    local function updateList()
        if editPage == 1 then
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
        elseif editPage == 2 then

        end
    end

    local function pageCallback(workspace,button)
        local function canFresh()
          updateList()
          doorListCallback()
        end
        if button.isPos then
          if button.isListNum == 1 then
            if listPageNumber < #doors/pageMult - 1 then
              listPageNumber = listPageNumber + 1
              canFresh()
            end
          else
            if doors[pageMult * listPageNumber + doorList.selectedItem].cardRead ~= -1 and listPageNumberPass < #doors[pageMult * listPageNumber + doorList.selectedItem].cardRead/pageMultPass - 1 then
              listPageNumberPass = listPageNumberPass + 1
              canFresh()
            end
          end
        else
          if button.isListNum == 1 then
            if listPageNumber > 0 then
              listPageNumber = listPageNumber - 1
              canFresh()
            end
          else
            if listPageNumberPass > 0 then
              listPageNumberPass = listPageNumberPass - 1
              canFresh()
            end
          end
        end
      end

    local function pageSetup()
        varEditWindow:removeChildren()
        if editPage == 1 then
            doorList = varEditWindow:addChild(GUI.list(2, 2, 35, 31, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
            
            varEditWindow:addChild(GUI.panel(42,20,37,14,style.listPanel))
            doorPassList = varEditWindow:addChild(GUI.list(43, 21, 35, 12, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
            

            listPageLabel = varEditWindow:addChild(GUI.label(2,33,3,3,style.listPageLabel,tostring(listPageNumber + 1)))
            listUpButton = varEditWindow:addChild(GUI.button(8,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "+"))
            listUpButton.onTouch, listUpButton.isPos, listUpButton.isListNum = pageCallback,true,1
            listDownButton = varEditWindow:addChild(GUI.button(12,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "-"))
            listDownButton.onTouch, listDownButton.isPos, listDownButton.isListNum = pageCallback,false,1

            listPageLabel2 = varEditWindow:addChild(GUI.label(43,33,3,3,style.listPageLabel,tostring(listPageNumberPass + 1)))
            listUpButton2 = varEditWindow:addChild(GUI.button(51,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "+"))
            listUpButton2.onTouch, listUpButton2.isPos, listUpButton2.isListNum = pageCallback,true,2
            listDownButton2 = varEditWindow:addChild(GUI.button(55,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "-"))
            listDownButton2.onTouch, listDownButton2.isPos, listDownButton2.isListNum = pageCallback,false,2

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
        elseif editPage == 2 then
            doorPathSelector = varEditWindow:addChild(GUI.filesystemChooser(30, 10, 30, 3, 0xE1E1E1, 0x888888, 0x3C3C3C, 0x888888, nil, "Open", "Cancel", "Choose", "/",GUI.IO_MODE_DIRECTORY))
            doorPathSelector.onSubmit = function()
                finishPath.disabled = false
            end
            finishPath = varEditWindow:addChild(GUI.button(30,12,14,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "Finish"))
            finishPath.disabled = true
            finishPath.onTouch = function()
                roller.active = true
                local tmpTable = {}
                for i=1,#doors,1 do
                    roller:roll()
                    tmpTable[i] = {}
                    local function seem(good,data)
                        if good or data ~= -1 then
                            return {["finished"]=true,["data"]=data}
                        else
                            return{["finished"]=false}
                        end
                    end
                    tmpTable[i].name = seem(true,doors[i].name)
                    tmpTable[i].redColor = seem(false,-1)
                    tmpTable[i].redSide = seem(false,-1)
                    tmpTable[i].doorAddress = seem(false,-1)
                    tmpTable[i].reader = seem(false,-1)
                    tmpTable[i].delay = seem(false,doors[i].delay)
                    tmpTable[i].toggle = seem(false,doors[i].toggle)
                    tmpTable[i].doorType = seem(false,doors[i].doorType)
                    tmpTable[i].sector = seem(false,doors[i].sector)
                    tmpTable[i].cardRead = seem(false,doors[i].cardRead)
                end
                roller:roll()
                local mep = fs.open(doorPathSelector.path .. "doorSettings.txt","w")
                mep:write(ser.serialize(tmpTable))
                mep:close()
                roller:roll()
                mep = fs.open(aRD .. "Modules/DoorSetup/finish.lua","r")
                local nw = fs.open(doorPathSelector.path .. "finish.lua")
                nw:write(mep:readAll())
                nw:close()
                mep:close() --TODO: Make it look fine when running this.
                roller.active = false
                GUI.alert("Finished exporting door settings and program to selected drive. You can now close out.")
            end
            cancelPath = varEditWindow:addChild(GUI.button(45,12,14,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "Cancel"))
            cancelPath.onTouch = function()
                editPage = 1
                pageSetup()
            end
            roller = varEditWindow:addChild(GUI.progressIndicator(30,14,0x3C3C3C, 0x00B640, 0x99FF80))
            roller.active = false
        end
    end
    
    local function exportDoorCall()
        editPage = 2
        pageSetup()
    end

    local function addDoorCall()
        local tmpTable = {["name"]="new",["toggle"]=-1,["delay"]=-1,["doorType"]=-1,["sector"]=-1,["cardRead"]=-1}
        table.insert(doors,tmpTable)
        updateList()
    end
    local function removeDoorCall()
        local selected = pageMult * listPageNumber + doorList.selectedItem
        table.remove(doors,selected)
        if #doors < pageMult * listPageNumber + 1 and listPageNumber ~= 0 then
            listPageNumber = listPageNumber - 1
        end
        updateList()
        doorName.text = ""
        doorName.disabled = true
        doorToggle.disabled = true
        doorToggle.selectedItem = 1
        doorType.disabled = true
        doorType.selectedItem = 1
        doorDelay.text = ""
        doorDelay.disabled = true
        if userTable.sectors then
            doorSector.disabled = true
            doorSector.selectedItem = 1
        end
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
        local disBut = doorSector.selectedItem - 2
        if disBut == -1 then
            doors[selected].sector = -1
        elseif disBut == 0 then
            doors[selected].sector = false
        else
            doors[selected].sector = userTable.sectors[disBut].uuid
        end
        updateList()
        doorListCallback()
    end

    if database.checkPerms("security",{"doorsetup"},true) then
        window:addChild(GUI.label(2,16,3,3,style.passNameLabel,"You do not have permissions to do this"))
        return
    end
    
    varEditWindow = window:addChild(GUI.container(1,1,window.width,window.height))
end

module.close = function()
  return {} --Return table of what you want the database to auto save (if enabled) of the keys used by this module
end

return module