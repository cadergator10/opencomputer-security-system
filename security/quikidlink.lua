--A program that allows users to link their card to their MC User (if there is not one linked already)
local apiCode = "https://raw.githubusercontent.com/cadergator10/Opencomputers-servertine/main/serpAPI.lua" --Shouldn't need the modified SecurityAPI version due to it implementing custom features.
local component = require("component")
local term = require("term")
local io = require("io")
local ser = require("serialization")
local fs = require("filesystem")
local event = require("event")
local api = require("serpAPI.lua")

term.clear()
if api == nil then --Checkong for SerpAPI program. If it doesn't exist, download it.
    print("No API installed. Downloading")
    os.execute("wget -f " .. apiCode .. " " .. "serpAPI")
    api = require("serpAPI.lua") --Attempt to get again. Experimental (dont know if it will work)
end

api.setup({["type"]="quikidlink"},{}) --Prepare table to submit to server. Setting the type in case I want to do something on the server and such

for key,_ in pairs(component.list("os_magreader")) do --Prepare light on magreader to signal stuff
    component.proxy(key).swipeIndicator(false)
    component.proxy(key).setLightState(3) --3 is red and yellow, meaning swipe card
  end

while true do
    term.clear()
    print("Quick Minecraft UUID Link")
    print("---------------------------------------------------------------------------")
    print("Please swipe the card you want to link your ID to")
    local ev, address, _, str = event.pull("magData") --wait for a card swipe
    component.proxy(address).setLightState(2) --2 is yellow, meaning waiting. Doing stuff
    local _, data = api.crypt(str, true) --decrypt card's data
    data = ser.unserialize(data) --unserialize card data
    if ev and data ~= nil then --Read the data successfully and decrypted
        print("Welcome " .. data.name)
        print("Please click the biometric reader to link player")
        component.proxy(address).setLightState(6) --6 is green and yellow, meaning click bioreader
        local e, ad, msg = event.pull(7,"bioReader") --wait for bioreader click or timeout
        component.proxy(address).setLightState(2) --2 is yellow. Waiting for message back
        if e then --clicked bioreader
            print("Waiting for response from server...")
            data = api.crypt(ser.serialize({["uuid"]=data.uuid,["mcid"]=msg})) --encrypting data and sending to server to check if user exists and they don't have a mcid linked yet
            e, msg = api.send(true,"linkMCID",data)
            if e then --Received message back
                _, msg = api.crypt(msg,true)
                if msg == "true" then --Linked user successfully
                    print("Link success! All biometric reader doors should work for you now")
                    component.proxy(address).setLightState(4) --4 is green, meaning success
                else --Failed for some reason
                    print("Link failed: Either card already is linked, account no longer exists, or card is blocked")
                    component.proxy(address).setLightState(1) --1 is red, meaning failed in this case.
                end
            else --No message received
                print("Server failed to respond. Has it crashed or is it off?")
                component.proxy(address).setLightState(7) --7 is all lights, indicating error (server down or crash?)
            end
        else --Didn't click bio reader in time
            print("Biometric timeout")
            component.proxy(address).setLightState(1) --1 is red, indicating a timeout for the bioreader and no link
        end
    else --Card wasn't able to be read
        print("Failed to read card")
        component.proxy(address).setLightState(1) --1 is red, indicating in this case that either nothing was received (ev) or card was nil (no data on card or incorrect crypted data)
    end
    os.sleep(3)
    component.proxy(address).setLightState(3) --reset it to swipe card mode
end