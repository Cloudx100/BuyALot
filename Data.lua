--[[
    BuyALot: Data.lua
    SavedVariables facade — pure SDK, no feature data.

    Stores: dbVersion, settings (language/debug/theme), modules namespaces.
    Feature modules call Data:RegisterNamespace(name, defaults) to claim a slot.
]]

local ADDON_NAME, ns = ...
local BuyALot = ns.BuyALot

local Data = {}
BuyALot:Register("Data", "core", Data)

-------------------------------------------------------------------------------
-- Schema versioning. Bump DB_VERSION + add an entry to Migrations whenever
-- the schema changes in a non-additive way. Additive changes are handled by
-- ApplyDefaults at every load.
-------------------------------------------------------------------------------
local DB_VERSION = 1

local Migrations = {
    -- [target_version] = function(db) ... end
    -- v1 is the initial schema; nothing to migrate from.
}

local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

-------------------------------------------------------------------------------
-- v1 default schema.
-------------------------------------------------------------------------------
local DB_DEFAULTS = {
    dbVersion = DB_VERSION,
    settings  = {
        language = nil,        -- nil = auto, else "enUS" / "ruRU"
        debug    = false,
        theme    = "native",
    },
    modules   = {},            -- per-feature namespaced data
}

-------------------------------------------------------------------------------
-- Lifecycle.
-------------------------------------------------------------------------------
function Data:OnInitialize()
    if not BuyALotDB then BuyALotDB = {} end

    local fromVersion = BuyALotDB.dbVersion or 0
    if fromVersion < DB_VERSION then
        for v = fromVersion + 1, DB_VERSION do
            local migrate = Migrations[v]
            if migrate then
                local ok, err = pcall(migrate, BuyALotDB)
                if not ok then geterrorhandler()(err) end
            end
            BuyALotDB.dbVersion = v
        end
    end

    ApplyDefaults(BuyALotDB, DB_DEFAULTS)

    local savedLang = BuyALotDB.settings.language
    if savedLang and savedLang ~= "auto" then
        local L = ns.L
        if L and L.SetLocale then L:SetLocale(savedLang) end
    end
end

-------------------------------------------------------------------------------
-- Public API.
-------------------------------------------------------------------------------
function Data:GetSettings()
    return BuyALotDB and BuyALotDB.settings or DB_DEFAULTS.settings
end

function Data:RegisterNamespace(name, defaults)
    BuyALotDB.modules = BuyALotDB.modules or {}
    BuyALotDB.modules[name] = BuyALotDB.modules[name] or {}
    if defaults then ApplyDefaults(BuyALotDB.modules[name], defaults) end
    return BuyALotDB.modules[name]
end

function Data:GetNamespace(name)
    return BuyALotDB and BuyALotDB.modules and BuyALotDB.modules[name]
end
