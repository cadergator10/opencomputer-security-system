--This program is aimed to provide an in-box way to put a multidoor anywhere in the world and have it work with the server (as long as its chunkloaded)
--What this means is, instead of putting a modem in the door computer, you put the linked card in the doorcomputer and the other in a computer running this.
--This computer must have a modem (wired recommended plugged into a relay plugged into the server) and at least 1 linking card with no maximum.
local component = require("component")
local gpu = component.gpu
local event = require("event")
local ser = require("serialization")
local term = require("term")
local thread = require("thread")
local process = require("process")
local uuid = require("uuid")
local computer = component.computer

local modem = component.modem
local links

local modemPort = 199

for key,_ in pairs(component.list("tunnel")) do
    table.insert(links,{["dev"]=component.proxy(key),["uuid"]="none"})
end

modem.open(modemPort)

while true do
    local e, _, from, port, _, msg, msg2, msg3 = event.pull("modem_message")
    if port == 0 then
        for i=1,#links,1 do
            if links[i].dev.address == from then
                links[i].uuid = msg
            end
        end
        modem.broadcast(modemPort,"rebroadcast",ser.serialize({["uuid"]=msg,["command"]=msg2,["data"]=msg3}))
    else
        if msg == "rebroadcast" then
            msg2 = ser.unserialize(msg2)
            for i=1,#links,1 do
                if msg2.uuid == links[i].address then
                    links[i].dev.send(msg2.data,msg2.data2)
                end
            end
        else
            for i=1,#links,1 do
                links[i].dev.send(msg,msg2,msg3)
            end
        end
    end
end