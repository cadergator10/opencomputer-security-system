local cryptKey = {1, 2, 3, 4, 5}
local departments = {"SD","ScD","MD","E&T","O5"}
local modemPort = 199

local component = require("component")
local gpu = component.gpu
local gui = require("gui")
local event = require("event")
local ser = require("serialization")
local uuid = require("uuid")
writer = component.os_cardwriter

local myGui, cardStatusLabel, userList, userNameText, userLevelLabel, LevelUpButton, LevelDownButton
local cardBlockedYesButton, cardBlockedNoButton, userNewButton, userDeleteButton, userResetUUIDButton, MTFYesButton, MTFNoButton
local GOIYesButton, GOINoButton, SecYesButton, SecNoButton, userArmoryLabel, ArmoryUpButton, ArmoryDownButton
local userDepLabel, DepUpButton, DepDownButton, IntYesButton, IntNoButton, StaffYesButton, StaffNoButton

local prgName = "SCP Security System"
local version = "v1.7.0"

local modem = component.modem 

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
--// The Save Function
function saveTable(  tbl,filename )
	local charS,charE = "   ","\n"
	local file,err
	-- create a pseudo file that writes to a string and return the string
	if not filename then
		file =  { write = function( self,newstr ) self.str = self.str..newstr end, str = "" }
		charS,charE = "",""
	-- write table to tmpfile
	elseif filename == true or filename == 1 then
		charS,charE,file = "","",io.tmpfile()
	-- write table to file
	-- use io.open here rather than io.output, since in windows when clicking on a file opened with io.output will create an error
	else
		file,err = io.open( filename, "w" )
		if err then return _,err end
	end
	-- initiate variables for save procedure
	local tables,lookup = { tbl },{ [tbl] = 1 }
	file:write( "return {"..charE )
	for idx,t in ipairs( tables ) do
		if filename and filename ~= true and filename ~= 1 then
			file:write( "-- Table: {"..idx.."}"..charE )
		end
		file:write( "{"..charE )
		local thandled = {}
		for i,v in ipairs( t ) do
			thandled[i] = true
			-- escape functions and userdata
			if type( v ) ~= "userdata" then
				-- only handle value
				if type( v ) == "table" then
					if not lookup[v] then
						table.insert( tables, v )
						lookup[v] = #tables
					end
					file:write( charS.."{"..lookup[v].."},"..charE )
				elseif type( v ) == "function" then
					file:write( charS.."loadstring("..exportstring(string.dump( v )).."),"..charE )
				else
					local value =  ( type( v ) == "string" and exportstring( v ) ) or tostring( v )
					file:write(  charS..value..","..charE )
				end
			end
		end
		for i,v in pairs( t ) do
			-- escape functions and userdata
			if (not thandled[i]) and type( v ) ~= "userdata" then
				-- handle index
				if type( i ) == "table" then
					if not lookup[i] then
						table.insert( tables,i )
						lookup[i] = #tables
					end
					file:write( charS.."[{"..lookup[i].."}]=" )
				else
					local index = ( type( i ) == "string" and "["..exportstring( i ).."]" ) or string.format( "[%d]",i )
					file:write( charS..index.."=" )
				end
				-- handle value
				if type( v ) == "table" then
					if not lookup[v] then
						table.insert( tables,v )
						lookup[v] = #tables
					end
					file:write( "{"..lookup[v].."},"..charE )
				elseif type( v ) == "function" then
					file:write( "loadstring("..exportstring(string.dump( v )).."),"..charE )
				else
					local value =  ( type( v ) == "string" and exportstring( v ) ) or tostring( v )
					file:write( value..","..charE )
				end
			end
		end
		file:write( "},"..charE )
	end
	file:write( "}" )
	-- Return Values
	-- return stringtable from string
	if not filename then
		-- set marker for stringtable
		return file.str.."--|"
	-- return stringttable from file
	elseif filename == true or filename == 1 then
		file:seek ( "set" )
		-- no need to close file, it gets closed and removed automatically
		-- set marker for stringtable
		return file:read( "*a" ).."--|"
	-- close file and return 1
	else
		file:close()
		return 1
	end
end
 
--// The Load Function
function loadTable( sfile )
	local tables, err, _
	-- catch marker for stringtable
	if string.sub( sfile,-3,-1 ) == "--|" then
---@diagnostic disable-next-line: deprecated
		tables,err = loadstring( sfile )
	else
		tables,err = loadfile( sfile )
	end
	if err then return _,err
	end
	tables = tables()
	for idx = 1,#tables do
		local tolinkv,tolinki = {},{}
		for i,v in pairs( tables[idx] ) do
			if type( v ) == "table" and tables[v[1]] then
				table.insert( tolinkv,{ i,tables[v[1]] } )
			end
			if type( i ) == "table" and tables[i[1]] then
				table.insert( tolinki,{ i,tables[i[1]] } )
			end
		end
		-- link values, first due to possible changes of indices
		for _,v in ipairs( tolinkv ) do
			tables[idx][v[1]] = v[2]
		end
		-- link indices
		for _,v in ipairs( tolinki ) do
			tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
		end
	end
	return tables[1]
end



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


function buttonCallback(guiID, id)
  local result = gui.getYesNo("", "Do you really want to exit?", "")
  if result == true then
    gui.exit()
  end
end

function eventCallback(ev, id)
  if ev == "cardInsert" then
    gui.setText(myGui, cardStatusLabel, "   Card present")
  elseif ev == "cardRemove" then
    gui.setText(myGui, cardStatusLabel, "     No card   ")
  end
end

function userListCallback(guiID, listID, selectedID, selectedText)
  gui.setText(myGui, userNameText, userTable[selectedID].name)
  gui.setText(myGui, userLevelLabel, tostring(userTable[selectedID].level))
  gui.setText(myGui, userArmoryLabel, tostring(userTable[selectedID].armory))
  gui.setText(myGui, userDepLabel, departments[userTable[selectedID].department])
  if userTable[selectedID].blocked == true then
    gui.setEnable(myGui, cardBlockedYesButton, false)
    gui.setEnable(myGui, cardBlockedNoButton, true)
  else
    gui.setEnable(myGui, cardBlockedYesButton, true)
    gui.setEnable(myGui, cardBlockedNoButton, false)
  end
  if userTable[selectedID].mtf == true then
    gui.setEnable(myGui, MTFNoButton, true)
    gui.setEnable(myGui, MTFYesButton, false)
  else
    gui.setEnable(myGui, MTFNoButton, false)
    gui.setEnable(myGui, MTFYesButton, true)
  end
  if userTable[selectedID].goi == true then
    gui.setEnable(myGui, GOINoButton, true)
    gui.setEnable(myGui, GOIYesButton, false)
  else
    gui.setEnable(myGui, GOINoButton, false)
    gui.setEnable(myGui, GOIYesButton, true)
  end
  if userTable[selectedID].sec == true then
    gui.setEnable(myGui, SecNoButton, true)
    gui.setEnable(myGui, SecYesButton, false)
  else
    gui.setEnable(myGui, SecNoButton, false)
    gui.setEnable(myGui, SecYesButton, true)
  end
  if userTable[selectedID].int == true then
    gui.setEnable(myGui, IntNoButton, true)
    gui.setEnable(myGui, IntYesButton, false)
  else
    gui.setEnable(myGui, IntNoButton, false)
    gui.setEnable(myGui, IntYesButton, true)
  end
  if userTable[selectedID].staff == true then
    gui.setEnable(myGui, StaffNoButton, true)
    gui.setEnable(myGui, StaffYesButton, false)
  else
    gui.setEnable(myGui, StaffNoButton, false)
    gui.setEnable(myGui, StaffYesButton, true)
  end
  gui.setEnable(myGui, LevelUpButton, true)
  gui.setEnable(myGui, LevelDownButton, true)
  gui.setEnable(myGui, ArmoryUpButton, true)
  gui.setEnable(myGui, ArmoryDownButton, true)
  gui.setEnable(myGui, DepUpButton, true)
  gui.setEnable(myGui, DepDownButton, true)
  gui.setEnable(myGui, userNameText, true)
end

function updateServer()
  local data = ser.serialize(userTable)
  local crypted = crypt(data, cryptKey)
  if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
  end
  modem.broadcast(modemPort, "updateuser", crypted)
end
  

function updateList()
  gui.clearList(myGui, userList)
  for key,value in pairs(userTable) do
    gui.insertList(myGui, userList, value.name)
  end
  saveTable(userTable, "userlist.txt")
  updateServer()
end

function mtfYesUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].mtf = true
  updateList()
  userListCallback(myGui, userList, selected)
end

function mtfNoUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].mtf = false
  updateList()
  userListCallback(myGui, userList, selected)
end
function goiYesUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].goi = true
  updateList()
  userListCallback(myGui, userList, selected)
end

function goiNoUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].goi = false
  updateList()
  userListCallback(myGui, userList, selected)
end

function secYesUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].sec = true
  updateList()
  userListCallback(myGui, userList, selected)
end

function secNoUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].sec = false
  updateList()
  userListCallback(myGui, userList, selected)
end

function intYesUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].int = true
  updateList()
  userListCallback(myGui, userList, selected)
end

function intNoUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].int = false
  updateList()
  userListCallback(myGui, userList, selected)
end
function staffYesUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].staff = true
  updateList()
  userListCallback(myGui, userList, selected)
end

function staffNoUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].staff = false
  updateList()
  userListCallback(myGui, userList, selected)
end

function blockUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].blocked = true
  updateList()
  userListCallback(myGui, userList, selected)
end

function unblockUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].blocked = false
  updateList()
  userListCallback(myGui, userList, selected)
end

function newUserCallback(guiID, id)
  local tmpTable = {["name"] = "new", ["blocked"] = false, ["level"] = 1, ["date"] = os.date(), ["armory"] = 0, ["mtf"] = false, ["sec"] = false, ["goi"] = false, ["int"] = false, ["staff"] = false, ["department"] = 1, ["uuid"] = uuid.next()}
  table.insert(userTable, tmpTable)
  updateList()
end

function deleteUserCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected] = nil
  updateList()
  gui.setText(myGui, userNameText, "")
  gui.setText(myGui, userLevelLabel, "")
  gui.setEnable(myGui, cardBlockedYesButton, false)
  gui.setEnable(myGui, cardBlockedNoButton, false)
  gui.setEnable(myGui, MTFYesButton, false)
  gui.setEnable(myGui, MTFNoButton, false)
  gui.setEnable(myGui, GOIYesButton, false)
  gui.setEnable(myGui, GOINoButton, false)
  gui.setEnable(myGui, SecYesButton, false)
  gui.setEnable(myGui, SecNoButton, false)
  gui.setEnable(myGui, IntYesButton, false)
  gui.setEnable(myGui, IntNoButton, false)
  gui.setEnable(myGui, StaffYesButton, false)
  gui.setEnable(myGui, StaffNoButton, false)
  gui.setEnable(myGui, LevelUpButton, false)
  gui.setEnable(myGui, LevelDownButton, false)
  gui.setEnable(myGui, ArmoryUpButton, false)
  gui.setEnable(myGui, ArmoryDownButton, false)
  gui.setEnable(myGui, DepUpButton, false)
  gui.setEnable(myGui, DepDownButton, false)
  gui.setEnable(myGui, userNameText, false)
end

function changeUUID(guiID, id)
	local selected = gui.getSelected(myGui, userList)
    userTable[selected].uuid = uuid.next()
    updateList()
    userListCallback(myGui, userList, selected)
end

function writeCardCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  local data = {["date"]=userTable[selected].date,["name"]=userTable[selected].name,["uuid"]=userTable[selected].uuid}
  data = ser.serialize(data)
  local crypted = crypt(data, cryptKey)
  writer.write(crypted, userTable[selected].name .. "'s security pass", false, 8)
end

function levelUpCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  if userTable[selected].level < 101 then
    userTable[selected].level = userTable[selected].level + 1
  end
  updateList()
  userListCallback(myGui, userList, selected)
end

function levelDownCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  if userTable[selected].level > 1 then
    userTable[selected].level = userTable[selected].level - 1
  end
  updateList()
  userListCallback(myGui, userList, selected)
end

function armorUpCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  if userTable[selected].armory < 4 then
    userTable[selected].armory = userTable[selected].armory + 1
  end
  updateList()
  userListCallback(myGui, userList, selected)
end

function armorDownCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  if userTable[selected].armory > 0 then
    userTable[selected].armory = userTable[selected].armory - 1
  end
  updateList()
  userListCallback(myGui, userList, selected)
end

function depUpCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  if userTable[selected].department < 5 then
    userTable[selected].department = userTable[selected].department + 1
  end
  updateList()
  userListCallback(myGui, userList, selected)
end

function depDownCallback(guiID, id)
  local selected = gui.getSelected(myGui, userList)
  if userTable[selected].department > 1 then
    userTable[selected].department = userTable[selected].department - 1
  end
  updateList()
  userListCallback(myGui, userList, selected)
end

function inputCallback(guiID, textID, text)
  local selected = gui.getSelected(myGui, userList)
  userTable[selected].name = text
  updateList()
  userListCallback(myGui, userList, selected)
end

-- main gui setup
myGui = gui.newGui(2, 2, 150, 45, true)
button = gui.newButton(myGui, "center", 42, "exit", buttonCallback)

-- frame with user list
gui.newFrame(myGui, 3, 3, 60, 36)
userList = gui.newList(myGui, 4, 4, 58, 34, {}, userListCallback)
userTable = loadTable("userlist.txt")
if userTable == nil then
  userTable = {}
end
updateList()

-- user infos
gui.newLabel(myGui, 64, 12, "User name : ")
gui.newLabel(myGui, 64, 14, "Level     : ")
gui.newLabel(myGui, 64, 16, "MTF       : ")
gui.newLabel(myGui, 64, 18, "GOI       : ")
gui.newLabel(myGui, 64, 20, "Security  : ")
gui.newLabel(myGui, 64, 22, "Intercom  : ")
gui.newLabel(myGui, 64, 24, "Staff     : ")
gui.newLabel(myGui, 64, 26, "ArmorLevel: ")
gui.newLabel(myGui, 64, 28, "Department: ")
gui.newLabel(myGui, 64, 30, "Blocked   : [yes] / [no]")
userNameText = gui.newText(myGui, 88, 12, 16, "", inputCallback)
userLevelLabel = gui.newLabel(myGui, 88, 14, "")
LevelUpButton = gui.newButton(myGui, 92, 14, "+", levelUpCallback)
LevelDownButton = gui.newButton(myGui, 96, 14, "-", levelDownCallback)
MTFYesButton = gui.newButton(myGui, 88, 16, "yes", mtfYesUserCallback)
MTFNoButton = gui.newButton(myGui, 96, 16, "no", mtfNoUserCallback)
GOIYesButton = gui.newButton(myGui, 88, 18, "yes", goiYesUserCallback)
GOINoButton = gui.newButton(myGui, 96, 18, "no", goiNoUserCallback)
SecYesButton = gui.newButton(myGui, 88, 20, "yes", secYesUserCallback)
SecNoButton = gui.newButton(myGui, 96, 20, "no", secNoUserCallback)
IntYesButton = gui.newButton(myGui, 88, 22, "yes", intYesUserCallback)
IntNoButton = gui.newButton(myGui, 96, 22, "no", intNoUserCallback)
StaffYesButton = gui.newButton(myGui, 88, 24, "yes", staffYesUserCallback)
StaffNoButton = gui.newButton(myGui, 96, 24, "no", staffNoUserCallback)
userArmoryLabel = gui.newLabel(myGui, 88, 26, "")
ArmoryUpButton = gui.newButton(myGui, 92, 26, "+", armorUpCallback)
ArmoryDownButton = gui.newButton(myGui, 96, 26, "-", armorDownCallback)
userDepLabel = gui.newLabel(myGui, 88, 28, "")
DepUpButton = gui.newButton(myGui, 92, 28, "+", depUpCallback)
DepDownButton = gui.newButton(myGui, 96, 28, "-", depDownCallback)
cardBlockedYesButton = gui.newButton(myGui, 88, 30, "yes", blockUserCallback)
cardBlockedNoButton = gui.newButton(myGui, 96, 30, "no", unblockUserCallback)
gui.setEnable(myGui, cardBlockedYesButton, false)
gui.setEnable(myGui, cardBlockedNoButton, false)
gui.setEnable(myGui, MTFYesButton, false)
gui.setEnable(myGui, MTFNoButton, false)
gui.setEnable(myGui, GOIYesButton, false)
gui.setEnable(myGui, GOINoButton, false)
gui.setEnable(myGui, SecYesButton, false)
gui.setEnable(myGui, SecNoButton, false)
gui.setEnable(myGui, IntYesButton, false)
gui.setEnable(myGui, IntNoButton, false)
gui.setEnable(myGui, StaffYesButton, false)
gui.setEnable(myGui, StaffNoButton, false)
gui.setEnable(myGui, LevelUpButton, false)
gui.setEnable(myGui, LevelDownButton, false)
gui.setEnable(myGui, ArmoryUpButton, false)
gui.setEnable(myGui, ArmoryDownButton, false)
gui.setEnable(myGui, DepUpButton, false)
gui.setEnable(myGui, DepDownButton, false)
gui.setEnable(myGui, userNameText, false)

gui.newHLine(myGui, 64, 36, 86)
userNewButton = gui.newButton(myGui, 4, 42, "new", newUserCallback)
userDeleteButton = gui.newButton(myGui, 18, 42, "delete", deleteUserCallback)
userResetUUIDButton = gui.newButton(myGui, 32, 42, "reset uuid", changeUUID)

-- frame with status of the writer
gui.newFrame(myGui, 114, 2, 38, 6, "Writer status")
cardStatusLabel = gui.newLabel(myGui, 116, 4, "     No card   ")

--updateServerButton = gui.newButton(myGui, 47, 21, "update server", updateServerCallback)

cardWriteButton = gui.newButton(myGui, 128, 42, "write card", writeCardCallback)


gui.clearScreen()
gui.setTop(prgName .. " " .. version)

event.listen("cardInsert", eventCallback)
event.listen("cardRemove", eventCallback)
while true do
  gui.runGui(myGui)
end