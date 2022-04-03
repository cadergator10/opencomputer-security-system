local GUI = require("GUI")
local system = require("System")
local modemPort = 199
local dbPort = 144

local adminCard = "admincard"

local showUUIDWarn = true
 
 
local component = require("component")
local gpu = component.gpu
local event = require("event")
local ser = require("serialization")
local uuid = require("uuid")
local fs = require("Filesystem")
local writer

local aRD = fs.path(system.getCurrentScript())
 
----------
 
local workspace, window, menu
local cardStatusLabel, userList, userNameText, createAdminCardButton, userUUIDLabel, linkUserButton, linkUserLabel
local cardBlockedYesButton, userNewButton, userDeleteButton, userChangeUUIDButton, listPageLabel, listUpButton, listDownButton
local addVarButton, delVarButton, varInput, labelInput, typeSelect, extraVar, varContainer, addVarArray, varYesButton
 
local baseVariables = {"name","uuid","date","link","blocked","staff"} --Usertable.settings = {["var"]="level",["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false}}
local guiCalls = {}
--[[set up on startup according to extra modifiers added by user.
If type is string, [1] = text input.
If type is -string, [1] = text label.
If type is bool, [1] = toggleable button.
If type is int, [1] = minus button, [2] = plus button, [3] = value label.
If type is -int, [1] = minus button, [2] = plus button, [3] = value label, [4] = {array of string values}
]]
----------
 
local prgName = "Security database"
local version = "v2.2.0"
 
local modem
 
local pageMult = 10
local listPageNumber = 0
local previousPage = 0

----------- Site 91 specific configuration (to avoid breaking commercial systems, don't enable)
local enableLinking = false
-----------

if component.isAvailable("os_cardwriter") then
    writer = component.os_cardwriter
else
    GUI.alert("This requires an Open Security card writer to run")
    return
end
if component.isAvailable("modem") then
    modem = component.modem
else
    GUI.alert("This requires a modem to run")
    return
end

-----------
 
local function convert( chars, dist, inv )
  return string.char( ( string.byte( chars ) - 32 + ( inv and -dist or dist ) ) % 95 + 32 )
end
 
local function split(s, delimiter)
  result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match);
  end
  return result;
end 

local function crypt(str,k,inv)
  local enc= "";
  for i=1,#str do
    if(#str-k[5] >= i or not inv)then
      for inc=0,3 do
    if(i%4 == inc)then
      enc = enc .. convert(string.sub(str,i,i),k[inc+1],inv);
      break;
    end
      end
    end
  end
  if(not inv)then
    for i=1,k[5] do
      enc = enc .. string.char(math.random(32,126));
    end
  end
  return enc;
end
 
--// exportstring( string )
--// returns a "Lua" portable version of the string
local function exportstring( s )
    s = string.format( "%q",s )
    -- to replace
    s = string.gsub( s,"\\\n","\\n" )
    s = string.gsub( s,"\r","\\r" )
    s = string.gsub( s,string.char(26),"\"..string.char(26)..\"" )
    return s
end
--// The Save Function
function saveTable(  tbl,filename )
    local tableFile = fs.open(filename, "w")
  	tableFile:write(ser.serialize(tbl))
  	tableFile:close()
end

--// The Load Function
function loadTable( sfile )
    local tableFile = fs.open(sfile, "r")
    if tableFile ~= nil then
  		return ser.unserialize(tableFile:readAll())
    else
        return nil
    end
end
 
----------Callbacks
function updateServer()
  local data = ser.serialize(userTable)
  local crypted = crypt(data, settingTable.cryptKey)
  if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
  end
  modem.broadcast(modemPort, "updateuserlist", crypted)
end
 
function updateList()
  selectedId = userList.selectedItem
  userList:remove()
  userList = window:addChild(GUI.list(4, 4, 58, 34, 3, 0, 0xE1E1E1, 0x4B4B4B, 0xD2D2D2, 0x4B4B4B, 0x3366CC, 0xFFFFFF, false)) 
  local temp = pageMult * listPageNumber
  for i = temp + 1, temp + pageMult, 1 do
  if (userTable[i] == nil) then

  else
    userList:addItem(userTable[i].name).onTouch = userListCallback
  end
  end

  saveTable(userTable, aRD .. "userlist.txt")
  if (previousPage == listPageNumber) then
  userList.selectedItem = selectedId
  else
  previousPage = listPageNumber
  end
  updateServer()
end
 
function eventCallback(ev, id)
  if ev == "cardInsert" then
    cardStatusLabel.text = "   Card present"
  elseif ev == "cardRemove" then
    cardStatusLabel.text = "     No card   "
  end
end
 
function userListCallback()
  selectedId = pageMult * listPageNumber + userList.selectedItem
  userNameText.text = userTable[selectedId].name
  userUUIDLabel.text = "UUID      : " .. userTable[selectedId].uuid
  if enableLinking == true then 
        linkUserLabel.text = "LINK      : " .. userTable[selectedId].link
        linkUserButton.disabled = false
  end
  if userTable[selectedId].blocked == true then
    cardBlockedYesButton.pressed = true
  else
    cardBlockedYesButton.pressed = false
  end
  cardBlockedYesButton.disabled = false
  if userTable[selectedId].staff == true then
    StaffYesButton.pressed = true
  else
    StaffYesButton.pressed = false
  end
  StaffYesButton.disabled = false
  listPageLabel.text = tostring(listPageNumber + 1)
  userNameText.disabled = false
  for i=1,#userTable.settings.var,1 do
    if userTable.settings.type[i] == "bool" then
      guiCalls[i][1].pressed = userTable[selectedId][userTable.settings.var[i]]
      guiCalls[i][1].disabled = false
    elseif userTable.settings.type[i] == "string" or userTable.settings.type[i] == "-string" then
      guiCalls[i][1].text = tostring(userTable[selectedId][userTable.settings.var[i]])
      if userTable.settings.type[i] == "string" then guiCalls[i][1].disabled = false end
    elseif userTable.settings.type[i] == "int" or userTable.settings.type[i] == "-int" then
      if userTable.settings.type[i] == "-int" then
        guiCalls[i][3].text = tostring(guiCalls[i][4][userTable[selectedId][userTable.settings.var[i]]] or "none")
      else
        guiCalls[i][3].text = tostring(userTable[selectedId][userTable.settings.var[i]])
      end
      guiCalls[i][1].disabled = false
      guiCalls[i][2].disabled = false
    else
      GUI.alert("Potential error in line 157 in function userListCallback()")
    end
  end
end
 
function buttonCallback(workspace, button)
  local buttonInt = button.buttonInt
  local callbackInt = button.callbackInt
  local isPos = button.isPos
  local selected = pageMult * listPageNumber + userList.selectedItem
  if callbackInt > #baseVariables then
    callbackInt = callbackInt - #baseVariables
    if userTable.settings.type[callbackInt] == "string" then
      userTable[selected][userTable.settings.var[callbackInt]] = guiCalls[buttonInt][1].text
    elseif userTable.settings.type[callbackInt] == "bool" then
      userTable[selected][userTable.settings.var[callbackInt]] = guiCalls[buttonInt][1].pressed
    elseif userTable.settings.type[callbackInt] == "int" then
      if isPos == true then
        if userTable[selected][userTable.settings.var[callbackInt]] < 100 then
          userTable[selected][userTable.settings.var[callbackInt]] = userTable[selected][userTable.settings.var[callbackInt]] + 1
        end
      else
        if userTable[selected][userTable.settings.var[callbackInt]] > 0 then
          userTable[selected][userTable.settings.var[callbackInt]] = userTable[selected][userTable.settings.var[callbackInt]] - 1
        end
      end
    elseif userTable.settings.type[callbackInt] == "-int" then
      if isPos == true then
        if userTable[selected][userTable.settings.var[callbackInt]] < #userTable.settings.data[callbackInt] then
          userTable[selected][userTable.settings.var[callbackInt]] = userTable[selected][userTable.settings.var[callbackInt]] + 1
        end
      else
        if userTable[selected][userTable.settings.var[callbackInt]] > 0 then
          userTable[selected][userTable.settings.var[callbackInt]] = userTable[selected][userTable.settings.var[callbackInt]] - 1
        end
      end
    else
      GUI.alert("error in button callback with button id: " .. buttonInt)
      return
    end
  else
    --userTable[selected][baseVariables[callbackInt]]
  end
  updateList()
  userListCallback()
end

function staffUserCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  userTable[selected].staff = StaffYesButton.pressed
  updateList()
  userListCallback()
end
 
function blockUserCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  userTable[selected].blocked = cardBlockedYesButton.pressed
  updateList()
  userListCallback()
end
 
function newUserCallback()
  local tmpTable = {["name"] = "new", ["blocked"] = false, ["date"] = os.date(), ["staff"] = false, ["uuid"] = uuid.next(), ["link"] = "nil"}
  for i=1,#userTable.settings.var,1 do
    if userTable.settings.type[i] == "string" or userTable.settings.type[i] == "-string" then
      tmpTable[userTable.settings.var[i]] = "none"
    elseif  userTable.settings.type[i] == "bool" then
      tmpTable[userTable.settings.var[i]] = false
    elseif userTable.settings.type[i] == "int" or userTable.settings.type[i] == "-int" then
      tmpTable[userTable.settings.var[i]] = 0
    end
  end
  table.insert(userTable, tmpTable)
  updateList()
end
 
function deleteUserCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  userTable[selected] = nil
  updateList()
  userNameText.text = ""
  userNameText.disabled = true
  StaffYesButton.disabled = true
  for i=1,#userTable.settings.var,1 do
    local tmp = userTable.settings.type[i]
    if tmp == "string" or tmp == "-string" or tmp == "bool" then
      if tmp ~= "bool" then guiCalls[i][1].text = "" end
      if tmp ~= "-string" then guiCalls[i][1].disabled = true end
    elseif tmp == "int" or tmp == "-int" then
      if tmp == "-int" then
        guiCalls[i][3] = "NAN"
      else
        guiCalls[i][3] = "#"
      end
      guiCalls[i][1].disabled = true
      guiCalls[i][2].disabled = true
    end
  end
  if enableLinking == true then linkUserButton.disabled = true end
end

function changeUUID()
    if showUUIDWarn == true then
        showUUIDWarn = false
        GUI.alert("This will reset this user's uuid, rendering all cards linked to it useless. Use this if a card gets stolen or in another emergency. Use at own risk.")
    else
        local selected = pageMult * listPageNumber + userList.selectedItem
        userTable[selected].uuid = uuid.next()
        updateList()
  		userListCallback()
    end
end
 
function writeCardCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  local data = {["date"]=userTable[selected].date,["name"]=userTable[selected].name,["uuid"]=userTable[selected].uuid}
  data = ser.serialize(data)
  local crypted = crypt(data, settingTable.cryptKey)
  writer.write(crypted, userTable[selected].name .. "'s security pass", false, 0)
end

function writeAdminCardCallback()
  local data =  adminCard
  local crypted = crypt(data, settingTable.cryptKey)
  writer.write(crypted, "ADMIN DIAGNOSTIC CARD", false, 14)
end

function pageCallback(isPos)
  if isPos then
    if listPageNumber < #userTable/pageMult - 1 then
      listPageNumber = listPageNumber + 1
    end
  else
    if listPageNumber > 0 then
      listPageNumber = listPageNumber - 1
    end
  end
  updateList()
  userListCallback()
end
 
function inputCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  userTable[selected].name = userNameText.text
  updateList()
  userListCallback()
end

function linkUserCallback()
    local container = GUI.addBackgroundContainer(workspace, false, true, "You have 20 seconds to link your device now. do not click anything")
    local selected = pageMult * listPageNumber + userList.selectedItem
    modem.open(dbPort)
    local e, _, from, port, _, msg = event.pull(20)
    container:remove()
    if e == "modem_message" then
        local data = crypt(msg,settingTable.cryptKey,true)
        userTable[selected].link = data
        modem.send(from,port,crypt(userTable[selected].name,settingTable.cryptKey))
        GUI.alert("Link successful")
    else
        userTable[selected].link = "nil"
        GUI.alert("failed link")
    end
    modem.close(dbPort)
    updateList()
    userListCallback()
end

function checkTypeCallback()
  addVarArray.above = false
  addVarArray.data = false
  local typeArray = {"string","-string","int","-int","bool"}
  local selected = typeSelect.selectedItem
  addVarArray.type = typeArray[selected]
  if extraVar ~= nil then
    extraVar:remove()
    extraVar = nil
  end
  if selected == 3 then
    extraVar = varContainer.layout:addChild(GUI.button(1,16,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "check above value"))
      extraVar.onTouch = function()
      addVarArray.above = extraVar.pressed
    end
    extraVar.switchMode = true
  elseif selected == 4 then
    extraVar = varContainer.layout:addChild(GUI.input(1,16,16,1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "groups (comma seperating each group)"))
    extraVar.onInputFinished = function()
    addVarArray.data = split(extraVar.text,",")
    end
  else
    
  end
end

function addVarYesCall()
  for i=1,#userTable,1 do
    if addVarArray.type == "string" or addVarArray.type == "-string" then
      userTable[i][addVarArray.var] = "none"
    elseif addVarArray.type == "int" or addVarArray.type == "-int" then
      userTable[i][addVarArray.var] = 0
    elseif addVarArray.type == "bool" then
      userTable[i][addVarArray.var] = false
    else
      GUI.alert("Error occured in addVarYesCall function. Please report this to author.")
        varContainer:removeChildren()
        varContainer:remove()
        varContainer = nil
      return
    end
  end
  table.insert(userTable.settings.var,addVarArray.var)
  table.insert(userTable.settings.label,addVarArray.label)
  table.insert(userTable.settings.calls,addVarArray.calls)
  table.insert(userTable.settings.type,addVarArray.type)
  table.insert(userTable.settings.above,addVarArray.above)
  table.insert(userTable.settings.data,addVarArray.data)
  addVarArray = nil
  varContainer:removeChildren()
  varContainer:remove()
  varContainer = nil
  saveTable(userTable,aRD .. "userlist.txt")
  GUI.alert("New variable added. App will be auto closed and changes will be applied on next start.")
  window:remove()
end

--TEST: Check if this successfully adds and removes variables.
function addVarCallback()
  addVarArray = {["var"]="placeh",["label"]="PlaceHold",["calls"]=uuid.next(),["type"]="string",["above"]=false,["data"]=false}
  varContainer = GUI.addBackgroundContainer(workspace, true, true)
  varInput = varContainer.layout:addChild(GUI.input(1,1,16,1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "variable key"))
  varInput.onInputFinished = function()
    addVarArray.var = varInput.text
  end
  labelInput = varContainer.layout:addChild(GUI.input(1,6,16,1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "variable label"))
  labelInput.onInputFinished = function()
    addVarArray.label = labelInput.text
  end
  typeSelect = varContainer.layout:addChild(GUI.comboBox(1,11,30,3, 0xEEEEEE, 0x2D2D2D, 0xCCCCCC, 0x888888))
  typeSelect:addItem("String").onTouch = checkTypeCallback
  typeSelect:addItem("Hidden String").onTouch = checkTypeCallback
  typeSelect:addItem("Level (Int)").onTouch = checkTypeCallback
  typeSelect:addItem("Group").onTouch = checkTypeCallback
  typeSelect:addItem("Pass (true/false)").onTouch = checkTypeCallback
  varYesButton = varContainer.layout:addChild(GUI.button(1,21,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "add variable to system"))
  varYesButton.onTouch = addVarYesCall
end

function delVarYesCall()
  local selected = typeSelect.selectedItem
  table.remove(userTable.settings.data,selected)
  table.remove(userTable.settings.label,selected)
  table.remove(userTable.settings.calls,selected)
  table.remove(userTable.settings.type,selected)
  table.remove(userTable.settings.above,selected)
  for i=1,#userTable,1 do
    userTable[i][userTable.settings.var[selected]] = nil
  end
  table.remove(userTable.settings.var,selected)
  varContainer:removeChildren()
  varContainer:remove()
  varContainer = nil
  saveTable(userTable,aRD .. "userlist.txt")
  GUI.alert("Variable removed. App will be auto closed and changes will be applied on next start.")
  window:remove()
end

function delVarCallback()
  varContainer = GUI.addBackgroundContainer(workspace, true, true)
  typeSelect = varContainer.layout:addChild(GUI.comboBox(1,1,30,3, 0xEEEEEE, 0x2D2D2D, 0xCCCCCC, 0x888888))
  for i=1,#userTable.settings.var,1 do
    typeSelect:addItem(userTable.settings.label[i])
  end
  varYesButton = varContainer.layout:addChild(GUI.button(1,21,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "remove variable from system"))
  varYesButton.onTouch = delVarYesCall
end
 
----------GUI SETUP
workspace, window, menu = system.addWindow(GUI.filledWindow(2,2,150,45,0xE1E1E1))
 
local layout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))
 
local contextMenu = menu:addContextMenuItem("File")
contextMenu:addItem("Close").onTouch = function()
window:remove()
  --os.exit()
end
 
window:addChild(GUI.panel(3,3,60,36,0x6B6E74))
userList = window:addChild(GUI.list(4, 4, 58, 34, 3, 0, 0xE1E1E1, 0x4B4B4B, 0xD2D2D2, 0x4B4B4B, 0x3366CC, 0xFFFFFF, false))
userList:addItem("HELLO")
listPageNumber = 0
userTable = loadTable(aRD .. "userlist.txt")
if userTable == nil then
  userTable = {["settings"]={["var"]={"level"},["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false}}}
end
settingTable = loadTable(aRD .. "dbsettings.txt")
if settingTable == nil then
  GUI.alert("It is recommended you check your cryptKey settings in dbsettings.txt file in the app's directory. Currently at default {1,2,3,4,5}. If the server is set to a different cryptKey than this, it will not function and crash the server.")
  settingTable = {["cryptKey"]={1,2,3,4,5}}
  saveTable(settingTable,aRD .. "dbsettings.txt")
end
updateList()
 
--user infos
local labelSpot = 12
window:addChild(GUI.label(64,labelSpot,3,3,0x165FF2,"User name : "))
userNameText = window:addChild(GUI.input(88,labelSpot,16,1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "input name"))
userNameText.onInputFinished = inputCallback
userNameText.disabled = true
labelSpot = labelSpot + 2
userUUIDLabel = window:addChild(GUI.label(64,labelSpot,3,3,0x165FF2,"UUID      : user not selected"))
labelSpot = labelSpot + 2
window:addChild(GUI.label(64,labelSpot,3,3,0x165FF2,"STAFF     : "))
StaffYesButton = window:addChild(GUI.button(88,labelSpot,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "toggle"))
StaffYesButton.switchMode = true
StaffYesButton.onTouch = staffUserCallback
StaffYesButton.disabled = true
labelSpot = labelSpot + 2
window:addChild(GUI.label(64,labelSpot,3,3,0x165FF2,"Blocked   : "))
cardBlockedYesButton = window:addChild(GUI.button(88,labelSpot,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "toggle"))
cardBlockedYesButton.switchMode = true
cardBlockedYesButton.onTouch = blockUserCallback
cardBlockedYesButton.disabled = true
labelSpot = labelSpot + 2
for i=1,#userTable.settings.var,1 do
  local labelText = userTable.settings.label[i]
  local spaceNum = 10 - #labelText
  if spaceNum < 0 then spaceNum = 0 end
  for j=1,spaceNum,1 do
    labelText = labelText .. " "
  end
  labelText = labelText .. ": "
  window:addChild(GUI.label(64,labelSpot,3,3,0x165FF2,labelText))
  guiCalls[i] = {}
  if userTable.settings.type[i] == "string" then
    guiCalls[i][1] = window:addChild(GUI.input(88,labelSpot,16,1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "input text"))
    guiCalls[i][1].buttonInt = i
    guiCalls[i][1].callbackInt = i + #baseVariables
    guiCalls[i][1].onInputFinished = buttonCallback
    guiCalls[i][1].disabled = true
  elseif userTable.settings.type[i] == "-string" then
    guiCalls[i][1] = window:addChild(GUI.label(88,labelSpot,3,3,0x165FF2,"NAN"))
  elseif userTable.settings.type[i] == "int" then
    guiCalls[i][3] = window:addChild(GUI.label(96,labelSpot,3,3,0x165FF2,"#"))
    guiCalls[i][1] = window:addChild(GUI.button(88,labelSpot,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "+"))
    guiCalls[i][1].buttonInt = i
    guiCalls[i][1].callbackInt = i + #baseVariables
    guiCalls[i][1].isPos = true
    guiCalls[i][1].onTouch = buttonCallback
    guiCalls[i][2] = window:addChild(GUI.button(92,labelSpot,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "-"))
    guiCalls[i][2].buttonInt = i
    guiCalls[i][2].callbackInt = i + #baseVariables
    guiCalls[i][2].isPos = false
    guiCalls[i][2].onTouch = buttonCallback
    guiCalls[i][1].disabled = true
    guiCalls[i][2].disabled = true
  elseif userTable.settings.type[i] == "-int" then
    guiCalls[i][3] = window:addChild(GUI.label(96,labelSpot,3,3,0x165FF2,"NAN"))
    guiCalls[i][1] = window:addChild(GUI.button(88,labelSpot,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "+"))
    guiCalls[i][1].buttonInt = i
    guiCalls[i][1].callbackInt = i + #baseVariables
    guiCalls[i][1].isPos = true
    guiCalls[i][1].onTouch = buttonCallback
    guiCalls[i][2] = window:addChild(GUI.button(92,labelSpot,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "-"))
    guiCalls[i][2].buttonInt = i
    guiCalls[i][2].callbackInt = i + #baseVariables
    guiCalls[i][2].isPos = false
    guiCalls[i][2].onTouch = buttonCallback
    guiCalls[i][4] = userTable.settings.data[i]
    guiCalls[i][1].disabled = true
    guiCalls[i][2].disabled = true
  elseif userTable.settings.type[i] == "bool" then
    guiCalls[i][1] = window:addChild(GUI.button(88,labelSpot,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "toggle"))
    guiCalls[i][1].buttonInt = i
    guiCalls[i][1].callbackInt = i + #baseVariables
    guiCalls[i][1].switchMode = true
    guiCalls[i][1].onTouch = buttonCallback,i,i + #baseVariables
    guiCalls[i][1].disabled = true
  end
  labelSpot = labelSpot + 2
end

if enableLinking == true then linkUserLabel = window:addChild(GUI.label(64,labelSpot,3,3,0x165FF2,"LINK      : user not selected")) end --put at end for safe keeping CADE
labelSpot = labelSpot + 2
if enableLinking == true then
  linkUserButton = window:addChild(GUI.button(96,labelSpot,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "link device"))
linkUserButton.onTouch = linkUserCallback
end
if enableLinking == true then linkUserButton.disabled = true end

listPageLabel = window:addChild(GUI.label(4,38,3,3,0x165FF2,tostring(listPageNumber + 1)))
listUpButton = window:addChild(GUI.button(8,38,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "+"))
listUpButton.onTouch = pageCallback,true
listDownButton = window:addChild(GUI.button(12,38,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "-"))
listDownButton.onTouch = pageCallback,false
 
--Line and user buttons
 
window:addChild(GUI.panel(64,36,86,1,0x6B6E74))
userNewButton = window:addChild(GUI.button(4,42,16,1,0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "new"))
userNewButton.onTouch = newUserCallback
userDeleteButton = window:addChild(GUI.button(18,42,16,1,0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "delete")) 
userDeleteButton.onTouch = deleteUserCallback
userChangeUUIDButton = window:addChild(GUI.button(32,42,16,1,0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "reset uuid")) 
userChangeUUIDButton.onTouch = changeUUID
createAdminCardButton = window:addChild(GUI.button(46,42,16,1,0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "admin card")) 
createAdminCardButton.onTouch = writeAdminCardCallback
addVarButton = window:addChild(GUI.button(60,42,16,1,0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "add var")) 
addVarButton.onTouch = addVarCallback
delVarButton = window:addChild(GUI.button(72,42,16,1,0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "delete var")) 
delVarButton.onTouch = delVarCallback
 
--CardWriter frame
 
window:addChild(GUI.panel(114, 2, 38, 6, 0x6B6E74))
cardStatusLabel = window:addChild(GUI.label(116, 4, 3,3,0x165FF2,"     No card   "))
 
--write card button
cardWriteButton = window:addChild(GUI.button(128,42,16,1,0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "write")) 
cardWriteButton.onTouch = writeCardCallback 
 
event.addHandler(eventCallback)
 
workspace:draw()
workspace:start()
