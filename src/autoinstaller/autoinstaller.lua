local component = require("component")
local term = require("term")
local io = require("io")
local ser = require("serialization")
local fs = require("filesystem")
local shell = require("shell")
local event = require("event")
local modem = component.modem
local modemPort = 199

local tableToFileCode = "https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/src/libraries/tableToFile.lua"
local singleCode = {"https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/src/doorcontrols/singleDoor.lua","https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/test/experimentalCode/singleDoor.lua"}
local multiCode = {"https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/src/doorcontrols/multiDoor.lua","https://raw.githubusercontent.com/cadergator10/opensecurity-scp-security-system/main/test/experimentalCode/multiDoor.lua"}
local program = "ctrl.lua"
local tableToFileName = "tableToFile.lua"
local settingFileName = "doorSettings.txt"

local ExperimentalCode = false

local settingData2 = {}
local randomNameArray = {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"}

local function save(table, location)
  --saves a table to a file
  local tableFile = assert(io.open(location, "w"))
  tableFile:write(ser.serialize(table))
  tableFile:close()
end
local function loadT(location)
  --returns a table stored in a file.
  local tableFile = assert(io.open(location))
  return ser.unserialize(tableFile:read("*all"))
end

local function runInstall(multi,num,accelerate,from2,port2,barcode)
    local settingData = {}
    if multi == false then --single
        
        if accelerate == true then
            local e,from,port,text
            from = from2
            port = port2
            modem.send(from,port,"clearTerm")
                    modem.send(from,port,"print","downloading files...")
                    os.execute("wget -f " .. singleCode[1] .. " " .. program)
                    modem.send(from,port,"print","ONLY ENTER NUMBERS FOR ALL THE SETTINGS! NO WORDS")
                    modem.send(from,port,"print","Door Type? 0= doorcontrol. 1=redstone. 2=bundled. 3=rolldoor")
                    modem.send(from,port,"getInput")
                    e, _, from, port, _, text = event.pull("modem_message")
                    settingData["doorType"] = tonumber(text)  
                    if(tonumber(text) == 1) then
                        modem.send(from,port,"print","What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=right")
                        modem.send(from,port,"getInput")
                        e, _, from, port, _, text = event.pull("modem_message")
                        settingData["redSide"] = tonumber(text)
                        modem.send(from,port,"print","No need for redColor! The settings you inputted dont require it :)")
                        settingData["redColor"] = 0
                    elseif(tonumber(text) == 2) then
                        modem.send(from,port,"print","What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=right")
                        modem.send(from,port,"getInput")
                        e, _, from, port, _, text = event.pull("modem_message")
                        settingData["redSide"] = tonumber(text)
                        modem.send(from,port,"print","What color. Use the Color API wiki provided in discord, and enter the NUMBER")
                        modem.send(from,port,"getInput")
                        e, _, from, port, _, text = event.pull("modem_message")
                        settingData["redColor"] = tonumber(text)
                    else
                        modem.send(from,port,"print","No need for redSide or redColor! The settings you inputted dont require it :)")
                        settingData["redSide"] = 0
                        settingData["redColor"] = 0
                    end
                    modem.send(from,port,"print","Should the door be toggleable, or not? 0 for auto close and 1 for toggleable")
                    modem.send(from,port,"getInput")
                    e, _, from, port, _, text = event.pull("modem_message")
                    settingData["toggle"] = tonumber(text)
                    if(tonumber(text) == 0) then
                        modem.send(from,port,"print","How long should the door stay open in seconds?")
                    	modem.send(from,port,"getInput")
                    	e, _, from, port, _, text = event.pull("modem_message")
                        settingData["delay"] = tonumber(text)
                    else
                        modem.send(from,port,"print","No need to change delay! Previous setting doesnt require it :)")
                        settingData["delay"] = 0
                    end
                    modem.send(from,port,"print","What should be read? 0 = level; 1 = armory level; 2 = MTF;")
                    modem.send(from,port,"print","3 = GOI; 4 = Security; 5 = Department; 6 = Intercom; 7 = Staff")
					modem.send(from,port,"getInput")
                    e, _, from, port, _, text = event.pull("modem_message")
                    settingData["cardRead"] = tonumber(text)
                    if(tonumber(text) <= 1 or tonumber(text) == 5) then
                        modem.send(from,port,"print","Access Level of what should be read?")
                        modem.send(from,port,"print","if level or armory level, enter the level that it should be.")
                        modem.send(from,port,"print","if department: 1=SD, 2=ScD, 3=MD, 4=E&T, 5=O5")
                        modem.send(from,port,"getInput")
                    	e, _, from, port, _, text = event.pull("modem_message")
                        settingData["accessLevel"] = tonumber(text)
                    else
                        modem.send(from,port,"print","No need to set access level. This mode doesnt require it :)")
                        settingData["accessLevel"] = 0
                    end
                    modem.send(from,port,"print","Is this door opened whenever all doors are asked to open? Not necessary if this is not Site 91")
                    modem.send(from,port,"print","0 if no, 1 if yes. Default is yes")
                    modem.send(from,port,"getInput")
                    e, _, from, port, _, text = event.pull("modem_message")
                    settingData["forceOpen"] = tonumber(text)
                    modem.send(from,port,"print","Is this door immune to lock door? Not necessary if this is not Site 91")
                    modem.send(from,port,"print","0 if no, 1 if yes. Default is no")
                    modem.send(from,port,"getInput")
                    e, _, from, port, _, text = event.pull("modem_message")
                    settingData["bypassLock"] = tonumber(text)
                    modem.send(from,port,"print","Installing table to file")
                    os.execute("wget -f " .. tableToFileCode .. " " .. tableToFileName)
                    term.clear()
                    modem.send(from,port,"clearTerm")
                    modem.send(from,port,"print","All done! go back to the main computer for final information")
                    print("All done! You can remove internet card now. Run " .. program .. " now to start door!")
                    modem.send(from,port,"terminate")
            		print("terminated connection")
            return settingData
        elseif accelerate == false then
            
            term.clear()
       os.execute("wget -f " .. singleCode[1] .. " " .. program)
        print("ONLY ENTER NUMBERS FOR ALL THE SETTINGS! NO WORDS")
        print("Door Type? 0= doorcontrol. 1=redstone. 2=bundled. 3=rolldoor")
        text = term.read()
        settingData["doorType"] = tonumber(text)  
        if(tonumber(text) == 1) then
            print("What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=right")
            text = term.read()
            settingData["redSide"] = tonumber(text)
            print("No need for redColor! The settings you inputted dont require it :)")
            settingData["redColor"] = 0
        elseif(tonumber(text) == 2) then
            print("What side? 0=bottom, 1=top, 2=back, 3=front, 4=right, 5=right")
            text = term.read()
            settingData["redSide"] = tonumber(text)
            print("What color. Use the Color API wiki provided in discord, and enter the NUMBER")
            text = term.read()
            settingData["redColor"] = tonumber(text)
        else
            print("No need for redSide or redColor! The settings you inputted dont require it :)")
            settingData["redSide"] = 0
            settingData["redColor"] = 0
        end
        print("Should the door be toggleable, or not? 0 for auto close and 1 for toggleable")
        text = term.read()
        settingData["toggle"] = tonumber(text)
        if(tonumber(text) == 0) then
            print("How long should the door stay open in seconds?")
            text = term.read()
            settingData["delay"] = tonumber(text)
        else
            print("No need to change delay! Previous setting doesnt require it :)")
            settingData["delay"] = 0
        end
        print("What should be read? 0 = level; 1 = armory level; 2 = MTF;")
        print("3 = GOI; 4 = Security; 5 = Department; 6 = Intercom; 7 = Staff")
        text = term.read()
        settingData["cardRead"] = tonumber(text)
        if(tonumber(text) <= 1 or tonumber(text) == 5) then
            print("Access Level of what should be read?")
            print("if level or armory level, enter the level that it should be.")
            print("if department: 1=SD, 2=ScD, 3=MD, 4=E&T, 5=O5")
            text = term.read()
            settingData["accessLevel"] = tonumber(text)
        else
            print("No need to set access level. This mode doesnt require it :)")
            settingData["accessLevel"] = 0
        end
        print("Is this door opened whenever all doors are asked to open? Not necessary if this is not Site 91")
        print("0 if no, 1 if yes. Default is yes")
        text = term.read()
        settingData["forceOpen"] = tonumber(text)
        print("Is this door immune to lock door? Not necessary if this is not Site 91")
        print("0 if no, 1 if yes. Default is no")
        text = term.read()
        settingData["bypassLock"] = tonumber(text)
        print("Installing table to file: ")
        os.execute("wget -f " .. tableToFileCode .. " " .. tableToFileName)
        term.clear()
        print("All done! You can remove internet card now. Run " .. program .. " now to start door!")
            return settingData
        end
        
    elseif multi == true then --multi
       
        if accelerate == true then
            local e,from,port,text
            from = from2
            port = port2
            		modem.send(from,port,"print","Would you like accelerated magreader setup?")
                    if barcode then
                        modem.send(from,port,"print","(instead of typing uuid you scan the devices with the tablet)")
                    else
                        modem.send(from,port,"print","(instead of typing uuid you swipe any card in the magnetic reader)")
                    end
                    modem.send(from,port,"print","1 for yes, 2 for no")
                    modem.send(from,port,"getInput")
                    e, _, from, port, _, text = event.pull("modem_message")
                    local swipeCard = tonumber(text)
                    for i=1, num, 1 do
                        term.clear()
                        modem.send(from,port,"print","Door # " .. i .. " is being edited:")
                		local keepLoop = true
                		local j
                		while keepLoop do
                		j = randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]..randomNameArray[math.floor(math.random(1,26))]
                    		keepLoop = false
                    		for key,value in pairs(settingData) do
                        		if key == j then
                            		keepLoop = true
                            	end
                        	end
                    	end
                        if swipeCard == 1 then
                            if barcode then
                                modem.send(from,port,"print","Magnetic card reader? Scan the magnetic card reader with your tablet")
                                modem.send(from,port,"write","uuid: ")
                                modem.send(from,port,"analyzer")
                                e, _, from, port, _, text = event.pull("modem_message")
                                modem.send(from,port,"write",text .. "\n")
                                settingData[j] = {}
                                settingData[j]["reader"] = text
                            else
                                modem.send(from,port,"print","Magnetic card reader? Swipe a card in the reader of your choice.")
                                modem.send(from,port,"write","uuid: ")
                                _, text = event.pull("magData")
                                modem.send(from,port,"write",text .. "\n")
                                settingData[j] = {}
                                settingData[j]["reader"] = text
                            end
                        else
                            modem.send(from,port,"print","Magnetic card reader address? TEXT")
                            modem.send(from,port,"getInput")
                            e, _, from, port, _, text = event.pull("modem_message")
                            settingData[j] = {}
                            settingData[j]["reader"] = text:sub(1,-2)
                        end
                        modem.send(from,port,"print","Door Type? 0= doorcontrol. 2=bundled. 3=rolldoor. NEVER USE 1! NUMBER ONLY")
                        modem.send(from,port,"getInput")
                    	e, _, from, port, _, text = event.pull("modem_message")
                        settingData[j]["doorType"] = tonumber(text)
                        if(tonumber(text) == 2) then
                            modem.send(from,port,"print","What color. Use the Color API wiki provided in discord, and enter the NUMBER")
                            modem.send(from,port,"getInput")
                    		e, _, from, port, _, text = event.pull("modem_message")
                            settingData[j]["redColor"] = tonumber(text)
                            modem.send(from,port,"print","No need to input anything for door address. The setting doesnt require it :)")
                            settingData[j]["doorAddress"] = ""
                        else
                            modem.send(from,port,"print","No need to input anything for redColor. The setting doesnt require it :)")
                            settingData[j]["redColor"] = 0
                            if barcode and swipeCard then
                                modem.send(from,port,"print","What is the address for the doorcontrol/rolldoor block? Scan with tablet.")
                                modem.send(from,port,"getInput")
                                e, _, from, port, _, text = event.pull("modem_message")
                                settingData[j]["doorAddress"] = text
                            else
                                modem.send(from,port,"print","What is the address for the doorcontrol/rolldoor block? text is fine.")
                                modem.send(from,port,"getInput")
                                e, _, from, port, _, text = event.pull("modem_message")
                                settingData[j]["doorAddress"] = text:sub(1,-2)
                            end
                        end
						modem.send(from,port,"print","Should the door be toggleable, or not? 0 for auto close and 1 for toggleable")
                        modem.send(from,port,"getInput")
                    	e, _, from, port, _, text = event.pull("modem_message")
                        settingData[j]["toggle"] = tonumber(text)
                        if(tonumber(text) == 0) then
                            modem.send(from,port,"print","How long should the door stay open in seconds? NUMBER ONLY")
                            modem.send(from,port,"getInput")
                    		e, _, from, port, _, text = event.pull("modem_message")
                            settingData[j]["delay"] = tonumber(text)
                        else
                            modem.send(from,port,"print","No need to change delay! Previous setting doesnt require it :)")
                            settingData[j]["delay"] = 0
                        end      
                        modem.send(from,port,"print","What should be read? 0 = level; 1 = armory level; 2 = MTF;")
                        modem.send(from,port,"print","3 = GOI; 4 = Security; 5 = Department; 6 = Intercom; 7 = Staff")
                        modem.send(from,port,"getInput")
                    	e, _, from, port, _, text = event.pull("modem_message")
                        settingData[j]["cardRead"] = tonumber(text)
                        if(tonumber(text) <= 1 or tonumber(text) == 5) then
                            modem.send(from,port,"print","Access Level of what should be read? NUMBER ONLY")
                            modem.send(from,port,"print","if level or armory level, enter the level that it should be.")
                            modem.send(from,port,"print","if department: 1=SD, 2=ScD, 3=MD, 4=E&T, 5=O5")
                            modem.send(from,port,"getInput")
                    		e, _, from, port, _, text = event.pull("modem_message")
                            settingData[j]["accessLevel"] = tonumber(text)
                        else
                            modem.send(from,port,"print","No need to set access level. This mode doesnt require it :)")
                            settingData[j]["accessLevel"] = 0
                        end
                        modem.send(from,port,"print","Is this door opened whenever all doors are asked to open? Not necessary if this is not Site 91")
                        modem.send(from,port,"print","0 if no, 1 if yes. Default is yes")
                        modem.send(from,port,"getInput")
                    	e, _, from, port, _, text = event.pull("modem_message")
                        settingData[j]["forceOpen"] = tonumber(text)
                        modem.send(from,port,"print","Is this door immune to lock door? Not necessary if this is not Site 91")
                        modem.send(from,port,"print","0 if no, 1 if yes. Default is no")
                        modem.send(from,port,"getInput")
                    	e, _, from, port, _, text = event.pull("modem_message")
                        settingData[j]["bypassLock"] = tonumber(text)
                    end
                    modem.send(from,port,"print","Installing table to file: ")
                    os.execute("wget -f " .. tableToFileCode .. " " .. tableToFileName)
                    modem.send(from,port,"clearTerm")
                    modem.send(from,port,"print","All done! go back to the main computer for final information")
                    print("All done! You can remove internet card now. Run " .. program .. " now to start door!")
                    modem.send(from,port,"terminate")
            		print("terminated connection")
            return settingData
        elseif accelerate == false then
            
       for i=1, num, 1 do
            term.clear()
            print("Door # " .. i .. " is being edited:")

            print("Magnetic card reader address? TEXT")
            text = term.read()
            settingData[randomNameArray[i]] = {}
            settingData[randomNameArray[i]]["reader"] = text:sub(1,-2)
            print("Door Type? 0= doorcontrol. 2=bundled. 3=rolldoor. NEVER USE 1! NUMBER ONLY")
            text = term.read()
            settingData[randomNameArray[i]]["doorType"] = tonumber(text)
            if(tonumber(text) == 2) then
                print("What color. Use the Color API wiki provided in discord, and enter the NUMBER")
                text = term.read()
                settingData[randomNameArray[i]]["redColor"] = tonumber(text)
                print("No need to input anything for door address. The setting doesnt require it :)")
                settingData[randomNameArray[i]]["doorAddress"] = ""
            else
                print("No need to input anything for redColor. The setting doesnt require it :)")
                settingData[randomNameArray[i]]["redColor"] = 0
                print("What is the address for the doorcontrol/rolldoor block? text is fine.")
                text = term.read()
                settingData[randomNameArray[i]]["doorAddress"] = text:sub(1,-2)
            end

            print("Should the door be toggleable, or not? 0 for auto close and 1 for toggleable")
            text = term.read()
            settingData[randomNameArray[i]]["toggle"] = tonumber(text)
            if(tonumber(text) == 0) then
                print("How long should the door stay open in seconds? NUMBER ONLY")
                text = term.read()
                settingData[randomNameArray[i]]["delay"] = tonumber(text)
            else
                print("No need to change delay! Previous setting doesnt require it :)")
                settingData[randomNameArray[i]]["delay"] = 0
            end      
            print("What should be read? 0 = level; 1 = armory level; 2 = MTF;")
            print("3 = GOI; 4 = Security; 5 = Department; 6 = Intercom; 7 = Staff")
            text = term.read()
            settingData[randomNameArray[i]]["cardRead"] = tonumber(text)
            if(tonumber(text) <= 1 or tonumber(text) == 5) then
                print("Access Level of what should be read? NUMBER ONLY")
                print("if level or armory level, enter the level that it should be.")
                print("if department: 1=SD, 2=ScD, 3=MD, 4=E&T, 5=O5")
                text = term.read()
                settingData[randomNameArray[i]]["accessLevel"] = tonumber(text)
            else
                print("No need to set access level. This mode doesnt require it :)")
                settingData[randomNameArray[i]]["accessLevel"] = 0
            end
            print("Is this door opened whenever all doors are asked to open? Not necessary if this is not Site 91")
            print("0 if no, 1 if yes. Default is yes")
            text = term.read()
            settingData[randomNameArray[i]]["forceOpen"] = tonumber(text)
            print("Is this door immune to lock door? Not necessary if this is not Site 91")
            print("0 if no, 1 if yes. Default is no")
            text = term.read()
            settingData[randomNameArray[i]]["bypassLock"] = tonumber(text)
       end
       print("Installing table to file: ")
        os.execute("wget -f " .. tableToFileCode .. " " .. tableToFileName)
        term.clear()
        print("All done! You can remove internet card now. Run " .. program .. " now to start door!")
            return settingData
        end
        
    end
end

modem.close()
term.clear()
print("Checking files...")
local fill = io.open(program,"r")
if fill~=nil then
    term.clear()
    print("Old files detected. Please select an option:")
    print("1 = wipe all files (maybe)")
    print("2 = add more doors (very experimental)")
    print("3 = delete a door (very experimental)")
    print("4 = change a door (not implemented yet)")
    print("5 = update door")
    local text = term.read()
    if(tonumber(text) == 1) then
        term.clear()
        print("Deleting all files...")
        local path = shell.getWorkingDirectory()
        fs.remove(path .. "/" .. program)
        fs.remove(path .. "/" .. tableToFileName)
        fs.remove(path .. "/" .. settingFileName)
        print("all done!")
    elseif(tonumber(text) == 2) then
        print("Is this door a multi or single door. 1 for single, 2 for multi, anything else for cancel.")
        text = term.read()
        if tonumber(text) == 1 then
			print("you cannot add more doors as this is a single door. If you want to swap to a multidoor,")
        	print("wipe all files and reinstall as a multidoor.")
            os.exit()
        elseif tonumber(text) == 2 then
            settingData2 = loadT(settingFileName)
			print("how many doors would you like to add?")
            text = term.read()
            local num = tonumber(text)
            local tempArray = runInstall(true,num,false)
            for key, value in pairs(tempArray) do
                settingData2[key] = value
            end
            save(settingData2,settingFileName)
            print("Added the doors. It is recommended you check if it worked, as this is experimental.")
        else
            print("not an answer")
            os.exit()
        end
    elseif(tonumber(text) == 3) then
        print("Is this door a multi or single door. 1 for single, 2 for multi, anything else for cancel.")
        text = term.read()
        if tonumber(text) == 1 then
			print("You cannot remove a door as this is a single door. This only works on a multidoor.")
            print("If this is meant to be a multidoor, wipe all files and reinstall as a multidoor.")
            os.exit()
        elseif tonumber(text) == 2 then
			settingData2 = loadT(settingFileName)
            print("What is the key for the door?")
            text = term.read()
            settingData2[text:sub(1,-2)] = nil
            save(settingData2,settingFileName)
            print("Removed the door. It is recommended you check if it worked, as this is experimental.")
        else
            print("not an answer")
            os.exit()
        end
    elseif(tonumber(text) == 4) then
            print("Is this door a multi or single door. 1 for single, 2 for multi, anything else for cancel.")
            text = term.read()
        if tonumber(text) == 1 then
			print("Starting single door editing...")
            local tempArray = runInstall(false,0,false)
                settingData2 = tempArray
                save(settingData2,settingFileName)
                print("Old config should be overwritten. It is recommended you check if it worked, as this is experimental.")
        elseif tonumber(text) == 2 then
			print("What is the key of the door you would like to edit?")
            text = term.read()
            local thisKey = text:sub(1,-2)
            settingData2 = loadT(settingFileName)
                term.clear()
                print("Door with key " .. thisKey .. " is being edited:")

            print("Magnetic card reader address? TEXT")
            text = term.read()
            settingData2[thisKey] = {}
            settingData2[thisKey]["reader"] = text:sub(1,-2)
            print("Door Type? 0= doorcontrol. 2=bundled. 3=rolldoor. NEVER USE 1! NUMBER ONLY")
            text = term.read()
            settingData2[thisKey]["doorType"] = tonumber(text)
            if(tonumber(text) == 2) then
                print("What color. Use the Color API wiki provided in discord, and enter the NUMBER")
                text = term.read()
                settingData2[thisKey]["redColor"] = tonumber(text)
                print("No need to input anything for door address. The setting doesnt require it :)")
                settingData2[thisKey]["doorAddress"] = ""
            else
                print("No need to input anything for redColor. The setting doesnt require it :)")
                settingData2[thisKey]["redColor"] = 0
                print("What is the address for the doorcontrol/rolldoor block? text is fine.")
                text = term.read()
                settingData2[thisKey]["doorAddress"] = text:sub(1,-2)
            end

            print("Should the door be toggleable, or not? 0 for auto close and 1 for toggleable")
            text = term.read()
            settingData2[thisKey]["toggle"] = tonumber(text)
            if(tonumber(text) == 0) then
                print("How long should the door stay open in seconds? NUMBER ONLY")
                text = term.read()
                settingData2[thisKey]["delay"] = tonumber(text)
            else
                print("No need to change delay! Previous setting doesnt require it :)")
                settingData2[thisKey]["delay"] = 0
            end      
            print("What should be read? 0 = level; 1 = armory level; 2 = MTF;")
            print("3 = GOI; 4 = Security; 5 = Department; 6 = Intercom; 7 = Staff")
            text = term.read()
            settingData2[thisKey]["cardRead"] = tonumber(text)
            if(tonumber(text) <= 1 or tonumber(text) == 5) then
                print("Access Level of what should be read? NUMBER ONLY")
                print("if level or armory level, enter the level that it should be.")
                print("if department: 1=SD, 2=ScD, 3=MD, 4=E&T, 5=O5")
                text = term.read()
                settingData2[thisKey]["accessLevel"] = tonumber(text)
            else
                print("No need to set access level. This mode doesnt require it :)")
                settingData2[thisKey]["accessLevel"] = 0
            end
            print("Is this door opened whenever all doors are asked to open? Not necessary if this is not Site 91")
            print("0 if no, 1 if yes. Default is yes")
            text = term.read()
            settingData2[thisKey]["forceOpen"] = tonumber(text)
            print("Is this door immune to lock door? Not necessary if this is not Site 91")
            print("0 if no, 1 if yes. Default is no")
            text = term.read()
            settingData2[thisKey]["bypassLock"] = tonumber(text)
                
            term.clear()
            save(settingData2,settingFileName)
            print("All done! The door should have been changed! It is recommended to check if it worked, as this is experimental.")
                
        else
            print("not an answer")
            os.exit()
        end
    elseif(tonumber(text) == 5) then
        print("Are you sure you want to do this? New updates sometimes require manual changing of config.")
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
    else
        
    end
else
    if true then
    term.clear()
    print("LEGACY AUTOINSTALLER! Use this ONLY if you need to do something to pc 1.7.1 and below.")
    print("Autoupdating a pc in this autoinstaller will mean the new autoinstaller must be used after on it.")
    print("...")
    print("Would you like to use an external device for accelerated setup?")
    print("This makes it easier to set up doors without having to move from the door to the pc constantly.")
    print("It requires the program here to be set up on a tablet with a modem: https://github.com/cadergator10/opensecurity-scp-security-system/blob/main/src/extras/acceleratedDoorSetup.lua")
    print("1 for yes, 2 for no")
    text = term.read()
        term.clear()
        if tonumber(text) == 1 then
            local code = math.floor(math.random(1000,9999))
            modem.open(code)
            print("Code is: " .. code)
            print("Enter the code into the door setup tablet. In 60 seconds setup will cancel.")
            local e, _, from, port, _, msg, barcode = event.pull(60, "modem_message")
            if e then
                modem.send(from,port,"connected")
                term.clear()
                print("Connection successful! All prompts will be on the tablet now on.")
                os.sleep(1)
                modem.send(from,port,"print","What kind of door do you want? 1 for single door, 2 for multidoor")
                modem.send(from,port,"getInput")
                e, _, from, port, _, text = event.pull("modem_message")
                if tonumber(text) == 1 then
                    local tempArray = runInstall(false,0,true,from,port,barcode)
                    settingData2 = tempArray
                    save(settingData2,settingFileName)
                    --was single accelerated
            		os.exit()
                elseif tonumber(text) == 2 then
                    modem.send(from,port,"clearTerm")
                    modem.send(from,port,"print","Downloading code...")
                    os.execute("wget -f " .. multiCode .. " " .. program)
                    modem.send(from,port,"print","Read the text carefully. Some of the inputs REQUIRE NUMBERS ONLY! Some require text.")
                    modem.send(from,port,"print","The redSide is always 2, or back of the computer.")
                    modem.send(from,port,"print","How many different doors are there?")
                    modem.send(from,port,"getInput")
                    e, _, from, port, _, text = event.pull("modem_message")
                    local num = tonumber(text)
                    local tempArray = runInstall(true,num,true,from,port,barcode)
                    settingData2 = tempArray
                    save(settingData2,settingFileName)
                    --was multi accelerated
            		os.exit()
                else
            		term.clear()  
       				modem.send(from,port,"print","not an answer")
            		modem.send(from,port,"terminated connection")
            		print("terminated")
            		os.exit()
                end
            else
                modem.close(code)
                print("Setup cancelled")
                os.exit()
            end
           else
                term.clear()
    print("What kind of door do you want? 1 for single door, 2 for multidoor")
    local text = term.read()
    if(tonumber(text) == 1) then
                local tempArray = runInstall(false,0,false)
                settingData2 = tempArray
                save(settingData2,settingFileName)
       --was single normal
    elseif(tonumber(text) == 2) then
                            term.clear()
       os.execute("wget -f " .. multiCode[1] .. " " .. program)
       print("Read the text carefully. Some of the inputs REQUIRE NUMBERS ONLY! Some require text.")
       print("The redSide is always 2, or back of the computer.")
       print("How many different doors are there?")
       local num = tonumber(term.read())
                local tempArray = runInstall(true,num,false)
                settingData2 = tempArray
                save(settingData2,settingFileName)
       --was multi normal
    else
       term.clear()  
       print("Not an answer:" .. text)
    end
        end
    end
end