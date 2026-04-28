--[[
    BuyALot / VendorBulk: Locale.lua
    Feature-specific strings. Built via BuyALot:CreateLocale (en/ru fallback).
]]

local ADDON_NAME, ns = ...
ns.VendorBulk = ns.VendorBulk or {}

local BuyALot = ns.BuyALot

local L = BuyALot:CreateLocale({
    enUS = {
        POPUP_TITLE        = "Buy: %s",
        BUTTON_STACK       = "Stack",
        BUTTON_MAX         = "Max",
        BUTTON_OK          = "Okay",
        BUTTON_CANCEL      = "Cancel",
        LABEL_COST         = "Cost:",

        TT_STACK           = "Buy one full stack: |cffffffff%d|r",
        TT_MAX_TITLE       = "Buy as many as possible: |cffffffff%d|r",
        TT_MAX_FIT         = "Fits in bags",
        TT_MAX_AFFORD      = "Can afford",
        TT_MAX_AVAIL       = "Vendor has",
        TT_AVAILABLE_INF   = "∞",

        CONFIRM_TEXT       = "Buy |cffffffff%d × %s|r ?\nMore than one stack will be created.",

        SLASH_CONFIRM_ON   = "Purchase confirmation: |cff00ff00ON|r",
        SLASH_CONFIRM_OFF  = "Purchase confirmation: |cffff4444OFF|r",
        SLASH_CONFIRM_HELP = "Usage: /bal confirm — toggle confirmation popup",

        ERR_NO_SPACE       = "Not enough bag space.",
        ERR_NO_MONEY       = "Not enough money.",
        ERR_NONE_AVAIL     = "Vendor has none of this item.",
    },
    ruRU = {
        POPUP_TITLE        = "Купить: %s",
        BUTTON_STACK       = "Стопка",
        BUTTON_MAX         = "Макс",
        BUTTON_OK          = "OK",
        BUTTON_CANCEL      = "Отмена",
        LABEL_COST         = "Стоимость:",

        TT_STACK           = "Купить одну полную стопку: |cffffffff%d|r",
        TT_MAX_TITLE       = "Купить максимум: |cffffffff%d|r",
        TT_MAX_FIT         = "Влезет в сумки",
        TT_MAX_AFFORD      = "Хватит денег",
        TT_MAX_AVAIL       = "У торговца",
        TT_AVAILABLE_INF   = "∞",

        CONFIRM_TEXT       = "Купить |cffffffff%d × %s|r ?\nБудет создано больше одной стопки.",

        SLASH_CONFIRM_ON   = "Подтверждение покупки: |cff00ff00ВКЛ|r",
        SLASH_CONFIRM_OFF  = "Подтверждение покупки: |cffff4444ВЫКЛ|r",
        SLASH_CONFIRM_HELP = "Использование: /bal confirm — переключить подтверждение",

        ERR_NO_SPACE       = "Недостаточно места в сумках.",
        ERR_NO_MONEY       = "Недостаточно денег.",
        ERR_NONE_AVAIL     = "У торговца нет этого предмета.",
    },
})

ns.VendorBulk.L = L
