--A second file I created to be able to store all the pass editing in a seperate file
local workspace, window, loc, database, style, permissions, userTable = table.unpack({...})

local component = require("component")
local ser = require("serialization")
local GUI = require("GUI")
local uuid = require("uuid")
local event = require("event")
local fs = require("Filesystem")
local system = require("System")
local modem = component.modem