local component = require("component")
local term = require("term")
local io = require("io")
local ser = require("serialization")
local fs = require("filesystem")
local event = require("event")
local modem = component.modem

term.clear()
print("Enter 4 digit code")
local text = term.read()
local code = tonumber(text)
modem.open(code)
--local temp = {}
--temp["analyzer"]=component.isAvailable("barcode_reader")
modem.broadcast(code,"link",component.isAvailable("barcode_reader"))
print("linking...")
local e, _, from, port, _, msg = event.pull(3, "modem_message")
if e then
    print("successful link")
    local stayIn = true
    while stayIn do
        local data
    	e, _, from, port, _, msg, data = event.pull("modem_message")
        if msg == "print" then
            print(data)
        elseif msg == "write" then
            term.write(data)
        elseif msg == "getInput" then
            text = term.read()
            modem.send(from,port,text:sub(1,-2))
        elseif msg == "clearTerm" then
            term.clear()
        elseif msg == "terminate" then
            stayIn = false
        elseif msg == "analyzer" then
            print("Scan the device with your tablet")
            _, text = event.pull("tablet_use")
            modem.send(from,port,text.analyzed[1].address)
        end
    end
    print("Finished")
    modem.close(code)
else
    modem.close(code)
    print("failed to link")
end

--modem.send(from,port,"print","")
--modem.send(from,port,"write","")
--modem.send(from,port,"getInput")
--modem.send(from,port,"clearTerm")
--modem.send(from,port,"terminate")
--modem.send(from,port,"analyzer")
--e, _, from, port, _, text = event.pull("modem_message")
