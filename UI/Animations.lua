--[[
    BuyALot: UI/Animations.lua
    Thin wrappers over Blizzard's UIFrameFade* helpers.

    Exposed via ns.UI_Animations (used by UI/UI.lua and feature frames).
]]

local ADDON_NAME, ns = ...

local Animations = {}
ns.UI_Animations = Animations

function Animations.FadeIn(frame, duration, fromAlpha, toAlpha)
    if not frame then return end
    if UIFrameFadeIn then
        UIFrameFadeIn(frame, duration or 0.2, fromAlpha or 0, toAlpha or 1)
    else
        frame:SetAlpha(toAlpha or 1)
    end
end

function Animations.FadeOut(frame, duration, fromAlpha, toAlpha)
    if not frame then return end
    if UIFrameFadeOut then
        UIFrameFadeOut(frame, duration or 0.2, fromAlpha or 1, toAlpha or 0)
    else
        frame:SetAlpha(toAlpha or 0)
    end
end
