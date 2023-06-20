local module = {}
local component = require("component")
local GUI = require("GUI")
local ser = require("serialization")
local modem = component.modem

local userTable -- Holds userTable stuff.

local workspace, window, loc, database, style, compat = table.unpack({...}) --Sets up necessary variables: workspace is workspace, window is area to work in, loc is localization file, database are database commands, and style is the selected style file.

module.name = "Remote Control" --The name that shows up on the module's button.
module.table = {} --Set to the keys you want pulled from the userlist on the server,
module.debug = false --The database will set to true if debug mode on database is enabled. If you want to enable certain functions in debug mode.
module.config = {} --optional. Lets you add config settings which can be pulled by database.checkConfig("name").
--[[ INFO ABOUT module.config
Each value of table must be this: ["name"] = {["label"] = "a label",["type"]="bool",["default"]=false}
name = name that the variable is stored in. What you'll call with database.checkConfig("name") replacing "name" with the name
label = What the label will be in the settings database
type = The type of input it takes. bool is a button, string is a string input, int is a number (int) input
default = Default value if created for first time. bool is true or false, string is string input, and int is a number.
server = Whether the settings are pushed to the server as well (server-side settings) Settings are always saved database side
]]
local diagPort = 180


module.init = function(usTable) --Set userTable to what's received. Runs only once at the beginning
    userTable = usTable
end

module.onTouch = function() --Runs when the module's button is clicked. Set up the workspace here.
    --Verify their permissions
    if database.checkPerms("security",{"rc"},true) then
        window:addChild(GUI.label(2,16,3,3,style.passNameLabel,"You do not have permissions to do this"))
        return
    end
    --Door Setup
    local worked,_,_,_,_,doors = database.send(true,"rcdoors") --get doors
    if(worked) then --got doors
        local tempPasses = ser.unserialize(database.crypt(doors,true)) --decrypt and make table
        doors = {}
        for key,value in pairs(tempPasses) do --Perform loop to sort in a way which will be sent to the doors to activate them
            for keym,valuem in pairs(value.data) do
                table.insert(doors,{["call"]=value.id,["type"]=value.type,["data"]=valuem,["key"]=keym})
            end
        end
        --Define Variables
        local doorList, listPageLabel, listUpButton, listDownButton, openFive, openTen, openThirty, toggleOpen, openNum, openNumInput
        local pageMult = 10
        local listPageNumber = 0
        local previousPage = 0

        --Functions

        local function doorListCallback()
            openFive.disabled = false
            openTen.disabled = false
            openThirty.disabled = false
            toggleOpen.disabled = false
            openNum.disabled = false
            openNumInput.disabled = false
        end

        local function updateList()
            doorList:removeChildren()
            if (pageMult * listPageNumber) + 1 > #doors and listPageNumber ~= 0 then
                listPageNumber = listPageNumber - 1
            end
            local temp = pageMult * listPageNumber
            for i = temp + 1, temp + pageMult, 1 do
                if doors[i] == nil then

                else
                    doorList:addItem(doors[i].data.name).onTouch = doorListCallback
                end
            end
            doorList.selectedItem = 1
            previousPage = listPageNumber
            if pageMult * listPageNumber + pageMult < #doors then
                listUpButton.disabled = false
            else
                listUpButton.disabled = true
            end
            if listPageNumber == 0 then
                listDownButton.disabled = true
            end
            listDownButton.disabled = listPageNumber == 0
            listUpButton.disabled = #doors <= temp + pageMult
            openFive.disabled = false
            openTen.disabled = false
            openThirty.disabled = false
            toggleOpen.disabled = false
            openNum.disabled = false
            openNumInput.disabled = false
        end

        local function pageCallback(_,button)
            local function canFresh()
                updateList()
                doorListCallback()
            end
            if #doors ~= 0 then
                if button.isPos then
                    if listPageNumber < #doors/pageMult - 1 then
                        listPageNumber = listPageNumber + 1
                        canFresh()
                    end
                else
                    if listPageNumber > 0 then
                        listPageNumber = listPageNumber - 1
                        canFresh()
                    end
                end
            end
        end

        local function performCommand(_,button)
            local selected = pageMult * listPageNumber + doorList.selectedItem
            local send = {["id"]=doors[selected].call,["key"]=doors[selected].key,["type"]="base"}
            if(button.sendIt == 1) then
                send.type = "toggle"
            elseif(button.sendIt == 2) then
                send.type, send.delay = "delay", 5
            elseif (button.sendIt == 3) then
                send.type,send.delay = "delay", 10
            elseif(button.sendIt == 4) then
                send.type,send.delay = "delay", 30
            elseif(button.sendIt == 5) then
                if(openNumInput.text ~= "") then
                    send.type,send.delay = "delay", tonumber(openNumInput.text)
                else
                    GUI.alert("No seconds specified")
                    return
                end
            end
            modem.send(send.id,diagPort,"remoteControl",ser.serialize(send))
        end

        --Setup GUI

        window:addChild(GUI.panel(1,1,37,33,style.listPanel))
        doorList = window:addChild(GUI.list(2, 2, 35, 31, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
        listPageLabel = window:addChild(GUI.label(2,33,3,3,style.listPageLabel,tostring(listPageNumber + 1)))
        listUpButton = window:addChild(GUI.button(8,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "+"))
        listUpButton.onTouch, listUpButton.isPos = pageCallback,true
        listDownButton = window:addChild(GUI.button(12,33,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "-"))
        listDownButton.onTouch, listDownButton.isPos = pageCallback,false
        openFive = window:addChild(GUI.button(64,14,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "5 Seconds"))
        openFive.sendIt = 2
        openFive.onTouch = performCommand
        openFive.disabled = true
        openTen = window:addChild(GUI.button(64,16,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "10 Seconds"))
        openTen.sendIt = 3
        openTen.onTouch = performCommand
        openTen.disabled = true
        openThirty = window:addChild(GUI.button(64,18,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "30 Seconds"))
        openThirty.sendIt = 4
        openThirty.onTouch = performCommand
        openThirty.disabled = true
        toggleOpen = window:addChild(GUI.button(64,12,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "Toggle Open"))
        toggleOpen.sendIt = 1
        toggleOpen.onTouch = performCommand
        toggleOpen.disabled = true
        openNumInput = window:addChild(GUI.input(64,21,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputname))
        openNumInput.onInputFinished = function()
            if openNumInput.text ~= nil and openNumInput ~= "" then
                local num = tonumber(openNumInput.text)
                if(num == nil and num > 0) then
                    openNumInput.text = ""
                end
            end
        end
        openNumInput.disabled = true
        openNum = window:addChild(GUI.button(64,20,16,1, style.sectorButton,style.sectorText,style.sectorSelectButton,style.sectorSelectText, "# Seconds"))
        openNum.sendIt = 5
        openNum.onTouch = performCommand
        openNum.disabled = true
        updateList()
    else
        GUI.alert("No connection received")
    end
end

module.close = function()
    return {} --Return table of what you want the database to auto save (if enabled) of the keys used by this module
end

return module
