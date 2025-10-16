-- peripheral and logic stuff

local countername = "minecraft:barrel_15"
local vaultname = "minecraft:shulker_box_2"
local drivename = "drive"
local serverid = 23

local CurrencyName = "numismatics:spur"
local EqualList = {"numismatics:spur","numismatics:bevel","numismatics:sprocket","numismatics:cog", "numismatics:crown", "numismatics:sun"}
local EqualValue = {1,8,16,64,512,4096}

local monitor = peripheral.find("monitor")
local vault = peripheral.wrap(vaultname)
local counter = peripheral.wrap(countername)
local drive = peripheral.find(drivename)

local casinoNetwerk = peripheral.find("modem")
casinoNetwerk.open(os.getComputerID())

-- try to open rednet on the modem so we can use rednet.send/receive
local modemName = peripheral.getName(casinoNetwerk)
if modemName then
    pcall(rednet.open, modemName)
end

-- Stockpile rednet helper functions
local function makeUUID()
    return math.random(1, 2^31)
end

local function stockpileSend(cmd, timeout)
    timeout = timeout or 5
    local uuid = makeUUID()
    -- send command as {commandString, uuid}
    rednet.send(serverid, {cmd, uuid}, "stockpile")
    while true do
        -- try receiving on the 'stockpile' protocol first
        local sender, response = rednet.receive("stockpile", timeout)
        if not sender then
            -- fallback: try receiving without specifying protocol
            sender, response = rednet.receive(nil, timeout)
        end
        if not sender then return nil end

        -- log raw response for debugging
        pcall(function()
            if not fs.exists("disk") then fs.makeDir("disk") end
            local f = fs.open("disk/last_stockpile_resp", "w")
            if f then f.write(textutils.serialiseJSON({sender=sender, response=response})) f.close() end
        end)

        if sender == serverid then
            -- response could be table {result, uuid}
            if type(response) == "table" and response[2] == uuid then
                return response[1]
            elseif type(response) ~= "table" then
                return response
            else
                -- maybe response is table but without uuid, return it
                return response
            end
        end
    end
end

local function stockpileSearch(itemFilter)
    itemFilter = itemFilter or ""
    local cmd = 'search("' .. itemFilter .. '")'
    local resp = stockpileSend(cmd, 6)
    -- resp expected to be a table mapping item ids to counts
    return resp
end

local function stockpileGetContent()
    local cmd = 'get_content()'
    local resp = stockpileSend(cmd, 8)
    -- resp expected to be the full content table: itemId -> count
    return resp
end

-- Normalize Stockpile content response into a simple itemId -> totalCount table
local function normalizeContent(raw)
    if not raw then return {} end
    -- Stockpile often returns a table where raw.item_index contains item entries
    local items = {}
    if type(raw) == "table" and raw.item_index then
        for itemId, entry in pairs(raw.item_index) do
            local total = 0
            -- entry may contain keys that are inventory names mapping to numbers or tables
            for k,v in pairs(entry) do
                if type(v) == "number" then
                    total = total + v
                elseif type(v) == "table" then
                    for _,vv in pairs(v) do
                        total = total + (tonumber(vv) or 0)
                    end
                end
            end
            items[itemId] = total
        end
    elseif type(raw) == "table" then
        -- fallback: if raw already is itemId -> count, copy numeric values
        for k,v in pairs(raw) do
            if type(v) == "number" then
                items[k] = v
            end
        end
    end
    return items
end

-- Extract a per-inventory mapping: itemId -> { inventoryName -> count }
local function extractPerInventory(raw)
    local out = {}
    if not raw then return out end
    if type(raw) == "table" and raw.item_index then
        for itemId, entry in pairs(raw.item_index) do
            out[itemId] = out[itemId] or {}
            for invName, v in pairs(entry) do
                local total = 0
                if type(v) == "number" then
                    total = v
                elseif type(v) == "table" then
                    for _, vv in pairs(v) do
                        total = total + (tonumber(vv) or 0)
                    end
                end
                out[itemId][invName] = total
            end
        end
    end
    return out
end

-- Helpers to persist/load per-inventory snapshot used as baseline between returns
local function savePerInvSnapshot(perinv)
    pcall(function()
        if not fs.exists("disk") then fs.makeDir("disk") end
        local f = fs.open("disk/initial_perinv", "w")
        if f then f.write(textutils.serialiseJSON(perinv or {})) f.close() end
    end)
end

local function loadPerInvSnapshot()
    if fs.exists("disk/initial_perinv") then
        local f = fs.open("disk/initial_perinv", "r")
        if f then
            local s = f.readAll()
            f.close()
            local ok, t = pcall(textutils.unserializeJSON, s)
            if ok and type(t) == "table" then return t end
        end
    end
    return {}
end

local function stockpileScan(invs)
    -- invs is a table of peripheral names
    local s = "{"
    for i,v in ipairs(invs) do
        s = s .. '"' .. v .. '"'
        if i < #invs then s = s .. ", " end
    end
    s = s .. "}"
    local cmd = 'scan(' .. s .. ')'
    return stockpileSend(cmd, 8)
end

local function stockpileMoveItem(fromInvs, toInvs, qty, itemFilter)
    -- fromInvs and toInvs are tables of names
    local function tblToStr(t)
        local s = "{"
        for i,v in ipairs(t) do
            s = s .. '"' .. v .. '"'
            if i < #t then s = s .. ", " end
        end
        s = s .. "}"
        return s
    end
    local itemStr = "nil"
    if itemFilter and type(itemFilter) == "string" then
        itemStr = '"'..itemFilter..'"'
    end
    local cmd = 'move_item(' .. tblToStr(fromInvs) .. ", " .. tblToStr(toInvs) .. ", " .. itemStr .. ", " .. tonumber(qty) .. ')'
    return stockpileSend(cmd, 10)
end

local monitorWidth, monitorHeight = monitor.getSize()
-- important vars
local state = "idleScreen"
local userId, balance, chipPrice

-- loading stuff



term.redirect(monitor)
term.clear()
monitor.setTextScale(1)


local numbers = {
    ["0"] = paintutils.loadImage("graphics/numbers/0.nfp"),
    ["1"] = paintutils.loadImage("graphics/numbers/1.nfp"), -- i know you could clean this up with a for loop but I like it this way
    ["2"] = paintutils.loadImage("graphics/numbers/2.nfp"),
    ["3"] = paintutils.loadImage("graphics/numbers/3.nfp"),
    ["4"] = paintutils.loadImage("graphics/numbers/4.nfp"),
    ["5"] = paintutils.loadImage("graphics/numbers/5.nfp"),
    ["6"] = paintutils.loadImage("graphics/numbers/6.nfp"),
    ["7"] = paintutils.loadImage("graphics/numbers/7.nfp"),
    ["8"] = paintutils.loadImage("graphics/numbers/8.nfp"),
    ["9"] = paintutils.loadImage("graphics/numbers/9.nfp")
}



-- interface stuff --
function changeBalance(amount, userId)
    function sendCommandLoop()
        while true do
            casinoNetwerk.transmit(1, os.getComputerID(), textutils.serialiseJSON({["command"]="changeBal", ["userId"]=userId, ["attributes"]=amount}))
            sleep(0.5)
        end
    end

    function receiveConfirmation()
        os.pullEvent("modem_message")
    end

    parallel.waitForAny(sendCommandLoop, receiveConfirmation)
    
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

    disk.setLabel(peripheral.getName(drive), tostring(getBalance(userId)).." chips")
    return message
end

function getBalance(userId)
    function sendCommandLoop()
        while true do
            casinoNetwerk.transmit(1, os.getComputerID(), textutils.serialiseJSON({["command"]="getBal", ["userId"]=userId, ["attributes"]=nil}))
            sleep(0.5)
        end
    end

    function receiveConfirmation()
        os.pullEvent("modem_message")
    end

    parallel.waitForAny(sendCommandLoop, receiveConfirmation)
    
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

    return tonumber(message)
end

function getChipPrice()
    function sendCommandLoop()
        while true do
            casinoNetwerk.transmit(1, os.getComputerID(), textutils.serialiseJSON({["command"]="getChipPrice", ["userId"]=nil, ["attributes"]=nil}))
            sleep(0.5)
        end
    end

    function receiveConfirmation()
        os.pullEvent("modem_message")
    end

    parallel.waitForAny(sendCommandLoop, receiveConfirmation)
    
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

    return tonumber(message)

end

function getWithdrawalFee()
    function sendCommandLoop()
        while true do
            casinoNetwerk.transmit(1, os.getComputerID(), textutils.serialiseJSON({["command"]="getWithdrawalFee", ["userId"]=nil, ["attributes"]=nil}))
            sleep(0.5)
        end
    end

    function receiveConfirmation()
        os.pullEvent("modem_message")
    end

    parallel.waitForAny(sendCommandLoop, receiveConfirmation)
    
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

    return tonumber(message)

end

function getNewToken()
    function sendCommandLoop()
        while true do
            casinoNetwerk.transmit(1, os.getComputerID(), textutils.serialiseJSON({["command"]="getNewToken"}))
            sleep(0.5)
        end
    end

    function receiveConfirmation()
        os.pullEvent("modem_message")
    end

    parallel.waitForAny(sendCommandLoop, receiveConfirmation)
    
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

    return message

end


-- main --

function waitForDisk() 
    while true do
        if fs.exists("disk/id") then
            local file = fs.open("disk/id", "r")
            userId = file.readAll()
            file.close()
            return userId
        elseif fs.exists("disk/") then
            local userId = getNewToken()
            local file = fs.open("disk/id", "w")
            file.write(userId)
            file.close()
        end
        sleep(0.5)
    end
end

function cardChecker()
    local playerPresent = 0
    while true do
        
        
        if not fs.exists("disk") then
            state = "idleScreen"
            return
        end

        sleep(0.1)
    end
end



function pay(adress, value, comment)
    
    return succes
end



while true do
    if state=="idleScreen" then
        userId = nil
        balance = 0

        term.setBackgroundColor(colors.black)
        term.clear()

        term.setCursorPos(3, 3)
        term.write("welcome to casino fortuna")

        term.setCursorPos(6, 10)
        term.write("Please insert disk")
        term.setCursorPos(10, 11)
        term.write("to proceed.")

        userId = waitForDisk()
        state = "menuScreen"
    end
    if state=="menuScreen" then
        balance = getBalance(userId)

        term.setBackgroundColor(colors.black)
        term.clear()



        term.setCursorPos(6, 1)
        term.write("Your current have")

        term.setBackgroundColor(colors.gray)
        paintutils.drawLine(1, 2, monitorWidth, 2, colors.gray)
        term.setCursorPos((monitorWidth-#tostring(balance))/2, 2)
        term.write(tostring(balance))

        term.setCursorPos(12, 3)
        term.setBackgroundColor(colors.black)
        term.write("chips")

        paintutils.drawFilledBox(4, 5, monitorWidth-3, 7, colors.green)
        term.setCursorPos(12, 6)
        term.write("SaveIn")

        paintutils.drawFilledBox(4, 9, monitorWidth-3, 11, colors.red)
        term.setCursorPos(12, 10)
        term.write("GetOut")
        
        function menu()
            while true do
                local event, side, x, y = os.pullEvent("monitor_touch")
                if x>=4 and x<=monitorWidth-3 then
                    if y>=5 and y<=7 then
                        state="deposit"
                        return
                    elseif y>=9 and y<=11 then
                        state="withdraw"
                        return
                    end

                end

            end
        end

        

        parallel.waitForAny(cardChecker, menu)

    end
    if state=="deposit" then
        chipPrice = tonumber(getChipPrice()) or chipPrice
        if not chipPrice or chipPrice <= 0 then
            -- fallback to 1 to avoid division by zero; better to surface an error in UI
            chipPrice = 1
        end

        term.setBackgroundColor(colors.black)
        term.clear()

        

        paintutils.drawLine(1, 3, monitorWidth, 3, colors.gray)
    term.setCursorPos(2, 3)
    term.setTextColor(colors.white)
    term.write(tostring(chipPrice)..' spur   -->   1 chip')

        term.setBackgroundColor(colors.black)
        term.setCursorPos(5, 5)
        term.write("insert in barrel -->")

        paintutils.drawFilledBox(4, 9, monitorWidth-3, 11, colors.green)
        term.setCursorPos(8, 10)
        term.write("ConfirmSaveIn")
        
        function checkReturnButton(initialTable)
            -- when user clicks return, scan counter and compute deposited diamonds
            while true do
                local event, side, x, y = os.pullEvent("monitor_touch")
                        if x>=4 and x<=monitorWidth-3 and y>=9 and y<=11 then
                            local counterName = countername
                            -- show scanning message
                            term.setBackgroundColor(colors.black)
                            term.setTextColor(colors.yellow)
                            term.setCursorPos(5,6)
                            term.write("Scanning...")

                            -- request server to scan the counter inventory (and vault to be safe)
                            stockpileScan({counterName, vaultname})

                            -- poll for updated per-inventory content and read counts for all denominations in EqualList
                            local attempts = 12
                            local afterRaw, perinv
                            local toMove = {} -- itemId -> count in counter
                            local beforeCounts = {} -- save before counts per item
                            local totalSpurValue = 0
                            for i=1,attempts do
                                afterRaw = stockpileGetContent() or {}
                                perinv = extractPerInventory(afterRaw)

                                -- collect counts for each denomination in EqualList
                                totalSpurValue = 0
                                for idx, itemId in ipairs(EqualList) do
                                    local cnt = 0
                                    if perinv and perinv[itemId] and perinv[itemId][counterName] then
                                        cnt = tonumber(perinv[itemId][counterName]) or 0
                                    end
                                    beforeCounts[itemId] = cnt
                                    if cnt > 0 then
                                        toMove[itemId] = cnt
                                        local val = EqualValue[idx] or 1
                                        totalSpurValue = totalSpurValue + (cnt * val)
                                    end
                                end

                                if totalSpurValue > 0 then break end
                                sleep(0.5)
                            end

                            if totalSpurValue <= 0 then
                                term.setTextColor(colors.white)
                                term.setCursorPos(5,6)
                                term.write("No spurs detected in counter.   ")
                                -- write zero to debug file
                                pcall(function()
                                    if not fs.exists("disk") then fs.makeDir("disk") end
                                    local f = fs.open("disk/last_deposit", "w")
                                    if f then f.write(textutils.serialiseJSON({totalSpur=0, breakdown=beforeCounts})); f.close() end
                                end)
                                -- also save current perinv as next baseline to avoid double-counting next time
                                savePerInvSnapshot(perinv)
                                sleep(1)
                                state = "menuScreen"
                                return
                            end

                            -- show found and moving messages: report total spur equivalent
                            term.setTextColor(colors.green)
                            term.setCursorPos(5,6)
                            term.write("Found equivalent "..tostring(totalSpurValue).." spurs in counter.       ")
                            term.setCursorPos(5,7)
                            term.setTextColor(colors.yellow)
                            term.write("Moving items...")

                            -- write breakdown to debug file so user can inspect
                            pcall(function()
                                if not fs.exists("disk") then fs.makeDir("disk") end
                                local f = fs.open("disk/last_deposit", "w")
                                if f then f.write(textutils.serialiseJSON({totalSpur=totalSpurValue, breakdown=toMove})); f.close() end
                            end)

                            -- attempt to move each detected denomination from counter to vault via stockpile
                            for itemId, qty in pairs(toMove) do
                                -- move that specific itemId
                                pcall(function()
                                    stockpileMoveItem({counterName}, {vaultname}, qty, itemId)
                                end)
                                sleep(0.15)
                            end

                            -- after move, verify actual moved by polling stockpile (short delay)
                            sleep(0.7)
                            local afterRaw2 = stockpileGetContent() or {}
                            local afterPer2 = extractPerInventory(afterRaw2)

                            -- compute actually moved per item and total spur equivalent
                            local movedBreakdown = {}
                            local actuallyMovedSpur = 0
                            for idx, itemId in ipairs(EqualList) do
                                local beforeCnt = beforeCounts[itemId] or 0
                                local afterCnt = 0
                                if afterPer2 and afterPer2[itemId] and afterPer2[itemId][counterName] then
                                    afterCnt = tonumber(afterPer2[itemId][counterName]) or 0
                                end
                                local movedCnt = beforeCnt - afterCnt
                                if movedCnt < 0 then movedCnt = 0 end
                                movedBreakdown[itemId] = movedCnt
                                local val = EqualValue[idx] or 1
                                actuallyMovedSpur = actuallyMovedSpur + (movedCnt * val)
                            end

                            -- credit chips to user based on actually moved spur equivalent and chipPrice
                            local creditedChips = (actuallyMovedSpur / chipPrice)
                            -- round to reasonable precision (2 decimals)
                            creditedChips = math.floor(creditedChips * 100 + 0.5) / 100
                            if creditedChips > 0 then
                                changeBalance(creditedChips, userId)
                            end

                            -- after successful move, persist the per-inventory snapshot as next baseline
                            savePerInvSnapshot(afterPer2)

                            -- also refresh the global normalized initial_snapshot to reflect moved items
                            pcall(function()
                                if not fs.exists("disk") then fs.makeDir("disk") end
                                local path = "disk/initial_snapshot"
                                local norm = normalizeContent(stockpileGetContent() or {})
                                local f = fs.open(path, "w")
                                if f then f.write(textutils.serialiseJSON(norm)) f.close() end
                            end)

                            -- prepare bill data for display (diamonds field used to display spur total)
                            billData = {
                                kind = "deposit",
                                diamonds = actuallyMovedSpur,
                                chips = creditedChips,
                                feeDiamonds = 0,
                                feeChips = 0,
                                feeRate = 0,
                                chipValue = chipPrice,
                                balance = tonumber(getBalance(userId)) or balance,
                                breakdown = movedBreakdown
                            }

                            term.setTextColor(colors.white)
                            term.setCursorPos(5,7)
                            term.write("Moved "..tostring(actuallyMovedSpur).." spurs.        ")
                            term.setCursorPos(5,8)
                            term.write("Credited "..tostring(creditedChips).." chips.")
                            sleep(1.0)

                            state = "bill"
                            return
                        end
                sleep(0.2)
            end
        end

    -- deposit flow: ensure server knows about our inventories and read initial full content
    -- Ask Stockpile to scan both the counter and the vault so the DB is up-to-date.
    pcall(function()
        stockpileScan({countername, vaultname})
    end)

    -- Request the server's list of known inventories and units and write them to disk for debugging.
    pcall(function()
        local invs = stockpileSend('list_all_inventories()')
        if not fs.exists("disk") then fs.makeDir("disk") end
        local f = fs.open("disk/stockpile_inventories", "w")
        if f then f.write(textutils.serialiseJSON(invs or {})) f.close() end
    end)
    pcall(function()
        local units = stockpileSend('unit.get()')
        if not fs.exists("disk") then fs.makeDir("disk") end
        local f = fs.open("disk/stockpile_units", "w")
        if f then f.write(textutils.serialiseJSON(units or {})) f.close() end
    end)

    -- read initial full content from server
    local initial = stockpileGetContent() or {}
    -- write normalized initial snapshot for debugging
    pcall(function()
        if not fs.exists("disk") then fs.makeDir("disk") end
        local norm = normalizeContent(initial)
        local f = fs.open("disk/initial_snapshot", "w")
        if f then f.write(textutils.serialiseJSON(norm)) f.close() end
    end)

    -- save per-inventory baseline so later deposit comparisons compute delta correctly
    pcall(function()
        local perinv = extractPerInventory(initial)
        savePerInvSnapshot(perinv)
    end)

    parallel.waitForAny(cardChecker, function() checkReturnButton(initial) end)
    end
    if state=="withdraw" then
        local depositConfirmation = false
        local requestedDiamonds = 0

        local chipPrice = tonumber(getChipPrice()) or chipPrice
        if not chipPrice or chipPrice <= 0 then
            chipPrice = 1
        end
        local withdrawalFee = getWithdrawalFee()

        local maxDeposit = getBalance(userId) * chipPrice
        local requiredChips = requestedDiamonds / chipPrice

        term.setBackgroundColor(colors.black)
        term.clear()

        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)

        term.setCursorPos(2, 2)
        term.write("+1  ")

        term.setCursorPos(2, 4)
        term.write("+10 ")

        term.setCursorPos(2, 6)
        term.write("+100")

        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)

        term.setCursorPos(monitorWidth-4, 2)
        term.write("-1  ")

        term.setCursorPos(monitorWidth-4, 4)
        term.write("-10 ")

        term.setCursorPos(monitorWidth-4, 6)
        term.write("-100")
        
        paintutils.drawFilledBox(2, 9, monitorWidth/2-1, 11, colors.green)
        term.setCursorPos(4, 10)
        term.write("GetOut")

        paintutils.drawFilledBox(monitorWidth/2+2, 9, monitorWidth-1, 11, colors.red)
        term.setCursorPos(monitorWidth/2+5, 10)
        term.write("return")
        

        paintutils.drawFilledBox(6, 1, monitorWidth-5, 8, colors.black)
    term.setCursorPos(monitorWidth/2-(#tostring(requiredChips)+#" chips")/2, 3)
    term.write(tostring(requiredChips).." chips")

        term.setCursorPos(monitorWidth/2, 4)
        term.write("V")

    term.setCursorPos(monitorWidth/2-(#tostring(requestedDiamonds)+#" krist")/2, 5)
    term.write(tostring(requestedDiamonds).." spurs")
        function menu()
            while true do
                local event, side, x, y = os.pullEvent("monitor_touch")
                -- top-right return to menu
                if x>=monitorWidth/2+2 and x<=monitorWidth-1 and y>=9 and y<=11 then
                    state = "menuScreen"
                    return
                -- confirm withdrawal (left bottom)
                elseif x>=2 and x<=monitorWidth/2-1 and y>=9 and y<=11 then
                    if requestedDiamonds > 0 then
                        depositConfirmation = true
                        requiredChips = requestedDiamonds / chipPrice
                    end
                    state = "menuScreen"
                    return
                -- increase buttons (left column)
                elseif x>=2 and x<=5 then
                    if y==2 then
                        requestedDiamonds = requestedDiamonds + 1
                    elseif y==4 then
                        requestedDiamonds = requestedDiamonds + 10
                    elseif y==6 then
                        requestedDiamonds = requestedDiamonds + 100
                    end
                -- decrease buttons (right column)
                elseif x>=monitorWidth-4 and x<=monitorWidth-1 then
                    if y==2 then
                        requestedDiamonds = requestedDiamonds - 1
                    elseif y==4 then
                        requestedDiamonds = requestedDiamonds - 10
                    elseif y==6 then
                        requestedDiamonds = requestedDiamonds - 100
                    end
                end

                if requestedDiamonds > maxDeposit then
                    requestedDiamonds = maxDeposit
                elseif requestedDiamonds < 0 then
                    requestedDiamonds = 0
                end

                requiredChips = requestedDiamonds / chipPrice

                paintutils.drawFilledBox(6, 1, monitorWidth-5, 8, colors.black)
                term.setCursorPos(monitorWidth/2-(#tostring(requiredChips)+#" chips")/2, 3)
                term.write(tostring(requiredChips).." chips")

                term.setCursorPos(monitorWidth/2, 4)
                term.write("V")

                term.setCursorPos(monitorWidth/2-(#tostring(requestedDiamonds)+#" krist")/2, 5)
                term.write(tostring(requestedDiamonds).." spurs")
            end
        end

        parallel.waitForAny(cardChecker, menu)

        
        if depositConfirmation then
            -- withdrawalFee is a fraction applied to spurs; compute fee based on actual moved
            local toWithdrawRequested = requestedDiamonds
            -- record balance before changes for bill
            local balanceBefore = tonumber(getBalance(userId)) or 0

            -- check vault available spur stock and limit request
            local content = stockpileGetContent() or {}
            local perinv = extractPerInventory(content)
            local vaultAvailable = 0
            if perinv and perinv[CurrencyName] and perinv[CurrencyName][vaultname] then
                vaultAvailable = tonumber(perinv[CurrencyName][vaultname]) or 0
            end

            if vaultAvailable <= 0 then
                term.setTextColor(colors.white)
                term.setCursorPos(4,12)
                term.write("No spurs available in vault.")
                sleep(1.0)
                state = "menuScreen"
                return
            end

            local toWithdraw = toWithdrawRequested
            if toWithdrawRequested > vaultAvailable then
                -- limit withdrawal to available amount and inform user
                toWithdraw = vaultAvailable
                term.setTextColor(colors.yellow)
                term.setCursorPos(4,12)
                term.write("Requested > available. Adjusted to "..tostring(toWithdraw) .." spurs.")
                sleep(1.0)
            end

            if toWithdraw <= 0 then
                state = "menuScreen"
            else
                -- get per-inv snapshot before move
                local beforeRaw = stockpileGetContent() or {}
                local beforePer = extractPerInventory(beforeRaw)

                -- attempt to move using stockpile (filter to currency)
                local moveResp = stockpileMoveItem({vaultname}, {countername}, toWithdraw, CurrencyName)

                -- wait briefly and fetch after snapshot
                sleep(0.7)
                local afterRaw = stockpileGetContent() or {}
                local afterPer = extractPerInventory(afterRaw)

                -- compute actual moved as delta on counter (or vault negative delta)
                local beforeCnt = 0
                if beforePer and beforePer[CurrencyName] and beforePer[CurrencyName][countername] then
                    beforeCnt = tonumber(beforePer[CurrencyName][countername]) or 0
                end
                local afterCnt = 0
                if afterPer and afterPer[CurrencyName] and afterPer[CurrencyName][countername] then
                    afterCnt = tonumber(afterPer[CurrencyName][countername]) or 0
                end

                local moved = afterCnt - beforeCnt
                if moved < 0 then moved = 0 end

                -- compute fee based on actual moved
                local feeSpursActual = math.ceil(moved * withdrawalFee)
                local costChips = moved / chipPrice
                local feeChips = feeSpursActual / chipPrice
                -- round to 2 decimals
                costChips = math.floor(costChips * 100 + 0.5) / 100
                feeChips = math.floor(feeChips * 100 + 0.5) / 100
                local totalCharge = costChips + feeChips
                totalCharge = math.floor(totalCharge * 100 + 0.5) / 100

                -- charge user once based on actual moved and fee
                if totalCharge > 0 then
                    changeBalance(-totalCharge, userId)
                end

                -- Persist the after-move per-inv snapshot as the next baseline
                savePerInvSnapshot(afterPer)

                -- Refresh the global normalized initial snapshot to reflect moved items
                pcall(function()
                    if not fs.exists("disk") then fs.makeDir("disk") end
                    local path = "disk/initial_snapshot"
                    local norm = normalizeContent(stockpileGetContent() or {})
                    local f = fs.open(path, "w")
                    if f then f.write(textutils.serialiseJSON(norm)) f.close() end
                end)

                -- compute final balance and prepare bill data
                local balanceAfter = tonumber(getBalance(userId)) or 0
                local netChipsChange = balanceAfter - balanceBefore

                billData = {
                    kind = "withdraw",
                    requested = toWithdrawRequested,
                    diamonds = moved,
                    chipsCharged = -totalCharge,
                    chipsRefunded = 0,
                    netChips = netChipsChange,
                    feeDiamonds = feeSpursActual,
                    feeChips = feeChips,
                    feeRate = withdrawalFee,
                    chipValue = chipPrice,
                    balance = balanceAfter
                }

                -- show results (short) and then show bill
                term.setCursorPos(4, 12)
                term.setTextColor(colors.white)
                term.write("Requested: "..tostring(toWithdrawRequested) .." spurs")
                term.setCursorPos(4, 13)
                term.write("Moved: "..tostring(moved) .." spurs")
                term.setCursorPos(4, 14)
                term.write("Charged: "..tostring(totalCharge) .." chips (incl. fee)")
                sleep(1.0)

                state = "bill"
            end
        end
    end
    if state == "bill" then
        term.setBackgroundColor(colors.black)
        term.clear()

        term.setTextColor(colors.white)
        term.setCursorPos(3,2)
        term.write("Transaction Summary")

        if not billData then
            term.setCursorPos(3,4)
            term.write("No transaction data available.")
        else
            local y = 4
            if billData.kind == "deposit" then
                term.setCursorPos(3,y)
                term.setTextColor(colors.green)
                term.write("+"..tostring(billData.chips).." chips credited")
                y = y + 1
                term.setTextColor(colors.white)
                term.setCursorPos(3,y)
                term.write("Spurs stored: "..tostring(billData.diamonds))
                y = y + 1
                term.setCursorPos(3,y)
                term.write("Chip value: "..tostring(billData.chipValue))
                y = y + 1
                term.setCursorPos(3,y)
                term.write("Balance: "..tostring(billData.balance) .. " chips")
            else
                -- withdraw
                term.setCursorPos(3,y)
                local net = billData.netChips or (billData.chipsCharged or 0) + (billData.chipsRefunded or 0)
                if net < 0 then
                    term.setTextColor(colors.red)
                    term.write(tostring(net) .. " chips debited")
                else
                    term.setTextColor(colors.green)
                    term.write("+"..tostring(net) .. " chips")
                end
                y = y + 1
                term.setTextColor(colors.white)
                term.setCursorPos(3,y)
                term.write("Requested spurs: "..tostring(billData.requested or billData.diamonds))
                y = y + 1
                term.setCursorPos(3,y)
                term.write("Moved spurs: "..tostring(billData.diamonds))
                y = y + 1
                term.setCursorPos(3,y)
                term.write("Fee: "..tostring(billData.feeDiamonds or 0) .. " spurs ("..tostring((billData.feeRate or 0)*100) .."%)")
                y = y + 1
                term.setCursorPos(3,y)
                term.write("Chip value: "..tostring(billData.chipValue))
                y = y + 1
                term.setCursorPos(3,y)
                term.write("Balance: "..tostring(billData.balance) .. " chips")
            end
        end

        term.setTextColor(colors.yellow)
        term.setCursorPos(3, monitorHeight - 2)
        term.write("Touch the screen to return")

        local function billWait()
            while true do
                local event, side, x, y = os.pullEvent("monitor_touch")
                state = "menuScreen"
                return
            end
        end

        parallel.waitForAny(cardChecker, billWait)
    else
        sleep(0.1)
    end
end


    





