-- Basalt 2 Generated Code
local basalt = require("basalt")

-- Smart Margin System: Auto-adapt to different screen sizes
local w, h = term.getSize()
local designWidth, designHeight = 51, 19
local scaleX, scaleY = w / designWidth, h / designHeight
local function smartPos(x, y) return math.floor(x * scaleX + 0.5), math.floor(y * scaleY + 0.5) end
local function smartSize(width, height) return math.max(1, math.floor(width * scaleX + 0.5)), math.max(1, math.floor(height * scaleY + 0.5)) end

-- Create main frame
local main = basalt.createFrame()
    :setSize(w, h)

-- Button element
local element1 = main:addButton()
    :setPosition(smartPos(11, 10))

-- Start the UI
basalt.run()