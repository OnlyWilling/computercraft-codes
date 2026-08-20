-- ============================================================
--  Bart Membership System - Security Module
--  Custom hash + Token generation/verification (no sha256 dep)
--  Compatible with Lua 5.1 / CraftOS-PC
-- ============================================================

-- ============================================================
--  Custom deterministic hash (HMAC style)
-- ============================================================

--- Convert bytes to hex string.
--- @param str string input
--- @return string hex
local function bytesToHex(str)
    local hex = ""
    for i = 1, #str do
        hex = hex .. string.format("%02x", string.byte(str, i))
    end
    return hex
end

--- Custom deterministic hash using multi-round XOR + rotation.
--- Not cryptographically strong, but sufficient for modded MC environment.
--- @param input string
--- @param secret string server secret
--- @return string hash 64-char hex
local function customHash(input, secret)
    local mixed = secret .. input .. secret
    local state = { 0x6a, 0x09, 0xe6, 0x67, 0xbb, 0x67, 0xae, 0x85 }
    local idx = 1

    for i = 1, #mixed do
        local byte = string.byte(mixed, i)
        for j = 1, #state do
            state[j] = (state[j] + byte + idx + j) % 256
            state[j] = bit.bxor(state[j], byte)
            state[j] = bit.band(
                bit.bor(
                    bit.blshift(state[j], 3),
                    bit.brshift(state[j], 5)
                ),
                0xFF
            )
            byte = state[j]
            idx = (idx % 7) + 1
        end
    end

    for _ = 1, 3 do
        for j = 1, #state do
            local next = (j % #state) + 1
            state[j] = bit.bxor(state[j], state[next])
            state[j] = bit.band(
                bit.bor(
                    bit.blshift(state[j], 1),
                    bit.brshift(state[j], 7)
                ),
                0xFF
            )
        end
    end

    local out = ""
    for _, v in ipairs(state) do
        out = out .. string.format("%02x", v)
    end
    return out
end

-- ============================================================
--  Token generation & verification
-- ============================================================

--- Generate a random 64-char hex token.
--- Uses multi-source seeding for better randomness.
--- @return string token
local function generateToken()
    local seedSource = tostring(os.clock()) .. tostring(math.random()) .. tostring(os.epoch("local") or "")
    local seed = 0
    for i = 1, #seedSource do
        seed = seed + string.byte(seedSource, i)
    end
    math.random(seed, seed + 1)

    local t = ""
    for i = 1, 64 do
        t = t .. string.format("%x", math.random(0, 15))
    end
    return t
end

--- Hash a token for server-side storage.
--- @param token string
--- @param secret string server secret
--- @return string hash
local function hashToken(token, secret)
    return customHash(token, secret)
end

--- Verify a token against its stored hash.
--- @param token string from disk
--- @param expectedHash string stored on server
--- @param secret string server secret
--- @return boolean match
local function verifyToken(token, expectedHash, secret)
    return hashToken(token, secret) == expectedHash
end

-- ============================================================
--  Card ID generation
-- ============================================================

--- Generate a unique card ID in format CARD-XXXXXXXX.
--- @return string cardID
local function generateCardID()
    local t = ""
    for i = 1, 8 do
        t = t .. string.format("%x", math.random(0, 15))
    end
    return "CARD-" .. t
end

-- ============================================================
--  Simple XOR cipher (for config sensitive fields)
-- ============================================================

--- Simple XOR encrypt/decrypt (symmetric).
--- NOT cryptographically strong; just avoids plaintext storage.
--- Real security relies on server isolation.
--- @param data string plaintext or ciphertext
--- @param key string cipher key
--- @return string encrypted or decrypted
local function xorCipher(data, key)
    local result = ""
    for i = 1, #data do
        local k = string.byte(key, ((i - 1) % #key) + 1)
        result = result .. string.char(bit.bxor(string.byte(data, i), k))
    end
    return result
end

return {
    customHash     = customHash,
    generateToken  = generateToken,
    hashToken      = hashToken,
    verifyToken    = verifyToken,
    generateCardID = generateCardID,
    xorCipher      = xorCipher,
}
