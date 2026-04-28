--[[
    BuyALot / VendorBulk: MerchantHook.lua
    Detects shift-click on merchant item buttons and opens the BuyALot popup.

    Strategy: hook each MerchantItem%dItemButton's OnClick via HookScript (post-hook,
    taint-safe). The default UI also opens StackSplitFrame on shift-click — we hide
    that and show our own popup anchored above the clicked button.

    Also auto-closes the popup when MerchantFrame closes.
]]

local ADDON_NAME, ns = ...
ns.VendorBulk = ns.VendorBulk or {}

local BuyALot = ns.BuyALot

local Hook = {}
ns.VendorBulk.MerchantHook = Hook

local hooked = false

-------------------------------------------------------------------------------
-- Per-button click hook.
-------------------------------------------------------------------------------

local function OnMerchantButtonClick(self, mouseBtn)
    -- Only react in the merchant tab (tab 1), not buyback (tab 2).
    if MerchantFrame and MerchantFrame.selectedTab and MerchantFrame.selectedTab ~= 1 then return end

    if not IsShiftKeyDown() then return end

    -- If user is composing a chat message, default behavior pastes the link — let it.
    if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then return end

    -- Hide default StackSplit popup if it just opened.
    if StackSplitFrame and StackSplitFrame:IsShown() then
        StackSplitFrame:Hide()
    end

    local Frame = ns.VendorBulk.Frame
    if Frame and Frame.Open then
        Frame.Open(self)
    end
end

-------------------------------------------------------------------------------
-- Attach hooks. Iterates MerchantItem%dItemButton until the first missing one
-- so we cover whatever count Blizzard ships in this client.
-------------------------------------------------------------------------------

local function AttachHooks()
    if hooked then return end
    local i = 1
    while _G["MerchantItem" .. i .. "ItemButton"] do
        local btn = _G["MerchantItem" .. i .. "ItemButton"]
        btn:HookScript("OnClick", OnMerchantButtonClick)
        btn:HookScript("OnHide", function()
            local Frame = ns.VendorBulk.Frame
            if Frame and Frame.IsShown and Frame.IsShown() then Frame.Hide() end
        end)
        i = i + 1
    end
    hooked = (i > 1)
    BuyALot:Debug("VendorBulk", "hooked", i - 1, "merchant buttons")
end

-------------------------------------------------------------------------------
-- Lifecycle: init on first MERCHANT_SHOW (default UI may load lazily).
-- Auto-close the popup when MerchantFrame hides.
-------------------------------------------------------------------------------

function Hook.Init()
    BuyALot:RegisterEvent("MERCHANT_SHOW", function()
        AttachHooks()
    end)

    BuyALot:RegisterEvent("MERCHANT_CLOSED", function()
        local Frame = ns.VendorBulk.Frame
        if Frame and Frame.IsShown and Frame.IsShown() then Frame.Hide() end
    end)
end
