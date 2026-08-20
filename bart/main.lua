-- ============================================================
--  Bart Membership System - Main Entry
--  Auto-detect mode:
--    bart/main.lua          -> interactive menu
--    bart/main.lua admin    -> admin panel
--    bart/main.lua terminal -> member terminal
--    bart/main.lua server   -> server backend
-- ============================================================

-- ============================================================
--  Mode detection
-- ============================================================

local function detectMode(...)
    local args = { ... }
    local mode = args[1]

    if mode == "admin" then
        return "admin"
    elseif mode == "terminal" then
        return "terminal"
    elseif mode == "server" then
        return "server"
    end

    return nil
end

-- ============================================================
--  Interactive startup
-- ============================================================

local function interactiveStart()
    term.clear()
    term.setCursorPos(1, 1)

    local w, h = term.getSize()
    local cx = math.floor(w / 2)
    local cy = math.floor(h / 2) - 5

    local lines = {
        "",
        "   ____        __  _            __",
        "  / __ )__  __/ /_(_)___  _____/ /__",
        " / __  / / / / __/ / __ \\/ ___/ //_/",
        "/ /_/ / /_/ / /_/ / /_/ / /__/ ,<",
        "\\____/ \\__,_/\\__/_/\\____/\\___/_/|_|",
        "",
        "     Bart Membership System v1.0",
        "     Storage * Identity * Points",
        "",
    }

    for i, line in ipairs(lines) do
        term.setCursorPos(cx - math.floor(#line / 2), cy + i)
        print(line)
    end

    term.setCursorPos(cx - 10, cy + #lines + 2)
    print("Select mode:")

    local options = {
        { "[1] Server",     "server" },
        { "[2] Admin",      "admin" },
        { "[3] Terminal",   "terminal" },
        { "[4] Exit",        nil },
    }

    for i, opt in ipairs(options) do
        term.setCursorPos(cx - 10, cy + #lines + 3 + i)
        print(opt[1])
    end

    term.setCursorPos(cx - 10, cy + #lines + 3 + #options + 1)
    write("Enter 1-4: ")

    local choice = tonumber(read())
    if choice and choice >= 1 and choice <= 3 then
        return options[choice][2]
    end
    return nil
end

-- ============================================================
--  Main
-- ============================================================

local function main(...)
    local currentDir = shell.dir()
    if not package.path:match(currentDir) then
        package.path = currentDir .. "/?.lua;" .. package.path
    end

    local mode = detectMode(...)

    if not mode then
        mode = interactiveStart()
        if not mode then
            print("Goodbye!")
            return
        end
    end

    term.clear()
    term.setCursorPos(1, 1)

    if mode == "server" then
        local server = require "server"
        server.run()
    elseif mode == "admin" then
        local dataDir = "data"
        if not fs.exists(dataDir) then
            fs.makeDir(dataDir)
            fs.makeDir(fs.combine(dataDir, "members"))
        end
        local admin = require "ui.admin"
        admin.run()
    elseif mode == "terminal" then
        local network = require "lib.network"
        local serverID = nil

        if network.init() then
            print("[Bart] Searching for server...")
            serverID = network.discoverServer(3)
            if serverID then
                print("[Bart] Connected to server #" .. serverID)
            else
                print("[Bart] No server found, starting local mode")
            end
        else
            print("[Bart] No network, starting local mode")
        end

        sleep(1)

        local terminal = require "ui.terminal"
        terminal.run(serverID, "data", nil)
    end
end

main()
