local basalt = require("basalt")

term.clear()
term.setCursorPos(1, 1)

local video_path = "nimmt.bimg"

local main = basalt.createFrame()

local img1 = main:addImage({
        bimg = video_path,
        autoResize = true,
    })
    :setPosition(2, 2)
    :onClick(function()
        basalt.stop()
    end)

basalt.run()
term.clear()
term.setCursorPos(1, 1)
print("Program terminated.")
