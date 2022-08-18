local module = {}
local component = require("component")
local ser = require("serialization")
local GUI = require("GUI")
local uuid = require("uuid")
local event = require("event")
local modem = component.modem
local writer

local userTable

local workspace, window, loc, database, style = table.unpack({...})

module.name = "Passes"
module.table = {"passes","passSettings"}
module.debug = false

module.init = function(usTable)
  userTable = usTable
end

if component.isAvailable("os_cardwriter") then
  writer = component.os_cardwriter
else
  GUI.alert(loc.cardwriteralert)
  return
end

module.onTouch = function()
  local cardStatusLabel, userList, userNameText, createAdminCardButton, userUUIDLabel, linkUserButton, linkUserLabel, cardWriteButton, StaffYesButton
  local cardBlockedYesButton, userNewButton, userDeleteButton, userChangeUUIDButton, listPageLabel, listUpButton, listDownButton, updateButton
  local addVarButton, delVarButton, editVarButton, varInput, labelInput, typeSelect, extraVar, varContainer, addVarArray, varYesButton, extraVar2, extraVar3, settingsButton
  local sectComboBox, sectLockBox, sectNewButton, sectDelButton, sectUserButton

  local baseVariables = {"name","uuid","date","link","blocked","staff"} --Usertable.settings = {["var"]="level",["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false}}
  local guiCalls = {}

  ----------- Site 91 specific configuration (to avoid breaking commercial systems, don't enable)
  local enableLinking = false
  -----------

  local adminCard = "admincard"

  local modemPort = 199
  local dbPort = 144

  local pageMult = 10
  local listPageNumber = 0
  local previousPage = 0

  local function userListCallback()
    local selectedId = pageMult * listPageNumber + userList.selectedItem
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
    workspace:draw()
  end

  local function updateList()
    local selectedId = userList.selectedItem
    userList:remove()
    userList = window:addChild(GUI.list(4, 4, 58, 34, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
    local temp = pageMult * listPageNumber
    for i = temp + 1, temp + pageMult, 1 do
      if (userTable[i] == nil) then

      else
        userList:addItem(userTable[i].name).onTouch = userListCallback
      end
    end
    database.save()
    if (previousPage == listPageNumber) then
      userList.selectedItem = selectedId
    else
      previousPage = listPageNumber
    end
    database.update()
  end

  local function eventCallback(ev, id)
    if ev == "cardInsert" then
      cardStatusLabel.text = loc.cardpresent
    elseif ev == "cardRemove" then
      cardStatusLabel.text = loc.cardabsent
    end
  end

  local function buttonCallback(workspace, button) --FIXME: Set all userTable stuff to new system (passes and passSettings)
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

  local function staffUserCallback()
    local selected = pageMult * listPageNumber + userList.selectedItem
    userTable[selected].staff = StaffYesButton.pressed
    updateList()
    userListCallback()
  end

  local function blockUserCallback()
    local selected = pageMult * listPageNumber + userList.selectedItem
    userTable[selected].blocked = cardBlockedYesButton.pressed
    updateList()
    userListCallback()
  end

  local function newUserCallback()
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

  local function deleteUserCallback()
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

  local function changeUUID()
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

  local function writeCardCallback()
    local selected = pageMult * listPageNumber + userList.selectedItem
    local data = {["date"]=userTable[selected].date,["name"]=userTable[selected].name,["uuid"]=userTable[selected].uuid}
    data = ser.serialize(data)
    local crypted = database.crypt(data)
    writer.write(crypted, userTable[selected].name .. loc.cardlabel, false, 0)
  end

  local function writeAdminCardCallback()
    local data =  adminCard
    local crypted = database.crypt(data)
    writer.write(crypted, loc.diagcardlabel, false, 14)
  end

  local function pageCallback(workspace,button)
    if button.isPos then
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

  local function inputCallback()
    local selected = pageMult * listPageNumber + userList.selectedItem
    userTable[selected].name = userNameText.text
    updateList()
    userListCallback()
  end

  local function linkUserCallback()
    local container = GUI.addBackgroundContainer(workspace, false, true, loc.linkinstruction)
    local selected = pageMult * listPageNumber + userList.selectedItem
    modem.open(dbPort)
    local e, _, from, port, _, msg = event.pull(20)
    container:remove()
    if e == "modem_message" then
      local data = database.crypt(msg,true)
      userTable[selected].link = data
      modem.send(from,port,database.crypt(userTable[selected].name))
      GUI.alert(loc.linksuccess)
    else
      userTable[selected].link = "nil"
      GUI.alert(loc.linkfail)
    end
    modem.close(dbPort)
    updateList()
    userListCallback()
  end



  window:addChild(GUI.panel(3,3,60,36,style.listPanel))
  userList = window:addChild(GUI.list(4, 4, 58, 34, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
  userList:addItem("HELLO")
  listPageNumber = 0
  updateList()


end

module.close = function()
  return {"passes","passSettings"}
end

return module