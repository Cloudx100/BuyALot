--[[
    BuyALot: Core.lua
    Module registry, event bus, slash dispatcher, lifecycle.

    Registry: BuyALot:Register(name, kind, module). kind = "core" | "feature".
    Lifecycle: ADDON_LOADED → OnInitialize, PLAYER_LOGIN → OnEnable.
    Events: WoW events via :RegisterEvent / :UnregisterEvent (callbacks pcall'd).
    Internal pub/sub: BuyALot.Events:On / :Off / :Emit (also pcall'd).
    Slash: /bal main + :RegisterSlashCommand("sub", fn) for subcommands.
]]

local ADDON_NAME, ns = ...
local L = ns.L

local BuyALot = {}
BuyALot.name = ADDON_NAME

local _GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
BuyALot.version = (_GetMeta and _GetMeta(ADDON_NAME, "Version")) or "0.0.0"

_G.BuyALot = BuyALot
ns.BuyALot = BuyALot

-------------------------------------------------------------------------------
-- Unified module registry. kind = "core" | "feature".
-- Insertion order is preserved via registryOrder so OnInitialize/OnEnable run
-- deterministically (TOC load order = call order within each kind).
-------------------------------------------------------------------------------
local registry      = {}  -- name -> { kind = "core"|"feature", mod = <table> }
local registryOrder = {}  -- ordered list of names

function BuyALot:Register(name, kind, module)
    if registry[name] then
        error(("BuyALot: module '%s' already registered"):format(name))
    end
    if kind ~= "core" and kind ~= "feature" then
        error(("BuyALot: invalid kind '%s' (expected 'core' or 'feature')"):format(tostring(kind)))
    end
    registry[name] = { kind = kind, mod = module }
    registryOrder[#registryOrder + 1] = name
    module.name = name
    return module
end

function BuyALot:Get(name)
    local entry = registry[name]
    return entry and entry.mod or nil
end

function BuyALot:Call(method, ...)
    -- Two passes: core first, then feature. Within each kind, registration order.
    for _, kind in ipairs({ "core", "feature" }) do
        for _, regName in ipairs(registryOrder) do
            local entry = registry[regName]
            if entry.kind == kind and type(entry.mod[method]) == "function" then
                local ok, err = pcall(entry.mod[method], entry.mod, ...)
                if not ok then geterrorhandler()(err) end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- WoW event bus with multi-subscriber dispatch (pcall-isolated).
-------------------------------------------------------------------------------
local eventFrame    = CreateFrame("Frame")
local eventHandlers = {}  -- event -> { fn, ... }

function BuyALot:RegisterEvent(event, callback)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventHandlers[event], callback)
end

function BuyALot:UnregisterEvent(event)
    eventHandlers[event] = nil
    eventFrame:UnregisterEvent(event)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = eventHandlers[event]
    if not list then return end
    for _, callback in ipairs(list) do
        local ok, err = pcall(callback, event, ...)
        if not ok then geterrorhandler()(err) end
    end
end)

-------------------------------------------------------------------------------
-- Internal pub/sub for cross-module messages.
-------------------------------------------------------------------------------
local subscribers = {}  -- name -> { fn, ... }

BuyALot.Events = {}

function BuyALot.Events:On(name, handler)
    subscribers[name] = subscribers[name] or {}
    table.insert(subscribers[name], handler)
    return handler
end

function BuyALot.Events:Off(name, handler)
    local list = subscribers[name]
    if not list then return end
    for i, fn in ipairs(list) do
        if fn == handler then
            table.remove(list, i)
            return
        end
    end
end

function BuyALot.Events:Emit(name, data)
    local list = subscribers[name]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, data)
        if not ok then geterrorhandler()(err) end
    end
end

-------------------------------------------------------------------------------
-- Locale helper for feature modules.
-- Usage: local FL = BuyALot:CreateLocale({ enUS = {...}, ruRU = {...} })
-------------------------------------------------------------------------------
function BuyALot:CreateLocale(tables)
    local enUS = tables.enUS or {}
    local ruRU = tables.ruRU or enUS
    local FL = {}
    setmetatable(FL, { __index = function(_, key)
        if L:GetLocale() == "ruRU" then
            return ruRU[key] or enUS[key] or key
        end
        return enUS[key] or key
    end })
    return FL
end

-------------------------------------------------------------------------------
-- Slash subcommand registry. /bal <sub> dispatches to registered fn.
-------------------------------------------------------------------------------
local slashSubs = {}  -- lowercased sub -> fn(rest)

function BuyALot:RegisterSlashCommand(sub, callback)
    slashSubs[sub:lower()] = callback
end

-------------------------------------------------------------------------------
-- Debug system.
-------------------------------------------------------------------------------
local debugMode = false

function BuyALot:SetDebug(enabled)
    debugMode = not not enabled
    print("|cff00ff00BuyALot:|r " .. (debugMode and L["DEBUG_ON"] or L["DEBUG_OFF"]))
end

function BuyALot:IsDebug()
    return debugMode
end

function BuyALot:Debug(scope, ...)
    if not debugMode then return end
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do parts[i] = tostring((select(i, ...))) end
    print(("|cff888888[BAL:%s]|r %s"):format(tostring(scope), table.concat(parts, " ")))
end

-------------------------------------------------------------------------------
-- Lifecycle.
--   ADDON_LOADED → :Call("OnInitialize") for all registered modules
--   PLAYER_LOGIN → :Call("OnEnable")
-------------------------------------------------------------------------------
BuyALot:RegisterEvent("ADDON_LOADED", function(_, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    BuyALot:Call("OnInitialize")

    local Data = BuyALot:Get("Data")
    if Data and Data:GetSettings().debug then debugMode = true end

    -- Defer the welcome print to avoid taint propagation through ADDON_LOADED.
    C_Timer.After(0, function() print(L["ADDON_LOADED"]) end)

    BuyALot:UnregisterEvent("ADDON_LOADED")
end)

BuyALot:RegisterEvent("PLAYER_LOGIN", function()
    BuyALot:Call("OnEnable")
    BuyALot:UnregisterEvent("PLAYER_LOGIN")
end)

-------------------------------------------------------------------------------
-- Slash command: /bal
-------------------------------------------------------------------------------
SLASH_BUYALOT1 = "/bal"

SlashCmdList["BUYALOT"] = function(msg)
    local cmd, rest = strsplit(" ", strtrim(msg or ""), 2)
    cmd = (cmd or ""):lower()

    if cmd == "" then
        local UI = BuyALot:Get("UI")
        if UI and UI.ToggleSettings then UI:ToggleSettings() end
        return
    end

    if cmd == "help" then
        print("|cff00ff00BuyALot:|r " .. L["SLASH_HELP"])
        return
    end

    if cmd == "debug" then
        BuyALot:SetDebug(not debugMode)
        local Data = BuyALot:Get("Data")
        if Data then Data:GetSettings().debug = debugMode end
        return
    end

    local fn = slashSubs[cmd]
    if fn then
        fn(rest)
        return
    end

    print("|cff00ff00BuyALot:|r " .. L["SLASH_UNKNOWN"])
end

BuyALot.L = L
