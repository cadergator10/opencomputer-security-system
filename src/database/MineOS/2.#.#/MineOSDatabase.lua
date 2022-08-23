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
local modulesPath = aRD .. "Modules/"
local loc = system.getLocalization(aRD .. "Localizations/")

--------

local workspace, window, menu, userTable, settingTable, modulesLayout, modules
local cardStatusLabel, userList, userNameText, createAdminCardButton, userUUIDLabel, linkUserButton, linkUserLabel, cardWriteButton, StaffYesButton
local cardBlockedYesButton, userNewButton, userDeleteButton, userChangeUUIDButton, listPageLabel, listUpButton, listDownButton, updateButton
local addVarButton, delVarButton, editVarButton, varInput, labelInput, typeSelect, extraVar, varContainer, addVarArray, varYesButton, extraVar2, extraVar3, settingsButton
local sectComboBox, sectLockBox, sectNewButton, sectDelButton, sectUserButton

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
local version = "v2.4.0"

local modem

local tableRay = {}
local prevmod

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
local function saveTable(  tbl,filename )
  local tableFile = fs.open(filename, "w")
  tableFile:write(ser.serialize(tbl))
  tableFile:close()
end

--// The Load Function
local function loadTable( sfile )
  local tableFile = fs.open(sfile, "r")
  if tableFile ~= nil then
    return ser.unserialize(tableFile:readAll())
  else
    return nil
  end
end

local function callModem(callPort,...) --Does it work?
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
--TODO: Finish the dang thing CJ! Modules and SUCCH

local function updateServer(table)
  local data
  if table then
    for _,value in pairs(table) do
      data[value] = userTable[value]
    end
  else
    data = userTable
  end
  data = ser.serialize(data)
  local crypted = crypt(data, settingTable.cryptKey)
  if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
  end
  modem.broadcast(modemPort, "updateuserlist", crypted)
end

local function devMod()
  local module = {}
  local component = require("component")

  module.onTouch = function()
    GUI.alert("It worked!")
  end
  module.close = function()

  end
end

local function modulePress()
  local selected = modulesLayout.selectedItem
  if prevmod ~= nil then updateServer(prevmod.close()) end
end

local function changeSettings()
  addVarArray = {["cryptKey"]=settingTable.cryptKey,["style"]=settingTable.style,["autoupdate"]=settingTable.autoupdate}
  varContainer = GUI.addBackgroundContainer(workspace, true, true)
  local styleEdit = varContainer.layout:addChild(GUI.input(1,1,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.style))
  styleEdit.text = settingTable.style
  styleEdit.onInputFinished = function()
    addVarArray.style = styleEdit.text
  end
  local autoupdatebutton = varContainer.layout:addChild(GUI.button(1,6,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.autoupdate))
  autoupdatebutton.switchMode = true
  autoupdatebutton.pressed = settingTable.autoupdate
  autoupdatebutton.onTouch = function()
    addVarArray.autoupdate = autoupdatebutton.pressed
  end
  local acceptButton = varContainer.layout:addChild(GUI.button(1,11,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.submit))
  acceptButton.onTouch = function()
    settingTable = addVarArray
    saveTable(settingTable,aRD .. "dbsettings.txt")
    varContainer:removeChildren()
    varContainer:remove()
    varContainer = nil
    GUI.alert(loc.settingchangecompleted)
    updateServer(tableRay)
    window:remove()
  end
end

----------Setup GUI
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

workspace, window, menu = system.addWindow(GUI.filledWindow(2,2,150,45,style.windowFill))

--window.modLayout = window:addChild(GUI.layout(14, 12, window.width - 14, window.height - 12, 1, 1))
window.modLayout = window:addChild(GUI.container(14, 12, window.width - 14, window.height - 12)) --136 width, 33 height

local dbstuff = {["update"] = function(table,its)
  if its and settingTable.autoupdate then
    updateServer(table)
  end
end, ["save"] = function()
  saveTable(userTable,"userlist.txt")
end, ["crypt"]=function(str,reverse)
  return crypt(str,settingTable.cryptKey,reverse)
end}

window:addChild(GUI.panel(1,11,12,12,style.listPanel))
modulesLayout = window:addChild(GUI.list(2,12,10,10,3,0,style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
local modulors = fs.list(modulesPath)
modules = {}
table.insert(modulors,1,"dev")
for i = 1, #modulors do
  if i == 1 then
    local object = modulesLayout:addItem(modulors[i])
    local success, result = pcall(devMod, workspace, window.modLayout, loc, dbstuff, style)
    if success then
      object.module = result
      object.isDefault = true
      object.onTouch = modulePress
      table.insert(modules,result)
    else
      error("Failed to execute module " .. modulors[i] .. ": " .. tostring(result))
    end
  else
    local result, reason = loadfile(modulesPath .. modulors[i] .. "Main.lua")
    if result then
      local success, result = pcall(result, window.modLayout, loc, dbstuff)
      if success then
        local object = modulesLayout:addItem(result.name)
        object.module = result
        object.isDefault = false
        object.onTouch = modulePress
        table.insert(modules,result)
        for i=1,#result.table,1 do
          table.insert(tableRay,result.table[i])
        end
      else
        error("Failed to execute module " .. modulors[i] .. ": " .. tostring(result))
      end
    else
      error("Failed to load module " .. modulors[i] .. ": " .. tostring(reason))
    end
  end
end

local check,_,_,_,_,work = callModem(modemPort,"getquery",ser.serialize(tableRay))
if check then
  work = ser.unserialize(crypt(work,settingTable.cryptKey,true))
  saveTable(work,aRD .. "userlist.txt")
  userTable = work
else
  GUI.alert(loc.userlistfailgrab)
  userTable = loadTable(aRD .. "userlist.txt")
  if userTable == nil then
    GUI.alert("No userlist found")
    window:remove()
  end
end

for i=1,#modules,1 do
  modules[i].init(userTable)
end

local contextMenu = menu:addContextMenuItem("File")
contextMenu:addItem("Close").onTouch = function()
  window:remove()
  --os.exit()
end

--Settings Stuff
settingsButton = window:addChild(GUI.button(40,42,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.settingsvar))
settingsButton.onTouch = changeSettings

--Database name and stuff and CardWriter
window:addChild(GUI.panel(64,2,88,5,style.cardStatusPanel))
window:addChild(GUI.label(66,4,3,3,style.cardStatusLabel,prgName .. " | " .. version))
cardStatusLabel = window:addChild(GUI.label(116, 4, 3,3,style.cardStatusLabel,loc.cardabsent))

--[[if settingTable.autoupdate == false then
  updateButton = window:addChild(GUI.button(128,8,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.updateserver))
  updateButton.onTouch = updateServer
end]]

