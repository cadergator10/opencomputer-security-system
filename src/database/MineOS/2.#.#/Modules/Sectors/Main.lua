local module = {}
local GUI = require("GUI")
local uuid = require("uuid")

local userTable

local workspace, window, loc, database, style = table.unpack({...})

module.name = "Sectors"
module.table = {"sectors"}
module.debug = false

module.init = function(usTable)
  userTable = usTable
end

module.onTouch = function()
  local sectorList, sectorNameInput, newSectorButton, delSectorButton, sectorPassNew, sectorPassRemove, sectorPassList, userPassSelfSelector, userPassDataSelector, userPassTypeSelector
  local sectorListNum, sectorListUp, sectorListDown, sectorPassListNum, sectorPassListUp, sectorPassListDown

  local pageMult = 10
  local listPageNumber = 0
  local previousPage = 0

  local pageMultPass = 10
  local listPageNumberPass = 0
  local previousPagePass = 0
  local prevPass = "string"

  --Sector functions

  local function uuidtopass(uuid)
    if uuid == "checkstaff" then
      return true, 0
    end
    for i=1,#userTable.passSettings.calls,1 do
      if userTable.passSettings.calls[i] == uuid then
        return true, i
      end
    end
    return false
  end

  local function refreshInput(uuid)
    if uuid == nil then
      uuid = userPassSelfSelector.selectedItem - 1
    end
    if uuid ~= 0 then
      if userTable.passSettings.type[uuid] == "string" or userTable.passSettings.type[uuid] == "-string" or userTable.passSettings.type[uuid] == "int" then
        if prevPass == "-int" then
          userPassDataSelector:remove() --TODO: Fix all numbers to go to the correct location on screen
          userPassDataSelector = window:addChild(GUI.input(1,1,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
        end
        userPassDataSelector.text = ""
        userPassDataSelector.disabled = false
      elseif userTable.passSettings.type[uuid] == "-int" then
        if prevPass ~= "-int" then
          userPassDataSelector:remove()
          userPassDataSelector = window:addChild(GUI.comboBox(1,1,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
        else
          userPassDataSelector:clear()
        end
        for _,value in pairs(userTable.passSettings.data[uuid]) do
          userPassDataSelector:addItem(value)
        end
        userPassDataSelector.selectedItem = 1
      else
        if prevPass == "-int" then
          userPassDataSelector:remove()
          userPassDataSelector = window:addChild(GUI.input(1,1,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
        end
        userPassDataSelector.text = ""
        userPassDataSelector.disabled = true
      end
    else
      if prevPass == "-int" then
        userPassDataSelector:remove()
        userPassDataSelector = window:addChild(GUI.input(1,1,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
      end
      userPassDataSelector.text = ""
      userPassDataSelector.disabled = true
    end
    prevPass = uuid ~= 0 and userTable.passSettings.type[uuid] or "bool"
  end

  --[[local function sectorPassCallback() Commented out because not planning on making it possible to add sectors for simplicity for meeeee
    local selectedId = pageMultPass * listPageNumberPass + sectorPassList.selectedItem
    local secSelect = pageMult * listPageNumber + sectorList.selectedItem
    local sectorpass = userTable.sectors[secSelect].pass[selectedId]
    local uuid = uuidtopass(sectorpass.uuid)
    userPassSelfSelector.selectedItem = uuid + 1
    userPassTypeSelector.selectedItem = sectorpass.lock
    refreshInput(uuid)
  end]]

  local function sectorListCallback()
    local selectedId = pageMult * listPageNumber + sectorList.selectedItem
    sectorNameInput.text = userTable.sectors[selectedId].name
    sectorPassList:removeChildren()
    local temp = pageMultPass * listPageNumberPass
    for i = temp + 1, temp + pageMultPass, 1 do
      if (userTable.sectors[selectedId].pass[i] == nil) then

      else
        local pass = uuidtopass(userTable.sectors[selectedId].pass[i].uuid)
        local lockType = {loc.sectoropen,loc.sectordislock}
        if pass ~= 0 then
          sectorPassList:addItem(userTable.passSettings.label[pass] .. " : " .. userTable.sectors[selectedId].pass[i].data .. " : " .. lockType[userTable.sectors[selectedId].pass[i].lock]).onTouch = sectorPassCallback()
        else
          sectorPassList:addItem("Staff : 0 : " .. lockType[userTable.sectors[selectedId].pass[i].lock])
        end
      end
    end

  end

  local function updateSecList()
    local selectedId = sectorList.selectedItem
    sectorList:removeChildren()
    local temp = pageMult * listPageNumber
    for i = temp + 1, temp + pageMult, 1 do
      if (userTable.sectors[i] == nil) then

      else
        sectorList:addItem(userTable.sectors[i].name).onTouch = sectorListCallback
      end
    end
    database.save()
    if (previousPage == listPageNumber) then
      sectorList.selectedItem = selectedId
    else
      previousPage = listPageNumber
    end
    database.update()
  end

  local function createSector()
    addVarArray = {["name"]="temp",["uuid"]=uuid.next(),["type"]=1,["pass"]={},["status"]=1}
    varContainer = GUI.addBackgroundContainer(workspace, true, true)
    varInput = varContainer.layout:addChild(GUI.input(1,1,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.sectornewname))
    varInput.onInputFinished = function()
      addVarArray.name = varInput.text
    end
    varYesButton = varContainer.layout:addChild(GUI.button(1,6,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.sectornewadd))
    varYesButton.onTouch = function()
      table.insert(userTable.settings.sectors,addVarArray)
      addVarArray = nil
      varContainer:removeChildren()
      varContainer:remove()
      varContainer = nil
      saveTable(userTable,aRD .. "userlist.txt")
      GUI.alert(loc.sectadded)
      updateServer()
      window:remove()
    end
  end
  local function deleteSector()
    varContainer = GUI.addBackgroundContainer(workspace, true, true)
    typeSelect = varContainer.layout:addChild(GUI.comboBox(1,1,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
    for i=1,#userTable.settings.sectors,1 do
      typeSelect:addItem(userTable.settings.sectors[i].name)
    end
    varYesButton = varContainer.layout:addChild(GUI.button(1,21,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.delvarcompletedbutton))
    varYesButton.onTouch = function()
      local selected = typeSelect.selectedItem
      table.remove(userTable.settings.sectors,selected)
      varContainer:removeChildren()
      varContainer:remove()
      varContainer = nil
      saveTable(userTable,aRD .. "userlist.txt")
      GUI.alert(loc.sectremoved)
      updateServer()
      window:remove()
    end
  end

  local function sectorPassManager() --Manages passes that bypass sector lockdown events. Was very difficult to think of & implement; Untested
    local selected = 1
    varContainer = GUI.addBackgroundContainer(workspace, true, true)
    varContainer.layout:addChild(GUI.label(1,1,3,1,style.sectorText, loc.sectorpasslabel))
    typeSelect = varContainer.layout:addChild(GUI.comboBox(1,1,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
    local freshType = function()
      selected = typeSelect.selectedItem
      typeSelect:clear()
      addVarArray = {} --Every spot: {["uuid"]="uuid for thing",["data"]="what it checks for"}
      for i=1,#userTable.settings.sectors[sectComboBox.selectedItem].pass, 1 do
        local e,it = uuidtopass(userTable.settings.sectors[sectComboBox.selectedItem].pass[i].uuid)
        table.insert(addVarArray, e == true and it or 0)
        typeSelect:addItem(e == true and userTable.settings.label[addVarArray[i]] .. " : " .. userTable.settings.sectors[sectComboBox.selectedItem].pass[i].data)
      end
      if typeSelect:count() > selected then
        selected = typeSelect:count()
      end
      typeSelect.selectedItem = selected
    end
    freshType()
    varYesButton = varContainer.layout:addChild(GUI.button(1,21,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.addvar))
    varYesButton.onTouch = function()
      local selected = extraVar2.selectedItem
      local data = userTable.settings.type[selected] == "-int" and varInput.selectedItem or userTable.settings.type[selected] == "bool" and nil or varInput.text
      table.insert(userTable.settings.sectors[sectComboBox.selectedItem].pass,{["uuid"]=userTable.settings.calls[selected],["data"]=data})
      freshType()
    end
    extraVar = varContainer.layout:addChild(GUI.button(1,21,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.delvar))
    extraVar.onTouch = function()
      local selected = typeSelect.selectedItem
      table.remove(userTable.settings.sectors[sectComboBox.selectedItem].pass,selected)
      freshType()
    end
    local prev = "string"
    local refreshInput = function()
      local selected = extraVar2.selectedItem
      if userTable.settings.type[selected] == "string" or userTable.settings.type[selected] == "-string" then
        if prev == "-int" then
          varInput:remove()
          varInput = varContainer.layout:addChild(GUI.input(1,1,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
        end
        varInput.text = ""
        varInput.disabled = false
      elseif userTable.settings.type[selected] == "int" then
        if prev == "-int" then
          varInput:remove()
          varInput = varContainer.layout:addChild(GUI.input(1,1,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
        end
        varInput.text = ""
        varInput.disabled = false
      elseif userTable.settings.type[selected] == "-int" then
        if prev ~= "-int" then
          varInput:remove()
          varInput = varContainer.layout:addChild(GUI.comboBox(1,1,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
        else
          varInput:clear()
        end
        for _,value in pairs(userTable.settings.data[selected]) do
          varInput:addItem(value)
        end
        varInput.selectedItem = 1
      else
        if prev == "-int" then
          varInput:remove()
          varInput = varContainer.layout:addChild(GUI.input(1,1,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
        end
        varInput.text = ""
        varInput.disabled = true
      end
      prev = userTable.settings.type[selected]
    end
    varContainer.layout:addChild(GUI.label(1,1,3,1,style.sectorText, loc.allpasseslabel))
    extraVar2 = varContainer.layout:addChild(GUI.comboBox(1,1,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
    for i=1,#userTable.settings.var,1 do
      extraVar2:addItem(userTable.settings.label[i]).onTouch = refreshInput
    end
    varInput = varContainer.layout:addChild(GUI.input(1,1,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
    refreshInput()
  end

  --GUI Setup
  window:addChild(GUI.panel(1,1,37,33,style.listPanel))
  sectorList = window:addChild(GUI.list(2, 2, 35, 31, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
  sectorList:addItem("HELLO")
  listPageNumber = 0
  updateSecList()


  --Sector infos local sectorList, sectorNameInput, newSectorButton, delSectorButton, sectorPassNew, sectorPassRemove, sectorPassList, userPassSelfSelector, userPassDataSelector, userPassTypeSelector
  window:addChild(GUI.label(40,12,1,1,style.passNameLabel,"Sector name: "))
  sectorNameInput = window:addChild(GUI.input(64,12,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputname))
  window:addChild(GUI.panel(40,14,96,1,style.bottomDivider))
  window:addChild(GUI.panel(40,15,1,18,style.bottomDivider))

  window:addChild(GUI.panel(42,17,37,33,style.listPanel))
  sectorPassList = window:addChild(GUI.list(43, 18, 35, 31, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))

  window:addChild(GUI.label(85,17,1,1,style.passNameLabel,"Select Pass : "))
  userPassSelfSelector = window:addChild(GUI.comboBox(100,17,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
  userPassSelfSelector:addItem("staff")
  for i=1,#userTable.passSettings.var,1 do
    userPassSelfSelector:addItem(userTable.settings.label[i]).onTouch = refreshInput
  end
  refreshInput(0)
  window:addChild(GUI.label(85,19,1,1,style.passNameLabel,"Change Input: "))
end

module.close = function()
  return {["sectors"]={}}
end

return module