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

local bimg_path = "./bimg/nimmt5.bimg"
local bimg_data = loadImageFile(bimg_path)

local base_frame = basalt.createFrame()
    :setSize(51, 19)
    :setBackground(colors.black)

local logo_img = base_frame:addImage({
        bimg = bimg_data,
    })
    :setPosition(1, 1)
    :setSize("{parent.width}", "{parent.height}")
    :applyPalette()
    :setBackground(colors.black)
    :setForeground(colors.white)
    :onClick(function()
        basalt.stop()
    end)

local function UI_task()
    basalt.run()
end

local function Keyboard_task()
    while true do
        local ev, key = os.pullEvent()
        if ev == "key" then
            if key == keys.q or key == keys.escape then
                basalt.stop()
            end
        end
    end
end

parallel.waitForAny(UI_task, Keyboard_task)

term.clear()
term.setCursorPos(1, 1)
print("Program terminated.")
