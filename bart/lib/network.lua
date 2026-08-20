-- ============================================================
--  Bart Membership System - Network Module
--  Rednet protocol with wired/wireless modem auto-detect
-- ============================================================

local C = require "lib/constants"

-- ============================================================
--  Modem discovery
-- ============================================================

--- Find the first available modem (wired preferred).
--- @return string|nil side
--- @return string|nil type "modem"|"wireless_modem"
local function findModem()
    local sides = { "back", "left", "right", "top", "bottom" }
    for _, s in ipairs(sides) do
        if peripheral.getType(s) == "modem" then
            return s, "modem"
        end
    end
    for _, s in ipairs(sides) do
        if peripheral.getType(s) == "wireless_modem" then
            return s, "wireless_modem"
        end
    end
    return nil, nil
end

-- ============================================================
--  Rednet wrapper
-- ============================================================

local _hostID = nil
local _modemSide = nil

--- Initialize the network connection.
--- @return boolean success
local function init()
    local side, mtype = findModem()
    if not side then
        return false
    end
    _modemSide = side
    rednet.open(side)
    _hostID = os.computerID()
    return true
end

--- Close the network connection.
local function close()
    if _modemSide then
        rednet.close(_modemSide)
        _modemSide = nil
    end
end

--- Get the local computer ID.
--- @return number hostID
local function hostID()
    return _hostID or os.computerID()
end

--- Check if network is ready.
--- @return boolean
local function isReady()
    return _modemSide ~= nil
end

-- ============================================================
--  Client: send requests to server
-- ============================================================

--- Send a request to the server and wait for response.
--- @param serverID number
--- @param msgType string
--- @param data table
--- @param timeout number seconds
--- @return table|nil response data
--- @return string|nil err
local function sendRequest(serverID, msgType, data, timeout)
    if not isReady() then
        return nil, "Network not initialized"
    end

    local packet = {
        type = msgType,
        data = data,
        from = hostID(),
        time = os.epoch("local") or 0,
    }

    rednet.send(serverID, packet, C.PROTOCOL)

    local sender, message, protocol
    if timeout and timeout > 0 then
        sender, message, protocol = rednet.receive(C.PROTOCOL, timeout)
    else
        sender, message, protocol = rednet.receive(C.PROTOCOL)
    end

    if not sender then
        return nil, "Request timed out"
    end

    if message and message.success then
        return message.data, nil
    elseif message and message.error then
        return nil, message.error
    else
        return nil, "Unknown response"
    end
end

--- Send a request without waiting for response.
local function sendRequestNoWait(serverID, msgType, data)
    if not isReady() then return false end

    local packet = {
        type = msgType,
        data = data,
        from = hostID(),
        time = os.epoch("local") or 0,
    }
    rednet.send(serverID, packet, C.PROTOCOL)
    return true
end

-- ============================================================
--  Server: handle incoming requests
-- ============================================================

--- Wait for and receive a request (blocking).
--- @param timeout number|nil
--- @return table|nil request { type, data, from }
local function waitForRequest(timeout)
    if not isReady() then
        return nil
    end

    local sender, message, protocol = rednet.receive(C.PROTOCOL, timeout)
    if not sender then
        return nil
    end

    return {
        type = message.type,
        data = message.data,
        from = sender,
    }
end

--- Send a response to a client.
--- @param target number
--- @param success boolean
--- @param data table|nil
--- @param error string|nil
local function sendResponse(target, success, data, error)
    if not isReady() then return end
    rednet.send(target, {
        success = success,
        data    = data,
        error   = error,
    }, C.PROTOCOL)
end

-- ============================================================
--  Service discovery: find a bart server
-- ============================================================

--- Broadcast to find a server, return first responder.
--- @param timeout number seconds
--- @return number|nil serverID
--- @return string|nil err
local function discoverServer(timeout)
    if not isReady() then
        return nil, "Network not initialized"
    end

    rednet.broadcast({
        type = "DISCOVER",
        from = hostID(),
        time = os.epoch("local") or 0,
    }, C.PROTOCOL)

    local deadline = os.clock() + (timeout or 3)
    while os.clock() < deadline do
        local sender, message = rednet.receive(C.PROTOCOL, deadline - os.clock())
        if sender and message and message.type == "DISCOVER_ACK" then
            return sender, nil
        end
    end

    return nil, "Server not found"
end

-- ============================================================
--  Convenience: send request to known or discovered server
-- ============================================================

--- Send a request to a known (or auto-discovered) server.
--- @param serverID number|nil known server ID
--- @param msgType string
--- @param data table
--- @param timeout number seconds
--- @return table|nil response
--- @return string|nil err
local function request(serverID, msgType, data, timeout)
    if not isReady() then
        return nil, "Network not initialized"
    end

    local sid = serverID
    if not sid then
        sid = discoverServer(2)
        if not sid then
            return nil, "Server not found"
        end
    end

    return sendRequest(sid, msgType, data, timeout or 5)
end

return {
    init              = init,
    close             = close,
    hostID            = hostID,
    isReady           = isReady,
    findModem         = findModem,

    sendRequest       = sendRequest,
    sendRequestNoWait = sendRequestNoWait,
    discoverServer    = discoverServer,
    request           = request,

    waitForRequest    = waitForRequest,
    sendResponse      = sendResponse,
}
