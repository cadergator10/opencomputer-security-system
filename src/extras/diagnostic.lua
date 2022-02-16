local cryptKey = {1, 2, 3, 4, 5}
local diagPort = 180

local component = require("component")
local event = require("event")
local modem = component.modem 
local ser = require ("serialization")
local term = require("term")
local ios = require("io")

local departments = {"SD","ScD","MD","E&T","O5"}
local cardReadTypes = {"access level","armory level","MTF","GOI","Security Pass","Department","Intercom","Staff"}
local toggleTypes = {"not toggleable","toggleable"}
local doorTypeTypes = {"Door Control","Redstone dust","Bundled Cable","Rolldoor"}
local redSideTypes = {"bottom","top","back","front","right","left"}
local redColorTypes = {"white","orange","magenta","light blue","yellow","lime","pink","gray","silver","cyan","purple","blue","brown","green","red","black"}
local forceOpenTypes = {"False","True"}
local bypassLockTypes = {"",""}

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

term.clear()
print("Admin Diagnostic Tablet")
print("Swipe an admin card on any security door to retrieve the door information")
local num = 0
while true do
  if modem.isOpen(diagPort) == false then
    modem.open(diagPort)
  end
  
  local _, _, from, port, _, command, msg = event.pull("modem_message")
  local data = msg
  data = crypt(msg, cryptKey, true)
  local diagInfo = ser.unserialize(data)
  num = num + 1
  term.clear()
  print("Retrieved new door information # " .. num)
  print("--------------------")
  print("	Main Computer info:")
  print("door status = " .. diagInfo["status"])
  print("door type = " .. diagInfo["type"])
  print("door update version = " .. diagInfo["version"])
    
  if diagInfo["status"] ~= "incorrect magreader" then
        if diagInfo["type"] == "multi" then
        print("number of door entries: " .. diagInfo["entries"])
        print("door's key: " .. diagInfo["key"])
    else
        print("***")
        print("***")
    end
  print("--------------------")
  print("	Door's settings")
    print("Pass type: " .. cardReadTypes[diagInfo["cardRead"] + 1])
    if diagInfo["cardRead"] <= 1 then
        print("Level read: " .. diagInfo["accessLevel"])
    elseif diagInfo["cardRead"] == 5 then
        print("Department: " .. departments[diagInfo["accessLevel"]])
    else
        print("***")
    end
    print("Door type: " .. doorTypeTypes[diagInfo["doorType"] + 1])
    if diagInfo["doorType"] == 1 then
        if diagInfo["type"] == "multi" then
            print("Redstone Output Side: " .. redSideTypes[3])
        	print("***")
        else
            print("Redstone Output Side: " .. redSideTypes[diagInfo["redSide"] + 1])
        	print("***")
        end
    elseif diagInfo["doorType"] == 2 then
        if diagInfo["type"] == "multi" then
            print("Redstone Output Side: " .. redSideTypes[3])
        	print("Redstone Output Color: " .. redColorTypes[diagInfo["redColor"] + 1])
        else
            print("Redstone Output Side: " .. redSideTypes[diagInfo["redSide"] + 1])
        	print("Redstone Output Color: " .. redColorTypes[diagInfo["redColor"] + 1])
        end
    else
        print("***")
        print("***")
    end
    print("Toggle Door: " .. toggleTypes[diagInfo["toggle"] + 1])
    if diagInfo["toggle"] == 0 then
        print("Delay: " .. diagInfo["delay"])
    else
        print("***")
    end
    if diagInfo["forceOpen"] == nil then
            print("Opens when forceopen called: " .. forceOpenTypes[2])
    else
            print("Opens when forceopen called: " .. forceOpenTypes[diagInfo["forceOpen"] + 1])
    end
    if diagInfo["bypassLock"] == nil then
            print("Bypasses door lock: " .. forceOpenTypes[1])
    else
            print("Bypasses door lock: " .. forceOpenTypes[diagInfo["bypassLock"] + 1])
    end
  print("--------------------")
  print("	Component Addresses")
        if diagInfo["type"] == "multi" then
            if diagInfo["doorType"] == 0 then
                print("Reader Address: " .. diagInfo["reader"])
                print("Doorcontrol Address: " .. diagInfo["doorAddress"])
            elseif diagInfo["doorType"] == 3 then
                print("Reader Address: " .. diagInfo["reader"])
                print("RollDoor Address: " .. diagInfo["doorAddress"])
            else
				print("Reader Address: " .. diagInfo["reader"])
           		print("***")
            end
        else
           print("***")
           print("***")
        end
  else
        if diagInfo["type"] == "multi" then
        print("number of door entries: " .. diagInfo["entries"])
        print("***")
    else
        print("***")
        print("***")
    end
  print("--------------------")
  print("	Door's settings")
    print("***")
    print("***")
    print("***")
    print("***")
    print("***")
    print("***")
    print("***")
    print("***")
    print("***")
  print("--------------------")
  print("	Component Addresses")
  print("***")
  print("***")
  end
    
  print("--------------------")
  print("Scan another security door to retrieve it's door information")
end