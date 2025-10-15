local diceMaps = {
    [0] = { 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0 },
    { 0x20, 0x10, 0x95, 0x8f, 0x8f, 0x85 },
    { 0x08, 0x20, 0x95, 0x8f, 0x8d, 0x85 },
    { 0x08, 0x10, 0x95, 0x8f, 0x8d, 0x85 },
    { 0x08, 0x08, 0x95, 0x8d, 0x8d, 0x85 },
    { 0x08, 0x18, 0x95, 0x8d, 0x8d, 0x85 },
    { 0x97, 0x97, 0x95, 0x8d, 0x8d, 0x85 }
}

local positions = {
    dice = { x = 2, y = 17 },
    rollCup = { x = 36, y = 15 },
    logo = { x = 2, y = 2 },
    status = { x = 23, y = 3 },
    scores = { x = 2, y = 7 }
}

local dice = { { value = 0 }, { value = 0 }, { value = 0 }, { value = 0 }, { value = 0 } }

local function drawDie(x, y, n, b)
    b = b or '0'
    local f = 'f'
    local d = diceMaps[n]
    term.setCursorPos(x, y)
    for i = 1, 3 do
        local c = d[i]
        if c == 0x20 then
            term.blit(' ', f, b)
        elseif c < 0x80 then
            term.blit(string.char(c + 0x80), f, b)
        else
            term.blit(string.char(c), b, f)
        end
    end
    term.setCursorPos(x, y + 1)
    for i = 4, 6 do
        local c = d[i]
        if c == 0x20 then
            term.blit(' ', f, b)
        elseif c < 0x80 then
            term.blit(string.char(c + 0x80), f, b)
        else
            term.blit(string.char(c), b, f)
        end
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

term.clear()
for _, v in ipairs(dice) do if not v.locked then v.value = math.random(1, 6) end end
drawDie(positions.dice.x + (1 - 1) * 3, positions.dice.y, dice[1].value, dice[1].locked and '4' or '0')

while true do
    local ev = { os.pullEvent() }
    if ev[1] == "key" then
        if ev[2] == keys.q then
            break
        elseif ev[2] == keys.one then
            dice[1].locked = not dice[1].locked
            drawDie(positions.dice.x + (1 - 1) * 3, positions.dice.y, dice[1].value, dice[1].locked and '4' or '0')
        end
    end
end

term.clear()
term.setCursorPos(1, 1)
