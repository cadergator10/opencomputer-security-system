local module = {}
local component = require("component")
local ser = require("serialization")
local GUI = require("GUI")
local uuid = require("uuid")
local event = require("event")
local fs = require("Filesystem")
local modem = component.modem
local scanner --if biometric reader is connected this isn't nil
local writer --Card reader

local handler --Holds the handler for cardinsert and cardremoval events in cardwriter

local permissions = {} --Holds current user's permissions whos signed in

local userTable

local workspace, window, loc, database, style, permissions = table.unpack({...})

module.name = "Security"
module.table = {"passes","passSettings","securityKeypads"} --passes is all card accounts; passSettings are the modular passes people can create
module.debug = false
module.config = {["secAPI"] = {["label"] = "Security API",["type"]="bool",["default"]=true,["server"]=true},["quickMCLink"] = {["label"] = "Allow quikidlink?",["type"]="bool",["default"]=false,["server"]=true}} --secAPI allows getVar and setVar commands by securityAPI; quikIDLink allows use of quikidlink program to link user with seperate bio reader

module.init = function(usTable)
  userTable = usTable
end

if component.isAvailable("os_cardwriter") then --see if it exists, otherwise close/crash program.
  writer = component.os_cardwriter
else
  GUI.alert(loc.cardwriteralert)
  return
end
if component.isAvailable("os_biometric") then --see if it exists, otherwise you can't link user biometrics
  scanner = component.os_biometric
end

local function split(s, delimiter) --splits string to table. "e,f,g" to {"e","f","g"}
  local result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match);
  end
  return result;
end

module.onTouch = function()
  local tabWindow, tabs, cardStatusLabel, selected
  local userEdit, passEdit
  do --keep it contained to remove memory after done
    local result, reason = loadfile(fs.path(system.getCurrentScript()) .. "Modules/modid" .. tostring(module.id) .. "/pass.lua")
    if result then
      passEdit = result
    else
      GUI.alert("Failed to load file pass.lua: " .. tostring(reason))
    end
    result, reason = loadfile(fs.path(system.getCurrentScript()) .. "Modules/modid" .. tostring(module.id) .. "/user.lua")
    if result then
      userEdit = result
    else
      GUI.alert("Failed to load file user.lua: " .. tostring(reason))
    end
  end
  
  local function migrateTab(_, button)
    if not button.doTheMove then
      varEditWindow:removeChildren()
    end
    if selected ~= button.myId then
      local success, result = pcall(button.toRun, workspace, tabWindow, loc, database, style, permissions, userTable)
      if not success then
        GUI.alert("Failed to run file: " .. tostring(reason))
      end

      selected = button.myId
    end
  end

  --Database name and stuff and CardWriter

  local function eventCallback(ev, id) --changing text of label if user inserts or removes all cards from cardwriter
    if ev == "cardInsert" then
      cardStatusLabel.text = loc.cardpresent
    elseif ev == "cardRemove" then
      cardStatusLabel.text = loc.cardabsent
    end
  end
  
  window:addChild(GUI.panel(123,2,12,3,style.cardStatusPanel))
  cardStatusLabel = window:addChild(GUI.label(124, 1, 10,3,style.cardStatusLabel,loc.cardabsent))
  handler = event.addHandler(eventCallback) --create callback to the handler to check for cardinsert and cardremoval

  tabWindow = window:addChild(GUI.container(1,4,window.width,window.height - 3))
  tabs = window:addChild(GUI.list(1, 1, window.width, 3, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
  tabs:setDirection(GUI.DIRECTION_HORIZONTAL)
  tabs:setAlignment(GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_TOP)
  local meh = tabs:addItem("Cards")
  meh.onTouch = migrateTab
  meh.myId = 1
  meh.toRun = userEdit
  meh = tabs:addItem("Passes / Keypad")
  meh.onTouch = migrateTab
  meh.myId = 2
  meh.toRun = passEdit

  tabs.selected = 1
  migrateTab(nil, {["doTheMove"]=true,["myId"]=1,["toRun"]=userEdit})
end

module.close = function() --when user switches modules
  event.removeHandler(handler) --don't keep looking for event
  return {"passes","passSettings"} --returns what I want updated (if autoupdate enabled)
end

return module
