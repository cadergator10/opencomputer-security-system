local GUI = require("GUI")
local system = require("System")
local modemPort = 1000
local syncPort = 199
local dbPort = 180

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

local workspace, window, menu, userTable, settingTable, modulesLayout, modules, permissions
local cardStatusLabel, varContainer, addVarArray, settingsButton, updateButton
local usernamename, userpasspass

----------

local prgName = loc.name
local version = "v3.0.0"

local modem

local tableRay = {}
local prevmod

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
  modem.broadcast(callPort,...)
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

local function checkPerms(base,data, reverse)
  for i=1,#data,1 do
    if permissions["~" .. base .."." .. data[i]] == true then
      return reverse == true and true or false
    end
  end
  if permissions["all"] == true or permissions[base .. ".*"] == true then
    return reverse == false and true or false
  end
  for i=1,#data,1 do
    if permissions[base .. "." .. data[i]] == true then
      return reverse == false and true or false
    end
  end
  return reverse == true and true or false
end

----------Callbacks

local function updateServer(table)
  local data = {}
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

local function devMod(...)
  local module = {}
  local component = require("component")

  local workspace, window, loc, database, style, permissions = table.unpack({...})

  module.init = function()

  end
  module.onTouch = function() --TODO: Prepare this for Module installation, user permissions, and more.
    local userEditButton, moduleInstallButton, layout

    local function disabledSet()
      userEditButton.disabled = checkPerms("dev",{"usermanagement"},true)
      moduleInstallButton.disabled = checkPerms("dev",{"systemmanagement"},true)
    end

    --Big Callbacks
    local function beginUserEditing() --136 width, 33 height big area, 116 width, 33 height extra area.
      local userList, permissionList, permissionInput, addPerm, deletePerm, users, addUser, deleteUser, userInput, passwordInput
      local listUp, listDown, listNum, listUp2, listDown2, listNum2

      local pageMult = 10
      local listPageNumber = 0
      local previousPage = 0

      local listPageNumber2 = 0
      local previousPage2 = 0

      local function updateUserStuff()
        local selectedId = pageMult * listPageNumber + userList.selectedItem
        local disselect = pageMult * listPageNumber2
        local pees = userList:getItem(userList.selectedItem)
        permissionList:removeChildren()
        for i=disselect+1,disselect+pageMult,1 do
          if users[pees.text].perm[i] == nil then

          else
            permissionList:addItem(users[pees.text].perm[i])
          end
        end
        permissionInput.disabled = false
        addPerm.disabled = false
        deletePerm.disabled = false
      end

      local function updateList()
        local selectedId = userList.selectedItem
        userList:removeChildren()
        local temp = pageMult * listPageNumber
        local count = 0
        for key,_ in pairs(users) do
          count = count + 1
          if count >= temp + 1 and count <= temp + pageMult then
            userList:addItem(key).onTouch = updateUserStuff
          end
        end
        if previousPage == listPageNumber then
          userList.selectedItem = selectedId
        else
          previousPage = listPageNumber
        end
      end

      local function pageCallback(workspace,button)
        local count = {}
        for key,_ in pairs(users) do
          table.insert(count,key)
        end
        if button.isPos then
          if button.isListNum == 1 then
            if listPageNumber < #count/pageMult - 1 then
              listPageNumber = listPageNumber + 1
            end
          else
            if listPageNumber2 < #users[count[pageMult * listPageNumber + userList.selectedItem]].perms/pageMult - 1 then
              listPageNumber2 = listPageNumber2 + 1
            end
          end
        else
          if button.isListNum == 1 then
            if listPageNumber > 0 then
              listPageNumber = listPageNumber - 1
            end
          else
            if listPageNumber2 > 0 then
              listPageNumber2 = listPageNumber2 - 1
            end
          end
        end
        updateList()
        updateUserStuff()
      end

      layout:removeChildren()
      userEditButton.disabled = true
      moduleInstallButton.disabled = true
      
      local e,_,_,_,_,peed,meed = callModem(modemPort,"signIn",crypt(ser.serialize({["command"]="grab",["user"]=usernamename,["pass"]=userpasspass}),settingTable.cryptKey))
      if e then
        if crypt(peed,settingTable.cryptKey,true) == "true" then
          users = ser.unserialize(crypt(meed,settingTable.cryptKey,true))
          layout:addChild(GUI.panel(1,1,37,33,style.listPanel))
          userList = layout:addChild(GUI.list(2, 2, 35, 31, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
          userList:addItem("HELLO")
          listPageNumber = 0
          layout:addChild(GUI.panel(40,1,37,33,style.listPanel))
          permissionList = layout:addChild(GUI.list(41, 2, 35, 31, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
          listPageNumber2 = 0
          updateList()
          --local permissionInput, addPerm, deletePerm, users, addUser, deleteUser
          userInput = layout:addChild(GUI.input(80,1,30,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputname))
          passwordInput = layout:addChild(GUI.input(80,3,30,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", "input pass",true,"*"))
          addUser = layout:addChild(GUI.button(80,5,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Add User"))
          addUser.onTouch = function()
            users[userInput.text] = {["pass"]=crypt(passwordInput.text,settingTable.cryptKey),["perms"]={}}
            modem.broadcast(modemPort,"signIn",ser.serialize({["command"]="update",["data"]=users}))
            userInput.text = ""
            passwordInput.text = ""
            updateList()
          end
          deleteUser = layout:addChild(GUI.button(100,5,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Delete User"))
          deleteUser.onTouch = function()
            users[userList:getItem(userList.selectedItem).text] = nil
            modem.broadcast(modemPort,"signIn",ser.serialize({["command"]="update",["data"]=users}))
            updateList()
          end
          layout:addChild(GUI.panel(80,7,36,1,style.bottomDivider))
          permissionInput = layout:addChild(GUI.input(80,9,30,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", "Input Perm"))
          addPerm = layout:addChild(GUI.button(80,11,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Add Perm"))
          addPerm.onTouch = function()
            table.insert(users[userList:getItem(userList.selectedItem).text].perms,permissionInput.text)
            permissionInput.text = ""
            modem.broadcast(modemPort,"signIn",ser.serialize({["command"]="update",["data"]=users}))
            updateUserStuff()
          end
          addPerm.disabled = true
          deletePerm = layout:addChild(GUI.button(100,11,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Delete Perm"))
          deletePerm.onTouch = function()
            table.remove(users[userList:getItem(userList.selectedItem).text].perms,pageMult * listPageNumber2 + permissionList.selectedItem)
            modem.broadcast(modemPort,"signIn",ser.serialize({["command"]="update",["data"]=users}))
            updateUserStuff()
          end
          addPerm.disabled = true
        else
          GUI.alert("incorrect permissions to grab userlist")
          disabledSet()
        end
      else
        GUI.alert("failed to grab permissions")
        disabledSet()
      end
    end
    local function moduleInstallation()
      layout:removeChildren()
      userEditButton.disabled = true
      moduleInstallButton.disabled = true
    end
    
    layout = window:addChild(GUI.container(20,1,window.width - 20, window.height))
    userEditButton = window:addChild(GUI.button(3,3,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Edit Users"))
    userEditButton.onTouch = beginUserEditing
    moduleInstallButton = window:addChild(GUI.button(3,5,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "Manage Modules")) --LEFT OFF
    moduleInstallButton.onTouch = moduleInstallation()
    disabledSet()
  end
  module.close = function()

  end
  return module
end

local function runModule(module)
  window.modLayout:removeChildren()
  module.onTouch()
  workspace:draw()
end

local function modulePress()
  local selected = modulesLayout.selectedItem
  if prevmod ~= nil then
    local p = prevmod.close()
    if p and settingTable.autoupdate then
      updateServer(p)
    end
  end
  selected = modulesLayout:getItem(selected)
  prevmod = selected.module
  runModule(selected.module)
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
  local portInput = varContainer.layout:addChild(GUI.input(1,11,16,1, style.containerInputBack,style.containerInputText,style.containerInputPlaceholder,style.containerInputFocusBack,style.containerInputFocusText, "", loc.style))
  portInput.text = settingTable.port
  portInput.onInputFinished = function()
    addVarArray.port = tonumber(portInput.text)
  end
  local acceptButton = varContainer.layout:addChild(GUI.button(1,16,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.submit))
  acceptButton.onTouch = function()
    settingTable = addVarArray
    saveTable(settingTable,aRD .. "dbsettings.txt")
    varContainer:removeChildren()
    varContainer:remove()
    varContainer = nil
    GUI.alert(loc.settingchangecompleted)
    updateServer()
    window:remove()
    event.push("gonow")
  end
end

----------Setup GUI
settingTable = loadTable(aRD .. "dbsettings.txt")
if settingTable == nil then
  GUI.alert(loc.cryptalert)
  settingTable = {["cryptKey"]={1,2,3,4,5},["style"]="default.lua",["autoupdate"]=false,["port"]=1000}
  modem.open(syncPort)
  local e,_,_,_,_, f = callModem(syncPort,"syncport")
  if e then
    settingTable.port = tonumber(f)
  end
  modem.close(syncPort)
  saveTable(settingTable,aRD .. "dbsettings.txt")
  os.exit()
end
if settingTable.style == nil then
  settingTable.style = "default.lua"
  saveTable(settingTable,aRD .. "dbsettings.txt")
end
if settingTable.autoupdate == nil then
  settingTable.autoupdate = false
  saveTable(settingTable,aRD .. "dbsettings.txt")
end

modemPort = settingTable.port
if modem.isOpen(modemPort) == false then
  modem.open(modemPort)
end

style = fs.readTable(stylePath .. settingTable.style)

workspace, window, menu = system.addWindow(GUI.filledWindow(2,2,150,45,style.windowFill))

--window.modLayout = window:addChild(GUI.layout(14, 12, window.width - 14, window.height - 12, 1, 1))
window.modLayout = window:addChild(GUI.container(14, 12, window.width - 14, window.height - 12)) --136 width, 33 height

local function finishSetup()
  local dbstuff = {["update"] = function(table,force)
    if force or settingTable.autoupdate then
      updateServer(table)
    end
  end, ["save"] = function()
    saveTable(userTable,"userlist.txt")
  end, ["crypt"]=function(str,reverse)
    return crypt(str,settingTable.cryptKey,reverse)
  end, ["send"]=function(wait,data,data2)
    if wait then
      return callModem(modemPort,data,data2)
    else
      modem.broadcast(modemPort,data,data2)
    end
  end, ["checkPerms"] = checkPerms}

  window:addChild(GUI.panel(1,11,12,window.height - 11,style.listPanel))
  modulesLayout = window:addChild(GUI.list(2,12,10,window.height - 13,3,0,style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
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
        local success, result = pcall(result, workspace, window.modLayout, loc, dbstuff, style)
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
    saveTable(work.data,aRD .. "userlist.txt")
    userTable = work.data
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
  settingsButton = window:addChild(GUI.button(40,3,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.settingsvar))
  settingsButton.onTouch = changeSettings

  --Database name and stuff and CardWriter
  window:addChild(GUI.panel(64,2,88,5,style.cardStatusPanel))
  window:addChild(GUI.label(66,3,3,1,style.cardStatusLabel,prgName .. " | " .. version))
  window:addChild(GUI.label(66,5,3,1,style.cardStatusLabel,"Welcome " .. usernamename))
  cardStatusLabel = window:addChild(GUI.label(116, 4, 3,3,style.cardStatusLabel,loc.cardabsent))

  if settingTable.autoupdate == false then
    updateButton = window:addChild(GUI.button(40,5,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.updateserver))
    updateButton.onTouch = function()
      updateServer()
    end
  end
end

local function signInPage()
  local username = window.modLayout:addChild(GUI.input(30,3,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", "username"))
  local password = window.modLayout:addChild(GUI.input(30,6,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", "password",true,"*"))
  local submit = window.modLayout:addChild(GUI.button(30,9,16,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "submit"))
  submit.onTouch = function()
    local check, work
    check,_,_,_,_,work,permissions = callModem(modemPort,"signIn",crypt(ser.serialize({["command"]="signIn",["user"]=username.text,["pass"]=password.text}),settingTable.cryptKey))
    if check then
      work = crypt(work,settingTable.cryptKey,true)
      if work == "true" then
        local pees = ser.unserialize(crypt(permissions,settingTable.cryptKey,true))
        permissions = {}
        for _,value in pairs(pees) do
          permissions[value] = true
        end
        GUI.alert("Successfully signed in!")
        usernamename, userpasspass = username.text,password.text
        window.modLayout:removeChildren()
        finishSetup()
      else
        GUI.alert("Incorrect username/password")
      end
    else
      GUI.alert("Failed to receive confirmatin from server")
    end
  end
end

signInPage()

workspace:draw()
workspace:start()