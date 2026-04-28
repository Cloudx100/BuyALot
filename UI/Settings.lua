--[[
    BuyALot: UI/Settings.lua
    Settings popup. v0.1: language switch (Auto/EN/RU) + debug toggle.
    A theme switcher will appear here automatically once a second theme is
    registered (currently only "native" exists).
]]

local ADDON_NAME, ns = ...
local BuyALot = ns.BuyALot
local L = ns.L

local Settings = {}
ns.UI_Settings = Settings

local frame  -- lazily created on first Toggle()

-------------------------------------------------------------------------------
-- Build / refresh content.
-------------------------------------------------------------------------------

local function ClearContent(f)
    if not f._children then return end
    for _, child in ipairs(f._children) do
        child:Hide()
        child:SetParent(nil)
        if child.labelText then
            child.labelText:Hide()
            child.labelText:SetParent(nil)
        end
    end
    f._children = nil
end

local function BuildContent(f)
    local UI   = BuyALot:Get("UI")
    local Data = BuyALot:Get("Data")
    local s    = Data:GetSettings()

    f._children = {}
    local function track(child) f._children[#f._children + 1] = child end

    -- Language section
    local langLabel = UI:CreateLabel(f, {
        text  = L["SETTINGS_LANGUAGE"],
        font  = "GameFontNormal",
        color = "TITLE",
    })
    langLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -34)
    track(langLabel)

    local langOptions = {
        { value = "auto", label = L["SETTINGS_LANG_AUTO"] },
        { value = "enUS", label = L["SETTINGS_LANG_EN"]   },
        { value = "ruRU", label = L["SETTINGS_LANG_RU"]   },
    }

    local langButtons = {}
    local function SelectLang(value)
        s.language = (value == "auto") and nil or value
        L:SetLocale(value)
        for _, btn in ipairs(langButtons) do
            btn:SetChecked(btn.langValue == value)
        end
        Settings.Refresh()
    end

    for i, opt in ipairs(langOptions) do
        local current = (s.language == nil and opt.value == "auto")
                     or (s.language == opt.value)
        local cb = UI:CreateCheckbox(f, {
            label    = opt.label,
            initial  = current,
            onChange = function() SelectLang(opt.value) end,
        })
        cb.langValue = opt.value
        cb:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", 0, -8 - (i - 1) * 24)
        langButtons[i] = cb
        track(cb)
    end

    -- Debug toggle
    local debugCb = UI:CreateCheckbox(f, {
        label    = L["SETTINGS_DEBUG"],
        initial  = s.debug == true,
        onChange = function(checked)
            s.debug = checked and true or false
            BuyALot:SetDebug(checked)
        end,
    })
    debugCb:SetPoint("TOPLEFT", langButtons[#langButtons], "BOTTOMLEFT", 0, -16)
    track(debugCb)
end

-------------------------------------------------------------------------------
-- Public API.
-------------------------------------------------------------------------------

function Settings.Create()
    if frame then return frame end
    local UI = BuyALot:Get("UI")
    frame = UI:CreatePopup({
        name   = "BuyALotSettingsFrame",
        title  = L["SETTINGS_TITLE"],
        width  = 320,
        height = 220,
    })
    BuildContent(frame)
    return frame
end

function Settings.Refresh()
    if not frame then return end
    if frame.SetTitle then
        frame:SetTitle(L["SETTINGS_TITLE"])
    elseif frame.TitleText then
        frame.TitleText:SetText(L["SETTINGS_TITLE"])
    end
    ClearContent(frame)
    BuildContent(frame)
end

function Settings.Toggle()
    Settings.Create()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function Settings.GetFrame()
    return frame
end

-- Re-apply colors when theme switches at runtime.
BuyALot.Events:On("THEME_CHANGED", function()
    if frame and frame:IsShown() then Settings.Refresh() end
end)
