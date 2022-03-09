local component = require("component")
local term = require("term")
local io = require("io")
local ser = require("serialization")
local fs = require("filesystem")
local shell = require("shell")
local modem = component.modem
local modemPort = 199

local program = "ctrl.lua"
local tableToFileName = "tableToFile.lua"
local settingFileName = "doorSettings.txt"
local configFileName = "extraConfig.txt"
local singleCode = {"https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/src/doorcontrols/singleDoor.lua","https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/test/experimentalCode/singleDoor.lua"}
local multiCode = {"https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/src/doorcontrols/multiDoor.lua","https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/test/experimentalCode/multiDoor.lua"}

local settingData = {}
local randomNameArray = {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"}

local function saveTable(table, location)
    --saves a table to a file
    local tableFile = assert(io.open(location, "w"))
    tableFile:write(ser.serialize(table))
    tableFile:close()
end
local function loadTable(location)
    --returns a table stored in a file.
    local tableFile = assert(io.open(location))
    return ser.unserialize(tableFile:read("*all"))
end

local function runInstall()

end

local function oldFiles()
    term.clear()
    print("Old files detected. Please select an option:")
    print("1 = wipe all files (maybe)")
    print("2 = add more doors (very experimental)")
    print("3 = delete a door (very experimental)")
    print("4 = change a door (not implemented yet)")
    print("5 = update door")
    print("6 = change cryptKey")
    local text = term.read()
    if tonumber(text) == 1 then
        term.clear()
        print("Deleting all files...")
        local path = shell.getWorkingDirectory()
        fs.remove(path .. "/" .. program)
        fs.remove(path .. "/" .. tableToFileName)
        fs.remove(path .. "/" .. settingFileName)
        fs.remove(path .. "/" .. configFileName)
        local fill = io.open(configFileName)
        if fill~=nil then
            print("an error occured and some files may not have deleted.")
        else
            print("all done!")
        end
        fill:close()
    elseif tonumber(text) == 2 then
        print("Is this door a multi or single door. 1 for single, 2 for multi, anything else for cancel.")
        text = term.read()
        if tonumber(text) == 1 then
            print("you cannot add more doors as this is a single door. If you want to swap to a multidoor,")
            print("wipe all files and reinstall as a multidoor.")
            os.exit()
        elseif tonumber(text) == 2 then
            settingData = loadTable(settingFileName)
            print("how many doors would you like to add?")
            text = term.read()
            local num = tonumber(text)
            --local tempArray = runInstall(true,num,false) FIXME: Update runInstall to be smaller and more me-friendly
            for key, value in pairs(tempArray) do
                settingData[key] = value
            end
            saveTable(settingData,settingFileName)
            print("Added the doors. It is recommended you check if it worked, as this is experimental.")
        else
            print("not an answer")
            os.exit()
        end
    elseif tonumber(text) == 3 then
        print("Is this door a multi or single door. 1 for single, 2 for multi, anything else for cancel.")
        text = term.read()
        if tonumber(text) == 1 then
            print("You cannot remove a door as this is a single door. This only works on a multidoor.")
            print("If this is meant to be a multidoor, wipe all files and reinstall as a multidoor.")
            os.exit()
        elseif tonumber(text) == 2 then
            settingData = loadTable(settingFileName)
            print("What is the key for the door?")
            text = term.read()
            settingData[text:sub(1,-2)] = nil
            saveTable(settingData,settingFileName)
            print("Removed the door. It is recommended you check if it worked, as this is experimental.")
        else
            print("not an answer")
            os.exit()
        end
    elseif tonumber(text) == 4 then
        --Implement a more "efficient" program to change door
    elseif tonumber(text) == 5 then
        print("Are you sure you want to do this? New updates sometimes require manual changing of config.") --FIXME: Add a function that sends an autoInstallerQuery message to server to check if 2.0.0 or 1.0.0
        print("1 for continue, 2 for cancel")
        text = term.read()
        if tonumber(text) == 1 then
            print("Is this door a multi or single door. 1 for single, 2 for multi, anything else for cancel.")
            text = term.read()
            if tonumber(text) == 1 then
                print("downloading...")
                os.execute("wget -f " .. singleCode[1] .. " " .. program)
            elseif tonumber(text) == 2 then
                print("downloading...")
                os.execute("wget -f " .. multiCode[1] .. " " .. program)
            else

            end
        end
    elseif tonumber(text) == 6 then
        local fill = loadTable(configFileName)
        if fill ~= nil then
            print("Found config file")
        else
            print("No config file. Is your doorcontrol updated to latest version?")
            os.exit()
        end
        print("there are 5 parameters, each requiring a number. Recommend doing 1 digit numbers cause I got no idea how this works lol")
        for i=1,5,1 do
            print("enter param " .. i)
            text = term.read()
            fill.cryptKey[i] = tonumber(text)
        end
        saveTable(fill,configFileName)
        print("all done! is set to " .. ser.serialize(fill))
    end
end

modem.close()
term.clear()
print("Checking files...")
local fill = io.open(program,"r")
if fill~=nil then
    fill:close()
    oldFile()
else

end