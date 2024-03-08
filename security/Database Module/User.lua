--Moved over all pass stuff from security module to another file to save space in main and make some stuff easier to see
local workspace, window, loc, database, style, permissions, userTable = table.unpack({...}) --main stuff TODO: Check to see if anything is missing

local component = require("component")
local ser = require("serialization")
local GUI = require("GUI")
local uuid = require("uuid")
local event = require("event")
local scanner --if biometric reader is connected this isn't nil
local writer --Card reader
local modem = component.modem

if component.isAvailable("os_cardwriter") then --see if it exists, otherwise close/crash program.
    writer = component.os_cardwriter
else
    GUI.alert(loc.cardwriteralert)
    return
end
if component.isAvailable("os_biometric") then --see if it exists, otherwise you can't link user biometrics
    scanner = component.os_biometric
end

local varEditWindow --Container of all the stuff for variable editing for easy removal of it all.
local userList, userNameText, createAdminCardButton, userUUIDLabel, linkUserButton, linkUserLabel, cardWriteButton, StaffYesButton
local cardBlockedYesButton, userNewButton, userDeleteButton, userChangeUUIDButton, listPageLabel, listUpButton, listDownButton, varContainer
local userMCIDLabel, userMCIDButton, userMCIDClear

local guiCalls = {} --Holds all the buttons and stuff for each pass created in a neat order.
--Usertable.settings = {["var"]="level",["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false}}
-----------
--136 width, 30 height
local adminCard = "admincard" --what is written to admin cards

local modemPort = 199
local dbPort = 144 --port used for linking

local pageMult = 9 --how many items in a list allowed
local listPageNumber = 0 --current page number (down by 1. page 1 is 0)
local previousPage = 0 --previous page that was selected.

local function split(s, delimiter) --splits string to table. "e,f,g" to {"e","f","g"}
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

--Pass types: security.* = all, security.passediting = pass stuff, security.varmanagement = add/del passes + users security.resetuuid = reset user uuid (make card useless)
local function userListCallback() --When a value is changed or new user selected
    local selectedId = pageMult * listPageNumber + userList.selectedItem --get user selected in list
    userNameText.text = userTable.passes[selectedId].name
    userUUIDLabel.text = "UUID      : " .. userTable.passes[selectedId].uuid --their card uuid
    --Linking and user id
    linkUserLabel.text = "LINK      : " .. userTable.passes[selectedId].link --new link feature non implemented
    linkUserButton.disabled = database.checkPerms("security",{"passediting","varmanagement","link"},true)
    userMCIDLabel.text = "MC ID     : " .. userTable.passes[selectedId].mcid --user's minecraft id linked to a card
    userMCIDButton.disabled = database.checkPerms("security",{"passediting","varmanagement","mcid"},true)
    userMCIDClear.disabled = database.checkPerms("security",{"passediting","varmanagement","mcid"},true)
    userChangeUUIDButton.disabled = database.checkPerms("security",{"varmanagement","resetuuid"},true)
    --end of linking and user id
    if userTable.passes[selectedId].blocked == true then --disallow all use of their account
    cardBlockedYesButton.pressed = true
    else
    cardBlockedYesButton.pressed = false
    end
    cardBlockedYesButton.disabled = database.checkPerms("security",{"passediting","varmanagement","block"},true)
    if userTable.passes[selectedId].staff == true then --should allow the user through every door no matter what. Might need to be debugged
    StaffYesButton.pressed = true
    else
    StaffYesButton.pressed = false
    end
    StaffYesButton.disabled = database.checkPerms("security",{"passediting","varmanagement","staff"},true)
    listPageLabel.text = tostring(listPageNumber + 1)
    userNameText.disabled = database.checkPerms("security",{"passediting","varmanagement","name"},true)
    for i=1,#userTable.passSettings.var,1 do --Manage all the variables and passes added by the user
    local pees = database.checkPerms("security",{"passediting","varmanagement",userTable.passSettings.var[i]},true) --pees is whether the buttons should be disabled for this pass
    if userTable.passSettings.type[i] == "bool" then --one button true/false
        guiCalls[i][1].pressed = userTable.passes[selectedId][userTable.passSettings.var[i]]
        guiCalls[i][1].disabled = pees
    elseif userTable.passSettings.type[i] == "string" then --one string input box
        if userTable.passSettings.data[i] == 1 then
        guiCalls[i][1].text = tostring(userTable.passes[selectedId][userTable.passSettings.var[i]])
        guiCalls[i][1].disabled = pees
        elseif userTable.passSettings.data[i] == 2 then
        guiCalls[i][1].text = tostring(userTable.passes[selectedId][userTable.passSettings.var[i]])
        end
    elseif userTable.passSettings.type[i] == "-string" then --multiple strings in one pass. Think of it as a nonstrict group pass (-int)
        if userTable.passSettings.data[i] == 1 then --Visible and editable by database user
        local remembah = guiCalls[i][1].selectedItem <= 1 and 1 or guiCalls[i][1].selectedItem --Remember last selection of the combobox
        guiCalls[i][1]:clear()
        local count = 0
        for j=1,#userTable.passes[selectedId][userTable.passSettings.var[i]],1 do --readd all strings user has
            count = count + 1
            guiCalls[i][1]:addItem(userTable.passes[selectedId][userTable.passSettings.var[i]][j])
        end
        if count < remembah then --If user removed a string and it was last one, lower by 1
            guiCalls[i][1].selectedItem = remembah - 1
        else
            guiCalls[i][1].selectedItem = remembah
        end
        guiCalls[i][2].disabled = pees
        guiCalls[i][3].disabled = count == 0 and true or pees
        guiCalls[i][4].disabled = pees
        guiCalls[i][4].text = ""
        elseif userTable.passSettings.data[i] == 2 then --Visible to user but can't edit
        guiCalls[i][1]:clear()
        for j=1,#userTable.passes[selectedId][userTable.passSettings.var[i]],1 do
            guiCalls[i][1]:addItem(userTable.passes[selectedId][userTable.passSettings.var[i]][j])
        end
        end --If 3, then they can't see or edit them.
    elseif userTable.passSettings.type[i] == "int" then --Level. Text box and +- buttons
        guiCalls[i][3].text = tostring(userTable.passes[selectedId][userTable.passSettings.var[i]])
        guiCalls[i][1].disabled = pees
        guiCalls[i][2].disabled = pees
        guiCalls[i][3].disabled = pees
    elseif userTable.passSettings.type[i] == "-int" then --Group: combobox dropdown
        guiCalls[i][1].selectedItem = userTable.passes[selectedId][userTable.passSettings.var[i]] < guiCalls[i][1]:count() and userTable.passes[selectedId][userTable.passSettings.var[i]] + 1 or 0
        guiCalls[i][1].disabled = pees
    else
        GUI.alert("Potential error in line 157 in function userListCallback()")
    end
    end
    workspace:draw()
end

local function updateList() --when a new user is selected
    local selectedId = userList.selectedItem --currently selected on list (not user just list)
    userList:removeChildren()
    if (pageMult * listPageNumber) + 1 > #userTable.passes and listPageNumber ~= 0 then --check if current page is not empty (if user deleted the last user on page 2 or higher)
    listPageNumber = listPageNumber - 1
    end
    local temp = pageMult * listPageNumber
    for i = temp + 1, temp + pageMult, 1 do
    if (userTable.passes[i] == nil) then --add it if that user exists at that spot

    else
        userList:addItem(userTable.passes[i].name).onTouch = userListCallback
    end
    end
    database.save() --save userTable to database
    if (previousPage == listPageNumber) then --if the page has changed, it resets the chosen user to 1, otherwise return to the last selected user
    userList.selectedItem = selectedId
    else
    userList.selectedItem = 1
    previousPage = listPageNumber
    end
    listDownButton.disabled = listPageNumber == 0
    listUpButton.disabled = #userTable.passes <= temp + pageMult
    database.update({"passes","passSettings"})
end

local function buttonCallback(workspace, button) --callback for all user created variables
    local buttonInt, isPos
    if button ~= nil then
        buttonInt = button.buttonInt --buttonInt is what spot the button is in the guiCalls
        isPos = button.isPos --for +- buttons in int passes.
    end
    local selected = pageMult * listPageNumber + userList.selectedItem
    if userTable.passSettings.type[buttonInt] == "string" then --simply change string value
        userTable.passes[selected][userTable.passSettings.var[buttonInt]] = guiCalls[buttonInt][1].text
    elseif userTable.passSettings.type[buttonInt] == "-string" then
        if isPos == true then --if isPos then add a string, otherwise remove the selected one
            table.insert(userTable.passes[selected][userTable.passSettings.var[buttonInt]],guiCalls[buttonInt][4].text)
        else
            table.remove(userTable.passes[selected][userTable.passSettings.var[buttonInt]],guiCalls[buttonInt][1].selectedItem)
        end
    elseif userTable.passSettings.type[buttonInt] == "bool" then --simply change true/false
        userTable.passes[selected][userTable.passSettings.var[buttonInt]] = guiCalls[buttonInt][1].pressed
    elseif userTable.passSettings.type[buttonInt] == "int" then --if isPos is true or false, increment up or down; otherwise if nil check if input is a number and between 0 and 100 inclusive, then change the value or if not a num or too large/small, return to prev. value
        if isPos == true then
            if userTable.passes[selected][userTable.passSettings.var[buttonInt]] < 100 then
            userTable.passes[selected][userTable.passSettings.var[buttonInt]] = userTable.passes[selected][userTable.passSettings.var[buttonInt]] + 1
            end
        elseif isPos == false then
            if userTable.passes[selected][userTable.passSettings.var[buttonInt]] > 0 then
            userTable.passes[selected][userTable.passSettings.var[buttonInt]] = userTable.passes[selected][userTable.passSettings.var[buttonInt]] - 1
            end
        elseif isPos == nil then
            local theNum = tonumber(guiCalls[buttonInt][3].text)
            if theNum and theNum >= 0 and theNum <= 100 then
            userTable.passes[selected][userTable.passSettings.var[buttonInt]] = theNum
            else
            guiCalls[buttonInt][3].text = tostring(userTable.passes[selected][userTable.passSettings.var[buttonInt]])
            end
        end
    elseif userTable.passSettings.type[buttonInt] == "-int" then --simply change to selected item on dropdown - 1 (0 = no group, which is the 1st selected in a dropdown)
        userTable.passes[selected][userTable.passSettings.var[buttonInt]] = guiCalls[buttonInt][1].selectedItem - 1
    else
        GUI.alert(loc.buttoncallbackalert .. buttonInt)
    end
    updateList()
    userListCallback()
end

local function staffUserCallback() --staff button
    local selected = pageMult * listPageNumber + userList.selectedItem
    userTable.passes[selected].staff = StaffYesButton.pressed
    updateList()
    userListCallback()
end

local function blockUserCallback() --block button
    local selected = pageMult * listPageNumber + userList.selectedItem
    userTable.passes[selected].blocked = cardBlockedYesButton.pressed
    updateList()
    userListCallback()
end

local function newUserCallback() --Add a new user with all correct values
    local tmpTable = {["name"] = "new", ["blocked"] = false, ["staff"] = false, ["uuid"] = uuid.next(), ["link"] = "nil", ["mcid"] = "nil"}
    for i=1,#userTable.passSettings.var,1 do
    if userTable.passSettings.type[i] == "string" then
        tmpTable[userTable.passSettings.var[i]] = "none"
    elseif userTable.passSettings.type[i] == "-string" then
        tmpTable[userTable.passSettings.var[i]] = {}
    elseif  userTable.passSettings.type[i] == "bool" then
        tmpTable[userTable.passSettings.var[i]] = false
    elseif userTable.passSettings.type[i] == "int" or userTable.passSettings.type[i] == "-int" then
        tmpTable[userTable.passSettings.var[i]] = 0
    end
    end
    table.insert(userTable.passes, tmpTable)
    updateList()
end

local function deleteUserCallback() --delete selected user and disable all buttons until new user selected
    local selected = pageMult * listPageNumber + userList.selectedItem
    table.remove(userTable.passes,selected)
    if #userTable.passes < pageMult * listPageNumber + 1 and listPageNumber ~= 0 then
    listPageNumber = listPageNumber - 1
    end
    updateList()
    userNameText.text = ""
    userNameText.disabled = true
    userChangeUUIDButton.disabled = true
    StaffYesButton.disabled = true
    for i=1,#userTable.passSettings.var,1 do
    local tmp = userTable.passSettings.type[i]
    if tmp == "bool" then
        guiCalls[i][1].disabled = true
    elseif tmp == "string" then
        tmp = userTable.passSettings.data[i]
        if tmp == 0 then
        guiCalls[i][1].disabled = true
        guiCalls[i][1].text = ""
        elseif tmp == 1 then
        guiCalls[i][1].text = ""
        end
    elseif tmp == "-string" then
        tmp = userTable.passSettings.data[i]
        if tmp == 0 then
        guiCalls[i][1].disabled = true
        guiCalls[i][1]:clear()
        guiCalls[i][2].disabled = true
        guiCalls[i][3].disabled = true
        guiCalls[i][4].disabled = true
        guiCalls[i][4].text = ""
        elseif tmp == 1 then
        guiCalls[i][1].disabled = true
        guiCalls[i][1]:clear()
        end
    elseif tmp == "int" or tmp == "-int" then
        if tmp == "-int" then
        guiCalls[i][3].text = "NAN"
        else
        guiCalls[i][3].text = "#"
        end
        guiCalls[i][1].disabled = true
        guiCalls[i][2].disabled = true
        guiCalls[i][3].disabled = true
    elseif tmp == "-int" then
        guiCalls[i][1].selected = 1
        guiCalls[i][1].disabled = true
    end
    end
    cardBlockedYesButton.disabled = true
    linkUserButton.disabled = true
    userMCIDButton.disabled = true
    userMCIDClear.disable = true
end

local function changeUUID() --all cards written will be rendered useless. In case cards get stolen
    varContainer = GUI.addBackgroundContainer(workspace,true,true)
    varContainer.layout:addChild(GUI.label(1,1,3,3,style.containerLabel,loc.changeuuidline1))
    varContainer.layout:addChild(GUI.label(1,3,3,3,style.containerLabel,loc.changeuuidline2))
    varContainer.layout:addChild(GUI.label(1,5,3,3,style.containerLabel,loc.changeuuidline3))
    local funcyes = function() --if the user confirms the reset uuid
    local selected = pageMult * listPageNumber + userList.selectedItem
    local selected = pageMult * listPageNumber + userList.selectedItem
    userTable.passes[selected].uuid = uuid.next()
    updateList()
    userListCallback()
    varContainer:remove()
    end --user doesn't want to change uuid
    local funcno = function()
    varContainer:remove()
    end
    local button1 = varContainer.layout:addChild(GUI.button(1,9,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.yes))
    local button2 = varContainer.layout:addChild(GUI.button(1,7,16,1, style.containerButton,style.containerText,style.containerSelectButton,style.containerSelectText, loc.no))
    button1.onTouch = funcyes
    button2.onTouch = funcno
end

local function writeCardCallback() --write a card, magswipe atm but possibly rfid in future
    local selected = pageMult * listPageNumber + userList.selectedItem
    local data, crypted
    local name = userTable.passes[selected].name
    while crypted == nil or string.len(crypted) >= 64 do
        data = {["name"]=name,["uuid"]=string.sub(userTable.passes[selected].uuid,1,-14)}
        data = ser.serialize(data)
        crypted = database.crypt(data)
        if string.len(crypted) >= 64 then
            name = string.sub(name,1,string.len(name) - 1)
        end
    end
    writer.write(crypted, userTable.passes[selected].name .. loc.cardlabel, false, 0)
end

local function writeAdminCardCallback() --write admin card (card for admin features)
    local data =  adminCard
    local crypted = database.crypt(data)
    writer.write(crypted, loc.diagcardlabel, false, 14)
end

local function pageCallback(workspace,button) --list buttons for changin pages of the userlist
    local function canFresh() --just runs updateList and userListCallback
    updateList()
    userListCallback()
    end
    if button.isPos then
    if listPageNumber < #userTable.passes/pageMult - 1 then --make sure enough users are there to populate at least 1 spot
        listPageNumber = listPageNumber + 1
        canFresh()
    end
    else
    if listPageNumber > 0 then --make sure not already on last page
        listPageNumber = listPageNumber - 1
        canFresh()
    end
    end
end

local function inputCallback() --username input
    local selected = pageMult * listPageNumber + userList.selectedItem
    userTable.passes[selected].name = userNameText.text
    updateList()
    userListCallback()
end

local function linkUserCallback() --linking button. TODO: Make this work a little nicer and be able to filter events in order to not be STUPID and break if you click the screen
    local container = GUI.addBackgroundContainer(workspace, false, true, loc.linkinstruction)
    local selected = pageMult * listPageNumber + userList.selectedItem
    modem.open(dbPort)
    workspace:draw()
    local e, _, from, port, _, msg
    while e ~= "modem_message" and e ~= "touch" do
        e, _, from, port, _, msg = event.pull(20) --wait for message
    end
    container:remove()
    if e == "modem_message" then
    local data = database.crypt(msg,true) --decrypt message
    userTable.passes[selected].link = data --set link to the data (uuid)
    modem.send(from,port,database.crypt(userTable.passes[selected].name)) --return the username of the player (indicating it worked)
    GUI.alert(loc.linksuccess)
    else
    userTable.passes[selected].link = "nil"
    GUI.alert(loc.linkfail)
    end
    modem.close(dbPort)
    updateList()
    userListCallback()
end

local function linkMCIDCallback() --use Biometric reader to link a card to a player
    if scanner ~= nil then --check if there is a biometric reader connected
    local container = GUI.addBackgroundContainer(workspace, false, true, "Please have the user who you are linking to the card click the Biometric Reader")
    local selected = pageMult * listPageNumber + userList.selectedItem
    workspace:draw()
    local e, _, msg
    while e ~= "bioReader" and e ~= "touch" do --implemented a check so button presses now don't mess it up
        e, _, msg = event.pull(10) --wait for message
    end
    container:remove()
    if e == "bioReader" then --set the card to the id of player
        userTable.passes[selected].mcid = msg
        GUI.alert(loc.linksuccess)
    else
        userTable.passes[selected].mcid = "nil"
        GUI.alert(loc.linkfail)
    end
    updateList()
    userListCallback()
    else --alert user one isn't connected
    GUI.alert("No Biometric Reader is connected to this computer")
    end
end

local function clearMCIDCallback() --set the user's mcid to "nil"
    local selected = pageMult * listPageNumber + userList.selectedItem
    userTable.passes[selected].mcid = "nil"
    updateList()
    userListCallback()
end

local function passSetup(deleteprev) --This sets up all the pass buttons into a edit window. Made so adding/deleting variables wouldn't mean restarting the database. Deletes all gui elements and recreates them
    if deleteprev then varEditWindow:removeChildren() end
    --I ain't explaining all this in comments. All it does is initializes variables declared by the user as well as built in ones. I will explain guiCalls tho
    --user infos
    local labelSpot = 1 --sorts all the buttons by Y value. TODO: Add overflow pages in case they create way more than the screen can handle
    varEditWindow:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"User name : "))
    userNameText = varEditWindow:addChild(GUI.input(64,labelSpot,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputname))
    userNameText.onInputFinished = inputCallback
    userNameText.disabled = true
    labelSpot = labelSpot + 2
    userUUIDLabel = varEditWindow:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"UUID      : " .. loc.usernotselected))
    labelSpot = labelSpot + 2
    varEditWindow:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"STAFF     : "))
    StaffYesButton = varEditWindow:addChild(GUI.button(64,labelSpot,16,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.toggle))
    StaffYesButton.switchMode = true
    StaffYesButton.onTouch = staffUserCallback
    StaffYesButton.disabled = true
    labelSpot = labelSpot + 2
    varEditWindow:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"Blocked   : "))
    cardBlockedYesButton = varEditWindow:addChild(GUI.button(64,labelSpot,16,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.toggle))
    cardBlockedYesButton.switchMode = true
    cardBlockedYesButton.onTouch = blockUserCallback
    cardBlockedYesButton.disabled = true
    labelSpot = labelSpot + 2

    guiCalls = {} --clear it. guiCalls[varInt][specNum], where varInt is the int of it on the userTable.passSettings tables; and specNum is the index of the gui element itself. There is a specific order each type (int, string, etc.) always go in
    for i=1,#userTable.passSettings.var,1 do
    --beg: If label text is less than 10, it will keep : in a specific spot (looks nice) otherwise, its kept at the end of the text (example: hello is "hello     :" and pickle is "pickle    :" and chickens is "chickens  :", but mississippi is "mississippi:")
    local labelText = userTable.passSettings.label[i]
    local spaceNum = 10 - #labelText
    if spaceNum < 0 then spaceNum = 0 end
    for j=1,spaceNum,1 do
        labelText = labelText .. " "
    end
    labelText = labelText .. ": "
    --end of section
    varEditWindow:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,labelText)) --create label gui element
    guiCalls[i] = {}
    if userTable.passSettings.type[i] == "string" then --No matter what only guiCalls[i][1] is populated. If editable, its an input box, if uneditable or hidden, its a label
        if userTable.passSettings.data[i] == 1 then
        guiCalls[i][1] = varEditWindow:addChild(GUI.input(64,labelSpot,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputtext))
        guiCalls[i][1].buttonInt = i
        guiCalls[i][1].onInputFinished = buttonCallback
        guiCalls[i][1].disabled = true
        elseif userTable.passSettings.data[i] == 2 then
        guiCalls[i][1] = varEditWindow:addChild(GUI.label(64,labelSpot,3,3,style.passIntLabel,"NAN"))
        else
        guiCalls[i][1] = varEditWindow:addChild(GUI.label(64,labelSpot,3,3,style.passIntLabel,"String Hidden"))
        end
    elseif userTable.passSettings.type[i] == "-string" then --If editable, then it has 4 populated: [1] is combobox holding all strings held, [2] and [3] are + and - buttons in that order, [4] is the input to add strings. If uneditable, [1] is the combo box showing all strings added. If hidden, [1] is just a label
        if userTable.passSettings.data[i] == 1 then
        guiCalls[i][1] = varEditWindow:addChild(GUI.comboBox(64,labelSpot,20,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
        guiCalls[i][1].buttonInt = i
        guiCalls[i][2] = varEditWindow:addChild(GUI.button(86,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "+"))
        guiCalls[i][2].buttonInt = i
        guiCalls[i][2].isPos = true
        guiCalls[i][2].onTouch = buttonCallback
        guiCalls[i][3] = varEditWindow:addChild(GUI.button(90,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "-"))
        guiCalls[i][3].buttonInt = i
        guiCalls[i][3].isPos = false
        guiCalls[i][3].onTouch = buttonCallback
        guiCalls[i][2].disabled = true
        guiCalls[i][3].disabled = true
        guiCalls[i][4] = varEditWindow:addChild(GUI.input(94,labelSpot,16,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "", loc.inputtext))
        guiCalls[i][4].buttonInt = i
        guiCalls[i][4].disabled = true
        elseif userTable.passSettings.data[i] == 2 then
        guiCalls[i][1] = varEditWindow:addChild(GUI.comboBox(64,labelSpot,30,1,style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
        else
        guiCalls[i][1] = varEditWindow:addChild(GUI.label(64,labelSpot,3,3,style.passIntLabel,"Strings Hidden"))
        end
    elseif userTable.passSettings.type[i] == "int" then --no matter what has 3 populated. [1] and [2] are the + and - buttons in that order, and [3] is the input box to input the number
        guiCalls[i][3] = varEditWindow:addChild(GUI.input(72,labelSpot,10,1, style.passInputBack,style.passInputText,style.passInputPlaceholder,style.passInputFocusBack,style.passInputFocusText, "#", loc.inputtext))
        guiCalls[i][3].buttonInt = i
        guiCalls[i][3].onInputFinished = buttonCallback
        guiCalls[i][1] = varEditWindow:addChild(GUI.button(64,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "+"))
        guiCalls[i][1].buttonInt = i
        guiCalls[i][1].isPos = true
        guiCalls[i][1].onTouch = buttonCallback
        guiCalls[i][2] = varEditWindow:addChild(GUI.button(68,labelSpot,3,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, "-"))
        guiCalls[i][2].buttonInt = i
        guiCalls[i][2].isPos = false
        guiCalls[i][2].onTouch = buttonCallback
        guiCalls[i][1].disabled = true
        guiCalls[i][2].disabled = true
        guiCalls[i][3].disabled = true
    elseif userTable.passSettings.type[i] == "-int" then
        guiCalls[i][1] = varEditWindow:addChild(GUI.comboBox(64,labelSpot,30,1, style.containerComboBack,style.containerComboText,style.containerComboArrowBack,style.containerComboArrowText))
        local cur = guiCalls[i][1]:addItem("none")
        cur.buttonInt = i
        cur.onTouch = buttonCallback
        for _,vas in pairs(userTable.passSettings.data[i]) do
            cur = guiCalls[i][1]:addItem(vas)
            cur.buttonInt = i
            cur.onTouch = buttonCallback
        end
        guiCalls[i][1].disabled = true
    elseif userTable.passSettings.type[i] == "bool" then --only [1] is populated by the button
        guiCalls[i][1] = varEditWindow:addChild(GUI.button(64,labelSpot,16,1, style.passButton, style.passText, style.passSelectButton, style.passSelectText, loc.toggle))
        guiCalls[i][1].buttonInt = i
        guiCalls[i][1].switchMode = true
        guiCalls[i][1].onTouch = buttonCallback
        guiCalls[i][1].disabled = true
    end
    labelSpot = labelSpot + 2 --increment y spot
    end

    linkUserLabel = varEditWindow:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"LINK      : " .. loc.usernotselected))
    linkUserButton = varEditWindow:addChild(GUI.button(85,labelSpot,16,1, style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.linkdevice))
    linkUserButton.onTouch = linkUserCallback
    linkUserButton.disabled = true
    labelSpot = labelSpot + 2

    userMCIDLabel = varEditWindow:addChild(GUI.label(40,labelSpot,3,3,style.passNameLabel,"MCID      : " .. loc.usernotselected))
    userMCIDButton = varEditWindow:addChild(GUI.button(85,labelSpot,10,1, style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "link user"))
    userMCIDButton.onTouch = linkMCIDCallback
    userMCIDButton.disabled = true
    userMCIDClear = varEditWindow:addChild(GUI.button(100,labelSpot,10,1, style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, "clear"))
    userMCIDClear.onTouch = clearMCIDCallback
    userMCIDClear.disabled = true
    labelSpot = labelSpot + 2
    --list button stuff to change pages
    listPageLabel = window:addChild(GUI.label(2,30,3,3,style.listPageLabel,tostring(listPageNumber + 1)))
    listUpButton = window:addChild(GUI.button(8,30,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "+"))
    listUpButton.onTouch, listUpButton.isPos = pageCallback,true
    listDownButton = window:addChild(GUI.button(12,30,3,1, style.listPageButton, style.listPageText, style.listPageSelectButton, style.listPageSelectText, "-"))
    listDownButton.onTouch, listDownButton.isPos = pageCallback,false

    --Line and user buttons (all the stuff on right and bottom of module)

    --window:addChild(GUI.panel(115,11,1,26,style.bottomDivider))
    --window:addChild(GUI.panel(64,10,86,1,style.bottomDivider))
    --window:addChild(GUI.panel(64,36,86,1,style.bottomDivider))
    local va = database.checkPerms("security",{"varmanagement"},true)
    userNewButton = window:addChild(GUI.button(118,9,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.new)) --118 is furthest right
    userNewButton.onTouch = newUserCallback
    userNewButton.disabled = va
    userDeleteButton = window:addChild(GUI.button(118,11,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.delete))
    userDeleteButton.onTouch = deleteUserCallback
    userDeleteButton.disabled = va
    userChangeUUIDButton = window:addChild(GUI.button(118,15,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.resetuuid))
    userChangeUUIDButton.onTouch = changeUUID
    userChangeUUIDButton.disabled = database.checkPerms("security",{"varmanagement","resetuuid"},true)
    createAdminCardButton = window:addChild(GUI.button(118,27,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.admincardbutton))
    createAdminCardButton.onTouch = writeAdminCardCallback
    createAdminCardButton.disabled = database.checkPerms("security",{"varmanagement","admincard"},true)
end

--permissionRefresh() permissions given by database

varEditWindow = window:addChild(GUI.container(1,1,window.width,window.height)) --create window all the passes are in
window:addChild(GUI.panel(1,1,37,30,style.listPanel))
userList = window:addChild(GUI.list(2, 2, 35, 28, 3, 0, style.listBackground, style.listText, style.listAltBack, style.listAltText, style.listSelectedBack, style.listSelectedText, false))
userList:addItem("HELLO") --if this shows an error occurred
listPageNumber = 0

passSetup(false) --don't del anything previously there (as nothing is there)
updateList() --populate the userlist list for the first time

--write card button
cardWriteButton = window:addChild(GUI.button(118,29,16,1,style.bottomButton, style.bottomText, style.bottomSelectButton, style.bottomSelectText, loc.writebutton))
cardWriteButton.onTouch = writeCardCallback
cardWriteButton.disabled = database.checkPerms("security",{"varmanagement","writecard"},true)
