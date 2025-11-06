local program_file = "bimg_play"
local video_file = "demo.bimg"

local command = string.format("%s %s", program_file, video_file)
local ok, err = pcall(shell.run, command)
if not ok then
    basalt.error("[ERROR]Fail to play bimg:\n" .. tostring(err))
end
