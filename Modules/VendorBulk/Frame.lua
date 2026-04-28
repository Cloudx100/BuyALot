--[[
    BuyALot / VendorBulk: Frame.lua
    Quantity popup + purchase logic.

    Layout (≈260×190, anchored above the clicked merchant button):
      [ ← ]  [ EditBox ]  [ → ]
      [ Stack ]    [ Max ]
      Cost: [money frame]
      [ Okay ]    [ Cancel ]

    Buy logic mirrors BuyEmAll (vanilla Cogwheel) — adapted to retail 12.x APIs.
]]

local ADDON_NAME, ns = ...
ns.VendorBulk = ns.VendorBulk or {}

local BuyALot = ns.BuyALot
local L       = ns.VendorBulk.L

local Frame = {}
ns.VendorBulk.Frame = Frame

local frame  -- lazy-created popup
local state  -- per-open state: { merchantIndex, name, presetStack, stackSize, price, available, bagMax, moneyMax, maxBuy, defaultStack }

-------------------------------------------------------------------------------
-- API compat wrappers. Several merchant/item globals were moved to
-- C_MerchantFrame / C_Item in 12.0.x. Wrap so the rest of this file can stay
-- on the legacy multi-return signature.
-------------------------------------------------------------------------------

local function _GetMerchantItemInfo(idx)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(idx)
        if not info then return nil end
        return info.name, info.texture, info.price, info.stackCount,
               info.numAvailable, info.isPurchasable, info.isUsable,
               info.hasExtendedCost, info.currencyID, info.spellID
    end
    if _G.GetMerchantItemInfo then return _G.GetMerchantItemInfo(idx) end
end

local function _GetMerchantItemLink(idx, btn)
    if _G.GetMerchantItemLink then
        local link = _G.GetMerchantItemLink(idx)
        if link then return link end
    end
    return btn and btn.link
end

local function _BuyMerchantItem(idx, qty)
    if _G.BuyMerchantItem then
        return _G.BuyMerchantItem(idx, qty)
    end
    if C_MerchantFrame and C_MerchantFrame.BuyItem then
        return C_MerchantFrame.BuyItem(idx, qty)
    end
end

local function _GetItemInfo(link)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(link) end
    if _G.GetItemInfo then return _G.GetItemInfo(link) end
end

-------------------------------------------------------------------------------
-- Bag space calculation (modern C_Container API).
-- Counts empty slots (× stackSize) plus partial stacks of the same itemID.
-------------------------------------------------------------------------------

local function ComputeBagSpace(itemID, stackSize)
    if not itemID or not stackSize or stackSize < 1 then return 0 end
    local total = 0
    for bagID = 0, 5 do  -- 0=backpack, 1-4=main bags, 5=reagent bag (DF+)
        local slots = C_Container.GetContainerNumSlots(bagID) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if not info then
                total = total + stackSize
            elseif info.itemID == itemID then
                total = total + math.max(0, stackSize - (info.stackCount or 0))
            end
        end
    end
    return total
end

-------------------------------------------------------------------------------
-- Cost display via GetCoinTextureString (returns "12g 34s 56c" with icons).
-- No template, no MoneyTypeInfo registration — just a FontString.
-------------------------------------------------------------------------------

local function UpdateCostDisplay(amount)
    if not state or not frame or not frame.costAmount then return end
    local stacks = math.ceil(amount / state.presetStack)
    local cost   = stacks * state.price
    frame.costAmount:SetText(GetCoinTextureString and GetCoinTextureString(cost) or tostring(cost))
end

-------------------------------------------------------------------------------
-- Quantity helpers.
-------------------------------------------------------------------------------

local function ClampToStep(amount)
    -- Always a multiple of presetStack, between presetStack and maxBuy.
    if not state then return amount end
    local step = state.presetStack
    amount = math.max(step, math.min(amount, state.maxBuy))
    amount = math.floor(amount / step) * step
    if amount < step then amount = step end
    return amount
end

local function SetQuantity(amount)
    amount = ClampToStep(amount)
    if frame.editBox then
        frame.editBox:SetText(tostring(amount))
        frame.editBox:SetCursorPosition(#tostring(amount))
    end
    UpdateCostDisplay(amount)
    -- Toggle ←/→ button enabled state
    if frame.leftBtn  then frame.leftBtn:SetEnabled(amount  > state.presetStack) end
    if frame.rightBtn then frame.rightBtn:SetEnabled(amount < state.maxBuy)      end
end

local function GetQuantity()
    if not frame or not frame.editBox then return 0 end
    return tonumber(frame.editBox:GetText() or "0") or 0
end

-------------------------------------------------------------------------------
-- Purchase loop. Mirrors BuyEmAll's accept handler.
-------------------------------------------------------------------------------

local function ExecutePurchase(amount)
    if not state then return end
    local idx = state.merchantIndex

    local numLoops, perCall, leftover
    if state.presetStack > 1 then
        -- Vendor sells in stacks of presetStack (e.g., "Pet Treats x5").
        -- Each BuyMerchantItem(idx, 1) buys one vendor-stack.
        numLoops  = math.floor(amount / state.presetStack)
        perCall   = 1
        leftover  = 0
    else
        -- Singletons: chunk by inventory stackSize so each call creates one stack.
        numLoops  = math.floor(amount / state.stackSize)
        perCall   = state.stackSize
        leftover  = amount % state.stackSize
    end

    for _ = 1, numLoops do
        _BuyMerchantItem(idx, perCall)
    end
    if leftover > 0 then
        _BuyMerchantItem(idx, leftover)
    end

    BuyALot:Debug("VendorBulk", "bought", amount, "of", state.name, "(loops:", numLoops, "per:", perCall, "leftover:", leftover, ")")
end

-------------------------------------------------------------------------------
-- Confirmation dialog.
-------------------------------------------------------------------------------

local function EnsureConfirmDialog()
    if StaticPopupDialogs["BUYALOT_VENDOR_CONFIRM"] then return end
    StaticPopupDialogs["BUYALOT_VENDOR_CONFIRM"] = {
        text         = "%s",  -- text passed to StaticPopup_Show
        button1      = YES,
        button2      = NO,
        OnAccept     = function(self, data)
            if data and data.amount and data.amount > 0 then
                ExecutePurchase(data.amount)
            end
        end,
        timeout      = 0,
        hideOnEscape = true,
        whileDead    = true,
        showAlert    = false,
    }
end

local function BuyOrConfirm(amount)
    if amount <= 0 then return end
    local Module = ns.VendorBulk.Module

    -- Confirm if the purchase exceeds one inventory stack AND the user opted in.
    local needsConfirm = Module:IsConfirmEnabled() and amount > state.stackSize
    if needsConfirm then
        EnsureConfirmDialog()
        local text = (L["CONFIRM_TEXT"]):format(amount, state.name)
        local dialog = StaticPopup_Show("BUYALOT_VENDOR_CONFIRM", text)
        if dialog then dialog.data = { amount = amount } end
    else
        ExecutePurchase(amount)
    end

    Frame.Hide()
end

-------------------------------------------------------------------------------
-- Tooltip handlers.
-------------------------------------------------------------------------------

local function StackTooltip(self)
    if not state then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText((L["TT_STACK"]):format(state.stackSize), 1, 1, 1, 1, true)
    GameTooltip:Show()
    UpdateCostDisplay(state.stackSize)
end

local function MaxTooltip(self)
    if not state then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine((L["TT_MAX_TITLE"]):format(state.maxBuy), 1, 1, 1)
    local availStr = (state.available == -1) and L["TT_AVAILABLE_INF"] or tostring(state.available)
    GameTooltip:AddDoubleLine(L["TT_MAX_FIT"],    tostring(state.bagMax),   1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["TT_MAX_AFFORD"], tostring(state.moneyMax), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["TT_MAX_AVAIL"],  availStr,                 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
    UpdateCostDisplay(state.maxBuy)
end

local function HideTooltip()
    GameTooltip_Hide()
    if state then UpdateCostDisplay(GetQuantity()) end
end

-------------------------------------------------------------------------------
-- Build / lazy-create the popup frame.
-------------------------------------------------------------------------------

local function Build()
    local UI = BuyALot:Get("UI")

    local f = UI:CreatePopup({
        name          = "BuyALotVendorBulkFrame",
        title         = L["POPUP_TITLE"]:format(""),
        width         = 280,
        height        = 200,
        strata        = "FULLSCREEN_DIALOG",
        closeOnEscape = true,
        movable       = true,
    })

    -- Quantity row: ← [ editBox ] →
    local editBox = UI:CreateEditBox(f, {
        width      = 70,
        height     = 22,
        numeric    = true,
        autoFocus  = true,
        maxLetters = 6,
        justify    = "CENTER",
        onTextChanged = function(self, userInput)
            if not state or not userInput then return end
            local n = tonumber(self:GetText() or "")
            if not n then return end
            UpdateCostDisplay(n)
            if frame.leftBtn  then frame.leftBtn:SetEnabled(n  > state.presetStack) end
            if frame.rightBtn then frame.rightBtn:SetEnabled(n < state.maxBuy)      end
        end,
        onEnterPressed = function() BuyOrConfirm(GetQuantity()) end,
    })
    editBox:SetPoint("TOP", f, "TOP", 0, -36)

    local leftBtn = UI:CreateButton(f, {
        label = "<", width = 24, height = 22,
        onClick = function() SetQuantity(GetQuantity() - state.presetStack) end,
    })
    leftBtn:SetPoint("RIGHT", editBox, "LEFT", -10, 0)

    local rightBtn = UI:CreateButton(f, {
        label = ">", width = 24, height = 22,
        onClick = function() SetQuantity(GetQuantity() + state.presetStack) end,
    })
    rightBtn:SetPoint("LEFT", editBox, "RIGHT", 10, 0)

    -- Stack / Max row
    local stackBtn = UI:CreateButton(f, {
        label = L["BUTTON_STACK"], width = 90, height = 22,
        onClick = function() SetQuantity(state.stackSize); BuyOrConfirm(state.stackSize) end,
    })
    stackBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -76)
    stackBtn:SetScript("OnEnter", StackTooltip)
    stackBtn:SetScript("OnLeave", HideTooltip)

    local maxBtn = UI:CreateButton(f, {
        label = L["BUTTON_MAX"], width = 90, height = 22,
        onClick = function() SetQuantity(state.maxBuy); BuyOrConfirm(state.maxBuy) end,
    })
    maxBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -76)
    maxBtn:SetScript("OnEnter", MaxTooltip)
    maxBtn:SetScript("OnLeave", HideTooltip)

    -- Cost display
    local costLabel = UI:CreateLabel(f, { text = L["LABEL_COST"], color = "LABEL" })
    costLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -110)

    local costAmount = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    costAmount:SetPoint("LEFT", costLabel, "RIGHT", 8, 0)
    costAmount:SetText(GetCoinTextureString and GetCoinTextureString(0) or "0")

    -- Okay / Cancel
    local okayBtn = UI:CreateButton(f, {
        label = L["BUTTON_OK"], width = 90, height = 22,
        onClick = function() BuyOrConfirm(GetQuantity()) end,
    })
    okayBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, 14)

    local cancelBtn = UI:CreateButton(f, {
        label = L["BUTTON_CANCEL"], width = 90, height = 22,
        onClick = function() Frame.Hide() end,
    })
    cancelBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 14)

    f.editBox    = editBox
    f.leftBtn    = leftBtn
    f.rightBtn   = rightBtn
    f.stackBtn   = stackBtn
    f.maxBtn     = maxBtn
    f.costLabel  = costLabel
    f.costAmount = costAmount
    f.okayBtn    = okayBtn
    f.cancelBtn  = cancelBtn

    return f
end

-------------------------------------------------------------------------------
-- Public API.
-------------------------------------------------------------------------------

function Frame.Open(merchantButton)
    if not merchantButton or not merchantButton.GetID then return end
    local idx = merchantButton:GetID()
    if not idx or idx < 1 then return end

    local name, _, price, presetStack, numAvailable, isPurchasable = _GetMerchantItemInfo(idx)
    if not name or not isPurchasable then return end

    local link = _GetMerchantItemLink(idx, merchantButton)
    local itemID = link and tonumber(string.match(link, "item:(%-?%d+)")) or nil
    local stackSize
    if link then
        local _, _, _, _, _, _, _, ss = _GetItemInfo(link)
        stackSize = ss
    end
    stackSize   = stackSize   or presetStack or 1
    presetStack = presetStack or 1

    -- Bag / money / availability limits.
    local bagSpace  = ComputeBagSpace(itemID, stackSize)
    local bagMax    = math.floor(bagSpace / presetStack) * presetStack
    local moneyMax  = (price > 0) and (math.floor(GetMoney() / price) * presetStack) or math.huge
    local availMax  = (numAvailable == -1) and math.huge or (numAvailable * presetStack)
    local maxBuy    = math.min(bagMax, moneyMax, availMax)

    if maxBuy < presetStack then
        -- Nothing affordable / nothing fits / vendor sold out.
        local Module = ns.VendorBulk.Module
        if bagMax    < presetStack then print("|cff00ff00BuyALot:|r " .. L["ERR_NO_SPACE"])
        elseif moneyMax < presetStack then print("|cff00ff00BuyALot:|r " .. L["ERR_NO_MONEY"])
        elseif availMax  < presetStack then print("|cff00ff00BuyALot:|r " .. L["ERR_NONE_AVAIL"])
        end
        return
    end

    state = {
        merchantIndex = idx,
        name          = name,
        presetStack   = presetStack,
        stackSize     = math.max(stackSize, presetStack),
        price         = price,
        available     = numAvailable,
        bagMax        = bagMax,
        moneyMax      = (moneyMax == math.huge) and 9999999 or moneyMax,
        maxBuy        = maxBuy,
        defaultStack  = math.min(math.max(presetStack, stackSize), maxBuy),
        itemID        = itemID,
    }

    if not frame then frame = Build() end

    -- Update title (item-specific) and reset quantity.
    if frame.SetTitle then
        frame:SetTitle(L["POPUP_TITLE"]:format(name))
    elseif frame.TitleText then
        frame.TitleText:SetText(L["POPUP_TITLE"]:format(name))
    end

    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", merchantButton, "TOPLEFT", 0, 4)

    SetQuantity(state.defaultStack)
    frame.stackBtn:SetEnabled(state.stackSize <= state.maxBuy)
    frame:Show()
    if frame.editBox then frame.editBox:HighlightText() end
end

function Frame.Hide()
    if frame then frame:Hide() end
    state = nil
end

function Frame.IsShown()
    return frame and frame:IsShown()
end

function Frame.GetFrame()
    return frame
end
