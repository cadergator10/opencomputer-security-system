local versionMajor = "2"
local versionMinor = "5"


local component = require("component")
local gpu = component.gpu
local event = require("event")
local ser = require("serialization")
local computer = require("computer")

local screenWidth, screenHeight = gpu.getResolution()

local gui = {}

local colorScreenBackground = 0xC0C0C0
local colorScreenForeground = 0x000000
local colorTopLineBackground = 0x0000FF
local colorTopLineForeground = 0xFFFFFF
local colorBottomLineBackground = 0x0000FF
local colorBottomLineForeground = 0xFFFFFF
local colorFrameBackground = 0xC0C0C0
local colorFrameForeground = 0x000000
local colorButtonBackground = 0x0000FF
local colorButtonForeground = 0xFFFFFF
local colorButtonClickedBackground = 0x00FF00
local colorButtonClickedForeground = 0xFFFFFF
local colorButtonDisabledBackground = 0x000000
local colorButtonDisabledForeground = 0xFFFFFF
local colorTextBackground = 0x000000
local colorTextForeground = 0xFFFF00
local colorInputBackground = 0x0000FF
local colorInputForeground = 0xFFFFFF
local colorProgressBackground = 0x000000
local colorProgressForeground = 0x00FF00
local colorProgressNumberForeground = 0xFFFF00
local colorListBackground = 0x0000FF
local colorListForeground = 0xFFFFFF
local colorListActiveBackground = 0x00FF00
local colorListActiveForeground = 0xFFFF00
local colorListDisabledBackground = 0x000000
local colorListDisabledForeground = 0xFFFF00
local colorVProgressBackground = 0x000000
local colorVProgressForeground = 0x00FF00
local colorVSliderBackground = 0x000000
local colorVSliderForeground = 0x00FF00
local colorChartBackground = 0x000000
local colorChartForeground = 0x00FF00

local displayed = false


function gui.Version()
  return versionMajor .. "." .. versionMinor, versionMajor, versionMinor
end

function gui.checkVersion(major, minor)
  if major > tonumber(versionMajor) then
    compGui = gui.newGui("center", "center", 40, 9, true, nil, 0xFF0000, 0xFFFF00)
    gui.displayGui(compGui)
    gui.newLabel(compGui, "center", 1, "!Wrong Gui version!")
    gui.newLabel(compGui, "center", 3, string.format("Need version %d.%d",major, minor))
    gui.newLabel(compGui, "center", 5, string.format("Installed version is v %d.%d",versionMajor, versionMinor))
    gui.newHLine(compGui, 1, 6, 38)
    gui.newButton(compGui, "center", 7, "exit", gui.exit)
    while true do
      gui.runGui(compGui)
    end
  else
    if minor > tonumber(versionMinor) then
      compGui = gui.newGui("center", "center", 40, 9, true, nil, 0xFF0000, 0xFFFF00)
      gui.displayGui(compGui)
      gui.newLabel(compGui, "center", 1, "!Wrong Gui version!")
      gui.newLabel(compGui, "center", 3, string.format("Need version %d.%d",major, minor))
      gui.newLabel(compGui, "center", 5, string.format("Installed version is v %d.%d",versionMajor, versionMinor))
      gui.newHLine(compGui, 1, 6, 38)
      gui.newButton(compGui, "center", 7, "exit", gui.exit)
      while true do
	gui.runGui(compGui)
      end
    end
  end
end

function gui.clearScreen()
  gpu.setBackground(colorScreenBackground)
  gpu.setForeground(colorScreenForeground)
  gpu.fill(1, 1, screenWidth, screenHeight, " ")

  gpu.setBackground(colorTopLineBackground)
  gpu.setForeground(colorTopLineForeground)
  gpu.fill(1, 1, screenWidth, 1, " ")
  
  gpu.setBackground(colorBottomLineBackground)
  gpu.setForeground(colorBottomLineForeground)
  gpu.fill(1, screenHeight, screenWidth, 1, " ")
end

function gui.setTop(text)
  gpu.setBackground(colorTopLineBackground)
  gpu.setForeground(colorTopLineForeground)
  gpu.set( (screenWidth / 2) - (string.len(text) / 2), 1, text)
end

function gui.setBottom(text)
  gpu.setBackground(colorBottomLineBackground)
  gpu.setForeground(colorBottomLineForeground)
  gpu.set( (screenWidth / 2) - (string.len(text) / 2), screenHeight, text)
end

local function saveBackground(x,y,w,h)
  local buffer = {}
  for i = x,x + w do
    for j = y,y + h do
      local ch,fc,bc = gpu.get(i,j)
      local tmp = {i,j,ch,fc,bc}
      table.insert(buffer, tmp)
    end
  end
  return buffer
end


local function restoreBackground(buff)
  for k,v in pairs(buff) do
    gpu.setBackground(v[5])
    gpu.setForeground(v[4])
    gpu.set(v[1], v[2], v[3])
  end
end

function gui.closeGui(guiID)
--  print("restoring" .. guiID.num)
--  os.sleep(1)
  restoreBackground(guiID.buffer)
  guiID.new = true
end


-- displays the gui frame, if set or just clears the display area
local function _displayFrame(guiID)
  if guiID.new == true then
--    print("saving" .. guiID.num)
    guiID.buffer = saveBackground(guiID.x, guiID.y, guiID.width, guiID.height)
    guiID.new = false
--    os.sleep(1)
  end
  gpu.setBackground(guiID.bg)
  gpu.setForeground(guiID.fg)
  gpu.fill(guiID.x, guiID.y, guiID.width, guiID.height, " ")
  if guiID.frame == true then
    gpu.fill(guiID.x, guiID.y, 1, guiID.height, "║")
    gpu.fill(guiID.x + guiID.width - 1, guiID.y, 1, guiID.height, "║")
    gpu.fill(guiID.x, guiID.y, guiID.width, 1, "═")
    gpu.fill(guiID.x, guiID.y + guiID.height - 1, guiID.width, 1, "═")
    gpu.set(guiID.x, guiID.y, "╔")
    gpu.set(guiID.x + guiID.width - 1 , guiID.y, "╗")
    gpu.set(guiID.x, guiID.y + guiID.height - 1 , "╚")
    gpu.set(guiID.x + guiID.width - 1 , guiID.y + guiID.height - 1, "╝")
    if guiID.text then
      gpu.set(guiID.x + math.floor((guiID.width/2)) - math.floor((string.len(guiID.text)/2)), guiID.y, guiID.text)
    end
  end
end

-- displays a frame
local function _displayAFrame(guiID, frameID)
  if guiID[frameID].visible == true then
    gpu.setBackground(guiID.bg)
    gpu.setForeground(guiID.fg)
    gpu.fill(guiID[frameID].x, guiID[frameID].y, 1, guiID[frameID].height, "║")
    gpu.fill(guiID[frameID].x + guiID[frameID].width - 1, guiID[frameID].y, 1, guiID[frameID].height, "║")
    gpu.fill(guiID[frameID].x, guiID[frameID].y, guiID[frameID].width, 1, "═")
    gpu.fill(guiID[frameID].x, guiID[frameID].y + guiID[frameID].height - 1, guiID[frameID].width, 1, "═")
    gpu.set(guiID[frameID].x, guiID[frameID].y, "╔")
    gpu.set(guiID[frameID].x + guiID[frameID].width - 1 , guiID[frameID].y, "╗")
    gpu.set(guiID[frameID].x, guiID[frameID].y + guiID[frameID].height - 1 , "╚")
    gpu.set(guiID[frameID].x + guiID[frameID].width - 1 , guiID[frameID].y + guiID[frameID].height - 1, "╝")
    if guiID[frameID].text then
      gpu.set(guiID[frameID].x + math.floor((guiID[frameID].width/2)) - math.floor((string.len(guiID[frameID].text)/2)+1), guiID[frameID].y, "╡" .. guiID[frameID].text .. "┝")
    end
  end
end

--display a horizontal line
local function _displayHLine(guiID, lineID)
  gpu.setBackground(guiID.bg)
  gpu.setForeground(guiID.fg)
  gpu.fill(guiID[lineID].x, guiID[lineID].y, guiID[lineID].width, 1, "═")
end

-- displays a checkbox
local function _displayCheckbox(guiID, checkboxID)
  if guiID[checkboxID].visible == true then
    gpu.setBackground(guiID.bg)
    gpu.setForeground(guiID.fg)
    local x = 0
    x =guiID.x + guiID[checkboxID].x
    if guiID[checkboxID].status == true then
      gpu.set(x, guiID[checkboxID].y, "[√]")
    else
      gpu.set(x, guiID[checkboxID].y, "[ ]")
    end
  end
end

-- displays a radio button
local function _displayRadio(guiID, radioID)
  if guiID[radioID].visible == true then
    gpu.setBackground(guiID.bg)
    gpu.setForeground(guiID.fg)
    local x = 0
    x =guiID.x + guiID[radioID].x
    if guiID[radioID].status == true then
      gpu.set(x, guiID[radioID].y, "(x)")
    else
      gpu.set(x, guiID[radioID].y, "( )")
    end
  end
end

-- displays a label
local function _displayLabel(guiID, labelID)
  if guiID[labelID].visible == true then
    gpu.setBackground(guiID[labelID].bg)
    gpu.setForeground(guiID[labelID].fg)
    local x = 0
    if guiID[labelID].x == "center" then
      x = guiID.x + math.floor((guiID.width / 2)) - math.floor((string.len(guiID[labelID].text)) / 2)
    else
      x =guiID.x + guiID[labelID].x
    end
    gpu.fill(x, guiID[labelID].y, guiID[labelID].l , 1, " ")
    gpu.set(x, guiID[labelID].y, guiID[labelID].text)
  end
end

-- displays a time label
local function _displayTimeLabel(guiID, labelID)
  if guiID[labelID].visible == true then
    gpu.setBackground(guiID[labelID].bg)
    gpu.setForeground(guiID[labelID].fg)
    local x = guiID.x + guiID[labelID].x
    gpu.set(x, guiID[labelID].y, os.date("%H:%M", os.time()))
  end
end

-- displays a date label
local function _displayDateLabel(guiID, labelID)
  if guiID[labelID].visible == true then
    gpu.setBackground(guiID[labelID].bg)
    gpu.setForeground(guiID[labelID].fg)
    local x = guiID.x + guiID[labelID].x
    if guiID[labelID].frm == false then
      gpu.set(x, guiID[labelID].y, os.date("%d/%m/%Y"))
    elseif guiID[labelID].frm == true then
      gpu.set(x, guiID[labelID].y, os.date("%A %d. %B %Y"))
    end
  end
end

local function splitWords(Lines, limit)
    while #Lines[#Lines] > limit do
        Lines[#Lines+1] = Lines[#Lines]:sub(limit+1)
        Lines[#Lines-1] = Lines[#Lines-1]:sub(1,limit)
    end
end

local function wrap(str, limit)
    local Lines, here, limit, found = {}, 1, limit or 72, str:find("(%s+)()(%S+)()")

    if found then
        Lines[1] = string.sub(str,1,found-1)  -- Put the first word of the string in the first index of the table.
    else Lines[1] = str end

    str:gsub("(%s+)()(%S+)()",
        function(sp, st, word, fi)  -- Function gets called once for every space found.
            splitWords(Lines, limit)

            if fi-here > limit then
                here = st
                Lines[#Lines+1] = word                                             -- If at the end of a line, start a new table index...
            else Lines[#Lines] = Lines[#Lines].." "..word end  -- ... otherwise add to the current table index.
        end)

    splitWords(Lines, limit)

    return Lines
end

-- displays a multi line label
local function _displayMultiLineLabel(guiID, labelID)
  if guiID[labelID].visible == true then
    gpu.setBackground(guiID[labelID].bg)
    gpu.setForeground(guiID[labelID].fg)
    gpu.fill(guiID[labelID].x, guiID[labelID].y, guiID[labelID].w, guiID[labelID].h, " ")
    local text = wrap(guiID[labelID].text, guiID[labelID].w)
    for i = 1, #text do
      gpu.set(guiID[labelID].x, guiID[labelID].y + i, text[i])
    end
  end
end

-- displays a button
local function _displayButton(guiID, buttonID)
  if guiID[buttonID].visible == true then
    if guiID[buttonID].active == true then
      gpu.setBackground(colorButtonClickedBackground)
      gpu.setForeground(colorButtonClickedForeground)
    elseif guiID[buttonID].enabled == false then
      gpu.setBackground(colorButtonDisabledBackground)
      gpu.setForeground(colorButtonDisabledForeground)
    else
      gpu.setBackground(colorButtonBackground)
      gpu.setForeground(colorButtonForeground)
    end
    local x = 0
    if guiID[buttonID].x == "center" then
      x = guiID.x + math.floor((guiID.width / 2)) - math.floor((guiID[buttonID].lenght / 2))
    else
      x = guiID.x + guiID[buttonID].x
    end
    gpu.fill(x, guiID[buttonID].y, guiID[buttonID].lenght, 1, " ")
    gpu.set(x, guiID[buttonID].y, guiID[buttonID].text)
  end
end

-- displays a text
local function _displayText(guiID, textID)
  if guiID[textID].visible == true then
    gpu.setBackground(colorTextBackground)
    gpu.setForeground(colorTextForeground)
    local x = 0
    if guiID[textID].x == "center" then
      x = guiID.x + math.floor((guiID.width / 2)) - math.floor((guiID[textID].fieldLenght) / 2)
    else
      x = guiID.x + guiID[textID].x
    end
    gpu.fill(x, guiID[textID].y , guiID[textID].fieldLenght, 1, " ")
    tmpStr = guiID[textID].text
    if guiID[textID].hide == true then
      tmpStr = ""
      for i = 1, string.len(guiID[textID].text) do
	tmpStr = tmpStr .."*"
      end
    end
    gpu.set(x, guiID[textID].y, string.sub(tmpStr, 1, guiID[textID].fieldLenght))
  end
end

-- displays a vertical slider
local function _displayVslider(guiID, sliderID)
  if guiID[sliderID].visible == true then
    gpu.setBackground(colorVSliderBackground)
    gpu.setForeground(colorVSliderForeground)
    local x = 0
    x = guiID.x + guiID[sliderID].x
    gpu.fill(x, guiID[sliderID].y , guiID[sliderID].lenght + 2, 1, " ")
    gpu.setBackground(colorButtonBackground)
    gpu.setForeground(colorButtonForeground)
    gpu.set(x, guiID[sliderID].y, "-")
    gpu.set(x + guiID[sliderID].lenght + 1, guiID[sliderID].y, "+")
    x = x + 1
    local proz = math.floor(100 / guiID[sliderID].max * guiID[sliderID].value)
    if proz > 100 then
      proz = 100
      if guiID[sliderID].func then
	guiID[sliderID].func(guiID, sliderID)
      end
    end
    local pos = math.floor(guiID[sliderID].lenght / 100 * proz)
    gpu.setBackground(colorVSliderForeground)
    gpu.setForeground(colorVSliderBackground)
    gpu.fill(x, guiID[sliderID].y , pos, 1, " ")
    gpu.setBackground(colorVSliderBackground)
    gpu.setForeground(colorVSliderForeground)
    gpu.fill(x + pos, guiID[sliderID].y , guiID[sliderID].lenght - pos, 1, " ")
  end
end

-- displays a progress bar
local function _displayProgress(guiID, progressID)
  if guiID[progressID].visible == true then
    gpu.setBackground(colorProgressForeground)
    gpu.setForeground(colorProgressBackground)
    local x = 0
    if guiID[progressID].x == "center" then
      x = guiID.x + math.floor((guiID.width / 2)) - math.floor((guiID[progressID].lenght) / 2)
    else
      x = guiID.x + guiID[progressID].x
    end
    local proz = math.floor(100 / guiID[progressID].max * guiID[progressID].value)
    if proz > 100 then
      proz = 100
      if guiID[progressID].finished == false and guiID[progressID].func then
	guiID[progressID].func(guiID, progressID)
      end
      guiID[progressID].finished = true
    end
    local pos = math.floor(guiID[progressID].lenght / 100 * proz)
    gpu.fill(x, guiID[progressID].y , pos, 1, " ")
    gpu.setBackground(colorProgressBackground)
    gpu.setForeground(colorProgressForeground)
    gpu.fill(x + pos, guiID[progressID].y , guiID[progressID].lenght - pos, 1, " ")
    gpu.setBackground(guiID.bg)
    gpu.setForeground(guiID.fg)
    if guiID[progressID].displayNumber == true then
      gpu.fill(x, guiID[progressID].y - 1, guiID[progressID].lenght, 1, " ")
      gpu.set(x + (math.floor(guiID[progressID].lenght / 2)) - 1, guiID[progressID].y - 1, proz .. "%")
    end
  end
end

-- displays a vertical progress bar
local function _displayVProgress(guiID, progressID)
  if guiID[progressID].visible == true then
    local x = 0
    if guiID[progressID].x == "center" then
      x = guiID.x + math.floor((guiID.width / 2)) - math.floor((guiID[progressID].lenght) / 2)
    else
      x = guiID.x + guiID[progressID].x
    end
    local proz = math.floor(100 / guiID[progressID].max * guiID[progressID].value)
    if proz > 100 then
      proz = 100
      if guiID[progressID].finished == false and guiID[progressID].func then
	guiID[progressID].func(guiID, progressID)
      end
      guiID[progressID].finished = true
    end
    local pos = math.floor(guiID[progressID].lenght / 100 * proz)
    for i = 1, guiID[progressID].width do
      if guiID[progressID].direction == 0 then
	gpu.setBackground(colorProgressForeground)
	gpu.setForeground(colorProgressBackground)
	gpu.fill(x+i-1, guiID[progressID].y , 1, pos, " ")
	gpu.setBackground(colorProgressBackground)
	gpu.setForeground(colorProgressForeground)
	gpu.fill(x+i-1, guiID[progressID].y + pos, 1, guiID[progressID].lenght - pos, " ")
      end
      if guiID[progressID].direction == 1 then
	gpu.setBackground(colorProgressBackground)
	gpu.setForeground(colorProgressForeground)
	gpu.fill(x+i-1, guiID[progressID].y, 1, guiID[progressID].lenght, " ")
	gpu.setBackground(colorProgressForeground)
	gpu.setForeground(colorProgressBackground)
	gpu.fill(x+i-1, guiID[progressID].y + guiID[progressID].lenght - pos , 1, pos, " ")
      end
    end
  end
end

-- display list
local function _displayList(guiID, listID)
  if guiID[listID].visible == true then
    if guiID[listID].enabled == true then
      gpu.setBackground(colorListBackground)
      gpu.setForeground(colorListForeground)
    else
      gpu.setBackground(colorListDisabledBackground)
      gpu.setForeground(colorListDisabledForeground)
    end
    gpu.fill(guiID[listID].x, guiID[listID].y, guiID[listID].width, guiID[listID].height, " ")
    gpu.fill(guiID[listID].x, guiID[listID].y, guiID[listID].width, 1, "═")
    if guiID[listID].text then
      gpu.set( guiID[listID].x + (guiID[listID].width/2) - (string.len(guiID[listID].text)/2), guiID[listID].y, "╡" .. guiID[listID].text .. "┝")
    end
    if guiID[listID].active + guiID[listID].height - 3 > #guiID[listID].entries then
      l = #guiID[listID].entries
    else
      l = guiID[listID].active + guiID[listID].height - 3
    end
    gpu.fill(guiID[listID].x, guiID[listID].y +guiID[listID].height - 1, guiID[listID].width, 1, "═")
    gpu.set(guiID[listID].x, guiID[listID].y + guiID[listID].height - 1, "[<]")
    gpu.set(guiID[listID].x + guiID[listID].width - 3, guiID[listID].y + guiID[listID].height - 1, "[>]")
    for v = guiID[listID].active, l  do
      if v == guiID[listID].selected then
	gpu.setBackground(colorListActiveBackground)
	gpu.setForeground(colorListActiveForeground)
      else
	if guiID[listID].enabled == true then
	  gpu.setBackground(colorListBackground)
	  gpu.setForeground(colorListForeground)
	else
	  gpu.setBackground(colorListDisabledBackground)
	  gpu.setForeground(colorListDisabledForeground)
	end
      end
      gpu.fill(guiID[listID].x, guiID[listID].y + v - guiID[listID].active + 1, guiID[listID].width, 1 , " ")
      gpu.set(guiID[listID].x + 1, guiID[listID].y + v - guiID[listID].active + 1, guiID[listID].entries[v] )
    end
  end
end

-- displays a chart
local function _displayChart(guiID, chartID)
  if guiID[chartID].visible == true then
    gpu.setBackground(colorChartBackground)
    gpu.setForeground(colorChartForeground)
    for x = 1, #guiID[chartID].data do
	local proz = math.floor(100 / guiID[chartID].max * guiID[chartID].data[x])
	local dotPos = guiID[chartID].height - math.floor( guiID[chartID].height / guiID[chartID].max * guiID[chartID].data[x])
	for y = 1, guiID[chartID].height do
	  if dotPos == y then
	    gpu.setBackground(colorChartForeground)
	  else
	    gpu.setBackground(colorChartBackground)
	  end
	  gpu.set(x + guiID[chartID].x, y + guiID[chartID].y, " ")
	  
	end
    end
  end
end

-- display the gui and all widgets
function gui.displayGui(guiID)

  _displayFrame(guiID)
  
  for i = 1, #guiID do
    if guiID[i].type == "label" then
      _displayLabel(guiID, i)
    elseif guiID[i].type == "multiLineLabel" then
      _displayMultiLineLabel(guiID, i)
    elseif guiID[i].type == "button" then
      _displayButton(guiID, i)
    elseif guiID[i].type == "text" then
      _displayText(guiID, i)
    elseif guiID[i].type == "progress" then
      _displayProgress(guiID, i)
    elseif guiID[i].type == "vprogress" then
      _displayVProgress(guiID, i)
    elseif guiID[i].type == "list" then
      _displayList(guiID, i)
    elseif guiID[i].type == "frame" then
      _displayAFrame(guiID, i)
    elseif guiID[i].type == "hline" then
      _displayHLine(guiID, i)
    elseif guiID[i].type == "checkbox" then
      _displayCheckbox(guiID, i)
    elseif guiID[i].type == "radio" then
      _displayRadio(guiID, i)
    elseif guiID[i].type == "vslider" then
      _displayVslider(guiID, i)
    elseif guiID[i].type == "chart" then
      _displayChart(guiID, i)
    end
  end
end

function gui.displayWidget(guiID, widgetID)

    if guiID[widgetID].type == "label" then
      _displayLabel(guiID, widgetID)
    elseif guiID[widgetID].type == "multiLineLabel" then
      _displayMultiLineLabel(guiID, widgetID)
    elseif guiID[widgetID].type == "button" then
      _displayButton(guiID, widgetID)
    elseif guiID[widgetID].type == "text" then
      _displayText(guiID, widgetID)
    elseif guiID[widgetID].type == "progress" then
      _displayProgress(guiID, widgetID)
    elseif guiID[widgetID].type == "vprogress" then
      _displayVProgress(guiID, widgetID)
    elseif guiID[widgetID].type == "list" then
      _displayList(guiID, widgetID)
    elseif guiID[widgetID].type == "frame" then
      _displayAFrame(guiID, widgetID)
    elseif guiID[widgetID].type == "hline" then
      _displayHLine(guiID, widgetID)
    elseif guiID[widgetID].type == "checkbox" then
      _displayCheckbox(guiID, widgetID)
    elseif guiID[widgetID].type == "radio" then
      _displayRadio(guiID, widgetID)
    elseif guiID[widgetID].type == "vslider" then
      _displayVslider(guiID, widgetID)
    elseif guiID[widgetID].type == "chart" then
      _displayChart(guiID, widgetID)
    end
end

function gui.exit()
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  gpu.fill(1, 1, screenWidth, screenHeight, " ")
  os.exit()
end

local guiCounter = 0
-- need to be called first to setup a new dialog
function gui.newGui(x, y, w, h, frame, text, bg, fg)
  local tmpTable = {}
  tmpTable["type"] = "gui"
  if x == "center" then
    tmpTable["x"] = math.floor((screenWidth / 2) - (w / 2))
  else
    tmpTable["x"] = x
  end
  if y == "center" then
    tmpTable["y"] = math.floor((screenHeight / 2) - (h / 2))
  else
    tmpTable["y"] = y
  end
  tmpTable["bg"] = bg or colorFrameBackground
  tmpTable["fg"] = fg or colorFrameForeground
  tmpTable["width"] = w
  tmpTable["height"] = h
  tmpTable["frame"] = frame
  if text then
    tmpTable["text"] = "╡" .. text .. "┝"
  end
  tmpTable["buffer"] = {}
  tmpTable["num"] = guiCounter
  guiCounter = guiCounter + 1
  tmpTable["new"] = true
  displayed = false
  return tmpTable
end

-- checkbox
function gui.newCheckbox(guiID, x, y, status, func)
  local tmpTable = {}
  tmpTable["type"] = "checkbox"
  tmpTable["status"] = status or false
  tmpTable["y"] = y + guiID.y
  tmpTable["visible"] = true
  tmpTable["enabled"] = true
  tmpTable["x"] = x
  tmpTable["func"] = func
  table.insert(guiID, tmpTable)
  return #guiID
end

-- radio button
function gui.newRadio(guiID, x, y, func)
  local tmpTable = {}
  tmpTable["type"] = "radio"
  tmpTable["status"] = false
  tmpTable["y"] = y + guiID.y
  tmpTable["visible"] = true
  tmpTable["enabled"] = true
  tmpTable["x"] = x
  tmpTable["func"] = func
  table.insert(guiID, tmpTable)
  return #guiID
end

-- label
function gui.newLabel(guiID, x, y, text, bg, fg, l)
  local tmpTable = {}
  tmpTable["type"] = "label"
  tmpTable["y"] = y + guiID.y
  tmpTable["text"] = text
  tmpTable["lenght"] = string.len(text)
  tmpTable["bg"] = bg or guiID.bg
  tmpTable["fg"] = fg or guiID.fg
  tmpTable["visible"] = true
  tmpTable["x"] = x
  tmpTable["l"] = l or string.len(text)
  table.insert(guiID, tmpTable)
  return #guiID
end

-- time label
function gui.newTimeLabel(guiID, x, y, bg, fg)
  local tmpTable = {}
  tmpTable["type"] = "timelabel"
  tmpTable["y"] = y + guiID.y
  tmpTable["bg"] = bg or guiID.bg
  tmpTable["fg"] = fg or guiID.fg
  tmpTable["visible"] = true
  tmpTable["x"] = x
  table.insert(guiID, tmpTable)
  return #guiID
end

-- date label
function gui.newDateLabel(guiID, x, y, bg, fg, frm)
  local tmpTable = {}
  tmpTable["type"] = "datelabel"
  tmpTable["y"] = y + guiID.y
  tmpTable["bg"] = bg or guiID.bg
  tmpTable["fg"] = fg or guiID.fg
  tmpTable["visible"] = true
  tmpTable["x"] = x
  tmpTable["frm"] = frm or false
  table.insert(guiID, tmpTable)
  return #guiID
end

-- multi line label
function gui.newMultiLineLabel(guiID, x, y, w, h, text, bg, fg)
  local tmpTable = {}
  tmpTable["type"] = "multiLineLabel"
  tmpTable["y"] = y + guiID.y
  tmpTable["text"] = text
  tmpTable["bg"] = bg or guiID.bg
  tmpTable["fg"] = fg or guiID.fg
  tmpTable["visible"] = true
  tmpTable["x"] = x + guiID.x
  tmpTable["w"] = w
  tmpTable["h"] = h
  table.insert(guiID, tmpTable)
  return #guiID
end

-- button
function gui.newButton(guiID, x, y, text, func)
  local tmpTable = {}
  tmpTable["type"] = "button"
  tmpTable["y"] = y + guiID.y
  tmpTable["text"] = "[" .. text .. "]"
  tmpTable["lenght"] = string.len(tmpTable.text)
  tmpTable["visible"] = true
  tmpTable["enabled"] = true
  tmpTable["active"] = false
  tmpTable["func"] = func
  tmpTable["x"] = x
  table.insert(guiID, tmpTable)
  return #guiID
end

-- text input field
function gui.newText(guiID, x, y, lenght, text, func, fieldLenght, hide)
  local tmpTable = {}
  tmpTable["type"] = "text"
  tmpTable["x"] = x
  tmpTable["y"] = y + guiID.y
  tmpTable["text"] = text
  tmpTable["lenght"] = lenght
  tmpTable["visible"] = true
  tmpTable["enabled"] = true
  tmpTable["func"] = func
  if fieldLenght then
    tmpTable["fieldLenght"] = fieldLenght
  else
    tmpTable["fieldLenght"] = lenght
  end
  table.insert(guiID, tmpTable)
  tmpTable["hide"] = hide or false
  return #guiID
end

-- progressbar
function gui.newProgress(guiID, x, y, lenght, maxValue, value, func, number)
  local tmpTable = {}
  tmpTable["type"] = "progress"
  tmpTable["x"] = x
  tmpTable["y"] = y + guiID.y
  tmpTable["lenght"] = lenght
  tmpTable["visible"] = true
  tmpTable["enabled"] = true
  tmpTable["max"] = maxValue
  tmpTable["value"] = value
  tmpTable["func"] = func
  tmpTable["finished"] = false
  tmpTable["displayNumber"] = number or false
  table.insert(guiID, tmpTable)
  return #guiID
end

-- vertical progress
function gui.newVProgress(guiID, x, y, lenght, width, maxValue, value, func, direction)
  local tmpTable = {}
  tmpTable["type"] = "vprogress"
  tmpTable["x"] = x
  tmpTable["y"] = y + guiID.y
  tmpTable["lenght"] = lenght
  tmpTable["width"] = width
  tmpTable["visible"] = true
  tmpTable["enabled"] = true
  tmpTable["max"] = maxValue
  tmpTable["value"] = value
  tmpTable["func"] = func
  tmpTable["direction"] = direction or 0
  tmpTable["finished"] = false
  table.insert(guiID, tmpTable)
  return #guiID
end

-- vertical slider
function gui.newVSlider(guiID, x, y, lenght, min, max, value, func)
  local tmpTable = {}
  tmpTable["type"] = "vslider"
  tmpTable["x"] = x
  tmpTable["y"] = y + guiID.y
  tmpTable["lenght"] = lenght
  tmpTable["visible"] = true
  tmpTable["enabled"] = true
  tmpTable["min"] = min
  tmpTable["max"] = max
  tmpTable["value"] = value
  tmpTable["func"] = func
  table.insert(guiID, tmpTable)
  return #guiID
end

-- list
function gui.newList(guiID, x, y, width, height, tab, func, text)
  local tmpTable = {}
  tmpTable["type"] = "list"
  tmpTable["x"] = x + guiID.x
  tmpTable["y"] = y + guiID.y
  tmpTable["width"] = width
  tmpTable["height"] = height
  tmpTable["visible"] = true
  tmpTable["enabled"] = true
  tmpTable["func"] = func
  tmpTable["selected"] = 1
  tmpTable["active"] = 1
  tmpTable["entries"] = tab
  tmpTable["text"] = text
  table.insert(guiID, tmpTable)
  return #guiID
end

--frame
function gui.newFrame(guiID, x, y, width, height, text)
  local tmpTable = {}
  tmpTable["type"] = "frame"
  tmpTable["x"] = x + guiID.x
  tmpTable["y"] = y + guiID.y
  tmpTable["width"] = width
  tmpTable["height"] = height
  tmpTable["visible"] = true
  tmpTable["enabled"] = true
  tmpTable["text"] = text
  table.insert(guiID, tmpTable)
  return #guiID
end

-- hline
function gui.newHLine(guiID, x, y, width)
  local tmpTable = {}
  tmpTable["type"] = "hline"
  tmpTable["x"] = x + guiID.x
  tmpTable["y"] = y + guiID.y
  tmpTable["width"] = width
  tmpTable["visible"] = true
  tmpTable["enabled"] = true
  table.insert(guiID, tmpTable)
  return #guiID
end

-- chart
function gui.newChart(guiID, x, y, minValue, maxValue, data, lenght, height, bg, fg)
  local tmpTable = {}
  tmpTable["type"] = "chart"
  tmpTable["y"] = y + guiID.y
  tmpTable["lenght"] = lenght
  tmpTable["height"] = height
  tmpTable["bg"] = bg or guiID.bg
  tmpTable["fg"] = fg or guiID.fg
  tmpTable["visible"] = true
  tmpTable["x"] = x + guiID.x
  tmpTable["data"] = data
  tmpTable["min"] = minValue
  tmpTable["max"] = maxValue
  table.insert(guiID, tmpTable)
  return #guiID
end

function gui.getSelected(guiID, listID)
  return guiID[listID].selected, guiID[listID].entries[guiID[listID].selected]
end

function gui.setSelected(guiID, listID, selection)
  if selection<= #guiID[listID].entries then
    guiID[listID].selected = selection
    _displayList(guiID, listID)
  end
end

function gui.setMax(guiID, widgetID, maxValue)
  guiID[widgetID].max = maxValue
  _displayProgress(guiID, widgetID)
end

function gui.setChartData(guiID, chartID, data)
  guiID[chartID].data = data
  _displayChart(guiID, chartID)
end

function gui.setValue(guiID, widgetID, value)
  guiID[widgetID].value = value
  if guiID[widgetID].type == "progress" then
    _displayProgress(guiID, widgetID)
  end
  if guiID[widgetID].type == "vprogress" then
    _displayVProgress(guiID, widgetID)
  end
  if guiID[widgetID].type == "vslider" then
    _displayVslider(guiID, widgetID)
  end
end

function gui.resetProgress(guiID, progressID)
  guiID[progressID].finished = false
  _displayProgress(guiID, progressID)
end

-- sets the text of a widget
function gui.setText(guiID, widgetID, text, refresh)
  guiID[widgetID].text = text
  if guiID[widgetID].type == "text" then
    if refresh == nil or refresh == true then
      _displayText(guiID, widgetID)
    end
  end
  if guiID[widgetID].type == "label" then
    if refresh == nil or refresh == true then
      _displayLabel(guiID, widgetID)
    end
  end
  if guiID[widgetID].type == "multiLineLabel" then
    if refresh == nil or refresh == true then
      _displayMultiLineLabel(guiID, widgetID)
    end
  end
--  gui.displayGui(guiID)
end

function gui.getText(guiID, widgetID)
  return guiID[widgetID].text
end

function gui.getCheckboxStatus(guiID, widgetID)
  return guiID[widgetID].status
end

function gui.setEnable(guiID, widgetID, state, refresh)
  guiID[widgetID].enabled = state
  if refresh == nil then
    gui.displayGui(guiID)
  end
  if refresh == true then
    gui.displayWidget(guiID, widgetID)
  end
end

function gui.setPosition(guiID, widgetID, x, y, refresh)
  guiID[widgetID].x = x
  guiID[widgetID].y = y
  if refresh == nil then
    gui.displayGui(guiID)
  end
  if refresh == true then
    gui.displayWidget(guiID, widgetID)
  end
end

function gui.setSize(guiID, widgetID, w, h, refresh)
  guiID[widgetID].width = w
  guiID[widgetID].height = h
  guiID[widgetID].w = w
  guiID[widgetID].h = h
  guiID[widgetID].lenght = w
  if refresh == nil then
    gui.displayGui(guiID)
  end
  if refresh == true then
    gui.displayWidget(guiID, widgetID)
  end
end

function gui.setVisible(guiID, widgetID, state, refresh)
  if state == false then
    guiID[widgetID].visible = state
    guiID[widgetID].enabled = state
  elseif state == true then
    guiID[widgetID].visible = state
  end
  if refresh == nil then
    gui.displayGui(guiID)
  end
  if refresh == true then
    gui.displayWidget(guiID, widgetID)
  end
end

function gui.setBackground(guiID, widgetID, color)
  guiID[widgetID].bg = color
  if guiID[widgetID].type == "label" then
    _displayLabel(guiID, widgetID)
  end
end
function gui.setForeground(guiID, widgetID, color)
  guiID[widgetID].fg = color
  if guiID[widgetID].type == "label" then
    _displayLabel(guiID, widgetID)
  end
end

function gui.clearList(guiID, listID)
  guiID[listID].entries = {}
end

function gui.insertList(guiID, listID, value)
  table.insert(guiID[listID].entries, value)
  _displayList(guiID, listID)
end

function gui.removeList(guiID, listID, entry)
  table.remove(guiID[listID].entries, entry)
  _displayList(guiID, listID)
end

function gui.renameList(guiID, listID, entry, newName)
  guiID[listID].entries[entry] = newName
  _displayList(guiID, listID)
end

function gui.getRadio(guiID)
  for i = 1, #guiID do
    if guiID[i].type == "radio" then
      if guiID[i].status == true then
	return i
      end
    end
  end
  return -1
end

function gui.setRadio(guiID, radioID)
  for i = 1, #guiID do
    if guiID[i].type == "radio" then
      guiID[i].status = false 
    end
  end
  guiID[radioID].status = true
  return -1
end

function gui.setCheckbox(guiID, checkboxID, status)
  guiID[checkboxID].status = status
end

local function runInput(guiID, textID)
  local inputText = guiID[textID].text
  gpu.setBackground(colorInputBackground)
  gpu.setForeground(colorInputForeground)
  
  local x = 0
  if guiID[textID].x == "center" then
    x = guiID.x + math.floor((guiID.width / 2)) - math.floor((guiID[textID].fieldLenght) / 2)
  else
    x =guiID.x + guiID[textID].x
  end

  local loopRunning = true
  while loopRunning == true do
    gpu.fill(x, guiID[textID].y, guiID[textID].fieldLenght, 1, " ")
    tmpStr = inputText
    if guiID[textID].hide == true then
      tmpStr = ""
      for i = 1, string.len(inputText) do
	tmpStr = tmpStr .."*"
      end
    end
    if string.len(tmpStr) + 1 > guiID[textID].fieldLenght then
      tmpStr = string.sub(tmpStr, string.len(tmpStr) - guiID[textID].fieldLenght + 2, string.len(tmpStr))
    end
    gpu.set(x, guiID[textID].y, tmpStr .. "_")
    local e, _, character, code = event.pullMultiple(0.1, "key_down", "touch")
    if e == "key_down" then
      if character == 8 then	-- backspace
	inputText = string.sub(inputText, 1, string.len(inputText) - 1)
      elseif character == 13 then 	-- return
	guiID[textID].text = inputText
	if guiID[textID].func then
	  guiID[textID].func(guiID, textID, inputText)
	end
	loopRunning = false
      elseif character > 31 and character < 128 and string.len(inputText) < guiID[textID].lenght then
	inputText = inputText .. string.char(character)
      end
    elseif e == "touch" then
      if character < x or character > (x + guiID[textID].fieldLenght) or guiID[textID].y ~= code then
	guiID[textID].text = inputText
	_displayText(guiID, textID)
	if guiID[textID].func then
	  guiID[textID].func(guiID, textID, inputText)
	end
	loopRunning = false
	computer.pushSignal("touch", _, character, code)
      end
    end
  end
end


function gui.runGui(guiID)
  if displayed == false then
    displayed = true
    gui.displayGui(guiID)
  end

  -- events with out touch
  for i = 1, #guiID do
    if guiID[i].type == "timelabel" then
      _displayTimeLabel(guiID, i)
    elseif guiID[i].type == "datelabel" then
      _displayDateLabel(guiID, i)
    end
  end
  
  local ix = 0
  local e, _, x, y, button = event.pull(0.1, "touch")
  if e == nil then
    return false
  end
  for i = 1, #guiID do
    if guiID[i].type == "button" then
      if guiID[i].x == "center" then
	ix = guiID.x + math.floor((guiID.width / 2)) - math.floor((guiID[i].lenght / 2))
      else
	ix = guiID.x + guiID[i].x
      end
      if x >= ix and x < (ix + guiID[i].lenght) and guiID[i].y == y then
	if guiID[i].func and guiID[i].enabled == true then
	  guiID[i].active = true
	  gui.displayGui(guiID)
	  os.sleep(0.05)
	  guiID[i].active = false
	  gui.displayGui(guiID)
	  guiID[i].func(guiID, i)
	end
      end
    elseif guiID[i].type == "timelabel" then
      _displayTimeLabel(guiID, i)
    elseif guiID[i].type == "checkbox" then
      ix = guiID.x + guiID[i].x + 1
      if x == ix and guiID[i].y == y then
	if guiID[i].enabled == true then
	  if guiID[i].status == true then
	    guiID[i].status = false
	  else
	    guiID[i].status = true
	  end
	  if guiID[i].func then
	    guiID[i].func(guiID, i, guiID[i].status)
	  end
	  _displayCheckbox(guiID, i)
	end
      end
    elseif guiID[i].type == "radio" then
      ix = guiID.x + guiID[i].x + 1
      if x == ix and guiID[i].y == y then
	if guiID[i].enabled == true then
	  for c = 1, #guiID do
	    if guiID[c].type == "radio" then
	      guiID[c].status = false
	      if guiID[i].func then
		guiID[i].func(guiID, i, guiID[i].status)
	      end
	      _displayRadio(guiID, c)
	    end
	  end
	  guiID[i].status = true
	  if guiID[i].func then
	    guiID[i].func(guiID, i, guiID[i].status)
	  end
	  _displayRadio(guiID, i)
	end
      end
    elseif guiID[i].type == "text" then
      if guiID[i].x == "center" then
	ix = guiID.x + math.floor((guiID.width / 2)) - math.floor((guiID[i].lenght / 2))
      else
	ix = guiID.x + guiID[i].x
      end
      if x >= ix and x < (ix + guiID[i].fieldLenght) and guiID[i].y == y then
	if guiID[i].enabled == true then
	  runInput(guiID, i)
	end
      end
    elseif guiID[i].type == "list" and guiID[i].enabled == true then
      if x == guiID[i].x +1 and y == guiID[i].y + guiID[i].height - 1 then
	guiID[i].active = guiID[i].active - guiID[i].height + 2
	if guiID[i].active < 1 then
	  guiID[i].active = 1
	end
	gpu.setBackground(colorListActiveBackground)
	gpu.setForeground(colorListActiveForeground)
	gpu.set(guiID[i].x, guiID[i].y + guiID[i].height - 1, "[<]")
	guiID[i].selected = guiID[i].active
--	_displayList(guiID, i)

	if guiID[i].func then
	  gpu.setBackground(colorButtonClickedBackground)
	  gpu.setForeground(colorButtonClickedForeground)
	  gpu.set(guiID[i].x, guiID[i].y + guiID[i].height - 1, "[<]")
	  os.sleep(0.05)
	  gpu.setBackground(colorListBackground)
	  gpu.setForeground(colorListForeground)
	  gpu.set(guiID[i].x, guiID[i].y + guiID[i].height - 1, "[<]")
	  guiID[i].func(guiID, i, guiID[i].selected, guiID[i].entries[guiID[i].selected])
	end
      end
      if x == guiID[i].x + guiID[i].width - 2 and y == guiID[i].y + guiID[i].height - 1 then
	if guiID[i].active + guiID[i].height - 2 < #guiID[i].entries + 1 then
	  guiID[i].active = guiID[i].active + guiID[i].height - 2
	  guiID[i].selected = guiID[i].active
	end
	gpu.setBackground(colorListActiveBackground)
	gpu.setForeground(colorListActiveForeground)
	gpu.set(guiID[i].x + guiID[i].width - 3, guiID[i].y + guiID[i].height - 1, "[>]")
--	_displayList(guiID, i)
	
	if guiID[i].func then
	  gpu.setBackground(colorButtonClickedBackground)
	  gpu.setForeground(colorButtonClickedForeground)
	  gpu.set(guiID[i].x + guiID[i].width - 3, guiID[i].y + guiID[i].height - 1, "[>]")
	  os.sleep(0.05)
	  gpu.setBackground(colorListBackground)
	  gpu.setForeground(colorListForeground)
	  gpu.set(guiID[i].x + guiID[i].width - 3, guiID[i].y + guiID[i].height - 1, "[>]")
	  guiID[i].func(guiID, i, guiID[i].selected, guiID[i].entries[guiID[i].selected])
	end
      end
      if x > guiID[i].x - 1 and x < guiID[i].x + guiID[i].width and y > guiID[i].y and y < guiID[i].y + guiID[i].height - 1 then
	if guiID[i].active + y - guiID[i].y - 1 <= #guiID[i].entries then
	  guiID[i].selected = guiID[i].active + y - guiID[i].y - 1
--	  _displayList(guiID, i)
	  
	  if guiID[i].func then
	    guiID[i].func(guiID, i, guiID[i].selected, guiID[i].entries[guiID[i].selected])
	  end
	end
      end
	  _displayList(guiID, i)
    elseif guiID[i].type == "chart" and guiID[i].enabled == true then
      _displayChart(guiID, i)
    elseif guiID[i].type == "vslider" and guiID[i].enabled == true then
      ix = guiID.x + guiID[i].x
      if x == ix and y == guiID[i].y and guiID[i].value > guiID[i].min then
	v = guiID[i].value - 1
	gui.setValue(guiID, i, v)
      elseif x == ix + guiID[i].lenght and y == guiID[i].y and guiID[i].value < guiID[i].max then
	v = guiID[i].value + 1
	gui.setValue(guiID, i, v)
      end
      if guiID[i].func then
	guiID[i].func(guiID, i, guiID[i].value)
      end
      _displayVslider(guiID, i)
    end
  end
  
--  gui.displayGui(guiID)
end

errorGui = gui.newGui("center", "center", 40, 10, true, "ERROR", 0xFF0000, 0xFFFF00)
errorMsgLabel1 = gui.newLabel(errorGui, "center", 3, "")
errorMsgLabel2 = gui.newLabel(errorGui, "center", 4, "")
errorMsgLabel3 = gui.newLabel(errorGui, "center", 5, "")
errorButton = gui.newButton(errorGui, "center", 8, "exit", gui.exit)

function gui.showError(msg1, msg2, msg3)
  gui.displayGui(errorGui)
  gui.setText(errorGui, errorMsgLabel1, msg1 or "")
  gui.setText(errorGui, errorMsgLabel2, msg2 or "")
  gui.setText(errorGui, errorMsgLabel3, msg3 or "")
  while true do
    gui.runGui(errorGui)
  end
  gui.closeGui(errorGui)
end


function gui.checkHardware(comp, msg)
  if component.isAvailable(comp) == false then
    compGui = gui.newGui("center", "center", 40, 8, true, nil, 0xFF0000, 0xFFFF00)
    gui.displayGui(compGui)
    gui.newLabel(compGui, "center", 1, "!Component missing!")
    gui.newLabel(compGui, "center", 3, msg)
    gui.newHLine(compGui, 1, 5, 38)
    gui.newButton(compGui, "center", 6, "exit", gui.exit)
    while true do
      gui.runGui(compGui)
    end
  end
end


local msgRunning = true
function msgCallback()
  msgRunning = false
end

msgGui = gui.newGui("center", "center", 40, 10, true, "Info")
msgLabel1 = gui.newLabel(msgGui, "center", 3, "")
msgLabel2 = gui.newLabel(msgGui, "center", 4, "")
msgLabel3 = gui.newLabel(msgGui, "center", 5, "")
msgButton = gui.newButton(msgGui, "center", 8, "ok", msgCallback)

function gui.showMsg(msg1, msg2, msg3)
  gui.displayGui(msgGui)
  gui.setText(msgGui, msgLabel1, msg1 or "")
  gui.setText(msgGui, msgLabel2, msg2 or "")
  gui.setText(msgGui, msgLabel3, msg3 or "")
  msgRunning = true
  while msgRunning == true do
    gui.runGui(msgGui)
  end
  gui.closeGui(msgGui)
end


local yesNoRunning = true
local yesNoValue = false

local function yesNoCallbackYes()
  yesNoRunning = false
  yesNoValue = true
end
local function yesNoCallbackNo()
  yesNoRunning = false
  yesNoValue = false
end

yesNoGui = gui.newGui("center", "center", 40, 10, true, "Question")
yesNoMsgLabel1 = gui.newLabel(yesNoGui, "center", 3, "")
yesNoMsgLabel2 = gui.newLabel(yesNoGui, "center", 4, "")
yesNoMsgLabel3 = gui.newLabel(yesNoGui, "center", 5, "")
yesNoYesButton = gui.newButton(yesNoGui, 3, 8, "yes", yesNoCallbackYes)
yesNoNoButton = gui.newButton(yesNoGui, 33, 8, "no", yesNoCallbackNo)


function gui.getYesNo(msg1, msg2, msg3)
  yesNoRunning = true
  gui.displayGui(yesNoGui)
  gui.setText(yesNoGui, yesNoMsgLabel1, msg1 or "")
  gui.setText(yesNoGui, yesNoMsgLabel2, msg2 or "")
  gui.setText(yesNoGui, yesNoMsgLabel3, msg3 or "")
  while yesNoRunning == true do
    gui.runGui(yesNoGui)
  end
  gui.closeGui(yesNoGui)
  return yesNoValue
end




-- File handling

function gui.splitString(str, sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        str:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end




local function convert( chars, dist, inv )
  return string.char( ( string.byte( chars ) - 32 + ( inv and -dist or dist ) ) % 95 + 32 )
end

function gui.string2key(str)
  tmpTable = {}
  for i = 1, string.len(str) do
    tmpTable[i] = string.byte(str,i)
  end
  while #tmpTable < 5 do
    table.insert(tmpTable,100)
  end
  return tmpTable
end


function gui.crypt(str, k, inv)
  if not k then
    k = {1,2,3,4,5}
  end
  while #k < 5 do
    table.insert(k,100)
  end
  local enc= "";
  for i=1,#str do
    if(#str-k[#k] >= i or not inv)then
      for inc=0,3 do
	if(i%4 == inc)then
	  enc = enc .. convert(string.sub(str,i,i),k[inc+1],inv);
	  break;
	end
      end
    end
  end
  if(not inv)then
    for i=1,k[#k] do
      enc = enc .. string.char(math.random(32,126));
    end
  end
  return enc;
end

--// exportstring( string )
--// returns a "Lua" portable version of the string
function exportstring( s )
	s = string.format( "%q",s )
	-- to replace
	s = string.gsub( s,"\\\n","\\n" )
	s = string.gsub( s,"\r","\\r" )
	s = string.gsub( s,string.char(26),"\"..string.char(26)..\"" )
	return s
end
--// The Save Function
function gui.saveTable(tbl,filename )
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
		if err then 
		  print ("Gui-lib: Error saving table " .. filename .." -> " .. err)
		  return _,err 
		end
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
function gui.loadTable( sfile )
	local tables, err, _

	-- catch marker for stringtable
	if string.sub( sfile,-3,-1 ) == "--|" then
		tables,err = loadstring( sfile )
	else
		tables,err = loadfile( sfile )
	end
	if err then 
	  print("Gui-lib: Error loading table " ..sfile .. " -> " ..err)
	  return _,err
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

function gui.sepString(str)
  tmpTable = {}
  for i = 1, string.len(str) do
    tmpTable[i] = string.char(string.byte(str,i))
  end
  return tmpTable
end






return gui
