-- YahtCC by JackMacWindows
-- GPL license

local diceMaps = {
<<<<<<< HEAD
    [0] = {0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0},
    {0x20, 0x10, 0x95, 0x8f, 0x8f, 0x85},
    {0x08, 0x20, 0x95, 0x8f, 0x8d, 0x85},
    {0x08, 0x10, 0x95, 0x8f, 0x8d, 0x85},
    {0x08, 0x08, 0x95, 0x8d, 0x8d, 0x85},
    {0x08, 0x18, 0x95, 0x8d, 0x8d, 0x85},
    {0x97, 0x97, 0x95, 0x8d, 0x8d, 0x85}
}

local logo = {
    {0x2F, 0x34, 0x00, 0x38, 0x1F, 0x00, 0x00, 0x28, 0x14, 0x00, 0x00, 0x3C, 0x00, 0x00, 0x38, 0x3C, 0x14, 0x20, 0x3C, 0x3C},
    {0x00, 0x0B, 0x3F, 0x07, 0x00, 0x00, 0x00, 0x2A, 0x15, 0x00, 0x0F, 0x3F, 0x0F, 0x2A, 0x17, 0x00, 0x00, 0x3F, 0x01, 0x00},
    {0x00, 0x00, 0x3F, 0x00, 0x38, 0x0F, 0x3E, 0x2A, 0x1F, 0x2F, 0x14, 0x3F, 0x00, 0x2A, 0x15, 0x00, 0x00, 0x3F, 0x00, 0x00},
    {0x00, 0x00, 0x3F, 0x00, 0x0B, 0x3C, 0x2F, 0x2A, 0x15, 0x2A, 0x15, 0x3F, 0x00, 0x02, 0x2F, 0x3C, 0x14, 0x0B, 0x3D, 0x3C}
}

local rollcup = {
    {0x00, 0x3C, 0x30, 0x30, 0x38, 0x14, 0x00},
    {0x00, 0x15, 0x17, 0x17, 0x15, 0x15, 0x00},
    {0x00, 0x15, 0x15, 0x15, 0x15, 0x15, 0x00},
    {0x00, 0x35, 0x15, 0x15, 0x35, 0x15, 0x00},
    {0x00, 0x03, 0x0F, 0x0F, 0x07, 0x01, 0x00}
=======
    [0] = { 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0 },
    { 0x20, 0x10, 0x95, 0x8f, 0x8f, 0x85 },
    { 0x08, 0x20, 0x95, 0x8f, 0x8d, 0x85 },
    { 0x08, 0x10, 0x95, 0x8f, 0x8d, 0x85 },
    { 0x08, 0x08, 0x95, 0x8d, 0x8d, 0x85 },
    { 0x08, 0x18, 0x95, 0x8d, 0x8d, 0x85 },
    { 0x97, 0x97, 0x95, 0x8d, 0x8d, 0x85 }
}

local logo = {
    { 0x2F, 0x34, 0x00, 0x38, 0x1F, 0x00, 0x00, 0x28, 0x14, 0x00, 0x00, 0x3C, 0x00, 0x00, 0x38, 0x3C, 0x14, 0x20, 0x3C, 0x3C },
    { 0x00, 0x0B, 0x3F, 0x07, 0x00, 0x00, 0x00, 0x2A, 0x15, 0x00, 0x0F, 0x3F, 0x0F, 0x2A, 0x17, 0x00, 0x00, 0x3F, 0x01, 0x00 },
    { 0x00, 0x00, 0x3F, 0x00, 0x38, 0x0F, 0x3E, 0x2A, 0x1F, 0x2F, 0x14, 0x3F, 0x00, 0x2A, 0x15, 0x00, 0x00, 0x3F, 0x00, 0x00 },
    { 0x00, 0x00, 0x3F, 0x00, 0x0B, 0x3C, 0x2F, 0x2A, 0x15, 0x2A, 0x15, 0x3F, 0x00, 0x02, 0x2F, 0x3C, 0x14, 0x0B, 0x3D, 0x3C }
}

local rollcup = {
    { 0x00, 0x3C, 0x30, 0x30, 0x38, 0x14, 0x00 },
    { 0x00, 0x15, 0x17, 0x17, 0x15, 0x15, 0x00 },
    { 0x00, 0x15, 0x15, 0x15, 0x15, 0x15, 0x00 },
    { 0x00, 0x35, 0x15, 0x15, 0x35, 0x15, 0x00 },
    { 0x00, 0x03, 0x0F, 0x0F, 0x07, 0x01, 0x00 }
>>>>>>> origin/main
}

local scorecardNames = {
    {
<<<<<<< HEAD
        {name = ""},
        {name = "Ones", score = function(dice)
            local score = 0
            for _,i in ipairs(dice) do if i.value == 1 then score = score + i.value end end
            return score
        end},
        {name = "Twos", score = function(dice)
            local score = 0
            for _,i in ipairs(dice) do if i.value == 2 then score = score + i.value end end
            return score
        end},
        {name = "Threes", score = function(dice)
            local score = 0
            for _,i in ipairs(dice) do if i.value == 3 then score = score + i.value end end
            return score
        end},
        {name = "Fours", score = function(dice)
            local score = 0
            for _,i in ipairs(dice) do if i.value == 4 then score = score + i.value end end
            return score
        end},
        {name = "Fives", score = function(dice)
            local score = 0
            for _,i in ipairs(dice) do if i.value == 5 then score = score + i.value end end
            return score
        end},
        {name = "Sixes", score = function(dice)
            local score = 0
            for _,i in ipairs(dice) do if i.value == 6 then score = score + i.value end end
            return score
        end},
        {name = "Bonus"}
    },
    {
        {name = "Three of a Kind", score = function(dice)
            local counts = {0, 0, 0, 0, 0, 0}
            local ok = false
            local sum = 0
            for _,i in ipairs(dice) do
                counts[i.value] = counts[i.value] + 1
                sum = sum + i.value
                if counts[i.value] >= 3 then ok = true end
            end
            return ok and sum or 0
        end},
        {name = "Four of a Kind", score = function(dice)
            local counts = {0, 0, 0, 0, 0, 0}
            local ok = false
            local sum = 0
            for _,i in ipairs(dice) do
                counts[i.value] = counts[i.value] + 1
                sum = sum + i.value
                if counts[i.value] >= 4 then ok = true end
            end
            return ok and sum or 0
        end},
        {name = "Full House", score = function(dice, scores)
            local counts = {0, 0, 0, 0, 0, 0}
            for _,i in ipairs(dice) do counts[i.value] = counts[i.value] + 1 end
            local three, two, yahtzee = false, false, nil
            for i = 1, 6 do
                if counts[i] == 3 then three = true
                elseif counts[i] == 2 then two = true 
                elseif counts[i] == 5 then yahtzee = i end
            end
            if yahtzee and scores[2][6].locked and not scores[1][yahtzee+1].locked then return 25 end
            return (three and two) and 25 or 0
        end},
        {name = "Small Straight", score = function(dice, scores)
            local counts = {0, 0, 0, 0, 0, 0}
            local yahtzee = nil
            for _,i in ipairs(dice) do counts[i.value] = counts[i.value] + 1 if counts[i.value] == 5 then yahtzee = i.value end end
            if yahtzee and scores[2][6].locked and not scores[1][yahtzee+1].locked then return 30 end
            if counts[3] == 0 or counts[4] == 0 then return 0
            elseif (counts[1] ~= 0 and counts[2] ~= 0) or
                   (counts[2] ~= 0 and counts[5] ~= 0) or
                   (counts[5] ~= 0 and counts[6] ~= 0) then return 30 end
            return 0
        end},
        {name = "Large Straight", score = function(dice, scores)
            local counts = {0, 0, 0, 0, 0, 0}
            local yahtzee = nil
            for _,i in ipairs(dice) do counts[i.value] = counts[i.value] + 1 if counts[i.value] == 5 then yahtzee = i.value end end
            if yahtzee and scores[2][6].locked and not scores[1][yahtzee+1].locked then return 30 end
            if counts[2] == 0 or counts[3] == 0 or counts[4] == 0 or counts[5] == 0 then return 0 end
            return (counts[1] ~= 0 or counts[6] ~= 0) and 40 or 0
        end},
        {name = "Yahtzee", score = function(dice)
            local c = dice[1].value
            for _,i in ipairs(dice) do if c ~= i.value then return 0 end end
            return 50
        end},
        {name = "Chance", score = function(dice)
            local sum = 0
            for _,i in ipairs(dice) do sum = sum + i.value end
            return sum
        end},
        {name = "Yahtzee Bonus"}
=======
        { name = "" },
        {
            name = "Ones",
            score = function(dice)
                local score = 0
                for _, i in ipairs(dice) do if i.value == 1 then score = score + i.value end end
                return score
            end
        },
        {
            name = "Twos",
            score = function(dice)
                local score = 0
                for _, i in ipairs(dice) do if i.value == 2 then score = score + i.value end end
                return score
            end
        },
        {
            name = "Threes",
            score = function(dice)
                local score = 0
                for _, i in ipairs(dice) do if i.value == 3 then score = score + i.value end end
                return score
            end
        },
        {
            name = "Fours",
            score = function(dice)
                local score = 0
                for _, i in ipairs(dice) do if i.value == 4 then score = score + i.value end end
                return score
            end
        },
        {
            name = "Fives",
            score = function(dice)
                local score = 0
                for _, i in ipairs(dice) do if i.value == 5 then score = score + i.value end end
                return score
            end
        },
        {
            name = "Sixes",
            score = function(dice)
                local score = 0
                for _, i in ipairs(dice) do if i.value == 6 then score = score + i.value end end
                return score
            end
        },
        { name = "Bonus" }
    },
    {
        {
            name = "Three of a Kind",
            score = function(dice)
                local counts = { 0, 0, 0, 0, 0, 0 }
                local ok = false
                local sum = 0
                for _, i in ipairs(dice) do
                    counts[i.value] = counts[i.value] + 1
                    sum = sum + i.value
                    if counts[i.value] >= 3 then ok = true end
                end
                return ok and sum or 0
            end
        },
        {
            name = "Four of a Kind",
            score = function(dice)
                local counts = { 0, 0, 0, 0, 0, 0 }
                local ok = false
                local sum = 0
                for _, i in ipairs(dice) do
                    counts[i.value] = counts[i.value] + 1
                    sum = sum + i.value
                    if counts[i.value] >= 4 then ok = true end
                end
                return ok and sum or 0
            end
        },
        {
            name = "Full House",
            score = function(dice, scores)
                local counts = { 0, 0, 0, 0, 0, 0 }
                for _, i in ipairs(dice) do counts[i.value] = counts[i.value] + 1 end
                local three, two, yahtzee = false, false, nil
                for i = 1, 6 do
                    if counts[i] == 3 then
                        three = true
                    elseif counts[i] == 2 then
                        two = true
                    elseif counts[i] == 5 then
                        yahtzee = i
                    end
                end
                if yahtzee and scores[2][6].locked and not scores[1][yahtzee + 1].locked then return 25 end
                return (three and two) and 25 or 0
            end
        },
        {
            name = "Small Straight",
            score = function(dice, scores)
                local counts = { 0, 0, 0, 0, 0, 0 }
                local yahtzee = nil
                for _, i in ipairs(dice) do
                    counts[i.value] = counts[i.value] + 1
                    if counts[i.value] == 5 then yahtzee = i.value end
                end
                if yahtzee and scores[2][6].locked and not scores[1][yahtzee + 1].locked then return 30 end
                if counts[3] == 0 or counts[4] == 0 then
                    return 0
                elseif (counts[1] ~= 0 and counts[2] ~= 0) or
                    (counts[2] ~= 0 and counts[5] ~= 0) or
                    (counts[5] ~= 0 and counts[6] ~= 0) then
                    return 30
                end
                return 0
            end
        },
        {
            name = "Large Straight",
            score = function(dice, scores)
                local counts = { 0, 0, 0, 0, 0, 0 }
                local yahtzee = nil
                for _, i in ipairs(dice) do
                    counts[i.value] = counts[i.value] + 1
                    if counts[i.value] == 5 then yahtzee = i.value end
                end
                if yahtzee and scores[2][6].locked and not scores[1][yahtzee + 1].locked then return 30 end
                if counts[2] == 0 or counts[3] == 0 or counts[4] == 0 or counts[5] == 0 then return 0 end
                return (counts[1] ~= 0 or counts[6] ~= 0) and 40 or 0
            end
        },
        {
            name = "Yahtzee",
            score = function(dice)
                local c = dice[1].value
                for _, i in ipairs(dice) do if c ~= i.value then return 0 end end
                return 50
            end
        },
        {
            name = "Chance",
            score = function(dice)
                local sum = 0
                for _, i in ipairs(dice) do sum = sum + i.value end
                return sum
            end
        },
        { name = "Yahtzee Bonus" }
>>>>>>> origin/main
    }
}

local function drawDie(x, y, n, b)
    b = b or '0'
    local f = 'f'
    local d = diceMaps[n]
    term.setCursorPos(x, y)
    for i = 1, 3 do
        local c = d[i]
<<<<<<< HEAD
        if c == 0x20 then term.blit(' ', f, b)
        elseif c < 0x80 then term.blit(string.char(c + 0x80), f, b)
        else term.blit(string.char(c), b, f) end
    end
    term.setCursorPos(x, y+1)
    for i = 4, 6 do
        local c = d[i]
        if c == 0x20 then term.blit(' ', f, b)
        elseif c < 0x80 then term.blit(string.char(c + 0x80), f, b)
        else term.blit(string.char(c), b, f) end
=======
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
>>>>>>> origin/main
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

local function drawDice(x, y, dice)
<<<<<<< HEAD
    for n,i in ipairs(dice) do drawDie(x + (n-1)*3, y, i.value, i.locked and '4' or '0') end
=======
    for n, i in ipairs(dice) do drawDie(x + (n - 1) * 3, y, i.value, i.locked and '4' or '0') end
>>>>>>> origin/main
end

local function drawLogo(xx, yy, ff)
    ff = ff or '0'
    for y = 1, 4 do
        term.setCursorPos(xx, yy + y - 1)
<<<<<<< HEAD
        for _,c in ipairs(logo[y]) do
=======
        for _, c in ipairs(logo[y]) do
>>>>>>> origin/main
            local f, b = ff, 'f'
            if bit32.btest(c, 0x20) then
                f, b = b, f
                c = bit32.band(bit32.bnot(c), 0x1F)
            end
            c = bit32.bor(c, 0x80)
            if c == 0x80 then c = 0x20 end
            term.blit(string.char(c), f, b)
        end
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

local function drawRollCup(xx, yy, color, rolling)
    color = color or 'b'
    for y = 1, 5 do
        term.setCursorPos(xx - 1, yy + y - 1)
<<<<<<< HEAD
        for x,c in ipairs(rollcup[y]) do
            local f, b
            if y > 1 and y < 5 and x > 1 and x < 6 then f, b = color, '8'
            else f, b = color, 'f' end
=======
        for x, c in ipairs(rollcup[y]) do
            local f, b
            if y > 1 and y < 5 and x > 1 and x < 6 then
                f, b = color, '8'
            else
                f, b = color, 'f'
            end
>>>>>>> origin/main
            if bit32.btest(c, 0x20) then
                f, b = b, f
                c = bit32.band(bit32.bnot(c), 0x1F)
            end
            c = bit32.bor(c, 0x80)
            if c == 0x80 then c = 0x20 end
            term.blit(string.char(c), f, b)
        end
    end
    term.setCursorPos(xx - 6, yy + 2)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.write(rolling and "      " or " Roll ")
end

local function drawScores(x, y, scores, selectcol, selectrow)
    term.setBackgroundColor(colors.black)
    term.setCursorBlink(false)
    for e = 1, 2 do
<<<<<<< HEAD
        for i,v in ipairs(scorecardNames[e]) do
            local selected = e == selectcol and i == selectrow
            term.setBackgroundColor(selected and colors.white or (i % 2 == 1 and colors.black or colors.gray))
            term.setTextColor(selected and colors.black or colors.white)
            term.setCursorPos(x + (e - 1)*20, y + i - 1)
            term.write(v.name .. (' '):rep(16 - #v.name))
            if not scores[e][i].locked and not v.bonus then
                if scores[e][i].value == 0 then term.setTextColor(colors.lightGray)
                else term.setTextColor(colors.lightBlue) end
            else term.setTextColor(selected and colors.black or colors.white) end
            if scores[e][i].value == nil then term.write("   ")
            elseif scores[e][i].value < 10 then term.write("  " .. scores[e][i].value)
            else term.write(" " .. scores[e][i].value) end
=======
        for i, v in ipairs(scorecardNames[e]) do
            local selected = e == selectcol and i == selectrow
            term.setBackgroundColor(selected and colors.white or (i % 2 == 1 and colors.black or colors.gray))
            term.setTextColor(selected and colors.black or colors.white)
            term.setCursorPos(x + (e - 1) * 20, y + i - 1)
            term.write(v.name .. (' '):rep(16 - #v.name))
            if not scores[e][i].locked and not v.bonus then
                if scores[e][i].value == 0 then
                    term.setTextColor(colors.lightGray)
                else
                    term.setTextColor(colors.lightBlue)
                end
            else
                term.setTextColor(selected and colors.black or colors.white)
            end
            if scores[e][i].value == nil then
                term.write("   ")
            elseif scores[e][i].value < 10 then
                term.write("  " .. scores[e][i].value)
            else
                term.write(" " .. scores[e][i].value)
            end
>>>>>>> origin/main
        end
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

local function drawStatus(x, y, scores, rolls)
    term.setCursorPos(x, y)
    term.write("Score: ")
    local sum = 0
    for e = 1, 2 do
<<<<<<< HEAD
        for i,v in ipairs(scores[e]) do
=======
        for i, v in ipairs(scores[e]) do
>>>>>>> origin/main
            if v.value and v.locked then sum = sum + v.value end
        end
    end
    term.write(sum)
    term.setCursorPos(x, y + 1)
    term.write("Rolls remaining: " .. rolls)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

local function calculateScores(scores, dice)
    for e = 1, 2 do
<<<<<<< HEAD
        for i,v in ipairs(scorecardNames[e]) do
=======
        for i, v in ipairs(scorecardNames[e]) do
>>>>>>> origin/main
            if not scores[e][i].locked and v.score then
                scores[e][i].value = v.score(dice, scores)
            end
        end
    end
    if scores[2][6].locked and scores[2][6].value == 50 then
        local c = dice[1].value
<<<<<<< HEAD
        for _,i in ipairs(dice) do if c ~= i.value then return scores end end
=======
        for _, i in ipairs(dice) do if c ~= i.value then return scores end end
>>>>>>> origin/main
        scores[2][8].value = 100
        scores[2][8].locked = true
    end
    return scores
end

local function confirmScore(scores, col, row)
    if col then scores[col][row].locked = true end
<<<<<<< HEAD
    for e = 1, 2 do for i,v in ipairs(scores[e]) do if not v.locked then v.value = nil end end end
    if ((scores[1][2].locked and scores[1][2].value or 0) +
        (scores[1][3].locked and scores[1][3].value or 0) +
        (scores[1][4].locked and scores[1][4].value or 0) +
        (scores[1][5].locked and scores[1][5].value or 0) +
        (scores[1][6].locked and scores[1][6].value or 0) +
        (scores[1][7].locked and scores[1][7].value or 0)) >= 63 then
=======
    for e = 1, 2 do for i, v in ipairs(scores[e]) do if not v.locked then v.value = nil end end end
    if ((scores[1][2].locked and scores[1][2].value or 0) +
            (scores[1][3].locked and scores[1][3].value or 0) +
            (scores[1][4].locked and scores[1][4].value or 0) +
            (scores[1][5].locked and scores[1][5].value or 0) +
            (scores[1][6].locked and scores[1][6].value or 0) +
            (scores[1][7].locked and scores[1][7].value or 0)) >= 63 then
>>>>>>> origin/main
        scores[1][8].value = 35
        scores[1][8].locked = true
    end
    return scores
end

local speaker = peripheral.find("speaker")

local function rollDice(dice, dx, dy, cx, cy, color, last)
<<<<<<< HEAD
    for _,v in ipairs(dice) do if not v.locked then v.value = 0 end end
    drawDice(dx, dy, dice)
    for i = 1, 4 do
        drawRollCup(cx, cy, color, true)
        if speaker then speaker.playNote("hat", 2, 12) speaker.playNote("hat", 2, 7) end
        sleep(0.1)
        drawRollCup(cx + 1, cy, color, true)
        if speaker then speaker.playNote("hat", 2, 11) speaker.playNote("hat", 2, 6) end
        sleep(0.1)
        drawRollCup(cx, cy, color, true)
        if speaker then speaker.playNote("hat", 2, 12) speaker.playNote("hat", 2, 7) end
        sleep(0.1)
        drawRollCup(cx - 1, cy, color, true)
        if speaker then speaker.playNote("hat", 2, 11) speaker.playNote("hat", 2, 6) end
        sleep(0.1)
    end
    if speaker then speaker.playNote("hat", 2, 3) speaker.playNote("hat", 2, 6) end
    for _,v in ipairs(dice) do if not v.locked then v.value = math.random(1, 6) end end
=======
    for _, v in ipairs(dice) do if not v.locked then v.value = 0 end end
    drawDice(dx, dy, dice)
    for i = 1, 4 do
        drawRollCup(cx, cy, color, true)
        if speaker then
            speaker.playNote("hat", 2, 12)
            speaker.playNote("hat", 2, 7)
        end
        sleep(0.1)
        drawRollCup(cx + 1, cy, color, true)
        if speaker then
            speaker.playNote("hat", 2, 11)
            speaker.playNote("hat", 2, 6)
        end
        sleep(0.1)
        drawRollCup(cx, cy, color, true)
        if speaker then
            speaker.playNote("hat", 2, 12)
            speaker.playNote("hat", 2, 7)
        end
        sleep(0.1)
        drawRollCup(cx - 1, cy, color, true)
        if speaker then
            speaker.playNote("hat", 2, 11)
            speaker.playNote("hat", 2, 6)
        end
        sleep(0.1)
    end
    if speaker then
        speaker.playNote("hat", 2, 3)
        speaker.playNote("hat", 2, 6)
    end
    for _, v in ipairs(dice) do if not v.locked then v.value = math.random(1, 6) end end
>>>>>>> origin/main
    drawRollCup(cx, cy, color, last)
    drawDice(dx, dy, dice)
    return dice
end

local positions = {
<<<<<<< HEAD
    dice = {x = 2, y = 17},
    rollCup = {x = 36, y = 15},
    logo = {x = 2, y = 2},
    status = {x = 23, y = 3},
    scores = {x = 2, y = 7}
}

local dice = {{value = 0}, {value = 0}, {value = 0}, {value = 0}, {value = 0}}
local scores = {{{}, {}, {}, {}, {}, {}, {}, {}}, {{}, {}, {}, {}, {}, {}, {}, {}}}
=======
    dice = { x = 2, y = 17 },
    rollCup = { x = 36, y = 15 },
    logo = { x = 2, y = 2 },
    status = { x = 23, y = 3 },
    scores = { x = 2, y = 7 }
}

local dice = { { value = 0 }, { value = 0 }, { value = 0 }, { value = 0 }, { value = 0 } }
local scores = { { {}, {}, {}, {}, {}, {}, {}, {} }, { {}, {}, {}, {}, {}, {}, {}, {} } }
>>>>>>> origin/main
local rollsRemaining = 3
local selectedcol, selectedrow = false, 0
local filledScores = 0
local cupColor = 0xb
<<<<<<< HEAD
local click_position_at_dice = 0  --click event at dice position
math.randomseed(os.epoch())
-- term.redirect(peripheral.wrap("top"))
=======
local click_position_at_dice = 0
math.randomseed(os.epoch())
>>>>>>> origin/main
term.clear()
drawLogo(positions.logo.x, positions.logo.y)
drawStatus(positions.status.x, positions.status.y, scores, rollsRemaining)
drawScores(positions.scores.x, positions.scores.y, scores)
drawDice(positions.dice.x, positions.dice.y, dice)
drawRollCup(positions.rollCup.x, positions.rollCup.y, ('%x'):format(cupColor))

while filledScores < 13 do
<<<<<<< HEAD
    local ev = {os.pullEvent()}
=======
    local ev = { os.pullEvent() }
>>>>>>> origin/main
    if ev[1] == "key" then
        if ev[2] == keys.r and rollsRemaining > 0 and not (dice[1].locked and dice[2].locked and dice[3].locked and dice[4].locked and dice[5].locked) then
            rollsRemaining = rollsRemaining - 1
            confirmScore(scores)
            drawScores(positions.scores.x, positions.scores.y, scores)
            drawStatus(positions.status.x, positions.status.y, scores, rollsRemaining)
<<<<<<< HEAD
            rollDice(dice, positions.dice.x, positions.dice.y, positions.rollCup.x, positions.rollCup.y, ('%x'):format(cupColor), rollsRemaining < 1)
=======
            rollDice(dice, positions.dice.x, positions.dice.y, positions.rollCup.x, positions.rollCup.y,
                ('%x'):format(cupColor), rollsRemaining < 1)
>>>>>>> origin/main
            calculateScores(scores, dice)
            if rollsRemaining == 0 then
                selectedcol = false
                selectedrow = 2
                while selectedrow <= 7 and scores[1][selectedrow].locked do selectedrow = selectedrow + 1 end
                if selectedrow > 7 then
                    selectedcol = true
                    selectedrow = 1
                    while selectedrow <= 7 and scores[2][selectedrow].locked do selectedrow = selectedrow + 1 end
                    if selectedrow > 7 then selectedrow = 0 end
                end
                drawScores(positions.scores.x, positions.scores.y, scores, selectedcol and 2 or 1, selectedrow)
            else
                selectedcol, selectedrow = false, 0
                drawScores(positions.scores.x, positions.scores.y, scores)
            end
        elseif ev[2] == keys.one and rollsRemaining < 3 and rollsRemaining > 0 then
            dice[1].locked = not dice[1].locked
<<<<<<< HEAD
            drawDie(positions.dice.x + (1-1)*3, positions.dice.y, dice[1].value, dice[1].locked and '4' or '0')
        elseif ev[2] == keys.two and rollsRemaining < 3 and rollsRemaining > 0 then
            dice[2].locked = not dice[2].locked
            drawDie(positions.dice.x + (2-1)*3, positions.dice.y, dice[2].value, dice[2].locked and '4' or '0')
        elseif ev[2] == keys.three and rollsRemaining < 3 and rollsRemaining > 0 then
            dice[3].locked = not dice[3].locked
            drawDie(positions.dice.x + (3-1)*3, positions.dice.y, dice[3].value, dice[3].locked and '4' or '0')
        elseif ev[2] == keys.four and rollsRemaining < 3 and rollsRemaining > 0 then
            dice[4].locked = not dice[4].locked
            drawDie(positions.dice.x + (4-1)*3, positions.dice.y, dice[4].value, dice[4].locked and '4' or '0')
        elseif ev[2] == keys.five and rollsRemaining < 3 and rollsRemaining > 0 then
            dice[5].locked = not dice[5].locked
            drawDie(positions.dice.x + (5-1)*3, positions.dice.y, dice[5].value, dice[5].locked and '4' or '0')
        elseif ev[2] == keys.q then break
=======
            drawDie(positions.dice.x + (1 - 1) * 3, positions.dice.y, dice[1].value, dice[1].locked and '4' or '0')
        elseif ev[2] == keys.two and rollsRemaining < 3 and rollsRemaining > 0 then
            dice[2].locked = not dice[2].locked
            drawDie(positions.dice.x + (2 - 1) * 3, positions.dice.y, dice[2].value, dice[2].locked and '4' or '0')
        elseif ev[2] == keys.three and rollsRemaining < 3 and rollsRemaining > 0 then
            dice[3].locked = not dice[3].locked
            drawDie(positions.dice.x + (3 - 1) * 3, positions.dice.y, dice[3].value, dice[3].locked and '4' or '0')
        elseif ev[2] == keys.four and rollsRemaining < 3 and rollsRemaining > 0 then
            dice[4].locked = not dice[4].locked
            drawDie(positions.dice.x + (4 - 1) * 3, positions.dice.y, dice[4].value, dice[4].locked and '4' or '0')
        elseif ev[2] == keys.five and rollsRemaining < 3 and rollsRemaining > 0 then
            dice[5].locked = not dice[5].locked
            drawDie(positions.dice.x + (5 - 1) * 3, positions.dice.y, dice[5].value, dice[5].locked and '4' or '0')
        elseif ev[2] == keys.q then -- quit the game
            break
>>>>>>> origin/main
        elseif ev[2] == keys.up and rollsRemaining < 3 then
            if selectedrow == 0 then
                selectedcol = false
                selectedrow = 2
                while selectedrow <= 7 and scores[1][selectedrow].locked do selectedrow = selectedrow + 1 end
                if selectedrow > 7 then
                    selectedcol = true
                    selectedrow = 1
                    while selectedrow <= 7 and scores[2][selectedrow].locked do selectedrow = selectedrow + 1 end
                    if selectedrow > 7 then selectedrow = 0 end
                end
            end
            if selectedrow > (selectedcol and 1 or 2) then
                local oldrow = selectedrow
                repeat selectedrow = selectedrow - 1 until selectedrow < (selectedcol and 1 or 2) or not scores[selectedcol and 2 or 1][selectedrow].locked
                if selectedrow < (selectedcol and 1 or 2) then selectedrow = oldrow end
            end
            drawScores(positions.scores.x, positions.scores.y, scores, selectedcol and 2 or 1, selectedrow)
        elseif ev[2] == keys.down and rollsRemaining < 3 then
            if selectedrow == 0 then
                selectedcol = false
                selectedrow = 7
                while selectedrow >= 2 and scores[1][selectedrow].locked do selectedrow = selectedrow - 1 end
                if selectedrow < 2 then
                    selectedcol = true
                    selectedrow = 7
                    while selectedrow >= 1 and scores[2][selectedrow].locked do selectedrow = selectedrow - 1 end
                    if selectedrow < 1 then selectedrow = 0 end
                end
            end
            if selectedrow > 0 and selectedrow < 7 then
                local oldrow = selectedrow
                repeat selectedrow = selectedrow + 1 until selectedrow > 7 or not scores[selectedcol and 2 or 1][selectedrow].locked
                if selectedrow > 7 then selectedrow = oldrow end
            end
            drawScores(positions.scores.x, positions.scores.y, scores, selectedcol and 2 or 1, selectedrow)
        elseif (ev[2] == keys.left or ev[2] == keys.right) and rollsRemaining < 3 and selectedrow ~= 1 and (selectedrow == 0 or not scores[selectedcol and 1 or 2][selectedrow].locked) then
            if selectedrow == 0 then
                selectedcol = ev[2] == keys.right
                selectedrow = (selectedcol and 1 or 2)
<<<<<<< HEAD
                while selectedrow <= 7 and scores[selectedcol and 2 or 1][selectedrow].locked do selectedrow = selectedrow + 1 end
                if selectedrow > 7 then
                    selectedcol = not selectedcol
                    selectedrow = (selectedcol and 1 or 2)
                    while selectedrow <= 7 and scores[selectedcol and 2 or 1][selectedrow].locked do selectedrow = selectedrow + 1 end
                    if selectedrow > 7 then selectedrow = 0 end
                end
            else selectedcol = not selectedcol end
            drawScores(positions.scores.x, positions.scores.y, scores, selectedcol and 2 or 1, selectedrow)
        elseif ev[2] == keys.enter and selectedrow ~= 0 and rollsRemaining < 3 and not scores[selectedcol and 2 or 1][selectedrow].locked then
            confirmScore(scores, selectedcol and 2 or 1, selectedrow)
            dice = {{value = 0}, {value = 0}, {value = 0}, {value = 0}, {value = 0}}
=======
                while selectedrow <= 7 and scores[selectedcol and 2 or 1][selectedrow].locked do selectedrow =
                    selectedrow + 1 end
                if selectedrow > 7 then
                    selectedcol = not selectedcol
                    selectedrow = (selectedcol and 1 or 2)
                    while selectedrow <= 7 and scores[selectedcol and 2 or 1][selectedrow].locked do selectedrow =
                        selectedrow + 1 end
                    if selectedrow > 7 then selectedrow = 0 end
                end
            else
                selectedcol = not selectedcol
            end
            drawScores(positions.scores.x, positions.scores.y, scores, selectedcol and 2 or 1, selectedrow)
        elseif ev[2] == keys.enter and selectedrow ~= 0 and rollsRemaining < 3 and not scores[selectedcol and 2 or 1][selectedrow].locked then
            confirmScore(scores, selectedcol and 2 or 1, selectedrow)
            dice = { { value = 0 }, { value = 0 }, { value = 0 }, { value = 0 }, { value = 0 } }
>>>>>>> origin/main
            rollsRemaining = 3
            drawStatus(positions.status.x, positions.status.y, scores, rollsRemaining)
            drawScores(positions.scores.x, positions.scores.y, scores)
            drawDice(positions.dice.x, positions.dice.y, dice)
            drawRollCup(positions.rollCup.x, positions.rollCup.y, ('%x'):format(cupColor))
            filledScores = filledScores + 1
        elseif ev[2] == keys.c then
            cupColor = cupColor + 1
            if cupColor > 0xf then cupColor = 0x0 end
            drawRollCup(positions.rollCup.x, positions.rollCup.y, ('%x'):format(cupColor))
        end
    elseif ev[1] == "mouse_click" and ev[2] == 1 then
        if ((ev[3] >= positions.rollCup.x and ev[3] < positions.rollCup.x + 5 and ev[4] >= positions.rollCup.y and ev[4] < positions.rollCup.y + 5) or (ev[3] >= positions.rollCup.x - 5 and ev[3] < positions.rollCup.x - 1 and ev[4] == positions.rollCup.y + 2)) and rollsRemaining > 0 and not (dice[1].locked and dice[2].locked and dice[3].locked and dice[4].locked and dice[5].locked) then
            rollsRemaining = rollsRemaining - 1
            confirmScore(scores)
            drawScores(positions.scores.x, positions.scores.y, scores)
            drawStatus(positions.status.x, positions.status.y, scores, rollsRemaining)
<<<<<<< HEAD
            rollDice(dice, positions.dice.x, positions.dice.y, positions.rollCup.x, positions.rollCup.y, ('%x'):format(cupColor), rollsRemaining < 1)
=======
            rollDice(dice, positions.dice.x, positions.dice.y, positions.rollCup.x, positions.rollCup.y,
                ('%x'):format(cupColor), rollsRemaining < 1)
>>>>>>> origin/main
            calculateScores(scores, dice)
            if rollsRemaining == 0 then
                selectedcol = false
                selectedrow = 2
                while selectedrow <= 7 and scores[1][selectedrow].locked do selectedrow = selectedrow + 1 end
                if selectedrow > 7 then
                    selectedcol = true
                    selectedrow = 1
                    while selectedrow <= 7 and scores[2][selectedrow].locked do selectedrow = selectedrow + 1 end
                    if selectedrow > 7 then selectedrow = 0 end
                end
                drawScores(positions.scores.x, positions.scores.y, scores, selectedcol and 2 or 1, selectedrow)
            else
                selectedcol, selectedrow = false, 0
                drawScores(positions.scores.x, positions.scores.y, scores)
            end
        elseif ev[3] >= positions.dice.x and ev[3] < positions.dice.x + 15 and ev[4] >= positions.dice.y and ev[4] < positions.dice.y + 2 and rollsRemaining < 3 and rollsRemaining > 0 then
            click_position_at_dice = math.floor((ev[3] - positions.dice.x) / 3) + 1
            dice[click_position_at_dice].locked = not dice[click_position_at_dice].locked
<<<<<<< HEAD
            drawDie(positions.dice.x + (click_position_at_dice-1)*3, positions.dice.y, dice[click_position_at_dice].value, dice[click_position_at_dice].locked and '4' or '0')
=======
            drawDie(positions.dice.x + (click_position_at_dice - 1) * 3, positions.dice.y, dice[click_position_at_dice].value, dice[click_position_at_dice].locked and '4' or '0')
>>>>>>> origin/main
        elseif ev[3] >= positions.scores.x and ev[3] < positions.scores.x + 40 and ev[4] >= positions.scores.y and ev[4] < positions.scores.y + 7 and rollsRemaining < 3 then
            local col, row = ev[3] - positions.scores.x >= 20, ev[4] - positions.scores.y + 1
            if selectedcol == col and selectedrow == row and not scores[col and 2 or 1][row].locked then
                confirmScore(scores, selectedcol and 2 or 1, selectedrow)
<<<<<<< HEAD
                dice = {{value = 0}, {value = 0}, {value = 0}, {value = 0}, {value = 0}}
=======
                dice = { { value = 0 }, { value = 0 }, { value = 0 }, { value = 0 }, { value = 0 } }
>>>>>>> origin/main
                rollsRemaining = 3
                drawStatus(positions.status.x, positions.status.y, scores, rollsRemaining)
                drawScores(positions.scores.x, positions.scores.y, scores)
                drawDice(positions.dice.x, positions.dice.y, dice)
                drawRollCup(positions.rollCup.x, positions.rollCup.y, ('%x'):format(cupColor))
                filledScores = filledScores + 1
            elseif (col or row > 1) and not scores[col and 2 or 1][row].locked then
                selectedcol = col
                selectedrow = row
                drawScores(positions.scores.x, positions.scores.y, scores, selectedcol and 2 or 1, selectedrow)
            end
        end
    end
end

if filledScores == 13 then
    for i = 1, 3 do
        drawLogo(positions.logo.x, positions.logo.y, '5')
        sleep(0.5)
        drawLogo(positions.logo.x, positions.logo.y, '0')
        sleep(0.5)
    end
    drawLogo(positions.logo.x, positions.logo.y, '5')
    sleep(1)
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
local sum = 0
<<<<<<< HEAD
for e = 1, 2 do for i,v in ipairs(scores[e]) do if v.value and v.locked then sum = sum + v.value end end end
print("Final score: " .. sum)
print("Thanks for playing YahtCC!")
=======
for e = 1, 2 do for i, v in ipairs(scores[e]) do if v.value and v.locked then sum = sum + v.value end end end
print("Final score: " .. sum)
print("Thanks for playing YahtCC!")
>>>>>>> origin/main
