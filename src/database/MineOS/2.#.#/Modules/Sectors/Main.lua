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

  local pageMult = 10
  local listPageNumber = 0
  local previousPage = 0

  local pageMultPass = 10
  local listPageNumberPass = 0
  local previousPagePass = 0

  --Sector functions

  local function uuidtopass(uuid)
    for i=1,#userTable.passSettings.calls,1 do
      if userTable.passSettings.calls[i] == uuid then
        return true, i
      end
    end
    return false
  end

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
        sectorPassList:addItem(userTable.passSettings.label[pass] .. " : " .. userTable.sectors[selectedId].pass[i].data .. " : " .. lockType[userTable.sectors[selectedId].pass[i].lock])
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
  sectorList = window:addChild(GUI.list(2, 2, 35, 31, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
  sectorList:addItem("HELLO")
  listPageNumber = 0
  updateSecList()

  --Sector infos

end

module.close = function()
  return {["sectors"]={}}
end

return module