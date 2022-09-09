local userTable = {}
local doorTable = {}
local server = {}
local modemPort = 199

local component = require("component")
local modem = component.modem
local ser = require("serialization")

module = {}
module.name = "passes"
module.commands = {"rcdoors","checkLinked","getvar","setvar","checkRules"}
module.skipcrypt = {"autoInstallerQuery","rcdoors"}
module.table = {["passes"]={},["passSettings"]={["var"]={"level"},["label"]={"Level"},["calls"]={"checkLevel"},["type"]={"int"},["above"]={true},["data"]={false}}}
module.debug = false

local function getPassID(command,rules)
    local bill
    if rules ~= nil then
        for i=1,#rules,1 do
            if rules[i].uuid == command then
                command = rules[i].call
                bill = i
                break
            end
        end
    end
    for i=1,#userTable.passSettings.calls,1 do
        if command == userTable.passSettings.calls[i] then
            return true, i, bill
        end
    end
    return command == "checkstaff" and true or false, command == "checkstaff" and 0 or false
end

local function getVar(var,user)
    for key, value in pairs(userTable.passes) do
        if value.uuid == user then
            return value[var]
        end
    end
    return "Nil "..var
end

local function checkVar(rule,user,index)
    if index ~= 0 then
        if userTable.passSettings.type[index] == "string" then
            return user[userTable.passSettings.var[index]] == rule.param
        elseif userTable.passSettings.type[index] == "-string" then
            for i=1,#user[userTable.passSettings.var[index]],1 do
                if user[userTable.passSettings.var[index]][i] == rule.param then
                    return true
                end
            end
            return false
        elseif userTable.passSettings.type[index] == "int" or userTable.passSettings.type[index] == "-int" then
            if userTable.passSettings.above[index] == false or userTable.passSettings.type[index] == "-int" then
                return user[userTable.passSettings.var[index]] == rule.param
            else
                return user[userTable.passSettings.var[index]] >= rule.param
            end
        elseif userTable.passSettings.type[index] == "bool" then
            return user[userTable.passSettings.var[index]]
        end
    else
        return user.staff
    end
    return false
end
--return true, not value.blocked, value[var], value.staff
local function checkAdvVar(user,rules) --{["uuid"]=uuid.next()["call"]=t1,["param"]=t2,["request"]="supreme",["data"]=false}
    local label,color = "will be set",0x000000
    local foundOne = false
    for key, value in pairs(userTable.passes) do
        if value.uuid == user then
            foundOne = true
            local skipBase = false
            for i=1,#rules,1 do
                if rules[i].request == "reject" then
                    local e, call = getPassID(rules[i].call)
                    if e then
                        local good = checkVar(rules[i],value,call)
                        if good then
                            label,color = call ~= 0 and "Denied: var " .. userTable.passSettings.label[call] .. " is rejected" or "Denied: var staff" .. " is rejected", 0xFF0000
                            skipBase = true
                            break
                        end
                    end
                end
            end
            if skipBase == false then
                for i=1,#rules,1 do
                    if rules[i].request == "base" then
                        local e, call = getPassID(rules[i].call)
                        if e then
                            local good = checkVar(rules[i],value,call)
                            if good then
                                label,color = call ~= 0 and "Accepted by base var " .. userTable.passSettings.label[call] or "Accepted by base var" .. "staff", 0x00B600
                                local isGood = true
                                for j=1,#rules[i].data,1 do
                                    local bill
                                    e, call, bill = getPassID(rules[i].data[j],rules)
                                    if e then
                                        good = checkVar(rules[bill],value,call)
                                        if good == false then
                                            isGood = false
                                            label,color = "Denied: did not meet base requirements", 0xFF0000
                                            break
                                        end
                                    end
                                end
                                if isGood then
                                    return true, not value.blocked, true, value.staff,label,color
                                end
                            end
                        end
                    end
                end
            end
            for i=1,#rules,1 do
                if rules[i].request == "supreme" then
                    local e,call = getPassID(rules[i].call)
                    if e then
                        local good = checkVar(rules[i],value,call)
                        if good then
                            label,color = call ~= 0 and "Accepted by supreme var " .. userTable.passSettings.label[call] or "Accepted by supreme var " .. "staff", 0x00FF00
                            return true, not value.blocked, true, value.staff,label,color
                        end
                    end
                end
            end
            if foundOne then
                if label == "will be set" then
                    label,color = "Denied: does not have any required passes",0xFF0000
                end
                return true, not value.blocked, false, value.staff,label,color
            end
        end
    end
    return false
end

local function getDoorInfo(type,id,key)
    local arrange
    if type == "doorsystem" then
        for i=1,#doorTable,1 do --doorTable[i] = {type="single or multi",id="computer's modem uuid",data={door's setting table}}
            if doorTable[i].id == id then
                if doorTable[i].data[key]~=nil then
                    return {["read"]=doorTable[i].data[key].cardRead,["name"]=doorTable[i].data[key].name}
                end
            end
        end
    end
    return nil, arrange
end

local function checkLink(user)
    for key, value in pairs(userTable.passes) do
        if value.link == user then
            return true, not value.blocked, value.name
        end
    end
    return false
end

function module.init(setit ,doors, serverCommands) --Called when server is first started
    userTable = setit
    doorTable = doors
    server = serverCommands
    if module.debug then print("Received Stuff for passes!") end
end

function module.setup() --Called when userlist is updated or server is first started
    if module.debug then print("Received Stuff for passes!") end
end

function module.message(command,datar,from) --Called when a command goes past all default commands and into modules.
    local data
    if datar ~= nil then
        data = ser.unserialize(datar)
    end
    local thisUserName = false
    if command == "setvar" or command == "getvar" or command == "checkRules" then
        thisUserName = getVar("name",data.uuid)
    end
    if command == "rcdoors" then
        local sendTable = {}
        for _,value in pairs(doorTable) do
            local datar
            if value.type == "multi" then
                datar = {}
                for key,pal in pairs(value.data) do
                    datar[key] = {["name"]=pal.name}
                end
            else
                datar = {["name"]=value.data.name}
            end
            table.insert(sendTable,{["id"]=value.id,["type"]=value.type,["data"]=datar})
        end
        return true,{{["text"]="Passes: ",["color"]=0x9924C0},{["text"]="Sending remote control table",["color"]=0xFFFFFF}},false,true,ser.serialize(sendTable)
    elseif command == "checkLinked" then
        local cu, isBlocked, thisName = checkLink(data)
        local dis = {}
        if cu == true then
            if isBlocked == false then
                dis["status"] = false
                dis["reason"] = 2
                data = server.crypt(ser.serialize(dis))
                return true,{{["text"]="Passes: ",["color"]=0x9924C0},{["text"]="Checking if device is linked to a user: ",["color"]=0xFFFF80},{["text"]=" user " .. thisName .. "is blocked",["color"]=0xFF0000,["line"]=true}},false,true,data
            else
                dis["status"] = true
                dis["name"] = thisName
                data = server.crypt(ser.serialize(dis))
                return true,{{["text"]="Passes: ",["color"]=0x9924C0},{["text"]="Checking if device is linked to a user: ",["color"]=0xFFFF80},{["text"]=" tablet is connected to " .. thisName,["color"]=0x00FF00,["line"]=true}},false,true,data
            end
        else
            dis["status"] = false
            dis["reason"] = 1
            data = server.crypt(ser.serialize(dis))
            return true,{{["text"]="Passes: ",["color"]=0x9924C0},{["text"]="Checking if device is linked to a user: ",["color"]=0xFFFF80},{["text"]=" tablet not linked",["color"]=0x990000,["line"]=true}},false,true,data
        end--IMPORTANT: Hello
    elseif command == "getvar" then
        local worked = false
        for _, value in pairs(userTable.passes) do
            if value.uuid == data.uuid then
                worked = true
                local mee = type(value[data.var]) == "table" and ser.serialize(value[data.var]) or value[data.var]
                return true,nil,false,true,server.crypt(mee)
            end
        end
    elseif command == "setvar" then
        local worked = false
        local counter = 1
        for _, value in pairs(userTable.passes) do
            if value.uuid == data.uuid then
                worked = true
                if type(userTable.passes[counter][data.var]) == type(data.data) then
                    userTable.passes[counter][data.var] = data.data
                end
                return true,nil,false,true,server.crypt("true")
            else
                counter = counter + 1
            end
        end
    elseif command == "checkRules" then
        local currentDoor = getDoorInfo(data.type,from,data.key)
        local enter = true
        if data.sector ~= false then
            local a,c,_,_,b = server.modulemsg("doorsector",ser.serialize(data))
            if a then
                if b ~= "true" and b ~= "openbypass" then
                    enter = false
                    if b == "false" then
                        return true,c,false,true,server.crypt("false")
                    elseif b == "lockbypass" then
                        return true,c,false,true,server.crypt("bypass")
                    end
                end
            end
        end
        if enter then
            local chatTable = {{["text"]="Passes: ",["color"]=0x9924C0}}
            table.insert(chatTable,{["text"]="Checking user " .. thisUserName .. "'s credentials on " .. currentDoor.name .. ":",["color"]=0xFFFF80,["line"]=false})
            local cu, isBlocked, varCheck, isStaff,label,color = checkAdvVar(data.uuid,currentDoor.read)
            if cu then
                if isBlocked then
                    if varCheck then
                        data = server.crypt("true")
                        table.insert(chatTable,{["text"]=label,["color"]=color,["line"]=true})
                    else
                        if isStaff then
                            data = server.crypt("true")
                            table.insert(chatTable,{["text"]="access granted due to staff",["color"]=0xFF00FF,["line"]=true})
                        else
                            data = server.crypt("false")
                            table.insert(chatTable,{["text"]=label,["color"]=color,["line"]=true})
                        end
                    end
                else
                    data = server.crypt("false")
                    table.insert(chatTable,{["text"]="user is blocked",["color"]=0xFF0000,["line"]=true})
                end
            else
                data = server.crypt("false")
                table.insert(chatTable,{["text"]="user not found",["color"]=0x990000,["line"]=true})
            end
            return true,chatTable,false,true,data
        end
    end
    return false
end
function module.piggyback(command,data) --Called after a command is passed. Passed to all modules which return nothing.
    if command == "setdevice" then
        server.send(true,server.crypt(ser.serialize({["settings"]=userTable.passSettings,["sectors"]=userTable.sectors})))
    end
    return
end

return module