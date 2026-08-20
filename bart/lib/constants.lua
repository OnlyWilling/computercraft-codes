-- ============================================================
--  Bart Membership System - Constants & Config
-- ============================================================

-- Member tier definitions (auto-upgrade thresholds)
local TIERS = {
    dirt    = { index = 0, name = "Dirt",    label = "Dirt Member",    threshold = 0,      discount = 1.0,  pointMultiplier = 1 },
    iron    = { index = 1, name = "Iron",    label = "Iron Member",    threshold = 1000,   discount = 0.95, pointMultiplier = 1 },
    gold    = { index = 2, name = "Gold",    label = "Gold Member",    threshold = 5000,   discount = 0.90, pointMultiplier = 2 },
    diamond = { index = 3, name = "Diamond", label = "Diamond Member", threshold = 20000,  discount = 0.85, pointMultiplier = 3 },
    basalt  = { index = 4, name = "Basalt",  label = "Admin Basalt",   threshold = -1,     discount = 0.80, pointMultiplier = 5 },
}

local TIER_NAMES = { "dirt", "iron", "gold", "diamond", "basalt" }

local TIER_COLORS = {
    dirt    = colors.orange,
    iron    = colors.lightGray,
    gold    = colors.yellow,
    diamond = colors.cyan,
    basalt  = colors.purple,
}

local PROTOCOL = "bart_member"

local MSG = {
    AUTH        = "AUTH",
    CONSUME     = "CONSUME",
    RECHARGE    = "RECHARGE",
    QUERY       = "QUERY",
    FREEZE      = "FREEZE",
    UNFREEZE    = "UNFREEZE",
    REISSUE     = "REISSUE",
    UPGRADE     = "UPGRADE",
    NEW_CARD    = "NEW_CARD",
    LIST_PLAYER = "LIST_PLAYER",
    HISTORY     = "HISTORY",
}

local STATUS = {
    SUCCESS = "SUCCESS",
    FAIL    = "FAIL",
}

local DEFAULT_CONFIG = {
    serverSecret       = nil,
    defaultTier        = "dirt",
    pointsPerCurrency  = 1,
    dataDir            = "data",
    logRetention       = 1000,
}

return {
    TIERS       = TIERS,
    TIER_NAMES  = TIER_NAMES,
    TIER_COLORS = TIER_COLORS,
    PROTOCOL    = PROTOCOL,
    MSG         = MSG,
    STATUS      = STATUS,
    DEFAULT_CONFIG = DEFAULT_CONFIG,
}
