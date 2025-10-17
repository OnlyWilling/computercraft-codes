local apiName = "touchpoint"
local pasteLink = "pFHeia96"
local infoName = "info"

term.clear()
term.setCursorPos(1, 1)

if not fs.exists(apiName) then
   shell.run("pastebin get " .. pasteLink .. " " .. apiName) --downloads the API
end

local touchpoint = require(apiName)
local helper = require("helper")
local dinerManager = require("dinerManager")

local monitorSide = nil
for _, name in ipairs(peripheral.getNames()) do --gets the side the monitor is on
   if peripheral.getType(name) == "monitor" then
      monitorSide = peripheral.wrap(name)
      break -- Wrap the first monitor
   end
end

local monitorWidth, monitorHeight = monitorSide.getSize()
if monitorWidth < 36 or monitorHeight < 24 then --changes text scale depending on the monitor size
   monitorSide.setTextScale(0.5)
   monitorWidth, monitorHeight = monitorSide.getSize()
end
monitorSide.clear()

print("A ComputerCraft Program by QiuYuan_ & OnlyWilling")
print("*Visual UI System by COD0ofDuty*")
print("*Touchpoint API by Lyqyd|Mit LISCENCE*")
print("===Automatic Diner System===")

os.sleep(2) -- show info for 2 sec

local floor = ""
local id = ""
local currentPage
local infoTable = {}

while not fs.exists(infoName) or not floor or not id do --check if file exists
   term.clear()
   term.setCursorPos(1, 1)
   local h = fs.open("info", "w") --w means read only,can create if the file not exists
   term.write("Total number of Recipe: ")
   floor = tonumber(read())
   id = os.getComputerID()
   currentPage = 1
   infoTable = { floor, id, currentPage }
   h.write(textutils.serialize(infoTable))
   h.close()
end

local h = fs.open(infoName, "r") --reads from a file,r means read only
infoTable = infoTable or textutils.unserialize(h.readAll())
if not infoTable then
   fs.delete(infoName)
   os.reboot()
end
floor = tonumber(infoTable[1])
id = tonumber(infoTable[2])
currentPage = tonumber(infoTable[3])
term.setCursorPos(1, 5)
print("Total number of floors: " .. floor)
print("ID of receiving computer: " .. id)
h.close()

-- Prompt user for device names corresponding to floors (e.g. "redstoneIntegrator_25 ...")
-- Stored in a file so it persists between runs
local deviceInfoName = "devices.info"
local indexToName, indexToPeripheral = {}, {}
if not fs.exists(deviceInfoName) then
   local baseDevicePrefix = "redstoneIntegrator_"
   term.setCursorPos(1, 7)
   term.clearLine()
   print("=== Device Mapping ===")
   print("Please enter " .. tostring(floor) .. " numbers (comma or space separated), e.g. 1 2 3 4")
   print("Each will be mapped as: redstoneIntegrator_<number>")
   term.write("Numbers: ")
   local numsInput = read()
   local nums = helper.split_device_names(numsInput)
   local names = {}
   for i, v in ipairs(nums) do
      local n = tonumber(v)
      if n then table.insert(names, baseDevicePrefix .. tostring(n)) end
   end
   local namesStr = table.concat(names, ",")
   local h2 = fs.open(deviceInfoName, "w")
   h2.write(namesStr)
   h2.close()
   indexToName, indexToPeripheral = helper.createDeviceMaps(namesStr, floor, { wrap = true })
else
   local h3 = fs.open(deviceInfoName, "r")
   local namesInput = h3.readAll()
   h3.close()
   indexToName, indexToPeripheral = helper.createDeviceMaps(namesInput, floor, { wrap = true })
end

-- Ask or load trigger side for each mapped device
local sidesFile = "devices.sides"
local indexToSide = indexToSide or {}
if fs.exists(sidesFile) then
   local h = fs.open(sidesFile, "r")
   local ok, t = pcall(textutils.unserialize, h.readAll())
   h.close()
   if ok and t then indexToSide = t else indexToSide = {} end
else
   print("Specify trigger side for each device (n/s/e/w/u/d). Press Enter to use default 'north'.")
   for i = 1, #indexToName do
      term.write(string.format("%d -> %s  side (n/s/e/w/u/d): ", i, indexToName[i]))
      local ans = read()
      local ch = ans and ans:sub(1, 1):lower() or ''
      local sideMap = { n = 'north', s = 'south', e = 'east', w = 'west', u = 'up', d = 'down' }
      indexToSide[i] = sideMap[ch] or 'north'
   end
   local h2 = fs.open(sidesFile, "w")
   h2.write(textutils.serialize(indexToSide))
   h2.close()
end

-- Print final mapping including sides
print("===Final mappings with sides===")
for i = 1, #indexToName do
   print(string.format(" %2d -> %-21s:side=%s", i, indexToName[i], tostring(indexToSide[i] or "north")))
end
print("")
print("Press E to clear data...")
print("Press Q to quit...")

local buttonsPerColumn = 4
local numberOfColumns = 1
local maxButtonsInOnePage = buttonsPerColumn * numberOfColumns
local numberOfPages = math.ceil(floor / maxButtonsInOnePage)
local buttonWidth = monitorWidth - 2

if currentPage > numberOfPages then --if monitor size is changed, current page will be set to the maximum number of pages
   currentPage = numberOfPages
end

local page = {}
for i = 1, numberOfPages do
   page[i] = touchpoint.new(monitorSide) --add pages
   if i ~= numberOfPages then
      page[i]:add(">>", nil, monitorWidth - 3, monitorHeight, monitorWidth, monitorHeight, colors.black, colors.white)
   end
   if i ~= 1 then
      page[i]:add("<<", nil, 1, monitorHeight, 4, monitorHeight, colors.black, colors.white)
   end
   if numberOfPages > 1 then
      local pageLabel = nil
      if monitorWidth == 15 then
         pageLabel = "P." .. i
      else --add page number
         pageLabel = "Page " .. i
      end
      page[i]:add(pageLabel, nil, 5, monitorHeight, monitorWidth - 4, monitorHeight, colors.black, colors.black)
   end
end

local minX = 2
local maxX = monitorWidth - 1
local buttonHeight = 2
local totalButtonHeight = buttonsPerColumn * buttonHeight
local topMargin = 2
local bottomMargin = 2
local availableHeight = monitorHeight - 1 - topMargin - bottomMargin
local spacing = math.floor((availableHeight - totalButtonHeight) / (buttonsPerColumn - 1))
local totalSpacing = spacing * (buttonsPerColumn - 1)
local totalHeight = totalButtonHeight + totalSpacing
local startY = topMargin + 1 + math.floor((availableHeight - totalHeight) / 2)
if startY < topMargin + 1 then startY = topMargin + 1 end
local minY = startY
local pageIndex = 1
for i = 1, floor do
   local maxY = minY + buttonHeight - 1
   page[pageIndex]:add(tostring(i), nil, minX, minY, maxX, maxY, colors.red, colors.lime)
   minY = minY + buttonHeight + spacing
   if i % buttonsPerColumn == 0 and i < floor then
      pageIndex = pageIndex + 1
      minY = startY
   end
end

dinerManager:init()
-- dinerManager:checkItemDetails()

-- Main event loop
while true do
   page[currentPage]:draw() --draws the buttons on the monitor
   h = fs.open(infoName, "w")
   infoTable = { floor, id, currentPage }
   h.write(textutils.serialize(infoTable))
   h.close()
   local event, p1 = page[currentPage]:handleEvents(os.pullEvent())
   if event == "button_click" then --wait for button clicks
      local chosen = tonumber(p1)
      page[currentPage]:flash(p1)
      if chosen ~= nil then
         -- Only send redstone pulse to mapped integrator
         local dev = indexToPeripheral[chosen]
         local side = indexToSide[chosen]
         if (dev and type(dev.setOutput) == "function") then
            if not dinerManager:recipeTransfer(chosen) then page[currentPage]:flash(p1, 1, colors.red) end
            dinerManager:recipeWaitForChange()
            dinerManager:recipeTakeback(chosen)
            dinerManager.callForIngredients(dev, side)
            print(("Call for Ingredients on %d on side %s").format(chosen, side))
         else
            print("[Error] No valid integrator or side for button " .. tostring(chosen))
         end
      elseif p1 == ">>" then
         currentPage = currentPage + 1
      elseif p1 == "<<" then
         currentPage = currentPage - 1
      end
   elseif event == "key" and p1 == keys.e then                        -- NOTE:clear all config
      if fs.exists(infoName) then fs.delete(infoName) end             -- delete info file
      if fs.exists(deviceInfoName) then fs.delete(deviceInfoName) end -- delete device mappings
      if fs.exists(sidesFile) then fs.delete(sidesFile) end           -- delete sides file
      term.clear()
      term.setCursorPos(1, 1)
      print("Cleared! All data reset.")
      break
   elseif event == "key" and p1 == keys.q then
      term.clear()
      term.setCursorPos(1, 1)
      print("Program quit")
      break
   end
end
