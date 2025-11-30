-- Basalt 2 Generated Code
local basalt = require("basalt")

-- Smart Margin System: Auto-adapt to different screen sizes
local w, h = term.getSize()
local designWidth, designHeight = 51, 19
local scaleX, scaleY = w / designWidth, h / designHeight
local function smartPos(x, y) return math.floor(x * scaleX + 0.5), math.floor(y * scaleY + 0.5) end
local function smartSize(width, height) return math.max(1, math.floor(width * scaleX + 0.5)),
        math.max(1, math.floor(height * scaleY + 0.5)) end

-- Create main frame
local main = basalt.createFrame()
    :setSize(w, h)

-- Button element
local element1 = main:addButton()
    :setPosition(smartPos(11, 10))
    :onClick(function(self)
        self:setText("Stop Play")
        local frame = main:addFrame({
                x = 2,
                y = 2,
                width = 28,
                height = 10,
                title = "Bimg Player",
                draggable = true,
            })
            :setDraggingMap({ { x = 1, y = 1, width = 27, height = 1 } })
            :onFocus(function(self)
                self:prioritize()     -- 选中时接受事件优先级置顶
            end)
    end)

-- Start the UI
basalt.run()
