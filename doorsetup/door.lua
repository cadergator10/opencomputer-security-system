local module = {}
local GUI = require("GUI")
local ser = require("serialization")
local internet = require("Internet")
local uuid = require("uuid")

local userTable -- Holds userTable stuff.

local workspace, window, loc, database, style, permissions = table.unpack({...}) --Sets up necessary variables: workspace is workspace, window is area to work in, loc is localization file, database are database commands, and style is the selected style file.

module.name = "Door Setup" --The name that shows up on the module's button.
module.table = {} --Set to the keys you want pulled from the userlist on the server
module.debug = false --The database will set to true if debug mode on database is enabled. If you want to enable certain functions in debug mode.
module.version = "1.0.0" --Version of the module. If different from version on global module file, it will alert database.
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
    local doorPassList, listPageLabel2, listUpButton2, listDownButton2, doorPassSelf, doorPassData, doorPassAddSelector, doorPassCreate, doorPassDelete, doorPassEdit, doorPassType, doorPassAddHave
    local doorPassAddAdd, doorPassAddDel
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
    local prevPass = "string"

    local function grabName(where,call)
        for i=1,#userTable.passSettings.calls,1 do
            if userTable.passSettings.calls[i] == call then
                return userTable.passSettings[where][i] or nil, i
            end
        end
        return nil
    end

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
            --doorPassSelf, doorPassData, doorPassAddSelector, doorPassCreate, doorPassDelete, doorPassEdit, doorPassType, doorPassAddHave, doorPassAddAdd, doorPassAddDel
            local selectedId = doorPassList.selectedItem
            doorPassList:removeChildren()
            local temp = pageMultPass * listPageNumberPass
            local otSel = temp + doorPassList.selectedItem
            for i = temp + 1, temp + pageMultPass, 1 do
                if doors[selected].cardRead.normal[i] == nil then

                else
                    local thisType = grabName("type",doors[selected].cardRead.normal[i].call)
                    local next = doors[selected].cardRead.normal[i].request == "add" and (" | " .. #doors[selected].cardRead.normal[i].data) or ""
                    local peep = doorPassList:addItem(grabName("label",doors[selected].cardRead.normal[i].call) .. " | " .. (thisType == "bool" and "0" or thisType == "-int" and grabName("data",doors[selected].cardRead.normal[i].call)[doors[selected].cardRead.normal[i].param] or tostring(doors[selected].cardRead.normal[i].param)) .. " | " .. doors[selected].cardRead.normal[i].request .. next)
                    peep.savedData = doors[selected.cardRead.normal[i]]
                end
            end
            if (previousPagePass == listPageNumberPass) then
                doorPassList.selectedItem = selectedId
            else
                previousPagePass = listPageNumberPass
            end
            doorPassSelf.disabled = false
            doorPassData.disabled = doorPassSelf.selectedItem == 1 and true or userTable.passSettings.type[doorPassSelf.selectedItem - 1] == "bool" and true or false
            doorPassCreate.disabled = false
            doorPassDelete.disabled = #doors[selected].cardRead.normal == 0 and true or false
            doorPassEdit.disabled = #doors[selected].cardRead.normal == 0 and true or false
            doorPassType.disabled = false
            doorPassAddSelector.disabled = false
            doorPassAddSelector:clear()
            doorPassAddHave.disabled = false
            doorPassAddHave:clear()
            doorPassAddAdd.disabled = true
            for key,value in pairs(doors[selected].cardRead.add) do
                doorPassAddAdd.disabled = false
                local disName = grabName("label",value.call) .. " | " .. (thisType == "bool" and "0" or thisType == "-int" and grabName("data",value.call)[value.param] or tostring(value.param))
                local mep = doorPassAddSelector:addItem(disName)
                mep.savedData = {["name"]=disName,["call"]=value.call}
            end
            doorPassAddDel.disabled = true
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

    local function refreshInput()
        local uuid = doorPassSelf.selectedItem - 1
        if uuid ~= 0 then
            if userTable.passSettings.type[uuid] == "string" or userTable.passSettings.type[uuid] == "-string" or userTable.passSettings.type[uuid] == "int" then
                if prevPass == "-int" then
                  doorPassData:remove()
                  doorPassData = window:addChild(GUI.input(100,23,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
                end
                doorPassData.text = ""
                doorPassData.disabled = false
            elseif userTable.passSettings.type[uuid] == "-int" then
                if prevPass ~= "-int" then
                    doorPassData:remove()
                    doorPassData = window:addChild(GUI.comboBox(100,23,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
                else
                    doorPassData:clear()
                end
                for _,value in pairs(userTable.passSettings.data[uuid]) do
                    doorPassData:addItem(value)
                end
                doorPassData.selectedItem = 1
            else
                if prevPass == "-int" then
                    doorPassData:remove()
                    doorPassData = window:addChild(GUI.input(100,23,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
                end
                doorPassData.text = ""
                doorPassData.disabled = true
            end
        else
            if prevPass == "-int" then
                doorPassData:remove()
                doorPassData = window:addChild(GUI.input(100,23,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
            end
            doorPassData.text = ""
            doorPassData.disabled = true
        end
        prevPass = uuid ~= 0 and userTable.passSettings.type[uuid] or "bool"
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
            newDoor = window:addChild(GUI.button(85,12,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "new door"))
            newDoor.onTouch = addDoorCall
            delDoor = window:addChild(GUI.button(100,12,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "del door"))
            delDoor.onTouch = removeDoorCall
            exportDoor = window:addChild(GUI.button(115,12,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "new door"))
            exportDoor.onTouch = exportDoorCall
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
            --doorPassSelf, doorPassData, doorPassAddSelector, doorPassCreate, doorPassDelete, doorPassEdit, doorPassType, doorPassAddHave, doorPassAddAdd, doorPassAddDel
            window:addChild(GUI.label(85,21,1,1,style.passNameLabel,"Select Pass : "))
            doorPassSelf = varEditWindow:addChild(GUI.comboBox(100,21,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
            doorPassSelf:addItem("staff").onTouch = refreshInput
            for i=1,#userTable.passSettings.var,1 do
                doorPassSelf:addItem(userTable.passSettings.label[i]).onTouch = refreshInput
            end
            doorPassSelf.disabled = true
            window:addChild(GUI.label(85,23,1,1,style.passNameLabel,"Change Input: "))
            doorPassData = window:addChild(GUI.input(100,23,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputtext))
            doorPassData.disabled = true
            refreshInput()
            window:addChild(GUI.label(85,25,1,1,style.passNameLabel,"Change Type : "))
            doorPassType = varEditWindow:addChild(GUI.comboBox(100,25,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
            doorPassType:addItem("Supreme")
            doorPassType:addItem("Base")
            doorPassType:addItem("Add")
            doorPassType:addItem("Reject")
            local typeArray = {"supreme","base","add","reject"}
            window:addChild(GUI.label(85,25,1,1,style.passNameLabel,"Manage Add Passes on door"))
            doorPassAddSelector = varEditWindow:addChild(GUI.comboBox(110,27,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
            doorPassAddSelector.disabled = true
            doorPassAddHave = varEditWindow:addChild(GUI.comboBox(85,27,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
            doorPassAddHave.disabled = true
            doorPassAddAdd = window:addChild(GUI.button(85,29,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "add pass"))
            doorPassAddAdd.onTouch = function()
                local moveMe = doorPassAddSelector:getItem(doorPassAddSelector.selectedItem)
                local newMe = doorPassAddHave:addItem(moveMe.savedData.name)
                newMe.savedData = moveMe.savedData
                doorPassAddSelector:removeItem(doorPassAddSelector.selectedItem)
                if #doorPassAddSelector.children == 0 then
                    doorPassAddAdd.disabled = true
                end
                doorPassAddDel.disabled = false
            end
            doorPassAddAdd.disabled = true
            doorPassAddDel = window:addChild(GUI.button(85,29,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "remove pass"))
            doorPassAddDel.onTouch = function()
                local moveMe = doorPassAddHave:getItem(doorPassAddHave.selectedItem)
                local newMe = doorPassAddSelector:addItem(moveMe.savedData.name)
                newMe.savedData = moveMe.savedData
                doorPassAddHave:removeItem(doorPassAddHave.selectedItem)
                if #doorPassAddHave.children == 0 then
                    doorPassAddDel.disabled = true
                end
                doorPassAddAdd.disabled = false
            end
            doorPassAddDel.disabled = true
            doorPassCreate = window:addChild(GUI.button(85,29,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.addvar))
            doorPassCreate.onTouch = function()
                local passFunc = function(type,num,selected)
                    local newRules = {["uuid"]=uuid.next(),["request"]=typeArray[type],["data"]=type == 2 and {} or false}
                    if selected == 0 then
                        newRules.call = "checkstaff"
                        newRules.param = 0
                    else
                        newRules["tempint"] = selected
                        newRules["call"] = userTable.passSettings.calls[selected]
                        if userTable.passSettings.type[selected] == "string" or userTable.passSettings.type == "-string" then
                            newRules["param"] = doorPassData.text
                        elseif userTable.passSettings.type[selected] == "bool" then
                            newRules["param"] = 0
                        elseif userTable.passSettings.type[selected] == "int" then
                            newRules["param"] = tonumber(doorPassData.text)
                        elseif userTable.passSettings.type[selected] == "-int" then
                            newRules["param"] = doorPassData.selectedItem
                        else
                            GUI.alert("error in cardRead area for num 2")
                            newRules["param"] = 0
                        end
                    end
                    if newRules.request == "base" then
                        for i=1,doorPassAddHave:count(),1 do
                            local doorData = doorPassAddHave:getItem(i)
                            table.insert(newRules.data,doorData.savedData.call)
                        end
                    end
                    return newRules
                end
                local needPass passFunc(doorPassType.selectedItem,nil,doorPassSelf.selectedItem - 1)
                local selected = pageMult * listPageNumber + doorList.selectedItem
                table.insert(doors[selected].cardRead.normal,needPass)
                if needPass.request == "add" then
                    doors[selected].cardRead.add[needPass.uuid] = needPass
                end
                doorListCallback()
            end
            doorPassCreate.disabled = true
            doorPassDelete = window:addChild(GUI.button(100,27,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.addvar))
            doorPassDelete.onTouch = function()
                local selected = pageMult * listPageNumber + doorList.selectedItem
                local otSel = pageMultPass * listPageNumberPass + doorPassList.selectedItem
                if doors[selected].cardRead.normal[otSel].request == "add" then
                    for i=1,#doors[selected].cardRead.normal,1 do
                        if doors[selected].cardRead.normal[i].request == "base" then
                            for j=1,#doors[selected].cardRead.normal[i].data,1 do
                                if doors[selected].cardRead.normal[i].data[j] == doors[selected].cardRead.normal[otSel].uuid then
                                    table.remove(doors[selected].cardRead.normal[i].data[j])
                                    break
                                end
                            end
                        end
                    end
                    doors[selected].cardRead.add[doors[selected].cardRead.normal[otSel].uuid] = nil
                end
                table.remove(doors[selected].cardRead.normal,otSel)
            end
            doorPassDelete.disabled = true
            doorPassEdit = window:addChild(GUI.button(115,27,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.addvar))
            doorPassEdit.onTouch = function()
                local selected = pageMult * listPageNumber + doorList.selectedItem
                local otSel = pageMultPass * listPageNumberPass + doorPassList.selectedItem
                if doors[selected].cardRead.normal[otSel].request == "add" then
                    GUI.alert("This is an add pass, meaning any passes with this add pass will have it unlinked to the pass.")
                    for i=1,#doors[selected].cardRead.normal,1 do
                        if doors[selected].cardRead.normal[i].request == "base" then
                            for j=1,#doors[selected].cardRead.normal[i].data,1 do
                                if doors[selected].cardRead.normal[i].data[j] == doors[selected].cardRead.normal[otSel].uuid then
                                    table.remove(doors[selected].cardRead.normal[i].data[j])
                                    break
                                end
                            end
                        end
                    end
                    doors[selected].cardRead.add[doors[selected].cardRead.normal[otSel].uuid] = nil
                end
                local old = doors[selected].cardRead.normal[otSel]
                table.remove(doors[selected].cardRead.normal,otSel)
                local disType,mep = grabName("type",old.call)
                doorPassSelf.selectedItem = mep + 1
                refreshInput()
                if disType == "-int" then
                    doorPassData.selectedItem = old.param
                elseif disType == "int" then
                    doorPassData.text = tostring(old.param)
                elseif disType == "string" or disType == "-string" then
                    doorPassData.text = old.param
                end
                doorPassType.selectedItem = old.request == "supreme" and 1 or old.request == "base" and 2 or old.request == "add" and 3 or old.request == "reject" and 4
                doorListCallback()
                if old.request == "base" then
                    doorPassAddDel.disabled = true
                    for i=1,#old.data,1 do
                        for j=1,doorPassAddSelector:count(),1 do
                            if doorPassAddSelector:getItem(j).savedData.call == old.data[i] then
                                local moveMe = doorPassAddSelector:getItem(j)
                                local newMe = doorPassAddHave:addItem(moveMe.savedData.name)
                                newMe.savedData = moveMe.savedData
                                doorPassAddSelector:removeItem(j)
                                if #doorPassAddSelector.children == 0 then
                                    doorPassAddAdd.disabled = true
                                end
                                doorPassAddDel.disabled = false
                            end
                        end
                    end
                end
            end
            doorPassEdit.disabled = true
            

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
                    tmpTable[i].cardRead = seem(false,#doors[i].cardRead.normal == 0 and -1 or doors[i].cardRead.normal)
                end
                local meep = loadTable(aRD .. "dbsettings.txt")
                tmpTable["config"]={["port"]=meep.port,["cryptKey"]=meep.cryptKey}
                roller:roll()
                local mep = fs.open(doorPathSelector.path .. "finishSettings.txt","w")
                mep:write(ser.serialize(tmpTable))
                mep:close()
                roller:roll()
                mep = fs.open(aRD .. "Modules/DoorSetup/finish.lua","r")
                local nw = fs.open(doorPathSelector.path .. "finish.lua")
                nw:write(mep:readAll())
                nw:close()
                mep:close()
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

    if database.checkPerms("security",{"doorsetup"},true) then
        window:addChild(GUI.label(2,16,3,3,style.passNameLabel,"You do not have permissions to do this"))
        return
    end
    
    varEditWindow = window:addChild(GUI.container(1,1,window.width,window.height))
    pageSetup()
end

module.close = function()
  return {} --Return table of what you want the database to auto save (if enabled) of the keys used by this module
end

return module