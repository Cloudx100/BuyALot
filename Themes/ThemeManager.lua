--[[
    BuyALot: Themes/ThemeManager.lua
    Color theme registry. v0.1 ships one theme ("native") drawn from Blizzard's
    palette so the addon matches the base WoW UI.

    On theme switch, ThemeManager emits "THEME_CHANGED" via BuyALot.Events.
    Frames that care subscribe and re-apply colors. (No destroy-and-recreate.)

    Public API (BuyALot:Get("Themes")):
      :GetColor(key)              -> { r, g, b, a }
      :C(key)                     -> r, g, b, a (unpacked, convenience)
      :GetThemeName()             -> string
      :SetTheme(name)             -> bool ok
      :RegisterTheme(name, table) -> register a new palette
      :GetThemes()                -> array of theme names
]]

local ADDON_NAME, ns = ...
local BuyALot = ns.BuyALot

local Themes = {}
BuyALot:Register("Themes", "core", Themes)

-------------------------------------------------------------------------------
-- Native WoW palette. All values in [0,1]; alpha defaults to 1.
-------------------------------------------------------------------------------
local NATIVE = {
    -- Text
    TITLE       = { 1.00, 0.82, 0.00, 1 },  -- gold (Blizzard heading)
    TEXT        = { 1.00, 1.00, 1.00, 1 },
    TEXT_DIM    = { 0.70, 0.70, 0.70, 1 },
    TEXT_HINT   = { 0.50, 0.50, 0.50, 1 },
    LABEL       = { 0.85, 0.85, 0.85, 1 },

    -- Semantic
    POSITIVE    = { 0.10, 0.85, 0.20, 1 },  -- "income" green
    NEGATIVE    = { 0.95, 0.30, 0.30, 1 },  -- "expense" red
    WARNING     = { 1.00, 0.65, 0.10, 1 },  -- orange

    -- Frame
    BORDER      = { 0.40, 0.40, 0.40, 1 },
    SEPARATOR   = { 0.30, 0.30, 0.30, 0.6 },

    -- Coin (matches in-game money frame)
    COIN_GOLD   = { 1.00, 0.82, 0.00, 1 },
    COIN_SILVER = { 0.75, 0.75, 0.75, 1 },
    COIN_COPPER = { 0.72, 0.45, 0.22, 1 },
}

local registered = { native = NATIVE }
local currentName = "native"
local current = NATIVE

-------------------------------------------------------------------------------
-- Lifecycle.
-------------------------------------------------------------------------------
function Themes:OnInitialize()
    local Data = BuyALot:Get("Data")
    local saved = Data and Data:GetSettings().theme
    if saved and registered[saved] then
        currentName = saved
        current = registered[saved]
    end
end

-------------------------------------------------------------------------------
-- Public API.
-------------------------------------------------------------------------------
function Themes:GetColor(key)
    return current[key] or NATIVE[key] or { 1, 1, 1, 1 }
end

function Themes:C(key)
    local c = self:GetColor(key)
    return c[1], c[2], c[3], c[4] or 1
end

function Themes:GetThemeName()
    return currentName
end

function Themes:GetThemes()
    local list = {}
    for name in pairs(registered) do list[#list + 1] = name end
    table.sort(list)
    return list
end

function Themes:RegisterTheme(name, palette)
    if type(name) ~= "string" or type(palette) ~= "table" then return false end
    registered[name] = palette
    return true
end

function Themes:SetTheme(name)
    if not registered[name] then return false end
    if name == currentName then return true end
    currentName = name
    current = registered[name]
    local Data = BuyALot:Get("Data")
    if Data then Data:GetSettings().theme = name end
    BuyALot.Events:Emit("THEME_CHANGED", name)
    return true
end
