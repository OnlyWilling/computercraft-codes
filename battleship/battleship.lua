-- Battleship for ComputerCraft by JackMacWindows
-- GPL license

local mask = {
    hasShip = 1,
    hover = 2,
    hit = 4,
    miss = 8,
}

local ships = {Carrier = 5, Battleship = 4, Destroyer = 3, Submarine = 3, ["Patrol Boat"] = 2}

local rednetConnection = {
    host = function()
        while true do
            local id, msg = rednet.receive("jmw.battleship")
            if msg == "connect" then
                rednet.send(id, "connected", "jmw.battleship")
                return {
                    send = function(m) rednet.send(id, m, "jmw.battleship") end,
                    receive = function()
                        while true do
                            local sender, m = rednet.receive("jmw.battleship")
                            if sender == id then return m end
                        end
                    end
                }
            end
        end
    end,
    connect = function(id)
        rednet.send(id, "connect", "jmw.battleship")
        while true do
            local id2, msg = rednet.receive("jmw.battleship", 5)
            if id2 == nil then return nil
            elseif id2 == id and msg == "connected" then return {
                send = function(m) rednet.send(id, m, "jmw.battleship") end,
                receive = function()
                    while true do
                        local sender, m = rednet.receive("jmw.battleship")
                        if sender == id then return m end
                    end
                end
            } end
        end
    end
}

local function toCoords(x, y) return string.char(y + 64) .. x end

local function drawMainMenu()
    -- Generated with juroku (https://tojuroku.switchcraft.pw)
	term.setCursorPos(1, 1)
	term.blit("\128\128\128\128\128\128\128\128\152\144\144\128\128\128\128\128\128\128\128\128\128\128\128\128\128\143\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128", "33333333eee3333333333333333333333333333333333333333", "333333333333333333333333373333333333333333333333333")
	term.setCursorPos(1, 2)
	term.blit("\128\128\128\143\143\130\144\137\133\143\138\155\143\143\128\143\143\138\143\144\159\143\133\128\128\128\128\128\128\143\143\143\159\159\143\143\143\149\149\153\134\128\149\149\128\143\143\144\139\128\128", "33300303e0e3003000030003333330003000030e33e0300e333", "3303e03e0e0ee303333033303733033303333033e0030e30033")
	term.setCursorPos(1, 3)
	term.blit("\128\128\128\153\134\133\149\151\151\152\148\148\130\134\128\144\128\128\128\149\149\128\128\128\128\128\128\128\128\128\128\128\129\129\128\159\155\149\149\152\152\128\149\149\128\129\137\155\128\128\128", "333e3e0e01e0333e33330333333333333033330113103333333", "3303e0e01e0eee033330333037330333033ee0eee00e0eee033")
	term.setCursorPos(1, 4)
	term.blit("\128\159\128\131\129\151\153\128\153\129\137\128\134\155\128\153\128\128\128\149\149\128\128\128\128\128\128\128\128\131\131\128\138\130\131\131\144\149\138\143\143\128\149\149\128\143\143\129\135\128\128", "333ee0e3eee31e333333033333333333033e0e1113103eee033", "3e000e101110e10e33303330373300033000e00000010000333")
	term.setCursorPos(1, 5)
	term.blit("\128\128\128\134\130\144\148\128\143\143\143\128\153\145\128\153\145\128\128\149\149\128\128\128\128\128\128\128\128\128\128\128\128\128\153\130\130\149\151\131\131\128\149\149\128\131\131\129\155\128\128", "333301030003113ee3330333333333333330e10003103000333", "330ee0101110ee03333033303733033333ee001140010eeee33")
	term.setCursorPos(1, 6)
	term.blit("\128\136\128\153\144\133\149\128\137\137\129\128\153\153\128\153\132\128\128\149\149\128\128\128\128\128\128\128\128\128\128\128\128\136\153\133\149\149\149\145\137\128\149\149\128\128\128\157\153\144\128", "38338e034443ee33e3330333333333333ee30e0e4310333ee83", "330ee0101110110e33303330373303333330101110010ee3333")
	term.setCursorPos(1, 7)
	term.blit("\128\128\143\143\143\135\129\143\153\155\153\143\153\129\143\153\153\128\128\138\133\128\128\143\143\143\143\133\143\143\143\143\138\143\143\135\128\138\133\153\155\143\138\133\143\159\132\152\153\128\128", "330000801110110ee3300330000000000000300110000e83333", "333eeee1eeeeeee33333333777733333333eeeeeeeeee8eee33")
	term.setCursorPos(1, 8)
	term.blit("\128\128\130\153\153\144\128\134\134\130\130\136\144\159\152\153\134\128\128\128\128\128\151\128\128\143\128\128\148\128\128\128\128\128\137\153\155\128\130\130\134\134\130\129\132\159\159\153\129\128\128", "33e3333111188e33e33333333733733333eee31111118eeee33", "333eeeeeeeeee8ee333333777877333333333eeeeeeee333333")
	term.setCursorPos(1, 9)
	term.blit("\128\128\128\137\137\137\155\159\159\128\128\159\153\157\153\133\128\128\128\128\128\151\128\128\149\128\149\128\128\148\128\128\128\128\128\153\153\152\144\144\130\144\144\152\152\153\134\130\128\128\128", "333eeeeee33eeeee333333337383373333333383833333ee333", "333333333ee333333333377788777333333eeeeeeeeeee33333")
	term.setCursorPos(1, 10)
	term.blit("\128\128\128\128\128\128\130\153\153\153\150\134\134\134\128\128\137\128\144\128\159\155\155\159\157\156\158\159\155\155\132\128\128\128\152\129\137\137\153\153\137\153\153\137\137\129\128\128\128\128\128", "333333e333eeee3383837777777777833388eeeeeeeeee33333", "3333333eee33333333338888888888733333333333333333333")
	term.setCursorPos(1, 11)
	term.blit("\128\128\128\128\128\128\128\128\128\129\129\128\128\128\128\128\128\128\130\139\128\153\153\153\153\153\153\153\153\153\129\143\134\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128", "333333333ee3333333833888888888838333333333333333333", "3333333333333333333e77777777777e3333333333333333333")
	term.setCursorPos(1, 12)
	term.blit("\128\128\128\152\136\136\136\136\129\129\129\129\129\129\129\129\129\129\129\129\131\131\131\131\131\131\131\131\131\131\131\129\129\129\129\129\129\137\136\136\136\136\136\144\144\144\128\128\128\128\128", "333888888888888888887777777777788888888888888833333", "333333333333333333330000000000033333333333333333333")
	term.setCursorPos(1, 13)
	term.blit("\128\130\128\128\128\159\155\137\139\155\128\128\128\128\128\128\128\128\130\147\128\128\128\128\128\128\128\128\128\128\128\156\129\128\128\128\128\128\128\128\128\159\155\147\159\130\130\130\132\132\128", "383333333333333333933333333333399333333333333888883", "33333eeeee3333333339000000000003333333333eeee333333")
	term.setCursorPos(1, 14)
	term.blit("\128\128\128\128\152\134\136\152\144\130\153\128\128\128\128\151\147\143\143\141\128\128\128\128\128\128\128\128\128\128\128\142\143\143\156\132\128\128\128\128\152\134\159\155\130\153\144\128\128\128\128", "3333e31113e33333333333333333333333993333e3ee3ee3333", "33333eeeee3333399999000000000009993333333e11e333333")
	term.setCursorPos(1, 15)
	term.blit("\143\143\144\128\153\128\153\129\137\128\137\128\128\143\143\143\143\143\143\137\128\128\128\128\128\128\128\128\128\128\128\134\140\140\140\128\128\128\128\128\153\128\153\130\153\128\153\128\128\128\128", "33b333eee3333333999333333333333399933333331e1333333", "bb33ee111ee33bbbbbb900000000000933333333eee1eee3333")
	term.setCursorPos(1, 16)
	term.blit("\128\128\128\128\128\131\131\131\131\129\128\128\128\128\128\128\128\128\128\128\143\143\143\143\143\143\143\143\143\143\143\128\128\128\128\128\128\128\131\131\139\144\153\128\153\159\135\131\131\129\128", "33333ee11e333333333300000000000333333333ebe3eee3333", "bbbbbbbbbbbbbbbbbbbbbbbb777bbbbbbbbbbbbbbe111bbbbbb")
	term.setCursorPos(1, 17)
	term.blit("\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128", "333333333333333333333333333333333333333333333333333", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
	term.setCursorPos(1, 18)
	term.blit("\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128", "333333333333333333333333333333333333333333333333333", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
	term.setCursorPos(1, 19)
	term.blit("\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128\128", "333333333333333333333333333333333333333333333333333", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
end

local function drawMenuText(lineA, lineB, lineC, selected)
    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    term.setCursorPos(21, 13)
    term.write(" " .. lineA .. " ")
    term.setCursorPos(21, 14)
    term.write(" " .. lineB .. " ")
    term.setCursorPos(21, 15)
    term.write(" " .. lineC .. " ")
    if selected then
        term.setCursorPos(21, selected + 12)
        term.write(">")
        term.setCursorPos(31, selected + 12)
        term.write("<")
    end
end

local function drawBoard(board, x, y, small)
    if small then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(x, y)
        term.write(" A BC DE FG HI J")
        for by = 1, 8 do
            local line, fg, bg = tostring(by) .. ("\x88\x95\x84"):rep(5), "0", "f"
            for bx = 1, 10, 2 do
                local c1, c2 = board[by][bx], board[by][bx+1]
                local b1, f1 = "b", "b"
                if bit32.btest(c1, mask.hasShip) then b1, f1 = "7", "7"
                elseif bit32.btest(c1, mask.hover) then b1, f1 = "8", "8" end
                if bit32.btest(c1, mask.hit) then f1 = "e"
                elseif bit32.btest(c1, mask.miss) then f1 = "0" end
                local b2, f2 = "b", "b"
                if bit32.btest(c2, mask.hasShip) then b2, f2 = "7", "7"
                elseif bit32.btest(c2, mask.hover) then b2, f2 = "8", "8" end
                if bit32.btest(c2, mask.hit) then f2 = "e"
                elseif bit32.btest(c2, mask.miss) then f2 = "0" end
                fg, bg = fg .. f1 .. b1 .. f2, bg .. b1 .. b2 .. b2
            end
            term.setCursorPos(x, y + by)
            term.blit(line, fg, bg)
        end
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(x, y)
        term.write("  A  B  C  D  E  F  G  H  I  J")
        for by = 1, 8 do
            local line1, line2, fg1, fg2, bg1, bg2 = tostring(by) .. ("\x80\x8F\x80"):rep(10), ("\x80\x83\x80"):rep(10), "0", "", "f", ""
            for bx = 1, 10 do
                local c, b, f = board[by][bx], "b", "b"
                if bit32.btest(c, mask.hasShip) then b, f = "7", "7"
                elseif bit32.btest(c, mask.hover) then b, f = "8", "8" end
                if bit32.btest(c, mask.hit) then f = "e"
                elseif bit32.btest(c, mask.miss) then f = "0" end
                fg1, bg1, fg2, bg2 = fg1 .. "0" .. b .. "0", bg1 .. b .. f .. b, fg2 .. "0" .. f .. "0", bg2 .. b:rep(3)
            end
            term.setCursorPos(x, y + by * 2 - 1)
            term.blit(line1, fg1, bg1)
            term.setCursorPos(x + 1, y + by * 2)
            term.blit(line2, fg2, bg2)
        end
    end
end

local function drawStatus(myBoard, otherBoard, x, y, shooting, msg, color)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(x, y)
    term.write("\x11    Ships    \x1E")
    for k in pairs(ships) do
        y=y+1
        term.setTextColor(colors.white)
        term.setCursorPos(x + 2 + (5.5 - (#k / 2)), y)
        term.write(k)
        term.setCursorPos(x + 14, y)
        if myBoard.ships[k].ok then term.blit("\x02", "5", "f")
        else term.blit("\xD7", "e", "f") end
        term.setCursorPos(x, y)
        if otherBoard.ships[k].ok then term.blit("\x02", "e", "f")
        else term.blit("\xD7", "5", "f") end
    end
    term.setCursorPos(x, y + 2)
    if color then term.setTextColor(color)
    else term.setTextColor(colors.lightBlue) end
    if msg then term.write(msg)
    else term.write(shooting and "Take your shot!" or "   Waiting...  ") end
end

local function shoot(board, opponent, x, y)
    opponent.send({x = x, y = y})
    local hit
    parallel.waitForAny(function() hit = opponent.receive() end, function() sleep(5) error("Timeout") end)
    board[y][x] = bit32.bor(board[y][x], hit and mask.hit or mask.miss)
    if type(hit) == "string" then board.ships[hit].ok = false end
    return hit
end

local function awaitShot(board, opponent, cb)
    while true do
        local msg = opponent.receive()
        if msg == "quit" then return false
        elseif msg ~= "ready" then
            if type(msg) ~= "table" or type(msg.x) ~= "number" or type(msg.y) ~= "number" then error("Invalid message from opponent") end
            local hit = bit32.btest(board[msg.y][msg.x], mask.hasShip)
            board[msg.y][msg.x] = bit32.bor(board[msg.y][msg.x], hit and mask.hit or mask.miss)
            if hit then
                for k,v in pairs(board.ships) do
                    local found, all = false, true
                    for i = 1, ships[k] do
                        if not found and msg.y == v.y + (v.r and i - 1 or 0) and msg.x == v.x + (v.r and 0 or i - 1) then found = true end
                        if not bit32.btest(board[v.y + (v.r and i - 1 or 0)][v.x + (v.r and 0 or i - 1)], mask.hit) then all = false break end
                    end
                    if found and all then v.ok, hit = false, k break end
                end
            end
            opponent.send(hit)
            if cb then
                local v = cb(msg.x, msg.y, hit)
                if v ~= nil then return v end
            end
            if not hit then return true end
        end
    end
end

local function addShip(board, x, y, r, s, temp)
    local b = false
    for i = 1, s do
        board[y + (r and i - 1 or 0)][x + (r and 0 or i - 1)] = bit32.bor(board[y + (r and i - 1 or 0)][x + (r and 0 or i - 1)], temp and mask.hover or mask.hasShip)
        b = b or bit32.btest(board[y + (r and i - 1 or 0)][x + (r and 0 or i - 1)], mask.hasShip)
    end
    return b
end

local function removeShip(board, x, y, r, s)
    for i = 1, s do
        board[y + (r and i - 1 or 0)][x + (r and 0 or i - 1)] = bit32.band(board[y + (r and i - 1 or 0)][x + (r and 0 or i - 1)], bit32.bnot(mask.hover))
    end
end

local opponent, shooting
local myBoard, otherBoard = {ships = {}}, {ships = {}}
for i = 1, 8 do myBoard[i], otherBoard[i] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0} end

local speaker = peripheral.find("speaker")
local modem = peripheral.find("modem")
if not modem then error("Please attach a modem.") end
rednet.open(peripheral.getName(modem))
term.clear()
drawMainMenu()
do
    local function hostGame()
        drawMenuText("Game Name", "         ", "   OK    ", 3)
        local win = window.create(term.current(), 22, 14, 9, 1)
        win.setBackgroundColor(colors.lightGray)
        win.setTextColor(colors.black)
        win.clear()
        local oldterm = term.redirect(win)
        local text = read()
        term.redirect(oldterm)
        if speaker then speaker.playSound("ui.button.click") end
        if text == "" then return end
        drawMenuText("Waiting..", "         ", "   Back  ", 3)
        rednet.host("jmw.battleship", text)
        parallel.waitForAny(function()
            while true do if select(2, os.pullEvent("key")) == keys.enter then
                if speaker then speaker.playSound("ui.button.click") end
                return
            end end
        end, function()
            opponent = rednetConnection.host()
            shooting = true
        end, function()
            while true do
                local id, msg = rednet.receive("jmw.battleship")
                if msg == "hostname" then rednet.send(id, text, "jmw.battleship") end
            end
        end)
        rednet.unhost("jmw.battleship", text)
    end
    local function joinGame()
        local function ew(s)
            if not s then return "         "
            elseif #s > 9 then return s:sub(1, 9)
            elseif #s < 9 then return s .. (" "):rep(9 - #s)
            else return s end
        end
        local function getName(id)
            rednet.send(id, "hostname", "jmw.battleship")
            while true do
                local sender, msg = rednet.receive("jmw.battleship", 2)
                if sender == nil then return tostring(id)
                elseif sender == id then return msg end
            end
        end
        drawMenuText("Searching", "         ", "         ")
        local ids = rednet.lookup("jmw.battleship")
        if ids then
            if type(ids) == "number" then ids = {ids} end
            local names = {[0] = "   Back  "}
            local coros = {}
            for i,v in ipairs(ids) do coros[i] = function() names[i] = getName(v) end end
            parallel.waitForAll(table.unpack(coros))
            local selected = 1
            drawMenuText(ew(names[math.max(selected - 2, 0)]), ew(names[math.max(selected - 1, 1)]), ew(names[math.max(selected, 2)]), math.min(selected + 1, 3))
            while true do
                local ev, p1, p2, p3 = os.pullEvent()
                if ev == "key" then
                    if p1 == keys.up and selected > 0 then selected = selected - 1
                    elseif p1 == keys.down and selected < #ids then selected = selected + 1
                    elseif p1 == keys.enter then
                        if speaker then speaker.playSound("ui.button.click") end
                        if selected == 0 then return else
                            drawMenuText("Connect..", "         ", "         ")
                            opponent = rednetConnection.connect(ids[selected])
                            if opponent then
                                shooting = false
                                return
                            end
                            drawMenuText("  Failed ", "         ", "   Back  ", 3)
                            while true do if select(2, os.pullEvent("key")) == keys.enter then break end end
                            if speaker then speaker.playSound("ui.button.click") end
                        end
                    end
                    drawMenuText(ew(names[math.max(selected - 2, 0)]), ew(names[math.max(selected - 1, 1)]), ew(names[math.max(selected, 2)]), math.min(selected + 1, 3))
                end
            end
        else
            drawMenuText("No games ", "         ", "   Back  ", 3)
            while true do if select(2, os.pullEvent("key")) == keys.enter then break end end
            if speaker then speaker.playSound("ui.button.click") end
        end
    end
    local selected = 1
    drawMenuText("Host Game", "Join Game", "   Quit  ", selected)
    while not opponent do
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "key" then
            if p1 == keys.up and selected > 1 then selected = selected - 1
            elseif p1 == keys.down and selected < 3 then selected = selected + 1
            elseif p1 == keys.enter then
                if speaker then speaker.playSound("ui.button.click") end
                if selected == 1 then hostGame()
                elseif selected == 2 then joinGame()
                else
                    term.setBackgroundColor(colors.black)
                    term.setTextColor(colors.white)
                    term.clear()
                    term.setCursorPos(1, 1)
                    return
                end
            end
            if not opponent then drawMenuText("Host Game", "Join Game", "   Quit  ", selected) end
        end
    end
end

for k, v in pairs(ships) do
    otherBoard.ships[k] = {ok = true}
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.clear()
    term.setCursorPos(35, 3)
    term.write("Please place the")
    term.setCursorPos(36 + (8 - (#k / 2)), 4)
    term.write(k:upper())
    term.setCursorPos(37, 5)
    term.write("on the board.")
    term.setCursorPos(37, 7)
    term.write("\x1B\x18\x19\x1A to move,")
    term.setCursorPos(38, 8)
    term.write("R to rotate,")
    term.setCursorPos(36, 9)
    term.write("Enter to place.")
    local x, y, r = 1, 1, false
    local pcx, pcy
    local ok = not addShip(myBoard, x, y, r, v, true)
    while true do
        drawBoard(myBoard, 2, 2)
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "key" then
            if p1 == keys.up and y > 1 then
                removeShip(myBoard, x, y, r, v)
                y = y - 1
                ok = not addShip(myBoard, x, y, r, v, true)
            elseif p1 == keys.down and y < (r and 9 - v or 8) then
                removeShip(myBoard, x, y, r, v)
                y = y + 1
                ok = not addShip(myBoard, x, y, r, v, true)
            elseif p1 == keys.left and x > 1 then
                removeShip(myBoard, x, y, r, v)
                x = x - 1
                ok = not addShip(myBoard, x, y, r, v, true)
            elseif p1 == keys.right and x < (r and 10 or 11 - v) then
                removeShip(myBoard, x, y, r, v)
                x = x + 1
                ok = not addShip(myBoard, x, y, r, v, true)
            elseif p1 == keys.r and ((r and x < 12 - v) or (not r and y < 10 - v)) then
                removeShip(myBoard, x, y, r, v)
                r = not r
                ok = not addShip(myBoard, x, y, r, v, true)
            elseif p1 == keys.enter then
                if ok then
                    removeShip(myBoard, x, y, r, v)
                    addShip(myBoard, x, y, r, v)
                    myBoard.ships[k] = {x = x, y = y, r = r, ok = true}
                    break
                else
                    term.setTextColor(colors.red)
                    term.setBackgroundColor(colors.black)
                    term.setCursorPos(37, 11)
                    term.write("Ships cannot")
                    term.setCursorPos(39, 12)
                    term.write("collide.")
                end
            elseif p1 == keys.q then
                return
            end
        elseif (ev == "mouse_click" or ev == "mouse_drag") and p1 == 1 then
            local cx, cy = math.floor((p2 - 3) / 3) + 1, math.floor((p3 - 3) / 2) + 1
            if cx >= 1 and cx <= 10 and cy >= 1 and cy <= 8 and ((r and cy <= 9 - v) or (not r and cx <= 11 - v)) then
                removeShip(myBoard, x, y, r, v)
                if ev == "mouse_click" then
                    if x == cx and y == cy then pcx, pcy = p2, p3
                    else pcx, pcy = nil end
                end
                x, y = cx, cy
                ok = not addShip(myBoard, x, y, r, v, true)
            end
        elseif ev == "mouse_click" and p1 == 2 and ((r and x < 12 - v) or (not r and y < 10 - v)) then
            removeShip(myBoard, x, y, r, v)
            r = not r
            ok = not addShip(myBoard, x, y, r, v, true)
        elseif ev == "mouse_up" and p1 == 1 and p2 == pcx and p3 == pcy then
            if ok then
                removeShip(myBoard, x, y, r, v)
                addShip(myBoard, x, y, r, v)
                myBoard.ships[k] = {x = x, y = y, r = r, ok = true}
                break
            else
                term.setTextColor(colors.red)
                term.setBackgroundColor(colors.black)
                term.setCursorPos(37, 11)
                term.write("Ships cannot")
                term.setCursorPos(39, 12)
                term.write("collide.")
            end
        end
    end
    if speaker then speaker.playSound("minecraft:block.stone.place") end
end

term.clear()
drawBoard(myBoard, 2, 2)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.lightBlue)
term.setCursorPos(37, 9)
term.write("Waiting for")
term.setCursorPos(37, 10)
term.write("opponent...")
opponent.send("ready")
while true do if opponent.receive() == "ready" then opponent.send("ready") break end end
if speaker then speaker.playSound("minecraft:entity.experience_orb.pickup") end
term.clear()

local win
local x, y = 1, 1
while win == nil do
    drawBoard(otherBoard, 2, 2)
    drawBoard(myBoard, 34, 2, true)
    drawStatus(myBoard, otherBoard, 35, 11, shooting)
    if shooting then
        local pcx, pcy
        otherBoard[y][x] = bit32.bor(otherBoard[y][x], mask.hover)
        while true do
            drawBoard(otherBoard, 2, 2)
            local ev, p1, p2, p3 = os.pullEvent()
            if ev == "key" then
                if p1 == keys.up and y > 1 then
                    otherBoard[y][x] = bit32.band(otherBoard[y][x], bit32.bnot(mask.hover))
                    y = y - 1
                    otherBoard[y][x] = bit32.bor(otherBoard[y][x], mask.hover)
                elseif p1 == keys.down and y < 8 then
                    otherBoard[y][x] = bit32.band(otherBoard[y][x], bit32.bnot(mask.hover))
                    y = y + 1
                    otherBoard[y][x] = bit32.bor(otherBoard[y][x], mask.hover)
                elseif p1 == keys.left and x > 1 then
                    otherBoard[y][x] = bit32.band(otherBoard[y][x], bit32.bnot(mask.hover))
                    x = x - 1
                    otherBoard[y][x] = bit32.bor(otherBoard[y][x], mask.hover)
                elseif p1 == keys.right and x < 10 then
                    otherBoard[y][x] = bit32.band(otherBoard[y][x], bit32.bnot(mask.hover))
                    x = x + 1
                    otherBoard[y][x] = bit32.bor(otherBoard[y][x], mask.hover)
                elseif p1 == keys.enter and not bit32.btest(otherBoard[y][x], mask.hit + mask.miss) then
                    otherBoard[y][x] = bit32.band(otherBoard[y][x], bit32.bnot(mask.hover))
                    local hit = shoot(otherBoard, opponent, x, y)
                    if speaker then
                        if type(hit) == "string" then speaker.playSound("minecraft:entity.generic.explode")
                        elseif hit then speaker.playSound("minecraft:entity.experience_orb.pickup")
                        else speaker.playSound("minecraft:entity.generic.splash") end
                    end
                    drawBoard(otherBoard, 2, 2)
                    drawStatus(myBoard, otherBoard, 35, 11, shooting, "   " .. toCoords(x, y) .. ": " .. (hit and "Hit! " or "Miss!") .. "   ", hit and colors.lime or colors.red)
                    sleep(1)
                    drawStatus(myBoard, otherBoard, 35, 11, shooting)
                    if not hit then break end
                    otherBoard[y][x] = bit32.bor(otherBoard[y][x], mask.hover)
                    local f = true
                    for k,v in pairs(otherBoard.ships) do if v.ok then f = false break end end
                    if f then win = true break end
                elseif p1 == keys.q then
                    opponent.send("quit")
                    win = false
                    break
                end
            elseif (ev == "mouse_click" or ev == "mouse_drag") and p1 == 1 then
                local cx, cy = math.floor((p2 - 3) / 3) + 1, math.floor((p3 - 3) / 2) + 1
                if cx >= 1 and cx <= 10 and cy >= 1 and cy <= 8 then
                    otherBoard[y][x] = bit32.band(otherBoard[y][x], bit32.bnot(mask.hover))
                    if ev == "mouse_click" then
                        if x == cx and y == cy then pcx, pcy = p2, p3
                        else pcx, pcy = nil end
                    end
                    x, y = cx, cy
                    otherBoard[y][x] = bit32.bor(otherBoard[y][x], mask.hover)
                end
            elseif ev == "mouse_up" and p1 == 1 and p2 == pcx and p3 == pcy and not bit32.btest(otherBoard[y][x], mask.hit + mask.miss) then
                otherBoard[y][x] = bit32.band(otherBoard[y][x], bit32.bnot(mask.hover))
                local hit = shoot(otherBoard, opponent, x, y)
                if speaker then
                    if type(hit) == "string" then speaker.playSound("minecraft:entity.generic.explode")
                    elseif hit then speaker.playSound("minecraft:entity.experience_orb.pickup")
                    else speaker.playSound("minecraft:entity.generic.splash") end
                end
                drawBoard(otherBoard, 2, 2)
                drawStatus(myBoard, otherBoard, 35, 11, shooting, "   " .. toCoords(x, y) .. ": " .. (hit and "Hit! " or "Miss!") .. "   ", hit and colors.lime or colors.red)
                sleep(1)
                drawStatus(myBoard, otherBoard, 35, 11, shooting)
                if not hit then break end
                otherBoard[y][x] = bit32.bor(otherBoard[y][x], mask.hover)
                local f = true
                for k,v in pairs(otherBoard.ships) do if v.ok then f = false break end end
                if f then win = true break end
            end
        end
    else
        if not awaitShot(myBoard, opponent, function(x, y, hit)
            drawBoard(myBoard, 34, 2, true)
            if speaker then
                if type(hit) == "string" then speaker.playSound("minecraft:entity.generic.explode")
                elseif hit then speaker.playSound("minecraft:entity.experience_orb.pickup")
                else speaker.playSound("minecraft:entity.generic.splash") end
            end
            drawStatus(myBoard, otherBoard, 35, 11, shooting, "   " .. toCoords(x, y) .. ": " .. (hit and "Hit! " or "Miss!") .. "   ", hit and colors.red or colors.lime)
            sleep(1)
            drawStatus(myBoard, otherBoard, 35, 11, shooting)
            local f = true
            for k,v in pairs(myBoard.ships) do if v.ok then f = false break end end
            if f then win = false return false end
        end) then break end
    end
    shooting = not shooting
    local f = true
    for k,v in pairs(myBoard.ships) do if v.ok then f = false break end end
    if f then win = false end
    f = true
    for k,v in pairs(otherBoard.ships) do if v.ok then f = false break end end
    if f then win = true end
end

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
if win then
    term.setTextColor(colors.lime)
    print("You win!")
    if speaker then speaker.playSound("minecraft:ui.toast.challenge_complete") end
else
    term.setTextColor(colors.red)
    print("You lose!")
    if speaker then speaker.playSound("minecraft:entity.ghast.death") end
end
term.setTextColor(colors.white)
print("Press any key to exit.")
os.pullEvent("key_up")