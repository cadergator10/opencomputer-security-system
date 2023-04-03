--A second file I created to be able to store all the pass editing in a seperate file
local workspace, window, loc, database, style, permissions, userTable = table.unpack({...})

local component = require("component")
local ser = require("serialization")
local GUI = require("GUI")
local uuid = require("uuid")
local modem = component.modem

local modemPort = 199

--Variable declarations for keypad stuff
local padBox, padLabel, padPass, padNew, padNewKey, padDel
local canPad = database.checkPerms("security",{"varmanagement","keypad"},true) --whether they have keypad perms
local canPass = database.checkPerms("security",{"varmanagement"},true)

local function split(s, delimiter) --splits string to table. "e,f,g" to {"e","f","g"}
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

local function keypadCallback(_,button)
    if padBox:count() > 0 then
        local selected = padBox.selectedItem
        padLabel.text = userTable.securityKeypads[button.key].label
        padPass.text = canPad and "****" or userTable.securityKeypads[button.key].pass
        padLabel.disabled = canPad
        padPass.disabled = canPad
    end
end

local function updateKeyList()
    database.save()
    local selected = padBox.selectedItem
    if padBox:count() > 0 then
        padBox:clear()
    end
    for  key,value in pairs(userTable.securityKeypads) do
        local meh = padBox:addItem(key)
        meh.key = key
        meh.onTouch = keypadCallback
    end
    if padBox:count() < selected then
        selected = selected - 1
    end
    padDel.disabled = true
    if padBox:count() ~= 0 then
        padDel.disabled = false
        padBox.selectedItem = selected
    end
    database.update({"securityKeypads"})
end

local function padNewF()
    if padNewKey.text ~= "" then
        userTable.securityKeypads[padNewKey.text] = {["pass"]="1234",["label"]=padNewKey.text}
        padNewKey.text = ""
        updateKeyList()
    end
end

local function padDelF()
    local selected = padBox.selectedItem
    local sel = padBox:getItem(selected)
    userTable.securityKeypads[sel.key] = nil
    padLabel.disabled = true
    padPass.disabled = true
    updateKeyList()
end

local function passLabelCallback()
    local selected = padBox:getItem(padBox.selectedItem)
    userTable.securityKeypads[selected.key].label = padLabel.text
end

local function passInputCallback()
    local selected = padBox:getItem(padBox.selectedItem)
    if tonumber(padPass.text) ~= nil and tonumber(padPass.text) >= 1000 and tonumber(padPass.text) <= 9999 then
        userTable.securityKeypads[selected.key].pass = padPass.text
    else
        padPass.text = userTable.securityKeypads[selected.key].pass
    end
end

--Variable declarations for Variable pass stuff
local addVarButton, delVarButton, editVarButton, updateVarButton, clearVarButton, varList, varLabel, varDesc
local varKeyInput, varLabelInput, varTypeSelect, addVarArray, extraVar, extraVar2 --NOTE: Updatevarbutton works in both add and edit mode
local varMode = "none" --Indicates the mode, so pressing add button knows what to do when pressed. add means that a new one is added to the list. edit means var will be edited. none means nothing will happen (just in case)

local function passComboPress()
    local describe = {["string"]="Regular String",["-string"]="Multi String",["int"]="Level",["-int"]="Group",["bool"]="Bool"}
    local selected = varList.selectedItem
    varLabel.text = "Label: " .. userTable.passSettings.label[selected]
    varDesc.text = "Desc: " .. describe[userTable.passSettings.type[selected]]
    if userTable.passSettings.type[selected] == "string" or userTable.passSettings.type[selected] == "-string" then
        varDesc.text = varDesc.text .. " | " .. (userTable.passSettings.data[selected] == 1 and "Editable" or userTable.passSettings.data[selected] == 2 and "Uneditable" or "Hidden")
    elseif userTable.passSettings.type[selected] == "int" then
        varDesc.text = varDesc.text .. " | " .. (userTable.passSettings.above[selected] and "Checks above" or "Checks exact")
    elseif userTable.passSettings.type[selected] == "-int" then
        varDesc.text = varDesc.text .. " | " .. tostring(#userTable.passSettings.data[selected]) .. " groups"
    end
    editVarButton.disabled = userTable.passSettings.type[selected] == "bool" and true or false
    delVarButton.disabled = false
end

local function updatePassCombo()
    if varList:count() > 0 then
        varList:clear()
    end
    for i=1,#userTable.passSettings.var,1 do
        local k = varList:addItem(userTable.passSettings.var[i])
        k.onTouch = passComboPress
    end
    varLabel.text = "Label: NAN"
    varDesc.text = "Desc: NAN"
    editVarButton.disabled = true
    delVarButton.disabled = true
end

local function checkTypeCallback() --Used when creating a var and choosing the type of var, or if editing
    local typeArray = {"string","-string","int","-int","bool"}
    local selected = varTypeSelect.selectedItem
    if varMode == "add" then --if add, it sets it all to default
        addVarArray.above = false
        addVarArray.data = false
        addVarArray.type = typeArray[selected]
    end
    if extraVar ~= nil then --if already populated, remove first so it can be readded
        extraVar:remove()
        extraVar = nil
    end
    --Merged edit and add mode checks
    if selected == 3 then --int (number)
        extraVar = window:addChild(GUI.button(36,19,32,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.newvarcheckabove))
        extraVar.onTouch = function() --a button to determine whether to check above or not. Checkabove means if needed 1 and they have 3, it lets them in. If false, 3 doesn't work
            addVarArray.above = extraVar.pressed
        end
        extraVar.switchMode = true
        if varMode == "edit" then
            extraVar.pressed = addVarArray.above
        else
            addVarArray.data = false
        end
    elseif selected == 4 then -- -int (groups)
        extraVar = window:addChild(GUI.input(36,19,32,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.newvargroup))
        extraVar.onInputFinished = function() --Input the groups into a textbox splitting with a comma
            addVarArray.data = split(extraVar.text,",")
        end
        if varMode == "edit" then
            local isme = addVarArray.data[1]
            for i=2,#addVarArray.data,1 do --combine back into a string to be rejoined after saving
                isme = isme .. "," .. addVarArray.data[i]
            end
            extraVar.text = isme
        else
            addVarArray.data = ""
        end
    elseif selected == 1 or selected == 2 then --string or -string
        extraVar = window:addChild(GUI.comboBox(36,19,32,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
        local sub = function()
            addVarArray.data = extraVar.selectedItem
        end --you choose whether they can edit it, only view it, or can't see it (only changed by setVar and getVar)
        extraVar:addItem("Editable").onTouch = sub
        extraVar:addItem("Uneditable").onTouch = sub
        extraVar:addItem("Hidden").onTouch = sub
        if varMode == "edit" then
            extraVar.selectedItem = addVarArray.data
        else
            addVarArray.data = 1
        end
    else --bool (no config and shouldn't be able to edit at all)
        extraVar = window:addChild(GUI.label(36,19,3,3,style.passNameLabel,"NAN"))
        if varMode == "add" then
            addVarArray.data = false
        end
    end
end

local function clearVarF() --Clear current stuff on creation area
    varKeyInput.text = ""
    varKeyInput.disabled = true
    varLabelInput.text = ""
    varLabelInput.disabled = true
    varTypeSelect.selectedItem = 5
    varTypeSelect.disabled = true
    addVarArray = nil
    if extraVar ~= nil then
        extraVar:remove()
        extraVar = window:addChild(GUI.label(36,19,3,3,style.passNameLabel,"NAN"))
    end
    updateVarButton.disabled = true
    clearVarButton.disabled = true
    varMode = "none"
end

local function addVarF() --Prep creation area for adding a var
    if varMode == "none" then
        varKeyInput.disabled = false
        varLabelInput.disabled = false
        varTypeSelect.disabled = false
        varTypeSelect.selectedItem = 5
        addVarArray = {["var"]="",["label"]="",["calls"]=uuid.next(),["type"]="bool",["above"]=false,["data"]=false}
        extraVar2 = nil
        updateVarButton.disabled = false
        clearVarButton.disabled = false
        varMode = "add"
    else
        GUI.alert("Please clear current changes in var edit mode before adding a var")
    end
end

local function editVarF() --Prep creation area for editing a var
    if varMode == "none" then
        local selected = varList.selectedItem
        addVarArray = {["var"]=userTable.passSettings.var[selected],["label"]=userTable.passSettings.label[selected],["type"]=userTable.passSettings.type[selected],["above"]=userTable.passSettings.above[selected],["data"]=userTable.passSettings.data[selected]}
        varKeyInput.disabled = true
        varKeyInput.text = addVarArray.var
        varLabelInput.disabled = false
        varLabelInput.text = addVarArray.label
        varTypeSelect.disabled = true
        varTypeSelect.selectedItem = addVarArray.type == "string" and 1 or addVarArray.type == "-string" and 2 or addVarArray.type == "int" and 3 or addVarArray.type == "-int" and 4 or 5
        extraVar2 = nil
        updateVarButton.disabled = false
        clearVarButton.disabled = false
        varMode = "edit"
        checkTypeCallback()
    else
        GUI.alert("Please clear current changes in var edit mode before editing a var")
    end
end

local function delVarF() --delete a created var
    local selected = varList.selectedItem
    table.remove(userTable.passSettings.data,selected)
    table.remove(userTable.passSettings.label,selected)
    table.remove(userTable.passSettings.calls,selected)
    table.remove(userTable.passSettings.type,selected)
    table.remove(userTable.passSettings.above,selected)
    for i=1,#userTable.passes,1 do
        userTable.passes[i][userTable.passSettings.var[selected]] = nil
    end
    table.remove(userTable.passSettings.var,selected)
    database.save()
    database.update({"passes","passSettings"})
    updatePassCombo()
end

local searchBase = {"name","blocked","staff","uuid","link","mcid"}

local function updateVarF() --Either add or change (depending on add or edit mode) a var
    if varMode == "add" then
        if addVarArray.var ~= "" and addVarArray.label ~= "" then
            local skipAll = false
            for _, value in pairs(searchBase) do
                if value == addVarArray.var then
                    skipAll = true
                    break
                end
            end
            if not skipAll then
                for _, value in pairs(userTable.passSettings.var) do
                    if value == addVarArray.var then
                        skipAll = true
                        break
                    end
                end
            end
            if not skipAll then
                for i=1,#userTable.passes,1 do
                    if addVarArray.type == "string" then
                        userTable.passes[i][addVarArray.var] = "none"
                    elseif addVarArray.type == "-string" then
                        userTable.passes[i][addVarArray.var] = {}
                    elseif addVarArray.type == "int" or addVarArray.type == "-int" then
                        userTable.passes[i][addVarArray.var] = 0
                    elseif addVarArray.type == "bool" then
                        userTable.passes[i][addVarArray.var] = false
                    else
                        GUI.alert(loc.addvaralert)
                        return
                    end
                end
                table.insert(userTable.passSettings.var,addVarArray.var)
                table.insert(userTable.passSettings.label,addVarArray.label)
                table.insert(userTable.passSettings.calls,addVarArray.calls)
                table.insert(userTable.passSettings.type,addVarArray.type)
                table.insert(userTable.passSettings.above,addVarArray.above)
                table.insert(userTable.passSettings.data,addVarArray.data)
                database.save()
                database.update({"passes","passSettings"})
                clearVarF()
                updatePassCombo()
            else
                GUI.alert("Var key conflicts with another one already created. Please change it.")
            end
        else
            GUI.alert("Please add a var key or label before updating")
        end
    elseif varMode == "edit" then
        local selected = 1
        for _,value in pairs(userTable.passSettings.var) do
            if value == addVarArray.var then
                break
            else
                selected = selected + 1
            end
        end
        if selected <= #userTable.passSettings.var then
            if userTable.passSettings.type[selected] == "int" then
                userTable.passSettings.above[selected] = addVarArray.above
            elseif userTable.passSettings.type[selected] == "-int" or userTable.passSettings.type[selected] == "string" or userTable.passSettings.type[selected] == "-string" then
                userTable.passSettings.data[selected] = addVarArray.data
            end
            userTable.passSettings.label[selected] = addVarArray.label
            database.save()
            database.update({"passes","passSettings"})
            clearVarF()
            updatePassCombo()
        else
            GUI.alert("Var not found in the list. Was it deleted?")
        end
    end
end

local function onVarKeyInput()
    addVarArray.var = varKeyInput.text
end

local function onVarLabelInput()
    addVarArray.label = varLabelInput.text
end

--Create keypad stuff
window:addChild(GUI.label(1,1,3,3,style.passNameLabel,"Global Keypads"))
padBox = window:addChild(GUI.comboBox(1,3,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
padDel = window:addChild(GUI.button(22,3,10,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.delete))
padDel.onTouch = padDelF
padDel.disabled = true
window:addChild(GUI.label(1,5,3,3,style.passNameLabel,"Label"))
padLabel = window:addChild(GUI.input(1,6,15,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputname))
padLabel.onInputFinished = passLabelCallback
padLabel.disabled = true
window:addChild(GUI.label(17,5,3,3,style.passNameLabel,"Pin / Password"))
padPass = window:addChild(GUI.input(17,6,15,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputpass))
padPass.onInputFinished = passInputCallback
padPass.disabled = true
padNew = window:addChild(GUI.button(22,8,7,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.new))
padNew.onTouch = padNewF
padNew.disabled = canPad
padNewKey = window:addChild(GUI.input(1,8,20,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", "input key"))
padNewKey.disabled = canPad
window:addChild(GUI.panel(34,2,1,28,style.bottomDivider)) --Create pass creation stuff
window:addChild(GUI.label(36,1,3,3,style.passNameLabel,"Pass Management"))
varList = window:addChild(GUI.comboBox(36,3,32,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
varList.disabled = canPass
varLabel = window:addChild(GUI.label(36,5,3,3,style.passNameLabel,"Label: NAN"))
varDesc = window:addChild(GUI.label(36,7,3,3,style.passNameLabel,"Desc: NAN"))
addVarButton = window:addChild(GUI.button(36,9,10,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.addvar))
addVarButton.onTouch = addVarF
addVarButton.disabled = canPass
editVarButton = window:addChild(GUI.button(47,9,10,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.editvar))
editVarButton.onTouch = editVarF
editVarButton.disabled = true
delVarButton = window:addChild(GUI.button(58,9,10,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.delvar))
delVarButton.onTouch = delVarF
delVarButton.disabled = true
window:addChild(GUI.panel(36,11,32,1,style.bottomDivider))
varKeyInput = window:addChild(GUI.input(36,13,32,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.newvarkey))
varKeyInput.onInputFinished = onVarKeyInput
varKeyInput.disabled = true
varLabelInput = window:addChild(GUI.input(36,15,32,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.newvarlabel))
varLabelInput.onInputFinished = onVarLabelInput
varLabelInput.disabled = true
varTypeSelect = window:addChild(GUI.comboBox(36,17,32,1, style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
local lik = varTypeSelect:addItem("String")
lik.onTouch = checkTypeCallback --every time one is selected it refreshes the extra setting needed for certain choices
lik = varTypeSelect:addItem("Multi-String")
lik.onTouch = checkTypeCallback
lik = varTypeSelect:addItem("Level (Int)")
lik.onTouch = checkTypeCallback
lik = varTypeSelect:addItem("Group")
lik.onTouch = checkTypeCallback
lik = varTypeSelect:addItem("Pass (true/false)")
lik.onTouch = checkTypeCallback
varTypeSelect.selectedItem = 5
extraVar = window:addChild(GUI.label(36,19,3,3,style.passNameLabel,"NAN"))
updateVarButton = window:addChild(GUI.button(36,21,20,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.update))
updateVarButton.onTouch = updateVarF
updateVarButton.disabled = true
clearVarButton = window:addChild(GUI.button(36,23,20,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "clear"))
clearVarButton.onTouch = clearVarF
clearVarButton.disabled = true

updateKeyList()
updatePassCombo()