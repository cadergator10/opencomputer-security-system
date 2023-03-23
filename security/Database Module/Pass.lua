--A second file I created to be able to store all the pass editing in a seperate file
local workspace, window, loc, database, style, permissions, userTable = table.unpack({...})

local component = require("component")
local ser = require("serialization")
local GUI = require("GUI")
local uuid = require("uuid")
local event = require("event")
local fs = require("Filesystem")
local system = require("System")
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

local function padNew()
    if padNewKey.text ~= "" then
        userTable.securityKeypads[padNewKey.text] = {["pass"]="1234",["label"]=padNewKey.text}
        padNewKey.text = ""
        updateKeyList()
    end
end

local function padDel()
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
local addVarButton, delVarButton, editVarButton, updateVarButton, clearVarButton varKeyInput, varLabelInput, varTypeSelect, addVarArray extraVar1, extraVar2, extraVar3 --NOTE: Updatevarbutton works in both add and edit mode
local varMode = "none" --Indicates the mode, so pressing add button knows what to do when pressed. add means that a new one is added to the list. edit means var will be edited. none means nothing will happen (just in case)



--Create keypad stuff
window:addChild(GUI.label(1,1,3,3,style.passNameLabel,"Global Keypads"))
padBox = window:addChild(GUI.comboBox(1,3,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
padDel = window:addChild(GUI.button(22,3,10,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.delete))
padDel.onTouch = padDel
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
padNew.onTouch = padNew
padNew.disabled = canPad
padNewKey = window:addChild(GUI.input(1,8,20,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", "input key"))
padNewKey.disabled = canPad
window:addChild(GUI.panel(34,1,1,8,style.bottomDivider)) --Create pass creation stuff
window:addChild(GUI.label(36,1,3,3,style.passNameLabel,"Pass Management"))
updateKeyList()