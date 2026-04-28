--[[
    BuyALot: Locale.lua
    Localization registry. enUS is the base; ruRU overrides via __index fallback.
    Access: ns.L["KEY"] returns translated string or the key itself if missing.
]]

local ADDON_NAME, ns = ...

local enUS = {
    ADDON_LOADED       = "|cff00ff00BuyALot|r loaded. Type |cfffff569/bal|r for settings.",
    ADDON_TITLE        = "BuyALot",

    SLASH_HELP         = "Usage: /bal — settings, /bal help — this help, /bal debug — toggle debug",
    SLASH_UNKNOWN      = "Unknown command. Type /bal help.",

    SETTINGS_TITLE     = "BuyALot — Settings",
    SETTINGS_LANGUAGE  = "Language",
    SETTINGS_LANG_AUTO = "Auto (game language)",
    SETTINGS_LANG_EN   = "English",
    SETTINGS_LANG_RU   = "Русский",
    SETTINGS_DEBUG     = "Debug messages",

    DEBUG_ON           = "debug |cff00ff00ON|r",
    DEBUG_OFF          = "debug |cffff4444OFF|r",
}

local ruRU = {
    ADDON_LOADED       = "|cff00ff00BuyALot|r загружен. Введите |cfffff569/bal|r для настроек.",
    ADDON_TITLE        = "BuyALot",

    SLASH_HELP         = "Использование: /bal — настройки, /bal help — справка, /bal debug — отладка",
    SLASH_UNKNOWN      = "Неизвестная команда. Введите /bal help.",

    SETTINGS_TITLE     = "BuyALot — Настройки",
    SETTINGS_LANGUAGE  = "Язык",
    SETTINGS_LANG_AUTO = "Авто (язык игры)",
    SETTINGS_LANG_EN   = "English",
    SETTINGS_LANG_RU   = "Русский",
    SETTINGS_DEBUG     = "Отладочные сообщения",

    DEBUG_ON           = "отладка |cff00ff00ВКЛ|r",
    DEBUG_OFF          = "отладка |cffff4444ВЫКЛ|r",
}

local L = {}
local activeLocale = (GetLocale() == "ruRU") and "ruRU" or "enUS"

setmetatable(L, {
    __index = function(_, key)
        if activeLocale == "ruRU" then
            return ruRU[key] or enUS[key] or key
        end
        return enUS[key] or key
    end,
})

function L:SetLocale(locale)
    if locale == nil or locale == "auto" then
        activeLocale = (GetLocale() == "ruRU") and "ruRU" or "enUS"
    else
        activeLocale = locale
    end
end

function L:GetLocale()
    return activeLocale
end

ns.L = L
