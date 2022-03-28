local cryptKey = {1, 2, 3, 4, 5}
local diagPort = 180
local modemPort = 199

local component = require("component")
local event = require("event")
local modem = component.modem 
local ser = require ("serialization")
local term = require("term")
local ios = require("io")

local toggleTypes = {"not toggleable","toggleable"}
local doorTypeTypes = {"Door Control","Redstone dust","Bundled Cable","Rolldoor"}
local redSideTypes = {"bottom","top","back","front","right","left"}
local redColorTypes = {"white","orange","magenta","light blue","yellow","lime","pink","gray","silver","cyan","purple","blue","brown","green","red","black"}
local forceOpenTypes = {"False","True"}
local bypassLockTypes = {"",""}

local settings

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

print("Sending query to server...") --TEST: Does this work with 1.#.# and 2.#.# (not og systems)
modem.open(modemPort)
modem.broadcast(modemPort,"autoInstallerQuery")
local e,_,_,_,_,msg = event.pull(3,"modem_message")
modem.close(modemPort)
if e == nil then
    print("No query received. Assuming old server system is in place and will not work")
    os.exit()
else
  print("Query received")
  settings = ser.unserialize(msg)
  
end


term.clear()
print("Admin Diagnostic Tablet (2.#.# only)")
print("Swipe an admin card on any security door to retrieve the door information")
local num = 0
while true do
  if modem.isOpen(diagPort) == false then
    modem.open(diagPort)
  end
  
  local _, _, from, port, _, command, msg = event.pull("modem_message")
  local data = msg
  local diagInfo = ser.unserialize(data)
  local temp
  num = num + 1
  term.clear()
  print("Retrieved new door information # " .. num)
  print("--Main Computer info--")
  print("door status = " .. diagInfo["status"])
  print("door type = " .. diagInfo["type"])
  print("door update version = " .. diagInfo["version"])
    
  if diagInfo["status"] ~= "incorrect magreader" then
        if diagInfo["type"] == "multi" then
        print("number of door entries: " .. diagInfo["entries"])
        print("door's key: " .. diagInfo["key"])
        print("door name: " .. diagInfo["name"])
    else
        print("***")
        print("***")
        print("door name: " .. diagInfo["name"])
    end
    print("---Door's settings----")
    local cardRead2 = 0
    if diagInfo["cardRead"] == "checkstaff" then
      temp = "staff"
    else
      temp = "ERROR"
      for i=1,#settings.data.label,1 do
        if settings.data.calls[i] == diagInfo["cardRead"] then
          temp = settings.data.label[i]
          cardRead2 = i
        end
      end
    end
    print("Pass type: " .. temp)

    if diagInfo["cardRead"] == "checkstaff" then
      print("***")
    else
      if settings.data.type[cardRead2] == "string" or settings.data.type[cardRead2] == "-string" then
        print("String input required: " .. diagInfo["accessLevel"])
      elseif settings.data.type[cardRead2] == "int" then
        if settings.data.above[cardRead2] == true then
          print("Level above " .. diagInfo["accessLevel"])
        else
          print("Level exactly " .. diagInfo["accessLevel"])
        end
      elseif settings.data.type[cardRead2] == "-int" then
        print("Group " .. settings.data.data[cardRead2][diagInfo["accessLevel"]])
      else
        print("***")
      end
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
  print("-Component Addresses--")
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
  print("---Door's settings----")
    print("***")
    print("***")
    print("***")
    print("***")
    print("***")
    print("***")
    print("***")
    print("***")
    print("***")
  print("-Component Addresses--")
  print("***")
  print("***")
  end
    
  print("--------------------")
  print("Scan another security door to retrieve it's door information")
end
