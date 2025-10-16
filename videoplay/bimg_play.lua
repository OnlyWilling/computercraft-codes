local function parser(bimg_player, args)
    -- Show help if no arguments
    if #args == 0 then
        bimg_player.showHelp()
        return
    end

    -- Parse arguments
    local ok, path, opts = pcall(bimg_player.parseArguments, args)
    if not ok then
        printError(path) -- Here path contains the error message
        bimg_player.showHelp()
        return
    elseif not path then
        return -- User requested help
    end

    -- Load image
    local img = nil
    if opts.isURL then
        img = bimg_player.loadImageURL(path)
    else
        img = bimg_player.loadImageFile(path)
    end

    -- Check img is not nil
    if not img then
        error("Failed to load image from: " .. path)
        return
    end

    -- Apply display scale
    if opts.scale and img.multiMonitor then
        img.multiMonitor.scale = opts.scale
    end
    return opts, img
end

local function main(...)
    local args = { ... }
    local bimg_player = require("bimg_player")

    local opts, img = parser(bimg_player, args)

    if not opts or not img then
        return
    end

    local player = bimg_player:create(img, opts)

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
            elseif ev == "bimg_stop" then
                player.ctrl.stop()
            end
        end
    end

    parallel.waitForAny(player.run, keysHandler)

    print("Animation finished. Press any key to exit.")
end

-- Here runs the main
main(...)
