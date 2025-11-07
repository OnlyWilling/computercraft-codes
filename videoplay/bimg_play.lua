local function main(...)
    local bimg_player = require("bimg_player")

    local path = nil
    local opts = {}
    if _ENV and type(_ENV.bimg_options) == "table" then
        -- Method 1: Load from environment table
        print("bimg_play: Loading options from environment.")
        opts = _ENV.bimg_options
        path = opts.path

        if not path then
            printError("bimg_play Error: 'bimg_options' table found, but 'path' key is missing.")
            return
        end
    else
        -- Method 2: Load from command-line arguments
        print("bimg_play: Loading options from command-line arguments.")
        local args = { ... }
        if #args == 0 then
            bimg_player.showHelp()
            return
        end

        -- Parse arguments using the library function
        local ok, parsed_path, parsed_opts = pcall(bimg_player.parseArguments, args)
        if not ok then
            printError(parsed_path) -- On error, first return value is the error message
            bimg_player.showHelp()
            return
        elseif not parsed_path then
            return -- User requested help (--help)
        end
        path = parsed_path
        opts = parsed_opts
    end

    -- --- From this point, the logic is the same regardless of the source ---

    -- Load image
    local img = nil
    if opts.isURL then
        img = bimg_player.loadImageURL(path)
    else
        img = bimg_player.loadImageFile(path)
    end

    if not img then
        printError("bimg_play Error: Failed to load image from: " .. tostring(path))
        return
    end

    -- Apply display scale if provided
    if opts.scale and img.multiMonitor then
        img.multiMonitor.scale = opts.scale
    end

    -- Create player instance
    local player = bimg_player.create(img, opts)

    -- Keyboard event handler for player controls
    local function keysHandler()
        while true do
            local ev, key = os.pullEvent()
            if ev == "key" then
                if key == keys.p then
                    player.ctrl.togglePause()
                elseif key == keys.space then
                    player.ctrl.toggleLoop()
                elseif key == keys.q or key == keys.escape then
                    player.ctrl.stop()
                end
            elseif ev == "bimg_pause" then -- Custom event to toggle pause
                player.ctrl.togglePause()
            elseif ev == "bimg_stop" then  -- Custom event to stop playback
                player.ctrl.stop()
            end
        end
    end

    -- Run player and event handler in parallel
    parallel.waitForAny(player.run, keysHandler)

    print("Animation finished. Press any key to exit.")
end

-- Here runs the main
-- We wrap it in pcall to catch any unexpected errors gracefully
local ok, err = pcall(main, ...)
if not ok then
    printError("[ERROR] A fatal error occurred in bimg_play: " .. tostring(err))
end
