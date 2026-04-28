--[[
    BuyALot: UI/UI.lua
    Reusable UI factories. All built on native Blizzard templates so the addon
    blends with the base game UI. Colors come from ThemeManager (lazy reads).

    Public API (BuyALot:Get("UI")):
      :CreatePopup(opts)
      :CreateButton(parent, opts)
      :CreateLabel(parent, opts)
      :CreateCheckbox(parent, opts)
      :CreateEditBox(parent, opts)
      :CreateSeparator(parent, yOffset)
      :ToggleSettings()
]]

local ADDON_NAME, ns = ...
local BuyALot = ns.BuyALot
local L = ns.L

local UI = {}
BuyALot:Register("UI", "core", UI)

-- Lazy theme color access. Re-reads on every call so frames that subscribe
-- to THEME_CHANGED can re-apply with one helper.
local function T(key)
    local Themes = BuyALot:Get("Themes")
    return Themes and Themes:GetColor(key) or { 1, 1, 1, 1 }
end

local function TC(key)
    local c = T(key)
    return c[1], c[2], c[3], c[4] or 1
end

UI.T  = T   -- exposed for feature modules
UI.TC = TC

-------------------------------------------------------------------------------
-- CreatePopup: BasicFrameTemplateWithInset window with title, close, drag,
-- ESC-to-close (via UISpecialFrames), fade-in on show.
--
-- opts: { name, title, width, height, parent, strata, movable, closeOnEscape, onClose }
-------------------------------------------------------------------------------
function UI:CreatePopup(opts)
    opts = opts or {}
    local f = CreateFrame("Frame", opts.name, opts.parent or UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(opts.width or 400, opts.height or 300)
    f:SetPoint("CENTER")
    f:SetFrameStrata(opts.strata or "DIALOG")
    f:SetClampedToScreen(true)

    if opts.movable ~= false then
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
    end

    if opts.title then
        if f.SetTitle then
            f:SetTitle(opts.title)
        elseif f.TitleText then
            f.TitleText:SetText(opts.title)
        elseif f.TitleContainer and f.TitleContainer.TitleText then
            f.TitleContainer.TitleText:SetText(opts.title)
        end
    end

    if opts.closeOnEscape ~= false and opts.name then
        tinsert(UISpecialFrames, opts.name)
    end

    if f.CloseButton then
        f.CloseButton:SetScript("OnClick", function()
            if opts.onClose then opts.onClose(f) end
            f:Hide()
        end)
    end

    f:HookScript("OnShow", function(self)
        local Anim = ns.UI_Animations
        if Anim and Anim.FadeIn then Anim.FadeIn(self, 0.15) end
    end)

    f:Hide()
    return f
end

-------------------------------------------------------------------------------
-- CreateButton: UIPanelButtonTemplate (native gold-accented button).
--
-- opts: { label, width, height, onClick, tooltip }
-------------------------------------------------------------------------------
function UI:CreateButton(parent, opts)
    opts = opts or {}
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn.fitTextCanWidthDecrease = false
    btn.fitTextWidthPadding = 0
    btn:SetSize(opts.width or 80, opts.height or 22)
    btn:SetText(opts.label or "")

    if opts.onClick then btn:SetScript("OnClick", opts.onClick) end

    if opts.tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(opts.tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
    end

    return btn
end

-------------------------------------------------------------------------------
-- CreateLabel: FontString.
--
-- opts: { text, font, color (key like "TITLE" or {r,g,b,a}), width, justify, anchor }
-- anchor: { point, relTo, relPoint, x, y }
-------------------------------------------------------------------------------
function UI:CreateLabel(parent, opts)
    opts = opts or {}
    local fs = parent:CreateFontString(nil, "OVERLAY", opts.font or "GameFontHighlight")
    if opts.text   then fs:SetText(opts.text)    end
    if opts.width  then fs:SetWidth(opts.width)  end
    if opts.justify then fs:SetJustifyH(opts.justify) end
    if opts.color then
        if type(opts.color) == "string" then
            fs:SetTextColor(TC(opts.color))
        else
            fs:SetTextColor(opts.color[1], opts.color[2], opts.color[3], opts.color[4] or 1)
        end
    end
    if opts.anchor then
        local a = opts.anchor
        fs:SetPoint(a.point or "TOPLEFT", a.relTo or parent, a.relPoint or a.point or "TOPLEFT", a.x or 0, a.y or 0)
    end
    return fs
end

-------------------------------------------------------------------------------
-- CreateCheckbox: UICheckButtonTemplate with right-aligned label.
--
-- opts: { label, initial, onChange(checked) }
-- Returns the checkbox; .labelText is the FontString next to it.
-------------------------------------------------------------------------------
function UI:CreateCheckbox(parent, opts)
    opts = opts or {}
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(opts.label or "")
    label:SetTextColor(TC("LABEL"))
    cb.labelText = label

    if opts.initial ~= nil then cb:SetChecked(opts.initial) end

    cb:SetScript("OnClick", function(self)
        if opts.onChange then opts.onChange(self:GetChecked()) end
    end)

    return cb
end

-------------------------------------------------------------------------------
-- CreateEditBox: InputBoxTemplate (single-line text/numeric input).
--
-- opts: { width, height, maxLetters, autoFocus, numeric, justify,
--         onTextChanged, onEnterPressed, onEscapePressed }
-------------------------------------------------------------------------------
function UI:CreateEditBox(parent, opts)
    opts = opts or {}
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(opts.width or 80, opts.height or 20)
    eb:SetAutoFocus(opts.autoFocus or false)
    eb:SetMaxLetters(opts.maxLetters or 16)
    eb:SetFontObject(ChatFontNormal)
    if opts.numeric then eb:SetNumeric(true) end
    if opts.justify then eb:SetJustifyH(opts.justify) end

    if opts.onTextChanged then
        eb:SetScript("OnTextChanged", function(self, userInput)
            opts.onTextChanged(self, userInput)
        end)
    end
    if opts.onEnterPressed then
        eb:SetScript("OnEnterPressed", opts.onEnterPressed)
    end
    eb:SetScript("OnEscapePressed", opts.onEscapePressed or function(self) self:ClearFocus() end)

    return eb
end

-------------------------------------------------------------------------------
-- CreateSeparator: thin horizontal divider line, anchored across parent's width.
-------------------------------------------------------------------------------
function UI:CreateSeparator(parent, yOffset)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  parent, "TOPLEFT",  12, yOffset or 0)
    sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset or 0)
    sep:SetColorTexture(TC("SEPARATOR"))
    return sep
end

-------------------------------------------------------------------------------
-- Settings popup convenience.
-------------------------------------------------------------------------------
function UI:ToggleSettings()
    local S = ns.UI_Settings
    if not S or not S.Toggle then return end
    S.Toggle()
end
