local module = {}
local component = require("component")
local ser = require("serialization")
local GUI = require("GUI")
local uuid = require("uuid")
local event = require("event")
local modem = component.modem
local writer

local handler

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

local function split(s, delimiter)
  local result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match);
  end
  return result;
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

  local function eventCallback(ev, id)
    if ev == "cardInsert" then
      cardStatusLabel.text = loc.cardpresent
    elseif ev == "cardRemove" then
      cardStatusLabel.text = loc.cardabsent
    end
  end

  local function userListCallback()
    local selectedId = pageMult * listPageNumber + userList.selectedItem
    userNameText.text = userTable.passes[selectedId].name
    userUUIDLabel.text = "UUID      : " .. userTable.passes[selectedId].uuid
    if enableLinking == true then
      linkUserLabel.text = "LINK      : " .. userTable.passes[selectedId].link
      linkUserButton.disabled = false
    end
    if userTable.passes[selectedId].blocked == true then
      cardBlockedYesButton.pressed = true
    else
      cardBlockedYesButton.pressed = false
    end
    cardBlockedYesButton.disabled = false
    if userTable.passes[selectedId].staff == true then
      StaffYesButton.pressed = true
    else
      StaffYesButton.pressed = false
    end
    StaffYesButton.disabled = false
    listPageLabel.text = tostring(listPageNumber + 1)
    userNameText.disabled = false
    for i=1,#userTable.passSettings.var,1 do
      if userTable.passSettings.type[i] == "bool" then
        guiCalls[i][1].pressed = userTable.passes[selectedId][userTable.passSettings.var[i]]
        guiCalls[i][1].disabled = false
      elseif userTable.passSettings.type[i] == "string" or userTable.passSettings.type[i] == "-string" then
        guiCalls[i][1].text = tostring(userTable.passes[selectedId][userTable.passSettings.var[i]])
        if userTable.passSettings.type[i] == "string" then guiCalls[i][1].disabled = false end
      elseif userTable.passSettings.type[i] == "int" or userTable.passSettings.type[i] == "-int" then
        if userTable.passSettings.type[i] == "-int" then
          guiCalls[i][3].text = tostring(guiCalls[i][4][userTable.passes[selectedId][userTable.passSettings.var[i]]] or "none")
        else
          guiCalls[i][3].text = tostring(userTable.passes[selectedId][userTable.passSettings.var[i]])
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
    userList:removeChildren()
    local temp = pageMult * listPageNumber
    for i = temp + 1, temp + pageMult, 1 do
      if (userTable.passes[i] == nil) then

      else
        userList:addItem(userTable.passes[i].name).onTouch = userListCallback
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

  local function buttonCallback(workspace, button)
    local buttonInt = button.buttonInt
    local callbackInt = button.callbackInt
    local isPos = button.isPos
    local selected = pageMult * listPageNumber + userList.selectedItem
    if callbackInt > #baseVariables then
      callbackInt = callbackInt - #baseVariables
      if userTable.passSettings.type[callbackInt] == "string" then
        userTable.passes[selected][userTable.passSettings.var[callbackInt]] = guiCalls[buttonInt][1].text
      elseif userTable.passSettings.type[callbackInt] == "bool" then
        userTable.passes[selected][userTable.passSettings.var[callbackInt]] = guiCalls[buttonInt][1].pressed
      elseif userTable.passSettings.type[callbackInt] == "int" then
        if isPos == true then
          if userTable.passes[selected][userTable.passSettings.var[callbackInt]] < 100 then
            userTable.passes[selected][userTable.passSettings.var[callbackInt]] = userTable.passes[selected][userTable.passSettings.var[callbackInt]] + 1
          end
        else
          if userTable.passes[selected][userTable.passSettings.var[callbackInt]] > 0 then
            userTable.passes[selected][userTable.passSettings.var[callbackInt]] = userTable.passes[selected][userTable.passSettings.var[callbackInt]] - 1
          end
        end
      elseif userTable.passSettings.type[callbackInt] == "-int" then
        if isPos == true then
          if userTable.passes[selected][userTable.passSettings.var[callbackInt]] < #userTable.passSettings.data[callbackInt] then
            userTable.passes[selected][userTable.passSettings.var[callbackInt]] = userTable.passes[selected][userTable.passSettings.var[callbackInt]] + 1
          end
        else
          if userTable.passes[selected][userTable.passSettings.var[callbackInt]] > 0 then
            userTable.passes[selected][userTable.passSettings.var[callbackInt]] = userTable.passes[selected][userTable.passSettings.var[callbackInt]] - 1
          end
        end
      else
        GUI.alert(loc.buttoncallbackalert .. buttonInt)
        return
      end
    else
      --userTable.passes[selected][baseVariables[callbackInt]]
    end
    updateList()
    userListCallback()
  end

  local function staffUserCallback()
    local selected = pageMult * listPageNumber + userList.selectedItem
    userTable.passes[selected].staff = StaffYesButton.pressed
    updateList()
    userListCallback()
  end

  local function blockUserCallback()
    local selected = pageMult * listPageNumber + userList.selectedItem
    userTable.passes[selected].blocked = cardBlockedYesButton.pressed
    updateList()
    userListCallback()
  end

  local function newUserCallback()
    local tmpTable = {["name"] = "new", ["blocked"] = false, ["date"] = os.date(), ["staff"] = false, ["uuid"] = uuid.next(), ["link"] = "nil"}
    for i=1,#userTable.passSettings.var,1 do
      if userTable.passSettings.type[i] == "string" or userTable.passSettings.type[i] == "-string" then
        tmpTable[userTable.passSettings.var[i]] = "none"
      elseif  userTable.passSettings.type[i] == "bool" then
        tmpTable[userTable.passSettings.var[i]] = false
      elseif userTable.passSettings.type[i] == "int" or userTable.passSettings.type[i] == "-int" then
        tmpTable[userTable.passSettings.var[i]] = 0
      end
    end
    table.insert(userTable.passes, tmpTable)
    updateList()
  end

  local function deleteUserCallback()
    local selected = pageMult * listPageNumber + userList.selectedItem
    table.remove(userTable.passes,selected)
    updateList()
    userNameText.text = ""
    userNameText.disabled = true
    StaffYesButton.disabled = true
    for i=1,#userTable.passSettings.var,1 do
      local tmp = userTable.passSettings.type[i]
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
      local selected = pageMult * listPageNumber + userList.selectedItem
      userTable.passes[selected].uuid = uuid.next()
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
    local data = {["date"]=userTable.passes[selected].date,["name"]=userTable.passes[selected].name,["uuid"]=userTable.passes[selected].uuid}
    data = ser.serialize(data)
    local crypted = database.crypt(data)
    writer.write(crypted, userTable.passes[selected].name .. loc.cardlabel, false, 0)
  end

  local function writeAdminCardCallback()
    local data =  adminCard
    local crypted = database.crypt(data)
    writer.write(crypted, loc.diagcardlabel, false, 14)
  end

  local function pageCallback(workspace,button)
    if button.isPos then
      if listPageNumber < #userTable.passes/pageMult - 1 then
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
    userTable.passes[selected].name = userNameText.text
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
      userTable.passes[selected].link = data
      modem.send(from,port,database.crypt(userTable.passes[selected].name))
      GUI.alert(loc.linksuccess)
    else
      userTable.passes[selected].link = "nil"
      GUI.alert(loc.linkfail)
    end
    modem.close(dbPort)
    updateList()
    userListCallback()
  end

  local function checkTypeCallback()
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
      if userTable.passSettings.type[selected] == "int" then
        extraVar = varContainer.layout:addChild(GUI.button(1,11,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.newvarcheckabove))
        extraVar.switchMode = true
        extraVar.pressed = userTable.passSettings.above[selected]
        extraVar.onTouch = function()
          extraVar2 = extraVar.pressed
        end
        extraVar2 = userTable.passSettings.above[selected]
      elseif userTable.passSettings.type[selected] == "-int" then
        extraVar = varContainer.layout:addChild(GUI.input(1,11,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.newvargroup))
        local isme = userTable.passSettings.data[selected][1]
        for i=2,#userTable.passSettings.data[selected],1 do
          isme = isme .. "," .. userTable.passSettings.data[selected][i]
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

  local function addVarYesCall()
    for i=1,#userTable,1 do
      if addVarArray.type == "string" or addVarArray.type == "-string" then
        userTable.passes[i][addVarArray.var] = "none"
      elseif addVarArray.type == "int" or addVarArray.type == "-int" then
        userTable.passes[i][addVarArray.var] = 0
      elseif addVarArray.type == "bool" then
        userTable.passes[i][addVarArray.var] = false
      else
        GUI.alert(loc.addvaralert)
        varContainer:removeChildren()
        varContainer:remove()
        varContainer = nil
        return
      end
    end
    table.insert(userTable.passSettings.var,addVarArray.var)
    table.insert(userTable.passSettings.label,addVarArray.label)
    table.insert(userTable.passSettings.calls,addVarArray.calls)
    table.insert(userTable.passSettings.type,addVarArray.type)
    table.insert(userTable.passSettings.above,addVarArray.above)
    table.insert(userTable.passSettings.data,addVarArray.data)
    addVarArray = nil
    varContainer:removeChildren()
    varContainer:remove()
    varContainer = nil
    database.save()
    GUI.alert(loc.newvaradded)
    database.update()
    window:remove()
  end

  local function addVarCallback()
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

  local function delVarYesCall()
    local selected = typeSelect.selectedItem
    table.remove(userTable.passSettings.data,selected)
    table.remove(userTable.passSettings.label,selected)
    table.remove(userTable.passSettings.calls,selected)
    table.remove(userTable.passSettings.type,selected)
    table.remove(userTable.passSettings.above,selected)
    for i=1,#userTable.passes,1 do
      userTable.passes[i][userTable.passSettings.var[selected]] = nil
    end
    table.remove(userTable.passSettings.var,selected)
    varContainer:removeChildren()
    varContainer:remove()
    varContainer = nil
    database.save()
    GUI.alert(loc.delvarcompleted)
    database.update()
    window:remove()
  end

  local function delVarCallback()
    varContainer = GUI.addBackgroundContainer(workspace, true, true)
    typeSelect = varContainer.layout:addChild(GUI.comboBox(1,1,30,3, style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
    for i=1,#userTable.passSettings.var,1 do
      typeSelect:addItem(userTable.passSettings.label[i])
    end
    varYesButton = varContainer.layout:addChild(GUI.button(1,21,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.delvarcompletedbutton))
    varYesButton.onTouch = delVarYesCall
  end

  local function editVarYesCall()
    local selected = addVarArray[typeSelect.selectedItem]
    if userTable.passSettings.type[selected] == "int" then
      userTable.passSettings.above[selected] = extraVar2
    elseif userTable.passSettings.type[selected] == "-int" then
      userTable.passSettings.data[selected] = extraVar2
    else

    end
    varContainer:removeChildren()
    varContainer:remove()
    varContainer = nil
    database.save()
    GUI.alert(loc.changevarcompleted)
    database.update()
    window:remove()
  end

  local function editVarCallback()
    addVarArray = {}
    varContainer = GUI.addBackgroundContainer(workspace, true, true)
    varContainer.layout:addChild(GUI.label(1,1,3,3,style.containerLabel, "You can only edit level and group passes"))
    typeSelect = varContainer.layout:addChild(GUI.comboBox(1,6,30,3, style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
    typeSelect.izit = "edit"
    for i=1,#userTable.passSettings.var,1 do
      if userTable.passSettings.type[i] == "-int" or userTable.passSettings.type[i] == "int" then
        typeSelect:addItem(userTable.passSettings.label[i]).onTouch = checkTypeCallback
        table.insert(addVarArray,i)
      end
    end
    local showThis = function(int)
      addVarArray.var = userTable.passSettings.var[int]
      addVarArray.label = userTable.passSettings.label[int]
      addVarArray.calls = userTable.passSettings.calls[int]
      addVarArray.type = userTable.passSettings.type[int]
      addVarArray.above = userTable.passSettings.above[int]
      addVarArray.data = userTable.passSettings.data[int]
    end
    varYesButton = varContainer.layout:addChild(GUI.button(1,21,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.changevarpropbutton))
    varYesButton.onTouch = editVarYesCall

    checkTypeCallback(nil,{["izit"]="edit"})
  end

  window:addChild(GUI.panel(1,1,37,33,style.listPanel))
  userList = window:addChild(GUI.list(2, 2, 35, 31, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
  userList:addItem("HELLO")
  listPageNumber = 0
  updateList()

  --user infos
  local labelSpot = 1
  window:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"User name : "))
  userNameText = window:addChild(GUI.input(64,labelSpot,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputname))
  userNameText.onInputFinished = inputCallback
  userNameText.disabled = true
  labelSpot = labelSpot + 2
  userUUIDLabel = window:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"UUID      : " .. loc.usernotselected))
  labelSpot = labelSpot + 2
  window:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"STAFF     : "))
  StaffYesButton = window:addChild(GUI.button(64,labelSpot,16,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.toggle))
  StaffYesButton.switchMode = true
  StaffYesButton.onTouch = staffUserCallback
  StaffYesButton.disabled = true
  labelSpot = labelSpot + 2
  window:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"Blocked   : "))
  cardBlockedYesButton = window:addChild(GUI.button(64,labelSpot,16,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.toggle))
  cardBlockedYesButton.switchMode = true
  cardBlockedYesButton.onTouch = blockUserCallback
  cardBlockedYesButton.disabled = true
  labelSpot = labelSpot + 2

  for i=1,#userTable.passSettings.var,1 do
    local labelText = userTable.passSettings.label[i]
    local spaceNum = 10 - #labelText
    if spaceNum < 0 then spaceNum = 0 end
    for j=1,spaceNum,1 do
      labelText = labelText .. " "
    end
    labelText = labelText .. ": "
    window:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,labelText))
    guiCalls[i] = {}
    if userTable.passSettings.type[i] == "string" then
      guiCalls[i][1] = window:addChild(GUI.input(64,labelSpot,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputtext))
      guiCalls[i][1].buttonInt = i
      guiCalls[i][1].callbackInt = i + #baseVariables
      guiCalls[i][1].onInputFinished = buttonCallback
      guiCalls[i][1].disabled = true
    elseif userTable.passSettings.type[i] == "-string" then
      guiCalls[i][1] = window:addChild(GUI.label(64,labelSpot,3,3,style.passIntLabel,"NAN"))
    elseif userTable.passSettings.type[i] == "int" then
      guiCalls[i][3] = window:addChild(GUI.label(72,labelSpot,3,3,style.passIntLabel,"#"))
      guiCalls[i][1] = window:addChild(GUI.button(64,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "+"))
      guiCalls[i][1].buttonInt = i
      guiCalls[i][1].callbackInt = i + #baseVariables
      guiCalls[i][1].isPos = true
      guiCalls[i][1].onTouch = buttonCallback
      guiCalls[i][2] = window:addChild(GUI.button(68,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "-"))
      guiCalls[i][2].buttonInt = i
      guiCalls[i][2].callbackInt = i + #baseVariables
      guiCalls[i][2].isPos = false
      guiCalls[i][2].onTouch = buttonCallback
      guiCalls[i][1].disabled = true
      guiCalls[i][2].disabled = true
    elseif userTable.passSettings.type[i] == "-int" then
      guiCalls[i][3] = window:addChild(GUI.label(72,labelSpot,3,3,style.passIntLabel,"NAN"))
      guiCalls[i][1] = window:addChild(GUI.button(64,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "+"))
      guiCalls[i][1].buttonInt = i
      guiCalls[i][1].callbackInt = i + #baseVariables
      guiCalls[i][1].isPos = true
      guiCalls[i][1].onTouch = buttonCallback
      guiCalls[i][2] = window:addChild(GUI.button(68,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "-"))
      guiCalls[i][2].buttonInt = i
      guiCalls[i][2].callbackInt = i + #baseVariables
      guiCalls[i][2].isPos = false
      guiCalls[i][2].onTouch = buttonCallback
      guiCalls[i][4] = userTable.passSettings.data[i]
      guiCalls[i][1].disabled = true
      guiCalls[i][2].disabled = true
    elseif userTable.passSettings.type[i] == "bool" then
      guiCalls[i][1] = window:addChild(GUI.button(64,labelSpot,16,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.toggle))
      guiCalls[i][1].buttonInt = i
      guiCalls[i][1].callbackInt = i + #baseVariables
      guiCalls[i][1].switchMode = true
      guiCalls[i][1].onTouch = buttonCallback,i,i + #baseVariables
      guiCalls[i][1].disabled = true
    end
    labelSpot = labelSpot + 2
  end

  if enableLinking == true then
    linkUserLabel = window:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"LINK      : " .. loc.usernotselected))
    labelSpot = labelSpot + 2
    linkUserButton = window:addChild(GUI.button(40,labelSpot,16,1, style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.linkdevice))
    linkUserButton.onTouch = linkUserCallback
    linkUserButton.disabled = true
  end

  listPageLabel = window:addChild(GUI.label(2,33,3,3,style.listPageLabel,tostring(listPageNumber + 1)))
  listUpButton = window:addChild(GUI.button(8,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "+"))
  listUpButton.onTouch, listUpButton.isPos = pageCallback,true
  listDownButton = window:addChild(GUI.button(12,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "-"))
  listDownButton.onTouch, listDownButton.isPos = pageCallback,false

  --Line and user buttons

  --window:addChild(GUI.panel(115,11,1,26,style.bottomDivider))
  --window:addChild(GUI.panel(64,10,86,1,style.bottomDivider))
  --window:addChild(GUI.panel(64,36,86,1,style.bottomDivider))
  userNewButton = window:addChild(GUI.button(118,12,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.new)) --118 is furthest right
  userNewButton.onTouch = newUserCallback
  userDeleteButton = window:addChild(GUI.button(118,14,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.delete))
  userDeleteButton.onTouch = deleteUserCallback
  userChangeUUIDButton = window:addChild(GUI.button(118,18,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.resetuuid))
  userChangeUUIDButton.onTouch = changeUUID
  createAdminCardButton = window:addChild(GUI.button(118,30,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.admincardbutton))
  createAdminCardButton.onTouch = writeAdminCardCallback
  addVarButton = window:addChild(GUI.button(118,22,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.addvar))
  addVarButton.onTouch = addVarCallback
  delVarButton = window:addChild(GUI.button(118,26,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.delvar))
  delVarButton.onTouch = delVarCallback
  editVarButton = window:addChild(GUI.button(118,24,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.editvar))
  editVarButton.onTouch = editVarCallback

  --Database name and stuff and CardWriter
  window:addChild(GUI.panel(123,2,12,3,style.cardStatusPanel))
  cardStatusLabel = window:addChild(GUI.label(124, 3, 10,3,style.cardStatusLabel,loc.cardabsent))

  --write card button
  cardWriteButton = window:addChild(GUI.button(118,32,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.writebutton))
  cardWriteButton.onTouch = writeCardCallback

  handler = event.addHandler(eventCallback)
end

module.close = function()
  event.removeHandler(handler)
  return {"passes","passSettings"}
end

return module