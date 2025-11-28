local basalt = require("basalt")

local function loadImageFile(path)
    local file, err = fs.open(shell.resolve(path), "rb")
    if not file then error("Cannot open file: " .. err) end
    local data = file.readAll()
    file.close()
    local success, img = pcall(textutils.unserialize, data)
    if not success then error("Invalid BIMG file: " .. img) end
    return img
end

term.clear()
term.setCursorPos(1, 1)

local bimg_path = "./bimg/nimmt2.bimg"
local bimg_data = loadImageFile(bimg_path)

local main = basalt.createFrame()
    :setSize(51, 19)
    :setBackground(colors.black)

local img1 = main:addImage({
        bimg = bimg_data,
    })
    :setPosition(1, 1)
    :setSize(51, 19)
    :onClick(function()
        basalt.stop()
    end)

basalt.run()
term.clear()
term.setCursorPos(1, 1)
print("Program terminated.")
