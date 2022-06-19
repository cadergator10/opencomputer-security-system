local GUI = require("GUI")
local system = require("System")
local modemPort = 199
local dbPort = 144

local adminCard = "admincard"
 
local component = require("component")
local gpu = component.gpu
local event = require("event")
local ser = require("serialization")
local uuid = require("uuid")
local fs = require("Filesystem")
local writer

local aRD = fs.path(system.getCurrentScript())
local stylePath = aRD.."Styles/"
local style = "default.lua"
local loc = system.getLocalization(aRD .. "Localizations/")

----------
 
local workspace, window, menu
local cardStatusLabel, userList, userNameText, createAdminCardButton, userUUIDLabel, linkUserButton, linkUserLabel, cardWriteButton, StaffYesButton
local cardBlockedYesButton, userNewButton, userDeleteButton, userChangeUUIDButton, listPageLabel, listUpButton, listDownButton, updateButton
local addVarButton, delVarButton, editVarButton, varInput, labelInput, typeSelect, extraVar, varContainer, addVarArray, varYesButton, extraVar2
 
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
 
local prgName = loc.name
local version = "v2.3.0"
 
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
    GUI.alert(loc.cardwriteralert)
    return
end
if component.isAvailable("modem") then
    modem = component.modem
else
    GUI.alert(loc.modemalert)
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

function callModem(callPort,...) --Does it work?
  modem.broadcast(modemPort,...)
  local e, _, from, port, _, msg,a,b,c,d,f,g,h
  repeat
      e, a,b,c,d,f,g,h = event.pull(1)
  until(e == "modem_message" or e == nil)
  if e == "modem_message" then
      return true,a,b,c,d,f,g,h
  else
      return false
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
  userList = window:addChild(GUI.list(4, 4, 58, 34, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false)) 
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
  if settingTable.autoupdate then
    updateServer()
  end
end
 
function eventCallback(ev, id)
  if ev == "cardInsert" then
    cardStatusLabel.text = loc.cardpresent
  elseif ev == "cardRemove" then
    cardStatusLabel.text = loc.cardabsent
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
      GUI.alert(loc.buttoncallbackalert .. buttonInt)
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
  table.remove(userTable,selected)
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
        guiCalls[i][3].text = "NAN"
      else
        guiCalls[i][3].text = "#"
      end
      guiCalls[i][1].disabled = true
      guiCalls[i][2].disabled = true
    end
  end
  cardBlockedYesButton.disabled = true
  if enableLinking == true then linkUserButton.disabled = true end
end

function changeUUID()
    varContainer = GUI.addBackgroundContainer(workspace,true,true)
    varContainer.layout:addChild(GUI.label(1,1,3,3,style.containerLabel,loc.changeuuidline1))
    varContainer.layout:addChild(GUI.label(1,3,3,3,style.containerLabel,loc.changeuuidline2))
    varContainer.layout:addChild(GUI.label(1,5,3,3,style.containerLabel,loc.changeuuidline3))
    local funcyes = function()
      local selected = pageMult * listPageNumber + userList.selectedItem
      userTable[selected].uuid = uuid.next()
      updateList()
      userListCallback()
      varContainer:remove()
    end
    local funcno = function()
      varContainer:remove()
    end
    local button1 = varContainer.layout:addChild(GUI.button(1,9,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.yes))
    local button2 = varContainer.layout:addChild(GUI.button(1,7,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.no))
    button1.onTouch = funcyes
    button2.onTouch = funcno
end
 
function writeCardCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  local data = {["date"]=userTable[selected].date,["name"]=userTable[selected].name,["uuid"]=userTable[selected].uuid}
  data = ser.serialize(data)
  local crypted = crypt(data, settingTable.cryptKey)
  writer.write(crypted, userTable[selected].name .. loc.cardlabel, false, 0)
end

function writeAdminCardCallback()
  local data =  adminCard
  local crypted = crypt(data, settingTable.cryptKey)
  writer.write(crypted, loc.diagcardlabel, false, 14)
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
    local container = GUI.addBackgroundContainer(workspace, false, true, loc.linkinstruction)
    local selected = pageMult * listPageNumber + userList.selectedItem
    modem.open(dbPort)
    local e, _, from, port, _, msg = event.pull(20)
    container:remove()
    if e == "modem_message" then
        local data = crypt(msg,settingTable.cryptKey,true)
        userTable[selected].link = data
        modem.send(from,port,crypt(userTable[selected].name,settingTable.cryptKey))
        GUI.alert(loc.linksuccess)
    else
        userTable[selected].link = "nil"
        GUI.alert(loc.linkfail)
    end
    modem.close(dbPort)
    updateList()
    userListCallback()
end

function checkTypeCallback() --TODO: finish the checks for this
  local typeArray = {"string","-string","int","-int","bool"}
  local selected
  if typeSelect.izit == "add" then
    addVarArray.above = false
    addVarArray.data = false
    selected = typeSelect.selectedItem
    addVarArray.type = typeArray[selected]
  else
    selected = addVarArray[typeSelect.selectedItem]
  end
  if extraVar ~= nil then
    extraVar:remove()
    extraVar = nil
  end
  if typeSelect.izit == "add" then
    if selected == 3 then
      extraVar = varContainer.layout:addChild(GUI.button(1,16,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.newvarcheckabove))
      extraVar.onTouch = function()
        addVarArray.above = extraVar.pressed
      end
      extraVar.switchMode = true
    elseif selected == 4 then
      extraVar = varContainer.layout:addChild(GUI.input(1,16,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.newvargroup))
      extraVar.onInputFinished = function()
        addVarArray.data = split(extraVar.text,",")
      end
    else

    end
  else
    if userTable.settings.type[selected] == "int" then
      extraVar = varContainer.layout:addChild(GUI.button(1,11,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.newvarcheckabove))
      extraVar.switchMode = true
      extraVar.pressed = userTable.settings.above[selected]
      extraVar.onTouch = function()
        extraVar2 = extraVar.pressed
      end
      extraVar2 = userTable.settings.above[selected]
    elseif userTable.settings.type[selected] == "-int" then
      extraVar = varContainer.layout:addChild(GUI.input(1,11,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.newvargroup))
      local isme = userTable.settings.data[selected][1]
      for i=2,#userTable.settings.data[selected],1 do
        isme = isme .. "," .. userTable.settings.data[selected][i]
      end
      extraVar.text = isme
      extraVar2 = split(extraVar.text,",")
      extraVar.onInputFinished = function()
        extraVar2 = split(extraVar.text,",")
      end
    else

    end
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
      GUI.alert(loc.addvaralert)
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
  GUI.alert(loc.newvaradded)
  updateServer()
  window:remove()
end

function addVarCallback()
  addVarArray = {["var"]="placeh",["label"]="PlaceHold",["calls"]=uuid.next(),["type"]="string",["above"]=false,["data"]=false}
  varContainer = GUI.addBackgroundContainer(workspace, true, true)
  varInput = varContainer.layout:addChild(GUI.input(1,1,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.newvarkey))
  varInput.onInputFinished = function()
    addVarArray.var = varInput.text
  end
  labelInput = varContainer.layout:addChild(GUI.input(1,6,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.newvarlabel))
  labelInput.onInputFinished = function()
    addVarArray.label = labelInput.text
  end
  typeSelect = varContainer.layout:addChild(GUI.comboBox(1,11,30,3, style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
  typeSelect.izit = "add"
  local lik = typeSelect:addItem("String")
  lik.onTouch = checkTypeCallback
  lik = typeSelect:addItem("Hidden String")
  lik.onTouch = checkTypeCallback
  lik = typeSelect:addItem("Level (Int)")
  lik.onTouch = checkTypeCallback
  lik = typeSelect:addItem("Group")
  lik.onTouch = checkTypeCallback
  lik = typeSelect:addItem("Pass (true/false)")
  lik.onTouch = checkTypeCallback
  varYesButton = varContainer.layout:addChild(GUI.button(1,21,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.newvaraddbutton))
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
  GUI.alert(loc.delvarcompleted)
  updateServer()
  window:remove()
end

function delVarCallback()
  varContainer = GUI.addBackgroundContainer(workspace, true, true)
  typeSelect = varContainer.layout:addChild(GUI.comboBox(1,1,30,3, style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
  for i=1,#userTable.settings.var,1 do
    typeSelect:addItem(userTable.settings.label[i])
  end
  varYesButton = varContainer.layout:addChild(GUI.button(1,21,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.delvarcompletedbutton))
  varYesButton.onTouch = delVarYesCall
end

function editVarYesCall()
  local selected = addVarArray[typeSelect.selectedItem]
  if userTable.settings.type[selected] == "int" then
    userTable.settings.above[selected] = extraVar2
  elseif userTable.settings.type[selected] == "-int" then
    userTable.settings.data[selected] = extraVar2
  else

  end
  varContainer:removeChildren()
  varContainer:remove()
  varContainer = nil
  saveTable(userTable,aRD .. "userlist.txt")
  GUI.alert(loc.changevarcompleted)
  updateServer()
  window:remove()
end

function editVarCallback() --TODO: Add the ability to edit passes
  addVarArray = {}
  varContainer = GUI.addBackgroundContainer(workspace, true, true)
  varContainer.layout:addChild(GUI.label(1,1,3,3,style.containerLabel, "You can only edit level and group passes"))
  typeSelect = varContainer.layout:addChild(GUI.comboBox(1,6,30,3, style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
  typeSelect.izit = "edit"
  for i=1,#userTable.settings.var,1 do
    if userTable.settings.type[i] == "-int" or userTable.settings.type[i] == "int" then
      typeSelect:addItem(userTable.settings.label[i]).onTouch = checkTypeCallback
      table.insert(addVarArray,i)
    end
  end
  local showThis = function(int)
    addVarArray.var = userTable.settings.var[int]
    addVarArray.label = userTable.settings.label[int]
    addVarArray.calls = userTable.settings.calls[int]
    addVarArray.type = userTable.settings.type[int]
    addVarArray.above = userTable.settings.above[int]
    addVarArray.data = userTable.settings.data[int]
  end
  varYesButton = varContainer.layout:addChild(GUI.button(1,21,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.changevarpropbutton))
  varYesButton.onTouch = editVarYesCall

  checkTypeCallback(nil,{["izit"]="edit"})
end

----------GUI SETUP
if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
 end
settingTable = loadTable(aRD .. "dbsettings.txt")
if settingTable == nil then
  GUI.alert(loc.cryptalert)
  settingTable = {["cryptKey"]={1,2,3,4,5},["style"]="default.lua",["autoupdate"]=false}
  saveTable(settingTable,aRD .. "dbsettings.txt")
end
if settingTable.style == nil then
  settingTable.style = "default.lua"
  saveTable(settingTable,aRD .. "dbsettings.txt")
end
if settingTable.autoupdate == nil then
  settingTable.autoupdate = false
  saveTable(settingTable,aRD .. "dbsettings.txt")
end
style = fs.readTable(stylePath .. settingTable.style)
local check,_,_,_,_,work = callModem(modemPort,"getuserlist")
if check then
  work = ser.unserialize(crypt(work,settingTable.cryptKey,true))
  saveTable(work,aRD .. "userlist.txt")
  userTable = work
else
  GUI.alert(loc.userlistfailgrab)
  userTable = loadTable(aRD .. "userlist.txt")
  if userTable == nil then
    userTable = {["settings"]={["var"]={"level"},["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false}}}
  end
end

workspace, window, menu = system.addWindow(GUI.filledWindow(2,2,150,45,style.windowFill))
 
local layout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))
 
local contextMenu = menu:addContextMenuItem("File")
contextMenu:addItem("Close").onTouch = function()
window:remove()
  --os.exit()
end
 
window:addChild(GUI.panel(3,3,60,36,style.listPanel))
userList = window:addChild(GUI.list(4, 4, 58, 34, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
userList:addItem("HELLO")
listPageNumber = 0
settingTable = loadTable(aRD .. "dbsettings.txt")
if settingTable == nil then
  GUI.alert(loc.cryptalert)
  settingTable = {["cryptKey"]={1,2,3,4,5}}
  saveTable(settingTable,aRD .. "dbsettings.txt")
end
updateList()
 
--user infos TODO: Make the page look better, be resizeable, use layouts instead, etc.
local labelSpot = 12
window:addChild(GUI.label(64,labelSpot,3,3,style.passNameLabel,"User name : "))
userNameText = window:addChild(GUI.input(88,labelSpot,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputname))
userNameText.onInputFinished = inputCallback
userNameText.disabled = true
labelSpot = labelSpot + 2
userUUIDLabel = window:addChild(GUI.label(64,labelSpot,3,3,style.passNameLabel,"UUID      : " .. loc.usernotselected))
labelSpot = labelSpot + 2
window:addChild(GUI.label(64,labelSpot,3,3,style.passNameLabel,"STAFF     : "))
StaffYesButton = window:addChild(GUI.button(88,labelSpot,16,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.toggle))
StaffYesButton.switchMode = true
StaffYesButton.onTouch = staffUserCallback
StaffYesButton.disabled = true
labelSpot = labelSpot + 2
window:addChild(GUI.label(64,labelSpot,3,3,style.passNameLabel,"Blocked   : "))
cardBlockedYesButton = window:addChild(GUI.button(88,labelSpot,16,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.toggle))
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
  window:addChild(GUI.label(64,labelSpot,3,3,style.passNameLabel,labelText))
  guiCalls[i] = {}
  if userTable.settings.type[i] == "string" then
    guiCalls[i][1] = window:addChild(GUI.input(88,labelSpot,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputtext))
    guiCalls[i][1].buttonInt = i
    guiCalls[i][1].callbackInt = i + #baseVariables
    guiCalls[i][1].onInputFinished = buttonCallback
    guiCalls[i][1].disabled = true
  elseif userTable.settings.type[i] == "-string" then
    guiCalls[i][1] = window:addChild(GUI.label(88,labelSpot,3,3,style.passIntLabel,"NAN"))
  elseif userTable.settings.type[i] == "int" then
    guiCalls[i][3] = window:addChild(GUI.label(96,labelSpot,3,3,style.passIntLabel,"#"))
    guiCalls[i][1] = window:addChild(GUI.button(88,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "+"))
    guiCalls[i][1].buttonInt = i
    guiCalls[i][1].callbackInt = i + #baseVariables
    guiCalls[i][1].isPos = true
    guiCalls[i][1].onTouch = buttonCallback
    guiCalls[i][2] = window:addChild(GUI.button(92,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "-"))
    guiCalls[i][2].buttonInt = i
    guiCalls[i][2].callbackInt = i + #baseVariables
    guiCalls[i][2].isPos = false
    guiCalls[i][2].onTouch = buttonCallback
    guiCalls[i][1].disabled = true
    guiCalls[i][2].disabled = true
  elseif userTable.settings.type[i] == "-int" then
    guiCalls[i][3] = window:addChild(GUI.label(96,labelSpot,3,3,style.passIntLabel,"NAN"))
    guiCalls[i][1] = window:addChild(GUI.button(88,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "+"))
    guiCalls[i][1].buttonInt = i
    guiCalls[i][1].callbackInt = i + #baseVariables
    guiCalls[i][1].isPos = true
    guiCalls[i][1].onTouch = buttonCallback
    guiCalls[i][2] = window:addChild(GUI.button(92,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "-"))
    guiCalls[i][2].buttonInt = i
    guiCalls[i][2].callbackInt = i + #baseVariables
    guiCalls[i][2].isPos = false
    guiCalls[i][2].onTouch = buttonCallback
    guiCalls[i][4] = userTable.settings.data[i]
    guiCalls[i][1].disabled = true
    guiCalls[i][2].disabled = true
  elseif userTable.settings.type[i] == "bool" then
    guiCalls[i][1] = window:addChild(GUI.button(88,labelSpot,16,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.toggle))
    guiCalls[i][1].buttonInt = i
    guiCalls[i][1].callbackInt = i + #baseVariables
    guiCalls[i][1].switchMode = true
    guiCalls[i][1].onTouch = buttonCallback,i,i + #baseVariables
    guiCalls[i][1].disabled = true
  end
  labelSpot = labelSpot + 2
end

if enableLinking == true then linkUserLabel = window:addChild(GUI.label(64,labelSpot,3,3,style.passNameLabel,"LINK      : " .. loc.usernotselected)) end
labelSpot = labelSpot + 2
if enableLinking == true then
  linkUserButton = window:addChild(GUI.button(96,labelSpot,16,1, style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.linkdevice))
linkUserButton.onTouch = linkUserCallback
end
if enableLinking == true then linkUserButton.disabled = true end

listPageLabel = window:addChild(GUI.label(4,38,3,3,style.listPageLabel,tostring(listPageNumber + 1)))
listUpButton = window:addChild(GUI.button(8,38,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "+"))
listUpButton.onTouch = pageCallback,true
listDownButton = window:addChild(GUI.button(12,38,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "-"))
listDownButton.onTouch = pageCallback,false
 
--Line and user buttons

window:addChild(GUI.panel(115,11,1,26,style.bottomDivider))
window:addChild(GUI.panel(64,10,86,1,style.bottomDivider))
window:addChild(GUI.panel(64,36,86,1,style.bottomDivider))
userNewButton = window:addChild(GUI.button(4,40,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.new))
userNewButton.onTouch = newUserCallback
userDeleteButton = window:addChild(GUI.button(4,42,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.delete))
userDeleteButton.onTouch = deleteUserCallback
userChangeUUIDButton = window:addChild(GUI.button(4,44,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.resetuuid))
userChangeUUIDButton.onTouch = changeUUID
createAdminCardButton = window:addChild(GUI.button(128,43,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.admincardbutton))
createAdminCardButton.onTouch = writeAdminCardCallback
addVarButton = window:addChild(GUI.button(22,40,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.addvar))
addVarButton.onTouch = addVarCallback
delVarButton = window:addChild(GUI.button(22,42,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.delvar))
delVarButton.onTouch = delVarCallback
editVarButton = window:addChild(GUI.button(22,44,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.editvar))
editVarButton.onTouch = editVarCallback

--Database name and stuff and CardWriter
window:addChild(GUI.panel(64,2,88,5,style.cardStatusPanel))
window:addChild(GUI.label(66,4,3,3,style.cardStatusLabel,prgName .. " | " .. version))
cardStatusLabel = window:addChild(GUI.label(116, 4, 3,3,style.cardStatusLabel,loc.cardabsent))
 
--write card button
cardWriteButton = window:addChild(GUI.button(128,41,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.writebutton))
cardWriteButton.onTouch = writeCardCallback

--Server Update button (only if setting is set to false)
if settingTable.autoupdate == false then
  updateButton = window:addChild(GUI.button(128,8,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.updateserver))
  updateButton.onTouch = updateServer
end

event.addHandler(eventCallback)
 
workspace:draw()
workspace:start()
