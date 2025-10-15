local player = {}

local httpEnabled = http and http.get
-- Show help message
function player.showHelp()
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
function player.loadImageFile(path)
    local file, err = fs.open(shell.resolve(path), "rb")
    if not file then error("Cannot open file: " .. err) end
    local data = file.readAll()
    file.close()
    local success, img = pcall(textutils.unserialize, data)
    if not success then error("Invalid BIMG file: " .. img) end
    return img
end

-- Load image from URL
function player.loadImageURL(url)
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

-- Parse command line arguments
function player.parseArguments(args)
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
            player.showHelp()
            return nil
        elseif not path and not arg:find("^-") then
            path = arg
        else
            error("Unknown option: " .. arg)
        end
        i = i + 1
    end

    if not path then
        player.showHelp()
        return nil
    end

    return path, options
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
                if names[name] then
                    print("Monitor already selected, please choose another.")
                else
                    monitors[y][x] = name
                end
            until monitors[y][x]

            names[monitors[y][x]] = true
            os.sleep(0.25)
        end
    end

    settings.set('bimg_player.multimonitor', monitors)
    settings.save()
    print("Calibration complete. Settings saved.")

    return monitors
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

-- Main playback function
function player:playAnimation(img)
    repeat
        self.state.frameindex = 1
        if img.multiMonitor then
            local width, height = img.multiMonitor.width, img.multiMonitor.height
            local monitors = settings.get('bimg_player.multimonitor')

            -- Calibrate if needed
            if not monitors or #monitors < height or #monitors[1] < width then
                monitors = calibrateMonitors(width, height)
            end

            -- Multi-monitor playback
            for i = 1, #img, width * height do
                if not self.state.running then break end

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

                os.sleep(self.frameDelay)
            end
        else
            -- Single monitor playback
            if not self.state.paused then self.displayObj.clear() end
            while self.state.frameindex <= #img do
                if not self.state.running then break end

                if not self.state.paused then
                    drawFrame(img[self.state.frameindex], self.displayObj)
                    os.sleep(self.frameDelay)
                    self.state.frameindex = self.state.frameindex + 1
                else
                    os.sleep(0.1)
                end
            end
        end
    until not self.state.loop or not self.state.running
    cleanupTerminal(self.displayObj)
end

-- Create a bimg player
function player:create(img, opts)
    opts = opts or {}
    local obj = {}
    setmetatable(obj, { __index = self })
    obj.displayObj = opts.display or term
    obj.fps = opts.fps or (img.secondsPerFrame and (1 / img.secondsPerFrame)) or 20
    obj.frameDelay = 1 / obj.fps
    obj.state = {
        running = true,
        paused = false,
        loop = opts.loop or false,
        frameindex = 1,
    }

    -- Return run and control API
    return {
        run = function() obj:playAnimation(img) end,
        ctrl = {
            stop        = function() obj.state.running = false end,
            togglePause = function() obj.state.paused = not obj.state.paused end,
            toggleLoop  = function() obj.state.loop = not obj.state.loop end,
            isRunning   = function() return obj.state.running end,
        }
    }
end

return player
