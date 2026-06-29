-- local detector = peripheral.find("playerDetector")
local detector_1 = peripheral.wrap("playerDetector_1") or find("playerDetector")
local detector_2 = peripheral.wrap("playerDetector_1") or find("playerDetector")
local monitor = peripheral.find("monitor") or term.native()
local relay = peripheral.find("redstone_relay")

local pos = {
    dect_1 = { x = -8, y = -59, z = -82 },
    dect_2 = { x = -10, y = -55, z = -84 },
    dect_cubic_1 = { w = 1, h = 6, d = 1 },
    dect_cubic_2 = { w = 2, h = 6, d = 2 }
}

local players_table_1 = nil
local players_table_2 = nil
local verify = nil

if monitor ~= term.native then
    monitor.setTextScale(1.0)
end

term.redirect(monitor)
term.clear()
term.setCursorPos(1, 1)

while true do
    os.pullEvent("redstone")
    term.clear()
    term.setCursorPos(1, 1)
    print("Detecting players...")
    -- players_table = detector.getPlayersInRange(16)
    -- players_table = detector.getPlayersInCoords(pos.dect_1, pos.dect_2)
    if relay.getInput("front") then
        players_table_1 = detector_1.getPlayersInCubic(pos.dect_cubic_1.w, pos.dect_cubic_1.h, pos.dect_cubic_1.d)
        if next(players_table_1) ~= nil then
            print("Detector1 found players:")
            for k, v in pairs(players_table_1) do
                print(k, v)
            end
        end
        players_table_2 = detector_2.getPlayersInCubic(pos.dect_cubic_2.w, pos.dect_cubic_2.h, pos.dect_cubic_2.d)
        if next(players_table_2) ~= nil then
            print("Detector2 found players:")
            for k, v in pairs(players_table_2) do
                print(k, v)
            end
        end
    elseif relay.getInput("right") then
        print("Signal from other side, waiting...")
    else
        print("No signal  waiting...")
    end
end
