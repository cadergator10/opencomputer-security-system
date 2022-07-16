local version = "2.4.0"

local sector = {}
local sectorSettings = {}

local modemPort = 199

local component = require("component")
local gpu = component.gpu
local event = require("event")
local ser = require("serialization")
local term = require("term")
local thread = require("thread")
local process = require("process")
local uuid = require("uuid")
local computer = component.computer
local keyboard = component.keyboard

local redstone = component.redstone
local modem = component.modem

local query

local testR = true
local lengthNum = 0
local pageNum = 1
local listNum = 1

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

--------Called Functions

local function arrangeSectors(query)
    sector = {}
    local amt = (#query+1) * 3
end

--------Main Program

term.clear()
print("Sending query to server...")
modem.open(modemPort)
modem.broadcast(modemPort,"autoInstallerQuery")
local e,_,_,_,_,msg = event.pull(3,"modem_message")
modem.close(modemPort)
if e == nil then
    print("No query received. Assuming old server system is in place and will not work")
    os.exit()
else
    print("Query received")
    query = ser.unserialize(msg).sectors
end
modem.open(modemPort)

arrangeSectors()

thread.create(function()
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
end)

local fill = io.open("redstonelinks.txt", "r")
if fill~=nil then
    io.close(fill)
else
    saveTable({},"redstonelinks.txt")
end

sector = loadTable("redstonelinks.txt")

while true do
    local ev,_,side,_,value,command,msg = event.pullMultiple("modem_message","redstone_changed")
end