local version = "4.0.0"

local sector = {}
local sectorStatus = {}
local sectorSettings = {}

local modemPort = 1000
local syncPort = 199

local component = require("component")
local gpu = component.gpu
local event = require("event")
local ser = require("serialization")
local term = require("term")
local thread = require("thread")
local process = require("process")
local uuid = require("uuid")
local computer = component.computer
local keyboard = require("keyboard")

local redstone = component.redstone
local modem = component.modem

local query

local testR = true
local lengthNum = 0
local pageNum = 1
local listNum = 1

local redColorTypes = {"white","orange","magenta","light blue","yellow","lime","pink","gray","silver","cyan","purple","blue","brown","green","red","black"}
local redSideTypes = {"bottom","top","back","front","right","left"}

local updatePulse = false

--------Table To File

local function saveTable(  tbl,filename )
    local tableFile = assert(io.open(filename, "w"))
    tableFile:write(ser.serialize(tbl))
    tableFile:close()
end

local function loadTable( sfile )
    local tableFile = io.open(sfile)
    if tableFile ~= nil then
        return ser.unserialize(tableFile:read("*all"))
    else
        return nil
    end
end

--------Base Functions

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

local function splitString(str, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function setGui(pos, text, wrap, color)
    term.setCursor(1,pos)
    term.clearLine()
    if color then gpu.setForeground(color) else gpu.setForeground(0xFFFFFF) end
    if wrap then print(text) else term.write(text) end
end

local function pageChange(dir,pos,length,call,...)
    if dir == "hor" then
        if type(pos) == "boolean" then
            if pos then
                if pageNum < length then
                    pageNum = pageNum + 1
                end
            else
                if pageNum > 1 then
                    pageNum = pageNum - 1
                end
            end
        else
            pageNum = pos
        end
    elseif dir == "ver" then
        if type(pos) == "boolean" then
            if pos then
                if listNum < length then
                    listNum = listNum + 1
                end
            else
                if listNum > 1 then
                    listNum = listNum - 1
                end
            end
        else
            listNum = pos
        end
    elseif dir == "setup" then
        pageNum = pos
        listNum = 1
    end
    call(...)
end

-- removed AutoUpdate function due to being unnecessary to the checking of if a change was detected

--------Called Functions

local function colorSearch(color,side)
    local c,s = -1,-1
    if type(color) == "number" then
        c = color
    else
        for i=1,#redColorTypes,1 do
            if redColorTypes[i] == color then
                c = i - 1
            end
        end
    end
    for i=1,#redSideTypes,1 do
        if type(side) == "number" then
            s = side
        else
            if redSideTypes[i] == side then
                s = i - 1
            end
        end
    end
    return c,s
end

local function redlinkcheck(color,side)
    for key,value in pairs(sectorSettings) do
        if key ~= "cryptKey" and key ~= "port" then --We don't want cryptKey or port being used
            if value.open.color == color and value.open.side == side then
                sectorSettings[key].open.color = -1
                sectorSettings[key].open.side = -1
            end
            if value.lock.color == color and value.lock.side == side then
                sectorSettings[key].lock.side = -1
                sectorSettings[key].lock.color = -1
            end
            if value.disable.color == color and value.disable.side == side then
                sectorSettings[key].disable.side = -1
                sectorSettings[key].disable.color = -1
            end
        end
    end
end

local function arrangeSectors(query)
    sector = {}
    local amt = (#query) * 3
    local count = 1
    local save = false
    for i=1,math.ceil(amt/9),1 do
        sector[i] = {}
        for j=1,3,1 do
            if query[count] ~= nil then
                sector[i][j] = deepcopy(query[count])
                if sectorSettings[query[count].uuid] == nil then
                    sectorSettings[query[count].uuid] = {["open"]={["side"]=-1,["color"]=-1},["lock"]={["side"]=-1,["color"]=-1},["disable"]={["side"]=-1,["color"]=-1}}
                    save = true
                end
                count = count + 1
            end
        end
    end
    for key,value in pairs(sectorSettings) do
        local here = false
        if key == "cryptKey" or key == "port" then
            here = true
        else
            for i=1,#query,1 do
                if query[i].uuid == key then
                    here = true
                    break
                end
            end
        end
        if here == false then
            sectorSettings[key] = nil
            save = true
        end
    end
    if save then
        saveTable(sectorSettings,"redstonelinks.txt")
    end
end

local function sectorGui(editmode)
    setGui(1,"Sector Control Program")
    if #sector == 0 then
        setGui(2,"Create a sector to begin")
    else
        setGui(2,"Page " .. pageNum .. "/" .. #sector)
        setGui(3,"")
        setGui(4,"------------------------------")
        local pre, count = "> ",1
        if (#sector[pageNum] * 3) < listNum then
            listNum = (#sector[pageNum] * 3)
        end
        if listNum == count then
            pre = "> "
        else
            pre = "  "
        end
        for i=1,#sector[pageNum],1 do
            local secKeys = {["disable"] = "Clear sector ",["lock"] = "Lockdown sector ",["open"] = "Open sector "}
            for key,value in pairs(secKeys) do
                if listNum == count then
                    pre = "> "
                else
                    pre = "  "
                end
                setGui(count + 4,sectorSettings[sector[pageNum][i].uuid][key].side ~= -1 and pre .. value .. sector[pageNum][i].name .. ": " .. redSideTypes[sectorSettings[sector[pageNum][i].uuid][key].side + 1]  .. " : " .. redColorTypes[sectorSettings[sector[pageNum][i].uuid][key].color + 1] or pre .. value .. sector[pageNum][i].name .. ": " .. "unlinked : unlinked")
                count = count + 1
            end
        end
        count = count + 4
        setGui(count,"------------------------------")
    end
end

--------Main Program

term.clear()
local fill = io.open("redstonelinks.txt", "r")
if fill~=nil then
    io.close(fill)
else
    modem.open(syncPort)
    modem.broadcast(syncPort,"syncport")
    local e,_,_,_,_,msg = event.pull(1,"modem_message")
    modem.close(syncPort)
    if e then
        modemPort = tonumber(msg)
    else
        print("What port is the server running off of?")
        local text = term.read()
        modemPort = tonumber(text:sub(1,-2))
        term.clear()
    end

    saveTable({["cryptKey"]={1,2,3,4,5},["port"]=modemPort,"redstonelinks.txt"})
    print("Crypt key is set to default (1,2,3,4,5)")
end

sectorSettings = loadTable("redstonelinks.txt")

if sectorSettings.cryptKey == nil then
    sectorSettings.cryptKey = {1,2,3,4,5}
    print("Crypt key is set to default (1,2,3,4,5)")
    modem.open(syncPort)
    modem.broadcast(syncPort,"syncport")
    local e,_,_,_,_,msg = event.pull(1,"modem_message")
    modem.close(syncPort)
    if e then
        modemPort = tonumber(msg)
    else
        print("What port is the server running off of?")
        local text = term.read()
        modemPort = tonumber(text:sub(1,-2))
        term.clear()
    end
    sectorSettings.port = modemPort
    saveTable(sectorSettings,"redstonelinks.txt")
end
if sectorSettings.default ~= nil then
    sectorSettings.default = nil
    for key, value in pairs(sectorSettings) do
        if key ~= "cryptKey" and key ~= "port" then
            value.disable = {["side"]=-1,["color"]=-1}
        end
    end
end

modemPort = sectorSettings.port

print("Sending query to server...")
modem.open(modemPort)
modem.broadcast(modemPort,"getquery",ser.serialize({"sectors"})) --TODO: Remove all sectorStatus calls
local e,_,_,_,_,msg = event.pull(3,"modem_message")
modem.close(modemPort)
if e == nil then
    print("No query received. Assuming old server system is in place and will not work")
    os.exit()
else
    print("Query received")
    msg = crypt(msg,sectorSettings.cryptKey,true)
    query = ser.unserialize(msg).data.sectors
end
modem.open(modemPort)

arrangeSectors(query)

--[[thread.create(function() --Unneeded function.
    while true do
        local ev, p1, p2, p3, p4, p5 = event.pull("key_down")
        local char = tonumber(keyboard.keys[p3])
        if char ~= nil then
            if char > 0 then
                if char <= lengthNum then
                    event.push("numInput",char)
                    lengthNum = 0
                end
            end
        end
    end
end)]]

local editmode = false

pageChange("setup",1,#sector, sectorGui, editmode)

while true do
    local ev,num,side,key,value,command,msg = event.pullMultiple("modem_message","redstone_changed","key_down")
    if #sector ~= 0 then
        if ev == "modem_message" then
            if command == "getSectorList" then
                query = ser.unserialize(msg).sectors
                arrangeSectors(query)
                pageChange("setup",1,#sector, sectorGui, editmode)
            end
        elseif ev == "key_down" then
            if editmode == false then
                local char = keyboard.keys[key]
                if char == "left" then
                    term.clear()
                    pageChange("hor",false,#sector, sectorGui, editmode)
                    os.sleep(0.5)
                elseif char == "right" then
                    term.clear()
                    pageChange("hor",true,#sector, sectorGui, editmode)
                    os.sleep(0.5)
                elseif char == "up" then
                    term.clear()
                    pageChange("ver",false,(#sector[pageNum]*2) + 1, sectorGui, editmode)
                    os.sleep(0.5)
                elseif char == "down" then
                    term.clear()
                    pageChange("ver",true,(#sector[pageNum]*2) + 1, sectorGui, editmode)
                    os.sleep(0.5)
                elseif char == "enter" then
                    setGui(20,"Which side should redstone input from?")
                    term.setCursor(1,21)
                    term.clearLine()
                    local side = term.read():sub(1,-2)
                    if tonumber(side) ~= nil then
                    side = tonumber(side)
                    end
                    setGui(20,"Which color should be checked?")
                    term.setCursor(1,21)
                    term.clearLine()
                    local color = term.read():sub(1,-2)
                    if tonumber(color) ~= nil then
                        color = tonumber(color)
                    end
                    color, side = colorSearch(color,side)
                    if color ~= -1 and side ~= -1 then
                        redlinkcheck(color,side)
                        if (listNum)%3 == 1 then
                            sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].disable.color = color
                            sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].disable.side = side
                        elseif (listNum)%3 == 2 then
                            sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].lock.color = color
                            sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].lock.side = side
                        else
                            sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].open.color = color
                            sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].open.side = side
                        end
                    end
                    saveTable(sectorSettings,"redstonelinks.txt")
                    pageChange("hor",pageNum,#sector, sectorGui, editmode)
                    os.sleep(0.5)
                elseif char == "back" then
                    if (listNum)%3 == 1 then
                        sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].disable.color = -1
                        sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].disable.side = -1
                    elseif (listNum)%3 == 2 then
                        sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].lock.color = -1
                        sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].lock.side = -1
                    else
                        sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].open.color = -1
                        sectorSettings[sector[pageNum][math.ceil((listNum - 1)/2)].uuid].open.side = -1
                    end
                    pageChange("hor",pageNum,#sector, sectorGui, editmode)
                    os.sleep(0.5)
                end
            end
        elseif ev == "redstone_changed" then
            local officialChange = {false} --If the change in redstone is something saved to redstonelinks.txtr
            if key == 0 and value > 0 then
                for i=1,#query,1 do
                    if sectorSettings[query[i].uuid].open.side == side and sectorSettings[query[i].uuid].open.color == command then
                        officialChange[1] = true
                        officialChange[2] = query[i].uuid
                        officialChange[3] = side
                        officialChange[4] = command
                        officialChange[5] = 3
                        break
                    end
                    if sectorSettings[query[i].uuid].lock.side == side and sectorSettings[query[i].uuid].lock.color == command then
                        officialChange[1] = true
                        officialChange[2] = query[i].uuid
                        officialChange[3] = side
                        officialChange[4] = command
                        officialChange[5] = 2
                        break
                    end
                    if sectorSettings[query[i].uuid].disable.side == side and sectorSettings[query[i].uuid].disable.color == command then
                        officialChange[1] = true
                        officialChange[2] = query[i].uuid
                        officialChange[3] = side
                        officialChange[4] = command
                        officialChange[5] = 1
                        break
                    end
                    --[[if sectorStatus[query[i].uuid] ~= current then --a change was detected
                        officialChange = true
                    end]]
                end
            end
            if officialChange then
                modem.broadcast(modemPort,"sectorupdate",crypt(ser.serialize({officialChange[2],officialChange[5]}),sectorSettings.cryptKey))
            end
        end
    else
        os.sleep(1)
    end
end
