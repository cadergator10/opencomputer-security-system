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

--------

local workspace, window, menu, userTable, settingTable
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
  local result = {};
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
local check,_,_,_,_,work = callModem(modemPort,"getuserlist")
if check then
  work = ser.unserialize(crypt(work,settingTable.cryptKey,true))
  saveTable(work,aRD .. "userlist.txt")
  userTable = work
else
  GUI.alert(loc.userlistfailgrab)
  userTable = loadTable(aRD .. "userlist.txt")
  if userTable == nil then
    userTable = {["settings"]={["var"]={"level"},["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false},["sectors"]={{["name"]="",["uuid"]=uuid.next(),["type"]=1,["pass"]={},["status"]=1}}}}
  end
end

workspace, window, menu = system.addWindow(GUI.filledWindow(2,2,150,45,style.windowFill))

window.modLayout = window:addChild(GUI.layout(2, 12, window.width, 36, 1, 1))

local contextMenu = menu:addContextMenuItem("File")
contextMenu:addItem("Close").onTouch = function()
  window:remove()
  --os.exit()
end

