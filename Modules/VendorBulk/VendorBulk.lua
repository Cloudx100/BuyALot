--[[
    BuyALot / VendorBulk: VendorBulk.lua
    Feature module entry. Mirrors BuyEmAll vendor flow on the BuyALot SDK.

    On shift-click of a merchant item, opens a custom quantity popup with
    Stack/Max buttons, live cost calc, and an optional confirmation when
    buying more than one stack.

    Persistent settings (per-account, BuyALotDB.modules.vendorBulk):
      confirmEnabled : bool — show confirmation when buying >1 stack
]]

local ADDON_NAME, ns = ...
ns.VendorBulk = ns.VendorBulk or {}

local BuyALot = ns.BuyALot
local L       = ns.VendorBulk.L

local Module = {}
ns.VendorBulk.Module = Module

BuyALot:Register("vendorBulk", "feature", Module)

-------------------------------------------------------------------------------
-- Lifecycle.
-------------------------------------------------------------------------------

function Module:OnInitialize()
    local Data = BuyALot:Get("Data")
    self.db = Data:RegisterNamespace("vendorBulk", {
        confirmEnabled = true,
    })
end

function Module:OnEnable()
    -- Slash subcommand: /bal confirm
    BuyALot:RegisterSlashCommand("confirm", function()
        self:SetConfirmEnabled(not self:IsConfirmEnabled())
    end)

    -- Initialize the merchant click hook (binds on first MERCHANT_SHOW).
    local Hook = ns.VendorBulk.MerchantHook
    if Hook and Hook.Init then Hook.Init() end
end

-------------------------------------------------------------------------------
-- Public settings API.
-------------------------------------------------------------------------------

function Module:IsConfirmEnabled()
    return self.db and self.db.confirmEnabled == true
end

function Module:SetConfirmEnabled(enabled)
    if not self.db then return end
    self.db.confirmEnabled = enabled and true or false
    print("|cff00ff00BuyALot:|r " .. (self.db.confirmEnabled and L["SLASH_CONFIRM_ON"] or L["SLASH_CONFIRM_OFF"]))
end
