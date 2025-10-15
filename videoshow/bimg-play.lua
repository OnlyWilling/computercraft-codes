-- bimg_player.lua
-- BIMG Player (Shell Version)
-- Usage: bimg_player <file.bimg> [options]

-- Initialize settings
local currentAnimation = nil
local httpEnabled = http and http.get

-- Show help message
local function showHelp()
    print("BIMG Player - Usage:")
    print("bimg_player <file.bimg> [options]")
    print()
    print("Options:")
    print("  --loop       Loop animation")
    print("  --url        Load from URL")
    print("  --monitor <side> Play on specific monitor (top/bottom/left/right/front/back)")
    print("  --scale <num>   Set display scale (0.5-3)")
    print("  --fps <num>     Set frame rate (1-60)")
    print("  --help       Show this help")
    print()
    print("Examples:")
    print("bimg_player animation.bimg --loop")
    print("bimg_player http://example.com/image.bimg --url --monitor top")
end

-- Load image file
local function loadImageFile(path)
    local file, err = fs.open(shell.resolve(path), "rb")
    if not file then error("Cannot open file: " .. err) end
    local data = file.readAll()
    file.close()
    local success, img = pcall(textutils.unserialize, data)
    if not success then error("Invalid BIMG file: " .. img) end
    return img
end

-- Load image from URL
local function loadImageURL(url)
    if not httpEnabled then
        error("HTTP API not available, cannot load from URL")
    end

    print("Downloading from URL: " .. url)
    local response = http.get(url)
    if not response then
        error("Download failed: " .. url)
    end

    local data = response.readAll()
    response.close()
    local success, img = pcall(textutils.unserialize, data)
    if not success then error("Invalid BIMG data: " .. img) end
    return img
end

-- Monitor calibration
local function calibrateMonitors(width, height)
    term.clear()
    term.setCursorPos(1, 1)
    print("Multi-Monitor Calibration Mode")
    print("Please right-click each monitor in order")
    print("From top-left to bottom-right, left to right first")

    local monitors = {}
    local names = {}

    for y = 1, height do
        monitors[y] = {}
        for x = 1, width do
            local _, oy = term.getCursorPos()

            -- Draw calibration UI
            for ly = 1, height do
                term.setCursorPos(3, oy + ly - 1)
                term.clearLine()
                for lx = 1, width do
                    term.blit('\x8F ', (lx == x and ly == y) and '00' or '77', 'ff')
                end
            end

            term.setCursorPos(3, oy + height)
            term.write(string.format("Position (%d, %d)", x, y))
            term.setCursorPos(1, oy)

            -- Wait for monitor click
            repeat
                local _, name = os.pullEvent('monitor_touch')
                monitors[y][x] = name
            until not names[name]

            names[monitors[y][x]] = true
            sleep(0.25)
        end
    end

    settings.set('bimg_player.multimonitor', monitors)
    settings.save()
    print("Calibration complete. Settings saved.")

    return monitors
end

-- Stop playback
local function stopPlayback()
    if currentAnimation and currentAnimation.running then
        os.queueEvent("bimg_stop")
    end
end

-- Clean up terminal
local function cleanupTerminal(termObj)
    termObj.setBackgroundColor(colors.black)
    termObj.setTextColor(colors.white)
    termObj.clear()
    termObj.setCursorPos(1, 1)
    for i = 0, 15 do
        termObj.setPaletteColor(2 ^ i, term.nativePaletteColor(2 ^ i))
    end
end

-- Draw single frame
local function drawFrame(frame, termObj)
    for y, row in ipairs(frame) do
        termObj.setCursorPos(1, y)
        termObj.blit(table.unpack(row))
    end
    if frame.palette then
        for i = 0, #frame.palette do
            local c = frame.palette[i]
            if type(c) == "table" then
                termObj.setPaletteColor(2 ^ i, table.unpack(c))
            else
                termObj.setPaletteColor(2 ^ i, c)
            end
        end
    end
end

-- Main playback function
local function playAnimation(img, options)
    options = options or {}
    local termObj = options.terminal or term
    local fps = options.fps or (img.secondsPerFrame and (1 / img.secondsPerFrame)) or 20
    local frameDelay = 1 / fps

    -- Set running state
    currentAnimation = {
        running = true,
        paused = false,
        loop = options.loop or false,
        frameindex = 1,
    }

    -- Playback function
    local function playFrames()
        repeat
            currentAnimation.frameindex = 1
            if img.multiMonitor then
                local width, height = img.multiMonitor.width, img.multiMonitor.height
                local monitors = settings.get('bimg_player.multimonitor')

                -- Calibrate if needed
                if not monitors or #monitors < height or #monitors[1] < width then
                    monitors = calibrateMonitors(width, height)
                end

                -- Multi-monitor playback
                for i = 1, #img, width * height do
                    if not currentAnimation.running then break end

                    for y = 1, height do
                        for x = 1, width do
                            local frameIndex = i + (y - 1) * width + x - 1
                            if frameIndex <= #img then
                                local monitor = peripheral.wrap(monitors[y][x])
                                if monitor then
                                    drawFrame(img[frameIndex], monitor)
                                end
                            end
                        end
                    end

                    sleep(frameDelay)
                end
            else
                -- Single monitor playback
                if not currentAnimation.paused then termObj.clear() end
                while currentAnimation.frameindex <= #img do
                    if not currentAnimation.running then break end

                    if not currentAnimation.paused then
                        drawFrame(img[currentAnimation.frameindex], termObj)
                        sleep(frameDelay)
                        currentAnimation.frameindex = currentAnimation.frameindex + 1
                    else
                        sleep(0.1)
                    end
                end
            end
        until not currentAnimation.loop or not currentAnimation.running
    end

    -- Start playback
    parallel.waitForAny(
        function()
            local ok, err = pcall(playFrames)
            if not ok then printError("Playback error: " .. err) end
            cleanupTerminal(termObj)
            currentAnimation.running = false
        end,
        function()
            while true do
                local event, key = os.pullEvent()
                if event == "bimg_stop" or (event == "key" and (key == keys.q or key == keys.escape)) then
                    cleanupTerminal(termObj)
                    currentAnimation.running = false
                elseif event == "key" then
                    if key == keys.q or key == keys.escape then
                        cleanupTerminal(termObj)
                        currentAnimation.running = false
                    elseif key == keys.space then
                        currentAnimation.loop = not currentAnimation.loop
                    elseif key == keys.t then
                        currentAnimation.paused = not currentAnimation.paused
                    end
                end
            end
        end
    )
end

-- Parse command line arguments
local function parseArguments(args)
    local options = {}
    local path = nil

    local i = 1
    while i <= #args do
        local arg = args[i]
        if arg == "--loop" then
            options.loop = true
        elseif arg == "--url" then
            options.isURL = true
        elseif arg == "--monitor" then
            i = i + 1
            options.terminal = peripheral.wrap(args[i])
            if not options.terminal then
                error("Invalid monitor side: " .. (args[i] or "nil"))
            end
        elseif arg == "--scale" then
            i = i + 1
            local scale = tonumber(args[i])
            if scale and scale >= 0.5 and scale <= 3 then
                options.scale = scale
            else
                error("Invalid scale value (should be 0.5-3)")
            end
        elseif arg == "--fps" then
            i = i + 1
            local fps = tonumber(args[i])
            if fps and fps >= 1 and fps <= 60 then
                options.fps = fps
            else
                error("Invalid FPS value (should be 1-60)")
            end
        elseif arg == "--help" then
            showHelp()
            return nil
        elseif not path and not arg:find("^-") then
            path = arg
        else
            error("Unknown option: " .. arg)
        end
        i = i + 1
    end

    if not path then
        showHelp()
        return nil
    end

    return path, options
end

-- Main program entry
local function main(...)
    local args = { ... }

    -- Show help if no arguments
    if #args == 0 then
        showHelp()
        return
    end

    -- Parse arguments
    local ok, path, options = pcall(parseArguments, args)
    if not ok then
        printError(path) -- Here path contains the error message
        showHelp()
        return
    end

    if not path then return end -- User requested help

    -- Load image
    local img
    if options.isURL then
        img = loadImageURL(path)
    else
        img = loadImageFile(path)
    end

    -- Apply display scale
    if options.scale and img.multiMonitor then
        img.multiMonitor.scale = options.scale
    end

    -- Start playback
    playAnimation(img, options)

    -- Wait for keypress if not looping

    print("Animation finished. Press any key to exit.")
    os.pullEvent("key")
end

-- Start program
main(...)
