local workspace, window, loc, database, style, userTable, compat, system, fs, module = table.unpack({...})

local GUI = require("GUI")
local ser = require("serialization")
local uuid = require("uuid")

local doorList, listPageLabel, listUpButton, listDownButton, doorName, doorType, doorDelay, doorToggle, doorSector, doorPad, doorPadPass --TODO: Add buttons for doorPad (undefined, local, or global) or doorPadPass (depending on doorPad, local (input for 4 char pin) or global (combo based on keypad global stuff))
local doorPassList, listPageLabel2, listUpButton2, listDownButton2, doorPassSelf, doorPassData, doorPassAddSelector, doorPassCreate, doorPassDelete, doorPassEdit, doorPassType, doorPassAddHave
local doorPassAddAdd, doorPassAddDel, resetDoorSave
local newDoor, delDoor, exportDoor, doorPathSelector, finishPath, cancelPath, roller
local currentDoor, currentKey, currentId, currentName

local doors = database.dataBackup("doorEditing") --TODO: Make sure this wipes the right door's passes in order to prevent errors
if (doors == nil) then
    doors = {} --doors = current list of doors the user has worked on
else --Check to ensure passes linked in doors are not MISSING
    local isHere = true
    local quikMessage = false
    for i=1,#doors,1 do
        if #doors[i].cardRead.normal > 0 then
            for j=1,#doors[i].cardRead.normal,1 do
                local noooo = false
                if not (doors[i].cardRead.normal[j].call == "checkstaff") then
                    for key,value in pairs(userTable.passSettings.calls) do
                        if value == doors[i].cardRead.normal[j].call then
                            noooo = true
                            break
                        end
                    end
                else
                    noooo = true
                end
                if not noooo then
                    isHere = false
                    break
                end
            end
        end
        if not isHere then
            quikMessage = true
            doors[i].cardRead.normal = {}
            doors[i].cardRead.add = {}
        end
    end
    if quikMessage then
        GUI.alert(loc.doorbadmessage)
    end
end
local worked,_,_,_,_, doorNames = database.send(true,"getdoornames")
if worked then

    local pageMult = 10
    local listPageNumber = 0
    local previousPage = 0

    local pageMultPass = 3
    local listPageNumberPass = 0
    local previousPagePass = 0
    local prevPass = "string"

    local function grabName(where,call)
        if call ~= "checkstaff" then
            for i=1,#userTable.passSettings.calls,1 do
                if userTable.passSettings.calls[i] == call then
                    return userTable.passSettings[where][i] or nil, i
                end
            end
        else --type, label, and data
            if where == "type" then
                return "bool", 0
            elseif where == "label" then
                return "Staff", 0
            elseif where == "data" then
                return false, 0
            end
        end
        return nil
    end

    local function allDisable()
        doorName.text = ""
        doorName.disabled = true
        doorToggle.disabled = true
        doorToggle.selectedItem = 1
        doorType.disabled = true
        doorType.selectedItem = 1
        doorDelay.text = ""
        doorDelay.disabled = true
        listUpButton2.disabled = true
        listDownButton2.disabled = true
        doorPassSelf.disabled = true
        doorPassData.disabled = true
        doorPassCreate.disabled = true
        doorPassDelete.disabled = true
        doorPassEdit.disabled = true
        doorPassType.disabled = true
        doorPassAddAdd.disabled = true
        doorPassAddDel.disabled = true
        doorPassEdit.disabled = true
        doorPassAddSelector.disabled = false
        doorPassAddHave.disabled = false
        if userTable.sectors then
            doorSector.disabled = true
            doorSector.selectedItem = 1
        end
        delDoor.disabled = true
        if #doors == 0 then
            exportDoor.disabled = true
        end
    end

    local function currentDoorChanges() --changes performed: make sure it exists in doors table
        if doors[currentId] == nil then
            doors[currentId] = {["data"]={}}
        end
        doors[currentId][currentKey] = currentDoor
    end

    local function doorListCallback(bypassAdd)
        --TODO: Set all stuff to right value
        local selected = pageMult * listPageNumber + doorList.selectedItem
        currentName = doorList:getItem(doorList.selectedItem).text
        currentId = doorNames[currentName].id
        currentKey = doorNames[currentName].key
        if doors[currentId] ~= nil then
            currentDoor = doors[currentId].data[currentKey]
        else
            local worked,_,_,_,_, nee = database.send(true,"getdoordata", database.crypt(ser.serialize(doorNames[currentName])))
            if worked then
                currentDoor = nee
            else
                GUI.alert("Failed to get data from server. Is it offline?")
            end
        end
        doorName.text, doorName.disabled = currentDoor.name, false
        doorType.selectedItem, doorType.disabled = currentDoor.doorType, false
        doorDelay.text, doorDelay.disabled = tostring(currentDoor.delay), currentDoor.toggle == 1 and true or false
        doorToggle.selectedItem, doorToggle.disabled = currentDoor.toggle + 1, false
        if userTable.sectors then
            doorSector.disabled = false
            if currentDoor.sector == false then
                doorSector.selectedItem = 1
            else
                for i=1,#userTable.sectors,1 do
                    if userTable.sectors[i].uuid == currentDoor.sector then
                        doorSector.selectedItem = i + 1
                        break
                    end
                end
            end
            doorSector.disabled = false
        end
        --doorPassSelf, doorPassData, doorPassAddSelector, doorPassCreate, doorPassDelete, doorPassEdit, doorPassType, doorPassAddHave, doorPassAddAdd, doorPassAddDel
        local selectedId = doorPassList.selectedItem
        doorPassList:removeChildren()
        if (pageMultPass * listPageNumberPass) + 1 > #currentDoor.cardRead.normal and listPageNumberPass ~= 0 then
            listPageNumberPass = listPageNumberPass - 1
        end
        local temp = pageMultPass * listPageNumberPass
        local otSel = temp + doorPassList.selectedItem
        for i = temp + 1, temp + pageMultPass, 1 do
            if currentDoor.cardRead.normal[i] == nil then

            else
                local thisType = grabName("type",currentDoor.cardRead.normal[i].call)
                local next = currentDoor.cardRead.normal[i].request == "base" and (" | " .. #currentDoor.cardRead.normal[i].data) or ""
                local peep = doorPassList:addItem(grabName("label",currentDoor.cardRead.normal[i].call) .. " | " .. (thisType == "bool" and "0" or thisType == "-int" and grabName("data",currentDoor.cardRead.normal[i].call)[currentDoor.cardRead.normal[i].param] or tostring(currentDoor.cardRead.normal[i].param)) .. " | " .. currentDoor.cardRead.normal[i].request .. next)
                peep.savedData = currentDoor.cardRead.normal[i]
            end
        end
        if (previousPagePass == listPageNumberPass) then
            doorPassList.selectedItem = selectedId
        else
            doorPassList.selectedItem = 1
            previousPagePass = listPageNumberPass
        end
        listPageLabel.text = tostring(listPageNumber + 1)
        listPageLabel2.text = tostring(listPageNumberPass + 1)
        listDownButton2.disabled = listPageNumberPass == 0
        listUpButton2.disabled = #currentDoor.cardRead.normal <= temp + pageMultPass
        doorPassSelf.disabled = false
        doorPassData.disabled = doorPassSelf.selectedItem == 1 and true or userTable.passSettings.type[doorPassSelf.selectedItem - 1] == "bool" and true or false
        doorPassCreate.disabled = false
        doorPassDelete.disabled = #currentDoor.cardRead.normal == 0 and true or false
        doorPassEdit.disabled = #currentDoor.cardRead.normal == 0 and true or false
        doorPassType.disabled = false
        doorPassAddSelector.disabled = false
        doorPassAddHave.disabled = false
        delDoor.disabled = false
        if bypassAdd ~= true then
            doorPassAddSelector:clear()
            doorPassAddHave:clear()
            doorPassAddAdd.disabled = true
            for key,value in pairs(currentDoor.cardRead.add) do
                local thisType = grabName("type",value.call)
                doorPassAddAdd.disabled = false
                local disName = grabName("label",value.call) .. " | " .. (thisType == "bool" and "0" or thisType == "-int" and grabName("data",value.call)[value.param] or tostring(value.param))
                local mep = doorPassAddSelector:addItem(disName)
                mep.savedData = {["name"]=disName,["call"]=value.uuid}
            end
            doorPassAddDel.disabled = true
        end
        workspace:draw()
    end

    local function updateList()
        doorList:removeChildren()
        if (pageMult * listPageNumber) + 1 > #doors and listPageNumber ~= 0 then
            listPageNumber = listPageNumber - 1
        end
        local temp = pageMult * listPageNumber
        for i = temp + 1, temp + pageMult, 1 do
            if doorNames[i] == nil then

            else
                doorList:addItem(doorNames[i].data.name).onTouch = doorListCallback
            end
        end
        doorList.selectedItem = 1
        previousPage = listPageNumber
        if pageMult * listPageNumber + pageMult < #doors then
            listUpButton.disabled = false
        else
            listUpButton.disabled = true
        end
        if listPageNumber == 0 then
            listDownButton.disabled = true
        end
        listDownButton.disabled = listPageNumber == 0
        listUpButton.disabled = #doors <= temp + pageMult
        allDisable()
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
                    doorPassData = window:addChild(GUI.comboBox(100,23,30,1, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
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

    local function pageCallback(_,button)
        local function canFresh()
            updateList()
        end
        if #doorNames ~= 0 then
            if button.isPos then
                if listPageNumber < #doors/pageMult - 1 then
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
    end

    local function resetDoorCall()
        doors = {}
        database.dataBackup("doorCreation",{})
        allDisable()
        updateList()
    end

    local function exportDoorCall()
        if #doors ~= 0 then
            local expList = {} --format it how the server wants it
            for key, value in pairs(doors) do
                for key2, value2 in pairs(value) do
                    table.insert(expList,{["id"]=key, ["key"]=key2, ["data"]=value2})
                end
            end
            local worked,_,_,_,_, woo = database.send(true,"setdoordata",database.crypt(ser.serialize(expList)))
            if worked and database.crypt(woo,true) == "true" then
                GUI.alert("Success!")
                resetDoorCall()
            else
                GUI.alert("Failed to broadcast door settings.")
            end
        end
    end

    local function setDoorType()
        currentDoor.doorType = doorType.selectedItem
        updateList()
        doorListCallback()
    end
    local function setDoorToggle()
        currentDoor.toggle = doorToggle.selectedItem - 1
        currentDoor.delay = currentDoor.toggle == 0 and 5 or 0
        updateList()
        doorListCallback()
    end
    local function setDoorName()
        currentDoor.name = doorName.text
        updateList()
        doorListCallback()
    end
    local function setDoorDelay()
        currentDoor.delay = doorDelay.text == "" and 5 or tonumber(doorDelay.text) or currentDoor.delay
        updateList()
        doorListCallback()
    end
    local function setDoorSector()
        local disBut = doorSector.selectedItem - 1
        if disBut == 0 then
            currentDoor.sector = false
        else
            currentDoor.sector = userTable.sectors[disBut].uuid
        end
        updateList()
        doorListCallback()
    end

    --Page Setup
    window:addChild(GUI.panel(1,1,37,30,style.listPanel))
    doorList = window:addChild(GUI.list(2, 2, 35, 28, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
    doorList:addItem("HELLO") --if this shows an error occurred
    listPageNumber = 0
    listPageLabel = window:addChild(GUI.label(2,33,3,3,style.listPageLabel,tostring(listPageNumber + 1)))
    listUpButton = window:addChild(GUI.button(8,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "+"))
    listUpButton.onTouch, listUpButton.isPos = pageCallback,true
    listDownButton = window:addChild(GUI.button(12,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "-"))
    listDownButton.onTouch, listDownButton.isPos = pageCallback,false
    listPageLabel2 = window:addChild(GUI.label(43,31,3,3,style.listPageLabel,tostring(listPageNumberPass + 1)))
    listUpButton2 = window:addChild(GUI.button(51,31,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "+"))
    listUpButton2.onTouch, listUpButton2.isPos, listUpButton2.isListNum = pageCallback,true,2
    listDownButton2 = window:addChild(GUI.button(55,31,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "-"))
    listDownButton2.onTouch, listDownButton2.isPos, listDownButton2.isListNum = pageCallback,false,2

    doorName = window:addChild(GUI.input(64,12,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputname))
    doorName.onInputFinished = setDoorName
    doorName.disabled = true
    exportDoor = window:addChild(GUI.button(115,12,8,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "export door"))
    exportDoor.onTouch = exportDoorCall
    exportDoor.disabled = #doors == 0
    resetDoorSave = window:addChild(GUI.button(124,12,7,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "reset"))
    resetDoorSave.onTouch = resetDoorCall
    doorType = window:addChild(GUI.comboBox(64,14,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
    doorType.disabled = true
    doorType:addItem("Unidentified").onTouch = setDoorType
    doorType:addItem("Redstone").onTouch = setDoorType
    doorType:addItem("Bundled Redstone").onTouch = setDoorType
    doorType:addItem("Door/RollDoor").onTouch = setDoorType
    doorToggle = window:addChild(GUI.comboBox(64,16,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
    doorToggle.disabled = true
    doorToggle:addItem("Unidentified").onTouch = setDoorToggle
    doorToggle:addItem("Delay").onTouch = setDoorToggle
    doorToggle:addItem("Toggle").onTouch = setDoorToggle
    doorDelay = window:addChild(GUI.input(64,18,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", "input number"))
    doorDelay.disabled = true
    doorDelay.onInputFinished = setDoorDelay
    if userTable.sectors then
        doorSector = window:addChild(GUI.comboBox(64,20,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
        doorSector.disabled = true
        doorSector:addItem("Unidentified").onTouch = setDoorSector
        doorSector:addItem("No Sector").onTouch = setDoorSector
        for i=1,#userTable.sectors,1 do
            doorSector:addItem(userTable.sectors[i].name).onTouch = setDoorSector
        end
    end
    --doorPassSelf, doorPassData, doorPassAddSelector, doorPassCreate, doorPassDelete, doorPassEdit, doorPassType, doorPassAddHave, doorPassAddAdd, doorPassAddDel
    window:addChild(GUI.label(85,21,1,1,style.passNameLabel,"Select Pass : "))
    doorPassSelf = window:addChild(GUI.comboBox(100,21,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
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
    doorPassType = window:addChild(GUI.comboBox(100,25,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
    doorPassType.disabled = true
    doorPassType:addItem("Supreme")
    doorPassType:addItem("Base")
    doorPassType:addItem("Add")
    doorPassType:addItem("Reject")
    local typeArray = {"supreme","base","add","reject"}
    window:addChild(GUI.label(85,27,1,1,style.passNameLabel,"Manage Add Passes on door"))
    doorPassAddSelector = window:addChild(GUI.comboBox(85,29,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
    doorPassAddSelector.disabled = true
    doorPassAddHave = window:addChild(GUI.comboBox(110,29,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
    doorPassAddHave.disabled = true
    doorPassAddAdd = window:addChild(GUI.button(85,30,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "add pass"))
    doorPassAddAdd.onTouch = function()
        local moveMe = doorPassAddSelector:getItem(doorPassAddSelector.selectedItem)
        local newMe = doorPassAddHave:addItem(moveMe.savedData.name)
        newMe.savedData = moveMe.savedData
        if module.debug then GUI.alert("savedData: " .. ser.serialize(newMe.savedData)) end
        doorPassAddSelector:removeItem(doorPassAddSelector.selectedItem)
        if doorPassAddSelector:count() == 0 then --ERROR
            doorPassAddAdd.disabled = true
        end
        doorPassAddDel.disabled = false
    end
    doorPassAddAdd.disabled = true
    doorPassAddDel = window:addChild(GUI.button(115,30,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "remove pass"))
    doorPassAddDel.onTouch = function()
        local moveMe = doorPassAddHave:getItem(doorPassAddHave.selectedItem)
        local newMe = doorPassAddSelector:addItem(moveMe.savedData.name)
        newMe.savedData = moveMe.savedData
        doorPassAddHave:removeItem(doorPassAddHave.selectedItem)
        if doorPassAddHave:count() == 0 then
            doorPassAddDel.disabled = true
        end
        doorPassAddAdd.disabled = false
    end --TODO: Almost everything seems fine. A panel is needed behind the 1st list and some issues with delay (mostly) Next: some hardcore testing. Base passes still don't work with the add passes :(
    doorPassAddDel.disabled = true
    doorPassCreate = window:addChild(GUI.button(85,32,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.addvar))
    doorPassCreate.onTouch = function()
        local passFunc = function(type,num,selected)
            local newRules = {["uuid"]=uuid.next(),["request"]=typeArray[type],["data"]=type == 2 and {} or false}
            if selected == 0 then
                newRules.call = "checkstaff"
                newRules.param = 0
            else
                newRules["tempint"] = selected
                newRules["call"] = userTable.passSettings.calls[selected]
                if userTable.passSettings.type[selected] == "string" or userTable.passSettings.type[selected] == "-string" then
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
        local needPass = passFunc(doorPassType.selectedItem,nil,doorPassSelf.selectedItem - 1)

        table.insert(currentDoor.cardRead.normal,needPass)
        if needPass.request == "add" then
            currentDoor.cardRead.add[needPass.uuid] = needPass
        end
        doorListCallback()
    end
    doorPassCreate.disabled = true
    doorPassDelete = window:addChild(GUI.button(100,32,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.delvar))
    doorPassDelete.onTouch = function()

        local otSel = pageMultPass * listPageNumberPass + doorPassList.selectedItem
        if currentDoor.cardRead.normal[otSel].request == "add" then
            for i=1,#currentDoor.cardRead.normal,1 do
                if currentDoor.cardRead.normal[i].request == "base" then
                    for j=1,#currentDoor.cardRead.normal[i].data,1 do
                        if currentDoor.cardRead.normal[i].data[j] == currentDoor.cardRead.normal[otSel].uuid then
                            table.remove(currentDoor.cardRead.normal[i].data,j)
                            break
                        end
                    end
                end
            end
            currentDoor.cardRead.add[currentDoor.cardRead.normal[otSel].uuid] = nil
        end
        table.remove(currentDoor.cardRead.normal,otSel)
        doorListCallback()
    end
    doorPassDelete.disabled = true
    doorPassEdit = window:addChild(GUI.button(115,32,14,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.editvar))
    doorPassEdit.onTouch = function()

        local otSel = pageMultPass * listPageNumberPass + doorPassList.selectedItem
        if currentDoor.cardRead.normal[otSel].request == "add" then
            GUI.alert("This is an add pass, meaning any passes with this add pass will have it unlinked to the pass.")
            for i=1,#currentDoor.cardRead.normal,1 do
                if currentDoor.cardRead.normal[i].request == "base" then
                    for j=1,#currentDoor.cardRead.normal[i].data,1 do
                        if currentDoor.cardRead.normal[i].data[j] == currentDoor.cardRead.normal[otSel].uuid then
                            table.remove(currentDoor.cardRead.normal[i].data,j)
                            break
                        end
                    end
                end
            end
            currentDoor.cardRead.add[currentDoor.cardRead.normal[otSel].uuid] = nil
        end
        local old = currentDoor.cardRead.normal[otSel]
        table.remove(currentDoor.cardRead.normal,otSel)
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
                    if doorPassAddSelector:getItem(j).savedData.call == old.data[i] then --TEST: Does not add ANY passes over to the have when editing
                        local moveMe = doorPassAddSelector:getItem(j)
                        local newMe = doorPassAddHave:addItem(moveMe.savedData.name)
                        newMe.savedData = moveMe.savedData
                        doorPassAddSelector:removeItem(j)
                        if doorPassAddSelector:count() == 0 then
                            doorPassAddAdd.disabled = true
                        end
                        doorPassAddDel.disabled = false
                        break
                    end
                end
            end
        end
        doorListCallback(true)
    end
    doorPassEdit.disabled = true


    updateList()
else
    GUI.alert("No connection received")
end
