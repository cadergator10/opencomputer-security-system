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
  local sectorList, sectorNameInput, newSectorButton, delSectorButton, sectorPassNew, sectorPassRemove, sectorPassList, userPassSelfSelector, userPassDataSelector, userPassTypeSelector, userPassPrioritySelector
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

  local function refreshInput(uuid) --Does not change field back to string if switched to staff
    if uuid == nil then
      uuid = userPassSelfSelector.selectedItem - 1
    end
    if uuid ~= 0 then
      if userTable.passSettings.type[uuid] == "string" or userTable.passSettings.type[uuid] == "-string" or userTable.passSettings.type[uuid] == "int" then
        if prevPass == "-int" then
          userPassDataSelector:remove()
          userPassDataSelector = window:addChild(GUI.input(100,22,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
        end
        userPassDataSelector.text = ""
        userPassDataSelector.disabled = false
      elseif userTable.passSettings.type[uuid] == "-int" then
        if prevPass ~= "-int" then
          userPassDataSelector:remove()
          userPassDataSelector = window:addChild(GUI.comboBox(100,21,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
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
          userPassDataSelector = window:addChild(GUI.input(100,22,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
        end
        userPassDataSelector.text = ""
        userPassDataSelector.disabled = true
      end
    else
      if prevPass == "-int" then
        userPassDataSelector:remove()
        userPassDataSelector = window:addChild(GUI.input(100,22,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.inputtext))
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
          sectorPassList:addItem(userTable.passSettings.label[pass] .. " : " .. userTable.sectors[selectedId].pass[i].data .. " : p" .. userTable.sectors[selectedId].pass[i].priority .. " : " .. lockType[userTable.sectors[selectedId].pass[i].lock]) --Cannot cocatenate a nil value: unknown field
        else
          sectorPassList:addItem("Staff : 0 : p" .. userTable.sectors[selectedId].pass[i].priority .. " : " .. lockType[userTable.sectors[selectedId].pass[i].lock])
        end
      end
    end
    workspace:draw()
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
    workspace:draw()
  end

  local function createSector()
    local addVarArray = {["name"]="new sector",["uuid"]=uuid.next(),["pass"]={}}
    table.insert(userTable.sectors,addVarArray)
    addVarArray = nil
    database.save()
    database.update()
    updateSecList()
  end
  local function deleteSector()
    local selected = pageMult * listPageNumber + sectorList.selectedItem
    table.remove(userTable.sectors,selected)
    database.save()
    database.update()
    updateSecList()
  end

  local function createSectorPass()
    local selected = userPassSelfSelector.selectedItem - 1
    local data = selected == 0 and nil or userTable.passSettings.type[selected] == "-int" and userPassDataSelector.selectedItem or userTable.passSettings.type[selected] == "bool" and nil or userPassDataSelector.text
    local uuid = selected == 0 and "checkstaff" or userTable.passSettings.calls[selected]
    table.insert(userTable.sectors[pageMult * listPageNumber + sectorList.selectedItem].pass,{["uuid"]=uuid,["data"]=data,["lock"]=userPassTypeSelector.selectedItem,["priority"]=userPassPrioritySelector.selectedItem})
    sectorListCallback()
  end
  local function deleteSectorPass()
    local selected = pageMultPass * listPageNumberPass + sectorPassList.selectedItem
    table.remove(userTable.sectors[pageMult * listPageNumber + sectorList.selectedItem].pass,selected)
    sectorListCallback()
  end

  --GUI Setup
  window:addChild(GUI.panel(1,1,37,33,style.listPanel))
  sectorList = window:addChild(GUI.list(2, 2, 35, 31, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
  sectorList:addItem("HELLO")
  listPageNumber = 0
  updateSecList()


  --Sector infos newSectorButton, delSectorButton
  window:addChild(GUI.label(40,12,1,1,style.passNameLabel,"Sector name: "))
  sectorNameInput = window:addChild(GUI.input(64,12,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputname))
  sectorNameInput.onInputFinished = function()
    local selected = pageMult * listPageNumber + sectorList.selectedItem
    userTable.passes[selected].name = sectorNameInput.text
    updateSecList()
    sectorListCallback()
  end

  newSectorButton = window:addChild(GUI.button(85,12,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.addvar))
  newSectorButton.onTouch = createSector
  delSectorButton = window:addChild(GUI.button(100,12,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.delvar))
  delSectorButton.onTouch = deleteSector

  window:addChild(GUI.panel(40,14,96,1,style.bottomDivider))
  window:addChild(GUI.panel(40,15,1,18,style.bottomDivider))

  window:addChild(GUI.panel(42,17,37,17,style.listPanel))
  sectorPassList = window:addChild(GUI.list(43, 18, 35, 15, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))

  window:addChild(GUI.label(85,18,1,1,style.passNameLabel,"Select Pass : "))
  userPassSelfSelector = window:addChild(GUI.comboBox(100,17,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
  userPassSelfSelector:addItem("staff")
  for i=1,#userTable.passSettings.var,1 do
    userPassSelfSelector:addItem(userTable.passSettings.label[i]).onTouch = refreshInput
  end
  window:addChild(GUI.label(85,22,1,1,style.passNameLabel,"Change Input: "))
  userPassDataSelector = window:addChild(GUI.input(100,22,30,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputtext))
  refreshInput(0)
  window:addChild(GUI.label(85,26,1,1,style.passNameLabel,"Bypass Type : "))
  userPassTypeSelector = window:addChild(GUI.comboBox(100,25,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
  userPassTypeSelector:addItem(loc.sectoropen)
  userPassTypeSelector:addItem(loc.sectordislock)
  window:addChild(GUI.label(85,30,1,1,style.passNameLabel,"Priority    : "))
  userPassPrioritySelector = window:addChild(GUI.comboBox(100,29,30,3, style.sectorComboBack,style.sectorComboText,style.sectorComboArrowBack,style.sectorComboArrowText))
  for i=1,5,1 do
    userPassPrioritySelector:addItem(tostring(i))
  end
  sectorPassNew = window:addChild(GUI.button(85,33,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.addvar))
  sectorPassNew.onTouch = createSectorPass
  sectorPassRemove = window:addChild(GUI.button(100,33,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, loc.delvar))
  sectorPassRemove.onTouch = deleteSectorPass
end

module.close = function()
  return {["sectors"]={}}
end

return module