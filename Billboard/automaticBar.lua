local apiName = "touchpoint"
local pasteLink = "pFHeia96"
local infoName = "info"
local Ring = peripheral.wrap("top")
term.clear()
term.setCursorPos(1,1)

if not fs.exists(apiName) then
   shell.run("pastebin get " .. pasteLink .. " " .. apiName)   --downloads the API
end

os.loadAPI(apiName)
peripheral.find("modem", rednet.open)  --find monitor
local monitor = peripheral.find("monitor")
monitor.setTextScale(0.5)
monitor.clear()

local monitorWidth, monitorHeight = monitor.getSize()
if monitorWidth >= 36 and monitorHeight >= 24 then   --changes text scale depending on the monitor size
   monitor.setTextScale(1)
   monitorWidth, monitorHeight = monitor.getSize()
end

local monitorSide
for _,name in ipairs(peripheral.getNames()) do   --gets the side the monitor is on
   if peripheral.getType(name) == "monitor" then
      monitorSide = name
   end
end

term.clear()
term.setCursorPos(1,1)
print("A ComputerCraft Program by QiuYuan_")
print("Visual UI System by COD0ofDuty")
print("Touchpoint API by Lyqyd|Mit LISCENCE")
print("Automatic Self Sale System")

local floor = ""
local id = ""
local currentPage

while not fs.exists(infoName) or not floor or not id do   --check if file exists
   term.setCursorPos(1,6)
   term.clearLine()
   term.setCursorPos(1,5)
   term.clearLine()
   local h = fs.open("info", "w")   --w means read only,can create if the file not exists
   term.write("Total number of Commodity: ")
   floor = tonumber(read())
   --term.write("ID of receiving computer: ")
   id = 114514
   currentPage = 1
   local infoTable = {floor, id, currentPage}
   h.write(textutils.serialize(infoTable))
   h.close()
end

local h = fs.open(infoName, "r")   --reads from a file,r means read only
local infoTable = textutils.unserialize(h.readAll())
if not infoTable then
   fs.delete(infoName)
   os.reboot()
end
floor = tonumber(infoTable[1])
id = tonumber(infoTable[2])
currentPage = tonumber(infoTable[3])
term.setCursorPos(1,5)
print("Total number of floors: " .. floor)
print("ID of receiving computer: " .. id)
h.close()

-- Helper: split device name string by commas or whitespace
local function split_device_names(s)
   local t = {}
   if not s then return t end
   for part in s:gmatch("[^,%s]+") do
      table.insert(t, part)
   end
   return t
end

-- Create mapping from index -> name and name -> index, optional peripheral.wrap
local function createDeviceMaps(namesString, floor, opts)
   opts = opts or {}
   local strict = opts.strict or false
   local doWrap = opts.wrap or false

   if floor <= 0 or floor > 24 then
      error("createDeviceMaps: floor must be 1..24")
   end
   if not namesString or namesString == "" then
      if strict then error("createDeviceMaps: namesString empty") end
      return {}, {}, {}
   end

   local rawNames = split_device_names(namesString)
   local n = math.min(#rawNames, floor)
   local indexToName = {}
   local nameToIndex = {}
   local indexToPeripheral = {}

   for i = 1, n do
      local name = rawNames[i]
      indexToName[i] = name
      nameToIndex[name] = i
      if doWrap and peripheral then
         local ok, obj = pcall(peripheral.wrap, name)
         if ok and obj then
            indexToPeripheral[i] = obj
         else
            indexToPeripheral[i] = nil
            print("Warning: cannot wrap peripheral: " .. tostring(name))
         end
      end
   end

   if #rawNames < floor then
      local msg = string.format("Note: provided device names (%d) < floor (%d). Mapped %d devices.", #rawNames, floor, n)
      if strict then error(msg) else print(msg) end
   elseif #rawNames > floor then
      print(string.format("Note: provided device names (%d) > floor (%d). Extra names truncated.", #rawNames, floor))
   end

   return indexToName, nameToIndex, indexToPeripheral
end

-- Prompt user for device names corresponding to floors (e.g. "redstoneIntegrator_25 ...")
-- Stored in a file so it persists between runs
local deviceInfoName = "devices.info"
local indexToName, nameToIndex, indexToPeripheral, indexToSide = {}, {}, {}, {}
if not fs.exists(deviceInfoName) then
   local baseDevicePrefix = "redstoneIntegrator_"
   term.setCursorPos(1,7)
   term.clearLine()
   print("=== Device Mapping ===")
   print("Please enter " .. tostring(floor) .. " numbers (comma or space separated), e.g. 1 2 3 4")
   print("Each will be mapped as: redstoneIntegrator_<number>")
   term.write("Numbers: ")
   local numsInput = read()
   local nums = split_device_names(numsInput)
   local names = {}
   for i, v in ipairs(nums) do
      local n = tonumber(v)
      if n then table.insert(names, baseDevicePrefix .. tostring(n)) end
   end
   local namesStr = table.concat(names, ",")
   local h2 = fs.open(deviceInfoName, "w")
   h2.write(namesStr)
   h2.close()
   indexToName, nameToIndex, indexToPeripheral = createDeviceMaps(namesStr, floor, {wrap=true})
else
   local h3 = fs.open(deviceInfoName, "r")
   local namesInput = h3.readAll()
   h3.close()
   indexToName, nameToIndex, indexToPeripheral = createDeviceMaps(namesInput, floor, {wrap=true})
end

-- Print mapping result and prompt for side selection, with clear layout
print("\n=== Mapping Result ===")
for i=1, #indexToName do
   print(string.format("%2d: %s", i, indexToName[i]))
end
print("\nNow specify the redstone side for each device.")
print("Use n/s/e/w/u/d for north/south/east/west/up/down. Press Enter for default (north).\n")

   -- Create sanitized global variables for each device for easy reference
   local function sanitize_name_for_var(name)
      if not name then return "" end
      -- replace non-alphanumeric with underscore, uppercase the name
      local s = name:gsub("[^%w]", "_")
      s = s:gsub("__+", "_")
      s = s:upper()
      return s
   end

   for i=1, #indexToName do
      local name = indexToName[i]
      local sanitized = sanitize_name_for_var(name)
      local varName = "DEV_" .. sanitized
      local shortVar = "dev" .. tostring(i)
      -- assign global and short variables if possible
      local periph = indexToPeripheral[i]
      if not periph and name then
         local ok, obj = pcall(peripheral.wrap, name)
         if ok then periph = obj end
      end
      _G[varName] = periph
      _G[shortVar] = periph
      -- print a summary line
      print(string.format("Mapped %d -> %s  as %s / %s", i, tostring(name), varName, shortVar))
   end

local buttonsPerColumn = math.floor((monitorHeight)/2)
local numberOfColumns = math.min(math.ceil(floor/buttonsPerColumn), 3)
local maxButtonsInOnePage = buttonsPerColumn * 3
local numberOfPages = math.ceil(floor/maxButtonsInOnePage)
local buttonWidth = monitorWidth - 2

if floor * 2 >= monitorHeight then
   buttonWidth = math.floor((monitorWidth-numberOfColumns - 3)/numberOfColumns)   --calculates the width of buttons
end

if currentPage > numberOfPages then   --if monitor size is changed, current page will be set to the maximum number of pages
   currentPage = numberOfPages
end

local page = {}
for i = 1, numberOfPages do
   page[i] = touchpoint.new(monitorSide)   --add pages
   if i ~= numberOfPages then
      page[i]:add(">>", nil, monitorWidth-3, monitorHeight, monitorWidth, monitorHeight, colors.black, colors.white)
   end
   if i ~= 1 then
      page[i]:add("<<", nil, 1, monitorHeight, 4, monitorHeight, colors.black, colors.white)
   end
   if numberOfPages > 1 then
      local pageLabel
      if monitorWidth == 15 then
         pageLabel = "P." .. i
      else                      --add page number
         pageLabel = "Page " .. i
      end
      page[i]:add(pageLabel, nil, 5, monitorHeight, monitorWidth-4, monitorHeight, colors.black, colors.black)
   end
end

local minX = 2
local minY = 1
local maxX = monitorWidth - 1
local maxY = minY

local pageIndex = 1
local topFloor = floor - 1

if topFloor < buttonsPerColumn then
   for i = 1, floor do
      page[pageIndex]:add(tostring(i), nil, minX, minY, maxX, maxY, colors.red, colors.lime)
      minY = minY + 2
      maxY = minY
   end
else
   minX = 2
   maxX = minX + buttonWidth
   minY = monitorHeight - 1
   maxY = minY
   for i = 1, floor do
      page[pageIndex]:add(tostring(i), nil, minX, minY, maxX, maxY, colors.red, colors.lime)
      local remainingFloors = floor - i
      minY = maxY - 2
      maxY = minY
      if maxY <= 0 then   --move buttons to the next column
         minX = maxX + 2
         maxX = minX + buttonWidth
         minY = monitorHeight - 1
         maxY = minY
         if maxX > monitorWidth then   --change to next page
            pageIndex = pageIndex + 1
            minX = 2
            maxX = minX + buttonWidth
            minY = monitorHeight - 1
            maxY = minY
         end
         if remainingFloors < buttonsPerColumn then   --moves the buttons up if there are spaces
            minY = monitorHeight - 1 - ((buttonsPerColumn - remainingFloors) * 2)
            maxY = minY
         end
      end
   end
end

term.setCursorPos(1,8)
print("")

-- Ask or load trigger side for each mapped device
local sidesFile = "devices.sides"
indexToSide = indexToSide or {}
if fs.exists(sidesFile) then
   local h = fs.open(sidesFile, "r")
   local ok, t = pcall(textutils.unserialize, h.readAll())
   h.close()
   if ok and t then indexToSide = t else indexToSide = {} end
else
   print("Specify trigger side for each device (n/s/e/w/u/d). Press Enter to use default 'north'.")
   for i=1, #indexToName do
      term.write(string.format("%d -> %s  side (n/s/e/w/u/d): ", i, indexToName[i]))
      local ans = read()
      local ch = ans and ans:sub(1,1):lower() or ''
      local sideMap = { n='north', s='south', e='east', w='west', u='up', d='down' }
      indexToSide[i] = sideMap[ch] or 'north'
   end
   local h2 = fs.open(sidesFile, "w")
   h2.write(textutils.serialize(indexToSide))
   h2.close()
end

-- Print final mapping including sides
print("Final mappings (including trigger side):")
for i=1, #indexToName do
   print(string.format(" %2d -> %-30s  side=%s", i, indexToName[i], tostring(indexToSide[i] or "north")))
end
print("")
print("Press E to clear data...")

while true do
   page[currentPage]:draw()   --draws the buttons on the monitor
   local h = fs.open(infoName, "w")
   local infoTable = {floor, id, currentPage}
   h.write(textutils.serialize(infoTable))
   h.close()
   local event, p1 = page[currentPage]:handleEvents(os.pullEvent())
   if event == "button_click" then   --wait for button clicks
      local chosen = tonumber(p1)
      page[currentPage]:flash(p1)
      if chosen ~= nil then
         -- Only send redstone pulse to mapped integrator
         local dev = _G["dev" .. tostring(chosen)]
         local side = indexToSide and indexToSide[chosen]
         if (dev and type(dev.setOutput) == "function") and side then
            dev.setOutput(side, true)
            sleep(0.2)
            dev.setOutput(side, false)
            Ring.playNote()
            print(string.format("Sent redstone pulse to %s on side %s", tostring(indexToName[chosen]), tostring(side)))
         else
            print("[Error] No valid integrator or side for button " .. tostring(chosen))
         end
      elseif p1 == ">>" then
         currentPage = currentPage + 1
      elseif p1 == "<<" then
         currentPage = currentPage - 1
      end
   elseif event == "key" and p1 == keys.e then
      fs.delete(infoName)   -- delete info file
      local deviceInfoName = "devices.info"
      if fs.exists(deviceInfoName) then fs.delete(deviceInfoName) end
      local sidesFile = "devices.sides"
      if fs.exists(sidesFile) then fs.delete(sidesFile) end -- delete way file
      -- delete device mappings
      indexToName = indexToName or {}
      nameToIndex = nameToIndex or {}
      indexToPeripheral = indexToPeripheral or {}
      for k in pairs(indexToName) do indexToName[k] = nil end
      for k in pairs(nameToIndex) do nameToIndex[k] = nil end
      for k in pairs(indexToPeripheral) do indexToPeripheral[k] = nil end
      -- delete global variables
      for i=1,24 do
         local shortVar = "dev" .. tostring(i)
         if _G[shortVar] ~= nil then _G[shortVar] = nil end
      end
      for k,v in pairs(_G) do
         if type(k) == "string" and k:match("^DEV_[%w_]+$") then
            _G[k] = nil
         end
      end
      term.setCursorPos(1,9)
      print("Cleared! All data reset.")
      sleep(1)
      os.reboot()
   end
end


--[[
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣶⣿⣿⣿⣿⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⠿⠟⠛⠻⣿⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣆⣀⣀⠀⣿⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠻⣿⣿⣿⠅⠛⠋⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢼⣿⣿⣿⣃⠠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣟⡿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣛⣛⣫⡄⠀⢸⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣴⣾⡆⠸⣿⣿⣿⡷⠂⠨⣿⣿⣿⣿⣶⣦⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣤⣾⣿⣿⣿⣿⡇⢀⣿⡿⠋⠁⢀⡶⠪⣉⢸⣿⣿⣿⣿⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⣿⣿⣿⣿⣿⡏⢸⣿⣷⣿⣿⣷⣦⡙⣿⣿⣿⣿⣿⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⣿⣿⣿⣿⣿⣿⣇⢸⣿⣿⣿⣿⣿⣷⣦⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣵⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣯⡁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
--]]
 
--https://www.youtube.com/watch?v=dQw4w9WgXcQ
