local GUI = require("GUI")
local system = require("System")
local departments = {"SD","ScD","MD","E&T","O5"}
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
 
----------
 
local workspace, window, menu
local cardStatusLabel, userList, userNameText, userLevelLabel, LevelUpButton, LevelDownButton, createAdminCardButton
local cardBlockedYesButton, userNewButton, userDeleteButton, userChangeUUIDButton, MTFYesButton, listPageLabel, listUpButton, listDownButton
local GOIYesButton, SecYesButton, userArmoryLabel, ArmoryUpButton, ArmoryDownButton, userUUIDLabel
local userDepLabel, DepUpButton, DepDownButton, IntYesButton, StaffYesButton, linkUserButton, linkUserLabel
 
----------
 
local prgName = "Security database"
local version = "v7.1"
 
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
  modem.broadcast(modemPort, "updateuser", crypted)
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

  saveTable(userTable, "userlist.txt")
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
  userLevelLabel.text = tostring(userTable[selectedId].level)
  userArmoryLabel.text = tostring(userTable[selectedId].armory)
  userDepLabel.text = departments[userTable[selectedId].department]
  if userTable[selectedId].blocked == true then
    cardBlockedYesButton.pressed = true
  else
    cardBlockedYesButton.pressed = false
  end
  cardBlockedYesButton.disabled = false
  if userTable[selectedId].mtf == true then
    MTFYesButton.pressed = true
  else
    MTFYesButton.pressed = false
  end
  MTFYesButton.disabled = false
  if userTable[selectedId].goi == true then
    GOIYesButton.pressed = true
  else
    GOIYesButton.pressed = false
  end
  GOIYesButton.disabled = false
  if userTable[selectedId].sec == true then
    SecYesButton.pressed = true
  else
    SecYesButton.pressed = false
  end
  SecYesButton.disabled = false
  if userTable[selectedId].int == true then
    IntYesButton.pressed = true
  else
    IntYesButton.pressed = false
  end
  IntYesButton.disabled = false
  if userTable[selectedId].staff == true then
    StaffYesButton.pressed = true
  else
    StaffYesButton.pressed = false
  end
  StaffYesButton.disabled = false
  
  listPageLabel.text = tostring(listPageNumber + 1)

  LevelUpButton.disabled = false
  LevelDownButton.disabled = false
  ArmoryUpButton.disabled = false
  ArmoryDownButton.disabled = false
  DepUpButton.disabled = false
  DepDownButton.disabled = false
  userNameText.disabled = false
end
 
function mtfUserCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  userTable[selected].mtf = MTFYesButton.pressed
  updateList()
  userListCallback()
end
 
function goiUserCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  userTable[selected].goi = GOIYesButton.pressed
  updateList()
  userListCallback()
end
 
function secUserCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  userTable[selected].sec = SecYesButton.pressed
  updateList()
  userListCallback()
end
 
function intUserCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  userTable[selected].int = IntYesButton.pressed
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
  local tmpTable = {["name"] = "new", ["blocked"] = false, ["level"] = 1, ["date"] = os.date(), ["armory"] = 0, ["mtf"] = false, ["sec"] = false, ["int"] = false, ["staff"] = false, ["goi"] = false, ["department"] = 1, ["uuid"] = uuid.next(), ["link"] = "nil"}
  table.insert(userTable, tmpTable)
  updateList()
end
 
function deleteUserCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  userTable[selected] = nil
  updateList()
  userNameText.text = ""
  userLevelLabel.text = "#"
  userArmoryLabel.text = "#"
  userDepLabel.text = "NAN"
  LevelUpButton.disabled = true
  LevelDownButton.disabled = true
  ArmoryUpButton.disabled = true
  ArmoryDownButton.disabled = true
  DepUpButton.disabled = true
  DepDownButton.disabled = true
  userNameText.disabled = true
  MTFYesButton.disabled = true
  GOIYesButton.disabled = true
  SecYesButton.disabled = true
  IntYesButton.disabled = true
  StaffYesButton.disabled = true
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
 
function levelUpCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  if userTable[selected].level < 101 then
    userTable[selected].level = userTable[selected].level + 1
  end
  updateList()
  userListCallback()
end
 
function levelDownCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  if userTable[selected].level > 1 then
    userTable[selected].level = userTable[selected].level - 1
  end
  updateList()
  userListCallback()
end
 
function armorUpCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  if userTable[selected].armory < 4 then
    userTable[selected].armory = userTable[selected].armory + 1
  end
  updateList()
  userListCallback()
end
 
function armorDownCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  if userTable[selected].armory > 0 then
    userTable[selected].armory = userTable[selected].armory - 1
  end
  updateList()
  userListCallback()
end
 
function depUpCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  if userTable[selected].department < 5 then
    userTable[selected].department = userTable[selected].department + 1
  end
  updateList()
  userListCallback()
end
 
function depDownCallback()
  local selected = pageMult * listPageNumber + userList.selectedItem
  if userTable[selected].department > 1 then
    userTable[selected].department = userTable[selected].department - 1
  end
  updateList()
  userListCallback()
end

function pageUpCallback()
  if listPageNumber < #userTable/pageMult - 1 then
    listPageNumber = listPageNumber + 1
  end
  updateList()
  userListCallback()
end
 
function pageDownCallback()
  if listPageNumber > 0 then
    listPageNumber = listPageNumber - 1
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
    local container = GUI.addBackgroundContainer(window, false, true, "You have 20 seconds to link your device now. Do not click anything")
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
 
----------GUI SETUP
workspace, window, menu = system.addWindow(GUI.filledWindow(2,2,150,45,0xE1E1E1))
 
local layout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))
 
local contextMenu = menu:addContextMenuItem("File")
contextMenu:addItem("Close").onTouch = function()
window:remove()
end
 
window:addChild(GUI.panel(3,3,60,36,0x6B6E74))
userList = window:addChild(GUI.list(4, 4, 58, 34, 3, 0, 0xE1E1E1, 0x4B4B4B, 0xD2D2D2, 0x4B4B4B, 0x3366CC, 0xFFFFFF, false))
userList:addItem("HELLO")
listPageNumber = 0
userTable = loadTable("userlist.txt")
if userTable == nil then
  userTable = {}
end
settingTable = loadTable("dbsettings.txt")
if settingTable == nil then
  GUI.alert("It is recommended you check your cryptKey settings in dbsettings.txt file in the app's directory. Currently at default {1,2,3,4,5}. If the server is set to a different cryptKey than this, it will not function and crash the server.")
  settingTable = {["cryptKey"]={1,2,3,4,5}}
  saveTable(settingTable,"dbsettings.txt")
end
updateList()
 
--user infos
window:addChild(GUI.label(64,12,3,3,0x165FF2,"User name : "))
userUUIDLabel = window:addChild(GUI.label(64,14,3,3,0x165FF2,"UUID      : user not selected"))
window:addChild(GUI.label(64,16,3,3,0x165FF2,"Level     : "))
window:addChild(GUI.label(64,18,3,3,0x165FF2,"MTF       : "))
window:addChild(GUI.label(64,20,3,3,0x165FF2,"GOI       : "))
window:addChild(GUI.label(64,22,3,3,0x165FF2,"Security  : "))
window:addChild(GUI.label(64,24,3,3,0x165FF2,"Intercom  : "))
window:addChild(GUI.label(64,26,3,3,0x165FF2,"STAFF     : "))
window:addChild(GUI.label(64,28,3,3,0x165FF2,"ArmorLevel: "))
window:addChild(GUI.label(64,30,3,3,0x165FF2,"Department: "))
window:addChild(GUI.label(64,32,3,3,0x165FF2,"Blocked   : "))
if enableLinking == true then linkUserLabel = window:addChild(GUI.label(64,34,3,3,0x165FF2,"LINK      : user not selected")) end --put at end for safe keeping CADE

listPageLabel = window:addChild(GUI.label(4,38,3,3,0x165FF2,tostring(listPageNumber + 1)))
listUpButton = window:addChild(GUI.button(8,38,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "+"))
listUpButton.onTouch = pageUpCallback
listDownButton = window:addChild(GUI.button(12,38,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "-"))
listDownButton.onTouch = pageDownCallback

userNameText = window:addChild(GUI.input(88,12,16,1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "input name"))
userNameText.onInputFinished = inputCallback
userLevelLabel = window:addChild(GUI.label(88,16,3,3,0x165FF2,"#"))
LevelUpButton = window:addChild(GUI.button(92,16,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "+"))
LevelUpButton.onTouch = levelUpCallback
LevelDownButton = window:addChild(GUI.button(96,16,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "-"))
LevelDownButton.onTouch = levelDownCallback
MTFYesButton = window:addChild(GUI.button(88,18,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "toggle"))
MTFYesButton.switchMode = true
MTFYesButton.onTouch = mtfUserCallback
GOIYesButton = window:addChild(GUI.button(88,20,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "toggle"))
GOIYesButton.switchMode = true
GOIYesButton.onTouch = goiUserCallback
SecYesButton = window:addChild(GUI.button(88,22,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "toggle"))
SecYesButton.switchMode = true
SecYesButton.onTouch = secUserCallback
IntYesButton = window:addChild(GUI.button(88,24,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "toggle"))
IntYesButton.switchMode = true
IntYesButton.onTouch = intUserCallback
StaffYesButton = window:addChild(GUI.button(88,26,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "toggle"))
StaffYesButton.switchMode = true
StaffYesButton.onTouch = staffUserCallback
userArmoryLabel= window:addChild(GUI.label(88,28,3,3,0x165FF2,"#"))
ArmoryUpButton = window:addChild(GUI.button(92,28,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "+"))
ArmoryUpButton.onTouch = armorUpCallback
ArmoryDownButton= window:addChild(GUI.button(96,28,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "-"))
ArmoryDownButton.onTouch = armorDownCallback
userDepLabel = window:addChild(GUI.label(88,30,3,3,0x165FF2,"NAN"))
DepUpButton = window:addChild(GUI.button(92,30,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "+"))
DepUpButton.onTouch = depUpCallback
DepDownButton = window:addChild(GUI.button(96,30,3,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "-"))
DepDownButton.onTouch = depDownCallback
cardBlockedYesButton = window:addChild(GUI.button(88,32,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "toggle"))
cardBlockedYesButton.switchMode = true
cardBlockedYesButton.onTouch = blockUserCallback
if enableLinking == true then
    linkUserButton = window:addChild(GUI.button(96,34,16,1, 0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "link device"))
	linkUserButton.onTouch = linkUserCallback
end
 
LevelUpButton.disabled = true
LevelDownButton.disabled = true
ArmoryUpButton.disabled = true
ArmoryDownButton.disabled = true
DepUpButton.disabled = true
DepDownButton.disabled = true
userNameText.disabled = true
MTFYesButton.disabled = true
GOIYesButton.disabled = true
SecYesButton.disabled = true
IntYesButton.disabled = true
StaffYesButton.disabled = true
cardBlockedYesButton.disabled = true
if enableLinking == true then linkUserButton.disabled = true end
 
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
 
--CardWriter frame
 
window:addChild(GUI.panel(114, 2, 38, 6, 0x6B6E74))
cardStatusLabel = window:addChild(GUI.label(116, 4, 3,3,0x165FF2,"     No card   "))
 
--write card button
cardWriteButton = window:addChild(GUI.button(128,42,16,1,0xFFFFFF, 0x555555, 0x880000, 0xFFFFFF, "write")) 
cardWriteButton.onTouch = writeCardCallback 
 
event.addHandler(eventCallback)
 
workspace:draw()
workspace:start()
