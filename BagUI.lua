local addonName, AM = ...

AM.Windows = {}

local function CreateIconButton(parent, name, iconTexture, tooltip, point, relativeTo, relativePoint, x, y, onClick)
    local btn = CreateFrame("Button", name, parent)
    btn:SetSize(24, 24)
    btn:SetPoint(point, relativeTo, relativePoint, x, y)
    btn:SetNormalTexture(iconTexture)
    btn:SetPushedTexture(iconTexture)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    
    if btn:GetNormalTexture() then btn:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if btn:GetPushedTexture() then btn:GetPushedTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(tooltip)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function AM_FormatGold(money)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(money)
    end
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    return string.format("%dg %ds %dc", gold, silver, copper)
end

function AM:GetLiveBankBags()
    local mainBankID = (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or -1
    local tab1 = (Enum and Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1) or 6
    
    local mainSlots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(mainBankID)) or 0
    local tab1Slots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(tab1)) or 0
    
    local primaryBank = mainBankID
    if tab1Slots > 0 and mainSlots > 0 then
        local mainHasItems = false
        for s = 1, mainSlots do
            if C_Container.GetContainerItemLink(mainBankID, s) then
                mainHasItems = true
                break
            end
        end
        local tab1HasItems = false
        for s = 1, tab1Slots do
            if C_Container.GetContainerItemLink(tab1, s) then
                tab1HasItems = true
                break
            end
        end
        if tab1HasItems and not mainHasItems then
            primaryBank = tab1
        elseif mainHasItems and not tab1HasItems then
            primaryBank = mainBankID
        elseif tab1Slots > mainSlots then
            primaryBank = tab1
        else
            primaryBank = mainBankID
        end
    elseif tab1Slots > 0 then
        primaryBank = tab1
    else
        primaryBank = mainBankID
    end
    
    local bankBags = { primaryBank }
    
    local startBag = 6
    if primaryBank == 6 then startBag = 7 end
    local endBag = startBag + (NUM_BANKBAGSLOTS or 7) - 1
    
    for b = startBag, endBag do
        local n = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(b)
        if n and n > 0 then
            local invID = ContainerIDToInventoryID and ContainerIDToInventoryID(b)
            local hasEquippedBag = invID and GetInventoryItemLink and (GetInventoryItemLink("player", invID) ~= nil)
            local hasItems = false
            for s = 1, n do
                if C_Container.GetContainerItemLink(b, s) then
                    hasItems = true
                    break
                end
            end
            if hasEquippedBag or hasItems then
                table.insert(bankBags, b)
            end
        end
    end
    
    return bankBags
end

function AM:SellTrashItems()
    if AM.isSellingTrash then return end
    
    local sellQueue = {}

    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots then
            for slot = 1, slots do
                local itemID = C_Container.GetContainerItemID(bag, slot)
                if itemID then
                    local _, _, rarity, _, _, _, _, _, _, _, sellPrice
                    if C_Item and C_Item.GetItemInfo then
                        _, _, rarity, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemID)
                    else
                        _, _, rarity, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
                    end
                    if (rarity == 0 or (AM.DB and AM.DB.IsTrash and AM.DB:IsTrash(AM.DB.GetFullPlayerName and AM.DB:GetFullPlayerName() or "", bag, slot, itemID))) and (sellPrice and sellPrice > 0) then
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        if info and not info.isLocked then
                            table.insert(sellQueue, {bag = bag, slot = slot, itemID = itemID, price = sellPrice, count = info.stackCount})
                        end
                    end
                end
            end
        end
    end

    if #sellQueue == 0 then return end
    
    AM.isSellingTrash = true
    local totalSold = 0
    local soldItems = 0

    if not AM.sellFrame then
        AM.sellFrame = CreateFrame("Frame")
    end

    local lastTick = 0
    AM.sellFrame:SetScript("OnUpdate", function(self, elapsed)
        lastTick = lastTick + elapsed
        -- Wait 0.1s between each sale to avoid server throttling
        if lastTick < 0.1 then return end
        lastTick = 0

        -- Stop if merchant window was closed (give it a grace period for the first tick)
        if not MerchantFrame or not MerchantFrame:IsShown() then
            AM.isSellingTrash = false
            self:SetScript("OnUpdate", nil)
            return
        end
        
        local item = table.remove(sellQueue, 1)
        if not item then
            AM.isSellingTrash = false
            self:SetScript("OnUpdate", nil)
            if soldItems > 0 then
                print(string.format("|cffffff00AltManager|r: Sold %d trash items for %s", soldItems, AM_FormatGold(totalSold)))
            end
            return
        end

        local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
        if info and not info.isLocked and info.itemID == item.itemID then
            totalSold = totalSold + (item.price * item.count)
            soldItems = soldItems + 1
            C_Container.UseContainerItem(item.bag, item.slot)
        end
    end)
end

local EQUIP_LOC_TO_SLOTS = {
    INVTYPE_HEAD = {1},
    INVTYPE_NECK = {2},
    INVTYPE_SHOULDER = {3},
    INVTYPE_BODY = {4},
    INVTYPE_CHEST = {5},
    INVTYPE_ROBE = {5},
    INVTYPE_WAIST = {6},
    INVTYPE_LEGS = {7},
    INVTYPE_FEET = {8},
    INVTYPE_WRIST = {9},
    INVTYPE_HAND = {10},
    INVTYPE_FINGER = {11, 12},
    INVTYPE_TRINKET = {13, 14},
    INVTYPE_CLOAK = {15},
    INVTYPE_WEAPON = {16, 17},
    INVTYPE_SHIELD = {17},
    INVTYPE_2HWEAPON = {16},
    INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_WEAPONOFFHAND = {17},
    INVTYPE_HOLDABLE = {17},
    INVTYPE_RANGED = {18},
    INVTYPE_THROWN = {18},
    INVTYPE_RANGEDRIGHT = {18},
    INVTYPE_RELIC = {18},
    INVTYPE_TABARD = {19},
}
local scanTooltip = CreateFrame("GameTooltip", "AltManagerScanTooltip", nil, "GameTooltipTemplate")

local function AM_GetEquippedItemLevel(equipLoc, itemClassID, itemSubclassID)
    local slots = EQUIP_LOC_TO_SLOTS[equipLoc]
    if not slots then return nil end
    
    local lowestILvl = 99999
    local lowestRarity = 999
    local equippedArmorType = -1
    local has2H = false
    local mainHandILvl, mainHandRarity = nil, nil
    
    -- Check if player can dual wield (Spell ID 1181 is Dual Wield in most WoW versions, or check for offhand weapon capability)
    local canDualWield = IsSpellKnown and (IsSpellKnown(1181) or IsSpellKnown(674)) 
    if not canDualWield and (equipLoc == "INVTYPE_WEAPON") then
        -- If they can't dual wield, a generic 1H weapon only belongs in the Main Hand (Slot 16)
        slots = {16}
    end
    
    if equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" then
        local mhLink = GetInventoryItemLink("player", 16)
        if mhLink then
            local mhEquipLoc, ilvl, rarity
            if C_Item and C_Item.GetItemInfo then
                _, _, rarity, ilvl, _, _, _, _, mhEquipLoc = C_Item.GetItemInfo(mhLink)
            elseif GetItemInfo then
                _, _, rarity, ilvl, _, _, _, _, mhEquipLoc = GetItemInfo(mhLink)
            end
            if mhEquipLoc == "INVTYPE_2HWEAPON" then
                has2H = true
                mainHandILvl = ilvl
                mainHandRarity = rarity
            end
        end
    end
    
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local ilvl, rarity, _, _, _, _, _, _, _, classID, subclassID
            if C_Item and C_Item.GetItemInfo then
                _, _, rarity, ilvl, _, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(link)
            elseif GetItemInfo then
                _, _, rarity, ilvl, _, _, _, _, _, _, _, classID, subclassID = GetItemInfo(link)
            end
            
            if ilvl and ilvl < lowestILvl then
                lowestILvl = ilvl
                lowestRarity = rarity or 0
                -- Store armor subclass (1=Cloth, 2=Leather, 3=Mail, 4=Plate)
                if classID == 4 then
                    equippedArmorType = subclassID
                end
            end
        else
            if slot == 17 and has2H then
                if mainHandILvl and mainHandILvl < lowestILvl then
                    lowestILvl = mainHandILvl
                    lowestRarity = mainHandRarity or 0
                end
            else
                -- Slot is empty, return 0 so anything usable is an upgrade
                return 0, 0, -1
            end
        end
    end
    
    if lowestILvl == 99999 then return 0, 0, -1 end
    return lowestILvl, lowestRarity, equippedArmorType
end

local trashEventFrame = CreateFrame("Frame")
trashEventFrame:RegisterEvent("MERCHANT_SHOW")
trashEventFrame:SetScript("OnEvent", function()
    if AM.DB and AM.DB.IsAutoSellTrashEnabled and AM.DB:IsAutoSellTrashEnabled() then
        AM:SellTrashItems()
    end
    if AM.DB and AM.DB.IsAutoRepairEnabled and AM.DB:IsAutoRepairEnabled() and CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost > 0 then
            local money = GetMoney()
            if money >= cost then
                RepairAllItems()
                print(string.format("|cffffff00AltManager|r: Repaired all items for %s", AM_FormatGold(cost)))
            else
                print("|cffffff00AltManager|r: Not enough money to Auto-Repair.")
            end
        end
    end
end)

function AM:CreateInventoryWindow(windowName, titleText, storageType, liveSections, hideExtras)
    local win = CreateFrame("Frame", windowName, UIParent, "BasicFrameTemplateWithInset")
    win.hideExtras = hideExtras
    win:SetSize(400, 500)
    win:SetPoint("CENTER")
    win:Hide()
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetToplevel(true)
    
    win.title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.title:SetPoint("TOP", 0, -5)
    win.title:SetText("Alt Manager - " .. titleText .. " (Live)")
    
    win.liveButtons = {}
    win.altButtons = {}
    win.sectionBGs = {}
    win.currentSort = "default"
    win.storageType = storageType
    win.liveSections = liveSections
    win.searchQuery = ""
    win.selectedCharacter = nil
    
    -- Search Box
    local searchBox = CreateFrame("EditBox", windowName.."SearchBox", win, "SearchBoxTemplate")
    searchBox:SetSize(120, 20)
    searchBox:SetPoint("TOPRIGHT", -15, -30)
    searchBox:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        win.searchQuery = self:GetText():lower()
        win:Update()
    end)
    
    -- LEFT COLUMN ICONS --
    
    if storageType == "bags" then
        local btnBlizz = CreateIconButton(win, windowName.."BlizzUI", "Interface\\Icons\\INV_Misc_Bag_10", "Switch to Blizz UI", "TOPLEFT", win, "TOPLEFT", 10, -30, function()
            win:Hide()
            AM.forceBlizz = true
            if OpenAllBags then
                OpenAllBags()
            elseif ToggleAllBags then
                ToggleAllBags()
            end
        end)
    end
    
    -- Sort Buttons in the column
    local btnAuto = CreateIconButton(win, windowName.."SortAuto", "Interface\\Icons\\INV_Pet_Broom", "Auto Sort", "TOPLEFT", win, "TOPLEFT", 10, -60, function(self, button)
        win.currentSort = nil
        win:Update()
        if not win.selectedCharacter and C_Container then
            -- 1. Backup and Clear Manual Trash Flags (Prevents Sort from wiping/misaligning slot flags)
            local trashItems = {}
            local player = AM.DB.GetFullPlayerName and AM.DB:GetFullPlayerName() or ""
            local function BackupAndClearTrash(bagList)
                if not (AM.DB and AM.DB.IsTrash and AM.DB.ToggleTrash) then return end
                for _, b in ipairs(bagList) do
                    local slots = C_Container.GetContainerNumSlots(b)
                    if slots then
                        for s = 1, slots do
                            local iID = C_Container.GetContainerItemID(b, s)
                            if iID and AM.DB:IsTrash(player, b, s, iID) then
                                trashItems[iID] = true
                                AM.DB:ToggleTrash(b, s, iID) -- Untoggle flag on the pre-sort coordinate
                            end
                        end
                    end
                end
            end

            -- Restore manual trash flags to their new coordinates based on itemID
            local function RestoreTrash(bagList)
                if not (AM.DB and AM.DB.IsTrash and AM.DB.ToggleTrash) then return end
                for _, b in ipairs(bagList) do
                    local slots = C_Container.GetContainerNumSlots(b)
                    if slots then
                        for s = 1, slots do
                            local iID = C_Container.GetContainerItemID(b, s)
                            if iID and trashItems[iID] then
                                if not AM.DB:IsTrash(player, b, s, iID) then
                                    AM.DB:ToggleTrash(b, s, iID)
                                end
                            end
                        end
                    end
                end
                win:Update()
            end

            local bagsToBackup = {}
            if storageType == "bags" then
                bagsToBackup = {0, 1, 2, 3, 4}
            elseif storageType == "bank" then
                bagsToBackup = AM:GetLiveBankBags()
            elseif storageType == "combined" then
                bagsToBackup = {0, 1, 2, 3, 4}
                for _, bb in ipairs(AM:GetLiveBankBags()) do table.insert(bagsToBackup, bb) end
            end
            
            BackupAndClearTrash(bagsToBackup)

            -- 2. Sort the bags and call the restoration sequence 
            if storageType == "bags" then
                if C_Container.SortBags then C_Container.SortBags() end
                C_Timer.After(0.5, function() RestoreTrash(bagsToBackup) end)
            elseif storageType == "bank" then
                if C_Container.SortBankBags then C_Container.SortBankBags() end
                C_Timer.After(0.5, function() RestoreTrash(bagsToBackup) end)
            elseif storageType == "combined" then
                if button == "RightButton" then
                    if C_Container.SortBankBags then C_Container.SortBankBags() end
                    C_Timer.After(0.5, function() RestoreTrash(bagsToBackup) end)
                elseif IsShiftKeyDown and IsShiftKeyDown() then
                    if C_Container.SortBags then C_Container.SortBags() end
                    C_Timer.After(0.5, function() RestoreTrash(bagsToBackup) end)
                else
                    if C_Container.SortBankBags then
                        C_Container.SortBankBags()
                    end
                    if C_Container.SortBags then
                        C_Container.SortBags()
                    end
                    C_Timer.After(0.5, function() RestoreTrash(bagsToBackup) end)
                end
            end
        end
    end)
    btnAuto:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    if storageType == "combined" then
        btnAuto:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Auto Sort", 1, 1, 1)
            GameTooltip:AddLine("Left Click: Sort Both (Bank then Bags)", 1, 0.82, 0)
            GameTooltip:AddLine("Right Click: Sort Bank only", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Shift + Click: Sort Bags only", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
    end
    
    local btnRarity = CreateIconButton(win, windowName.."SortRarity", "Interface\\Icons\\INV_Misc_Gem_Diamond_02", "Sort by Rarity", "TOPLEFT", win, "TOPLEFT", 10, -90, function()
        win.currentSort = (win.currentSort == "rarity") and nil or "rarity"
        win:Update()
    end)
    
    local btnValue = CreateIconButton(win, windowName.."SortValue", "Interface\\Icons\\INV_Misc_Coin_02", "Sort by Value", "TOPLEFT", win, "TOPLEFT", 10, -120, function()
        win.currentSort = (win.currentSort == "value") and nil or "value"
        win:Update()
    end)
    
    local btnName = CreateIconButton(win, windowName.."SortName", "Interface\\Icons\\INV_Misc_Note_01", "Sort by Name", "TOPLEFT", win, "TOPLEFT", 10, -150, function()
        win.currentSort = (win.currentSort == "name") and nil or "name"
        win:Update()
    end)
    
    local btnTrashSort = CreateIconButton(win, windowName.."SortTrash", "Interface\\Icons\\INV_Box_03", "Trash Sort", "TOPLEFT", win, "TOPLEFT", 10, -180, function()
        win.currentSort = (win.currentSort == "trash") and nil or "trash"
        win:Update()
    end)
    
    win.btnRarity = btnRarity
    win.btnValue = btnValue
    win.btnName = btnName
    win.btnTrashSort = btnTrashSort
    
    win.activeSortGlow = win:CreateTexture(nil, "OVERLAY")
    win.activeSortGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    win.activeSortGlow:SetBlendMode("ADD")
    win.activeSortGlow:SetSize(30, 30)
    win.activeSortGlow:Hide()

    local charBtn = CreateIconButton(win, windowName.."CharSelect", "Interface\\Icons\\Achievement_GuildPerk_Everyones a Hero_rank2", "Alt Bags", "BOTTOMLEFT", win, "BOTTOMLEFT", 10, 15, nil)
    
    local dd = CreateFrame("Frame", nil, win, "BackdropTemplate")
    dd:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    dd:SetBackdropColor(0, 0, 0, 0.95)
    dd:SetPoint("BOTTOMLEFT", charBtn, "BOTTOMRIGHT", 5, 0)
    dd:SetSize(150, 100)
    dd:SetFrameLevel(win:GetFrameLevel() + 10)
    dd:Hide()
    
    charBtn:SetScript("OnClick", function()
        if dd:IsShown() then
            dd:Hide()
        else
            for _, child in ipairs({dd:GetChildren()}) do child:Hide() end
            
            local yOff = -10
            local function AddOption(name, isLive)
                local b = CreateFrame("Button", nil, dd)
                b:SetSize(130, 20)
                b:SetPoint("TOPLEFT", 10, yOff)
                local txt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                txt:SetPoint("LEFT")
                txt:SetText(name)
                b:SetFontString(txt)
                b:SetScript("OnClick", function()
                    if isLive then
                        win.selectedCharacter = nil
                        win.title:SetText("Alt Manager - " .. titleText .. " (Live)")
                    else
                        win.selectedCharacter = name
                        win.title:SetText("Alt Manager - " .. titleText .. " (" .. name .. ")")
                    end
                    dd:Hide()
                    win:Update()
                end)
                b:Show()
                yOff = yOff - 20
            end
            
            AddOption("Current Character", true)
            
            if AM.DB and AM.DB.data then
                local ruleset = AM.DB.GetRuleset and AM.DB:GetRuleset()
                local faction = AM.DB.GetFaction and AM.DB:GetFaction()
                if ruleset and faction then
                    local chars = AM.DB.data[ruleset] and AM.DB.data[ruleset][faction]
                    if chars then
                        for charName, charData in pairs(chars) do
                            if charName ~= (AM.DB.GetFullPlayerName and AM.DB:GetFullPlayerName() or "") and not (charData and charData.isIgnored) then
                                AddOption(charName, false)
                            end
                        end
                    end
                end
            end
            
            dd:SetHeight(math.abs(yOff) + 10)
            dd:Show()
        end
    end)
    
    win.moneyText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.moneyText:SetPoint("BOTTOMRIGHT", -15, 15)
    
    if not hideExtras then
        local btnSellTrash = CreateIconButton(win, windowName.."SellTrash", "Interface\\Icons\\Achievement_GuildPerk_CashFlow_Rank2", "Sell Trash (Gray items + Custom Trash)", "RIGHT", win.moneyText, "LEFT", -15, 0, function()
            AM:SellTrashItems()
        end)
        
        local chkAutoSell = CreateFrame("CheckButton", windowName.."AutoSell", win, "UICheckButtonTemplate")
        chkAutoSell:SetSize(24, 24)
        chkAutoSell:SetPoint("RIGHT", btnSellTrash, "LEFT", -5, 0)
        chkAutoSell:SetScript("OnShow", function(self)
            if AM.DB and AM.DB.IsAutoSellTrashEnabled then
                self:SetChecked(AM.DB:IsAutoSellTrashEnabled())
            end
        end)
        chkAutoSell:SetScript("OnClick", function(self)
            if AM.DB and AM.DB.SetAutoSellTrashEnabled then
                AM.DB:SetAutoSellTrashEnabled(self:GetChecked())
            end
        end)
        chkAutoSell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Auto-Sell Trash")
            GameTooltip:AddLine("Automatically sell gray items and marked trash when visiting a vendor.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        chkAutoSell:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
        
        win.trashTotalText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        win.trashTotalText:SetPoint("RIGHT", chkAutoSell, "LEFT", -5, 0)
        win.trashTotalText:SetTextColor(0.6, 0.6, 0.6)
        
        local chkAutoRepair = CreateFrame("CheckButton", windowName.."AutoRepair", win, "UICheckButtonTemplate")
        chkAutoRepair:SetSize(24, 24)
        chkAutoRepair:SetPoint("RIGHT", win.trashTotalText, "LEFT", -10, 0)
        chkAutoRepair:SetScript("OnShow", function(self)
            if AM.DB and AM.DB.IsAutoRepairEnabled then
                self:SetChecked(AM.DB:IsAutoRepairEnabled())
            end
        end)
        chkAutoRepair:SetScript("OnClick", function(self)
            if AM.DB and AM.DB.SetAutoRepairEnabled then
                AM.DB:SetAutoRepairEnabled(self:GetChecked())
            end
        end)
        chkAutoRepair:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Auto-Repair")
            GameTooltip:AddLine("Automatically repair all your gear when visiting a merchant that can repair.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        chkAutoRepair:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
        
        win.repairTotalText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        win.repairTotalText:SetPoint("RIGHT", chkAutoRepair, "LEFT", -5, 0)
        win.repairTotalText:SetTextColor(0.8, 0.4, 0.4)
        
        local repairText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        repairText:SetPoint("RIGHT", win.repairTotalText, "LEFT", -5, 0)
        repairText:SetText("Repair:")
        repairText:SetTextColor(1, 0.82, 0)
    end
    
    local moneyFrame = CreateFrame("Frame", nil, win)
    moneyFrame:SetAllPoints(win.moneyText)
    moneyFrame:EnableMouse(true)
    moneyFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("AltManager Wealth", 1, 0.82, 0)
        
        local ruleset = AM.DB and AM.DB.GetRuleset and AM.DB:GetRuleset()
        local faction = AM.DB and AM.DB.GetFaction and AM.DB:GetFaction()
        if not ruleset or not faction or not AM.DB.data[ruleset] or not AM.DB.data[ruleset][faction] then return end
        
        local totalGold = 0
        local chars = {}
        for cName, cData in pairs(AM.DB.data[ruleset][faction]) do
            if not cData.isIgnored then
                table.insert(chars, {name = cName, money = cData.money or 0})
                totalGold = totalGold + (cData.money or 0)
            end
        end
        table.sort(chars, function(a, b) return a.money > b.money end)
        
        for _, c in ipairs(chars) do
            if c.money > 0 then
                GameTooltip:AddDoubleLine(c.name, AM_FormatGold(c.money), 1, 1, 1, 1, 1, 1)
            end
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total Account Wealth:", AM_FormatGold(totalGold), 0, 1, 0, 0, 1, 0)
        GameTooltip:Show()
    end)
    moneyFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    win.bgContainer = CreateFrame("Frame", nil, win)
    win.bgContainer:SetAllPoints()
    win.bgContainer:SetFrameLevel(win:GetFrameLevel() + 2)
    
    win.bagDummies = {}
    if liveSections then
        for _, sec in ipairs(liveSections) do
            for _, bag in ipairs(sec.bags) do
                local dummy = CreateFrame("Frame", nil, win)
                dummy:SetID(bag)
                dummy:SetAllPoints()
                dummy:SetFrameLevel(win:GetFrameLevel() + 5)
                dummy:Show()
                win.bagDummies[bag] = dummy
            end
        end
    end
    
    win.Update = function(self)
        
        local isPlayerBags = (self.storageType == "bags" and not self.selectedCharacter)
        local allSectionsData = {}
        
        if not self.selectedCharacter then
            local quiverItems = {}
            local profItems = {}
            local profConfig = nil
            for _, sec in ipairs(self.liveSections) do
                if sec.title == "Profession" then
                    profConfig = sec
                end
            end
            
            for _, sec in ipairs(self.liveSections) do
                if sec.title ~= "Profession" then
                    local secItems = {}
                    local bagsToScan = sec.bags
                    if sec.title == "Bank" then
                        bagsToScan = AM:GetLiveBankBags()
                    end
                    for _, bag in ipairs(bagsToScan) do
                        if not self.bagDummies[bag] then
                            local dummy = CreateFrame("Frame", nil, self)
                            dummy:SetID(bag)
                            dummy:SetAllPoints()
                            dummy:SetFrameLevel(self:GetFrameLevel() + 5)
                            dummy:Show()
                            self.bagDummies[bag] = dummy
                        end
                        local isQuiv = AM.DB and AM.DB.IsQuiver and AM.DB:IsQuiver(bag)
                        local isProf = AM.DB and AM.DB.IsProfessionBag and AM.DB:IsProfessionBag(bag)
                        local targetList = secItems
                        if isQuiv then
                            targetList = quiverItems
                        elseif isProf then
                            targetList = profItems
                        end
                        
                        local slots = C_Container.GetContainerNumSlots(bag)
                        if slots then
                            for slot = 1, slots do
                                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                                
                                local name, rarity, value = "", 0, 0
                                if itemLink then
                                    local itemName, _, itemQuality, _, _, _, _, _, _, _, sellPrice
                                    if C_Item and C_Item.GetItemInfo then
                                        itemName, _, itemQuality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemLink)
                                    else
                                        itemName, _, itemQuality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
                                    end
                                    name = itemName or ""
                                    rarity = itemQuality or 0
                                    value = sellPrice or 0
                                end
                                
                                table.insert(targetList, {
                                    bag = bag,
                                    slot = slot,
                                    info = itemInfo,
                                    link = itemLink,
                                    name = name,
                                    rarity = rarity,
                                    value = value,
                                    isEmpty = (itemLink == nil),
                                    isLive = true
                                })
                            end
                        end
                    end
                    if #secItems > 0 or sec.alwaysShow then
                        table.insert(allSectionsData, { config = sec, items = secItems })
                    end
                end
            end
            
            local reagentBag = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
            if reagentBag then
                if not self.bagDummies[reagentBag] then
                    local dummy = CreateFrame("Frame", nil, self)
                    dummy:SetID(reagentBag)
                    dummy:SetAllPoints()
                    dummy:SetFrameLevel(self:GetFrameLevel() + 5)
                    dummy:Show()
                    self.bagDummies[reagentBag] = dummy
                end
                local reagentSlots = C_Container.GetContainerNumSlots(reagentBag)
                if reagentSlots and reagentSlots > 0 then
                    for slot = 1, reagentSlots do
                        local itemInfo = C_Container.GetContainerItemInfo(reagentBag, slot)
                        local itemLink = C_Container.GetContainerItemLink(reagentBag, slot)
                        local name, rarity, value = "", 0, 0
                        if itemLink then
                            local itemName, _, itemQuality, _, _, _, _, _, _, _, sellPrice
                            if C_Item and C_Item.GetItemInfo then
                                itemName, _, itemQuality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemLink)
                            else
                                itemName, _, itemQuality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
                            end
                            name = itemName or ""
                            rarity = itemQuality or 0
                            value = sellPrice or 0
                        end
                        table.insert(profItems, {
                            bag = reagentBag,
                            slot = slot,
                            info = itemInfo,
                            link = itemLink,
                            name = name,
                            rarity = rarity,
                            value = value,
                            isEmpty = (itemLink == nil),
                            isLive = true
                        })
                    end
                end
            end
            
            if #profItems > 0 then
                table.insert(allSectionsData, {
                    config = profConfig or { title = "Profession", r = 0.4, g = 0.85, b = 0.4, a = 0.3 },
                    items = profItems
                })
            end
            
            if #quiverItems > 0 then
                table.insert(allSectionsData, { 
                    config = { title = "Quiver / Pouch", r = 0.4, g = 0.6, b = 1.0, a = 0.3 }, 
                    items = quiverItems 
                })
            end
        else
            local ruleset = AM.DB:GetRuleset()
            local faction = AM.DB:GetFaction()
            local charDB = AM.DB.data[ruleset] and AM.DB.data[ruleset][faction] and AM.DB.data[ruleset][faction][self.selectedCharacter]
            
            if charDB then
                if charDB.profession and charDB.bags and not charDB._profDeduplicated then
                    charDB._profDeduplicated = true
                    for itemID, pCount in pairs(charDB.profession) do
                        if charDB.bags[itemID] then
                            charDB.bags[itemID] = charDB.bags[itemID] - pCount
                            if charDB.bags[itemID] <= 0 then
                                charDB.bags[itemID] = nil
                            end
                        end
                    end
                end
                
                local typesToRead = {}
                if storageType == "combined" then
                    table.insert(typesToRead, "bank")
                    table.insert(typesToRead, "bankQuiver")
                    table.insert(typesToRead, "bags")
                    table.insert(typesToRead, "quiver")
                    table.insert(typesToRead, "profession")
                elseif charDB[storageType] then
                    table.insert(typesToRead, storageType)
                    if storageType == "bags" then
                        table.insert(typesToRead, "quiver")
                        table.insert(typesToRead, "profession")
                    elseif storageType == "bank" then
                        table.insert(typesToRead, "bankQuiver")
                    end
                end
                
                for _, sType in ipairs(typesToRead) do
                    local secItems = {}
                    if charDB[sType] then
                        for itemID, count in pairs(charDB[sType]) do
                            if count > 0 then
                                local itemName, _, itemQuality, _, _, _, _, itemStackCount, _, itemTexture, sellPrice
                                if C_Item and C_Item.GetItemInfo then
                                    itemName, _, itemQuality, _, _, _, _, itemStackCount, _, itemTexture, sellPrice = C_Item.GetItemInfo(itemID)
                                else
                                    itemName, _, itemQuality, _, _, _, _, itemStackCount, _, itemTexture, sellPrice = GetItemInfo(itemID)
                                end
                                
                                itemStackCount = itemStackCount or 1
                                if itemStackCount < 1 then itemStackCount = 1 end
                                
                                local remaining = count
                                while remaining > 0 do
                                    local btnCount = remaining
                                    if btnCount > itemStackCount then btnCount = itemStackCount end
                                    remaining = remaining - btnCount
                                    
                                    table.insert(secItems, {
                                        link = "item:"..itemID,
                                        name = itemName or ("Item #"..itemID),
                                        rarity = itemQuality or 0,
                                        value = sellPrice or 0,
                                        iconFileID = itemTexture or 134400,
                                        count = btnCount,
                                        isEmpty = false,
                                        isLive = false
                                    })
                                end
                            end
                        end
                    end
                    
                    local capacity = 0
                    if sType == "bank" and charDB.bankCapacity then capacity = charDB.bankCapacity
                    elseif sType == "bags" and charDB.bagCapacity then
                        capacity = charDB.bagCapacity
                        if capacity == 56 and (charDB.profCapacity == 4 or charDB.profession) then
                            capacity = 52
                        end
                    elseif sType == "profession" then
                        capacity = charDB.profCapacity or 4
                    elseif sType == "quiver" and charDB.quiverCapacity then capacity = charDB.quiverCapacity
                    elseif sType == "bankQuiver" and charDB.bankQuiverCapacity then capacity = charDB.bankQuiverCapacity
                    end
                    
                    local emptySlots = capacity - #secItems
                    if emptySlots > 0 then
                        for i = 1, emptySlots do
                            table.insert(secItems, { isEmpty = true, isLive = false })
                        end
                    end
                    
                    if #secItems > 0 then
                        local sTitle = (sType == "bank") and "Cached Bank" 
                            or ((sType == "profession") and "Cached Profession" 
                            or ((sType == "quiver" or sType == "bankQuiver") and "Cached Quiver/Pouch" 
                            or ("Cached " .. titleText)))
                            
                        local bgR, bgG, bgB = 0.8, 0.8, 0.8
                        if sType == "bank" then
                            bgR, bgG, bgB = 0.8, 0.8, 0.9
                        elseif sType == "bags" then
                            bgR, bgG, bgB = 1.0, 0.95, 0.5
                        elseif sType == "profession" then
                            bgR, bgG, bgB = 0.4, 0.85, 0.4
                        elseif sType == "quiver" or sType == "bankQuiver" then
                            bgR, bgG, bgB = 0.4, 0.6, 1.0
                        end
                        
                        table.insert(allSectionsData, {
                            config = { title = sTitle, r = bgR, g = bgG, b = bgB, a = 0.3, alwaysShow = true },
                            items = secItems
                        })
                    end
                end
            end
        end
        
        for _, secData in ipairs(allSectionsData) do
            local items = secData.items
            
            for _, item in ipairs(items) do
                item.isFiltered = false
                if self.searchQuery ~= "" and not item.isEmpty then
                    if not string.find(item.name:lower(), self.searchQuery, 1, true) then
                        item.isFiltered = true
                    end
                end
            end
            
            if self.currentSort == "name" then
                table.sort(items, function(a, b)
                    if a.isEmpty and b.isEmpty then return false end
                    if a.isEmpty ~= b.isEmpty then return not a.isEmpty end
                    return a.name < b.name
                end)
            elseif self.currentSort == "value" then
                table.sort(items, function(a, b)
                    if a.isEmpty and b.isEmpty then return false end
                    if a.isEmpty ~= b.isEmpty then return not a.isEmpty end
                    if a.value ~= b.value then return a.value > b.value end
                    return a.name < b.name
                end)
            elseif self.currentSort == "rarity" then
                table.sort(items, function(a, b)
                    if a.isEmpty and b.isEmpty then return false end
                    if a.isEmpty ~= b.isEmpty then return not a.isEmpty end
                    if a.rarity ~= b.rarity then return a.rarity > b.rarity end
                    return a.name < b.name
                end)
            elseif self.currentSort == "trash" then
                table.sort(items, function(a, b)
                    local aID = nil
                    if a.link then aID = tonumber(string.match(a.link, "item:(%d+)")) end
                    if not aID and a.isLive and C_Container then aID = C_Container.GetContainerItemID(a.bag, a.slot) end
                    
                    local bID = nil
                    if b.link then bID = tonumber(string.match(b.link, "item:(%d+)")) end
                    if not bID and b.isLive and C_Container then bID = C_Container.GetContainerItemID(b.bag, b.slot) end
                    
                    local aTrash = aID and (a.rarity == 0 or (AM.DB and AM.DB.IsTrash and AM.DB:IsTrash(win.selectedCharacter or (AM.DB.GetFullPlayerName and AM.DB:GetFullPlayerName() or ""), a.bag, a.slot, aID)))
                    local bTrash = bID and (b.rarity == 0 or (AM.DB and AM.DB.IsTrash and AM.DB:IsTrash(win.selectedCharacter or (AM.DB.GetFullPlayerName and AM.DB:GetFullPlayerName() or ""), b.bag, b.slot, bID)))
                    
                    local function GetGroup(item, isTrash)
                        if isTrash then return 3 end
                        if item.isEmpty then return 2 end
                        return 1
                    end
                    
                    local aGroup = GetGroup(a, aTrash)
                    local bGroup = GetGroup(b, bTrash)
                    
                    if aGroup ~= bGroup then
                        return aGroup < bGroup
                    end
                    
                    if a.isEmpty and b.isEmpty then return false end
                    return a.name < b.name
                end)
            elseif not self.selectedCharacter then
                -- Live default
            else
                table.sort(items, function(a, b) 
                    if a.isEmpty and b.isEmpty then return false end
                    if a.isEmpty ~= b.isEmpty then return not a.isEmpty end
                    return a.name < b.name 
                end)
            end
        end
        
        for _, b in pairs(self.liveButtons) do b:Hide() end
        for _, b in pairs(self.altButtons) do b:Hide() end
        for _, bg in pairs(self.sectionBGs) do bg:Hide() end
        
        local displayMoney = 0
        if not self.selectedCharacter then
            displayMoney = GetMoney()
        else
            local ruleset = AM.DB and AM.DB.GetRuleset and AM.DB:GetRuleset()
            local faction = AM.DB and AM.DB.GetFaction and AM.DB:GetFaction()
            if ruleset and faction then
                local charDB = AM.DB.data[ruleset] and AM.DB.data[ruleset][faction] and AM.DB.data[ruleset][faction][self.selectedCharacter]
                if charDB then
                    displayMoney = charDB.money or 0
                end
            end
        end
        self.moneyText:SetText(AM_FormatGold(displayMoney))
        
        if not self.hideExtras then
            if not self.selectedCharacter then
                local totalCost = 0
                for slot = 1, 18 do
                    local hasItem, hasCooldown, repairCost = scanTooltip:SetInventoryItem("player", slot)
                    if repairCost and repairCost > 0 then
                        totalCost = totalCost + repairCost
                    end
                end
                if totalCost > 0 then
                    self.repairTotalText:SetText("-" .. AM_FormatGold(totalCost))
                    self.repairTotalText:Show()
                else
                    self.repairTotalText:Hide()
                end
            else
                self.repairTotalText:Hide()
            end
        end
        
        if self.currentSort == "rarity" then
            self.activeSortGlow:SetPoint("CENTER", self.btnRarity, "CENTER", 0, 0)
            self.activeSortGlow:Show()
        elseif self.currentSort == "value" then
            self.activeSortGlow:SetPoint("CENTER", self.btnValue, "CENTER", 0, 0)
            self.activeSortGlow:Show()
        elseif self.currentSort == "name" then
            self.activeSortGlow:SetPoint("CENTER", self.btnName, "CENTER", 0, 0)
            self.activeSortGlow:Show()
        elseif self.currentSort == "trash" then
            self.activeSortGlow:SetPoint("CENTER", self.btnTrashSort, "CENTER", 0, 0)
            self.activeSortGlow:Show()
        else
            self.activeSortGlow:Hide()
        end
        
        if not self.hideExtras then
            local totalTrashValue = 0
            for _, secData in ipairs(allSectionsData) do
                for _, item in ipairs(secData.items) do
                    local itemID = nil
                    if item.link then itemID = tonumber(string.match(item.link, "item:(%d+)")) end
                    if not itemID and item.isLive and C_Container then itemID = C_Container.GetContainerItemID(item.bag, item.slot) end
                    
                    if itemID then
                        local _, _, rarity, _, _, _, _, _, _, _, sellPrice
                        if C_Item and C_Item.GetItemInfo then
                            _, _, rarity, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemID)
                        else
                            _, _, rarity, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
                        end
                        
                        if (rarity == 0 or (AM.DB and AM.DB.IsTrash and AM.DB:IsTrash(self.selectedCharacter or (AM.DB.GetFullPlayerName and AM.DB:GetFullPlayerName() or ""), item.bag, item.slot, itemID))) and (sellPrice and sellPrice > 0) then
                            local count = 1
                            if item.isLive and item.info then count = item.info.stackCount
                            elseif item.count then count = item.count end
                            
                            totalTrashValue = totalTrashValue + (sellPrice * count)
                        end
                    end
                end
            end
            
            if totalTrashValue > 0 then
                self.trashTotalText:SetText("+" .. AM_FormatGold(totalTrashValue))
                self.trashTotalText:Show()
            else
                self.trashTotalText:Hide()
            end
        end
        
        local COLUMNS = 10
        local BUTTON_SIZE = 37
        local SPACING = 2
        
        local btnLiveIndex = 1
        local btnAltIndex = 1
        local bgIndex = 1
        local yOffset = -60
        
        for _, secData in ipairs(allSectionsData) do
            local startY = yOffset
            local rows = 0
            
            for i, item in ipairs(secData.items) do
                local btn
                if item.isLive then
                    btn = self.liveButtons[btnLiveIndex]
                    if not btn then
                        btn = CreateFrame("ItemButton", windowName.."LiveBtn"..btnLiveIndex, self, "ContainerFrameItemButtonTemplate")
                        self.liveButtons[btnLiveIndex] = btn
                    end
                    btnLiveIndex = btnLiveIndex + 1
                    
                    local dummy = self.bagDummies[item.bag]
                    if dummy then btn:SetParent(dummy) end
                    btn:SetID(item.slot)
                    
                   local isNew = false
                    if isPlayerBags and not item.isEmpty then
                        -- Ask the game's native bag cache if this specific slot has a new item
                        if C_NewItems and C_NewItems.IsNewItem then
                            isNew = C_NewItems.IsNewItem(item.bag, item.slot)
                        end
                    end

                    if not btn.AM_NewItemGlow then
                        btn.AM_NewItemGlow = btn:CreateTexture(nil, "OVERLAY", nil, 6)
                        btn.AM_NewItemGlow:SetPoint("TOPLEFT", -3, 3)
                        btn.AM_NewItemGlow:SetPoint("BOTTOMRIGHT", 3, -3)
                        btn.AM_NewItemGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
                        btn.AM_NewItemGlow:SetBlendMode("ADD")
                        btn.AM_NewItemGlow:SetVertexColor(1, 0.85, 0.2, 0.85)
                    end

                   if not btn.AM_NewItemHooked then
                        btn:HookScript("OnEnter", function(self)
                            if self.AM_NewItemGlow and self.AM_NewItemGlow:IsShown() then
                                self.AM_NewItemGlow:Hide()
                                if self.NewItemTexture then self.NewItemTexture:Hide() end
                                if self.newitemglowAnim and self.newitemglowAnim:IsPlaying() then
                                    self.newitemglowAnim:Stop()
                                end
                                
                                -- Tell the game's cache to unflag this slot
                                local bID = self:GetParent():GetID()
                                local sID = self:GetID()
                                if C_NewItems and C_NewItems.RemoveNewItem then
                                    C_NewItems.RemoveNewItem(bID, sID)
                                end
                            end
                        end)
                        btn.AM_NewItemHooked = true
                    end
                    
                    if isNew then
                        btn.AM_SeenKey = seenKey
                        btn.AM_NewItemGlow:Show()
                        if btn.NewItemTexture then btn.NewItemTexture:Show() end
                        if btn.newitemglowAnim and not btn.newitemglowAnim:IsPlaying() then
                            btn.newitemglowAnim:Play()
                        end
                    else
                        btn.AM_SeenKey = nil
                        btn.AM_NewItemGlow:Hide()
                        if btn.NewItemTexture then btn.NewItemTexture:Hide() end
                        if btn.newitemglowAnim and btn.newitemglowAnim:IsPlaying() then
                            btn.newitemglowAnim:Stop()
                        end
                        if C_NewItems and C_NewItems.RemoveNewItem then
                            C_NewItems.RemoveNewItem(item.bag, item.slot)
                        end
                    end
                    if btn.BattlepayItemTexture then btn.BattlepayItemTexture:Hide() end
                    if btn.flash then btn.flash:Hide() end
                    
                    if not btn.AM_TrashHooked then
                        btn:HookScript("OnClick", function(self, button)
                            if button == "RightButton" and IsAltKeyDown() then
                                local bID = self:GetParent():GetID()
                                local sID = self:GetID()
                                local iID = C_Container.GetContainerItemID(bID, sID)
                                if iID then
                                    local _, _, _, _, _, _, _, _, _, _, sellPrice
                                    if C_Item and C_Item.GetItemInfo then
                                        _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(iID)
                                    else
                                        _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(iID)
                                    end
                                    
                                    if sellPrice and sellPrice > 0 then
                                        if AM.DB and AM.DB.ToggleTrash then
                                            AM.DB:ToggleTrash(bID, sID, iID)
                                        end
                                        if AM.BagUI then AM.BagUI:Update() end
                                    else
                                        print("|cffffff00AltManager|r: Cannot mark items with no sell value as trash.")
                                    end
                                end
                                return
                            end
                        end)
                        btn.AM_TrashHooked = true
                    end
                    
                    if not btn.AM_CursorHooked then
                        btn:HookScript("OnEnter", function(self)
                            if MerchantFrame and MerchantFrame:IsShown() then
                                local bID = self:GetParent():GetID()
                                local sID = self:GetID()
                                if C_Container and C_Container.ShowContainerSellCursor then
                                    C_Container.ShowContainerSellCursor(bID, sID)
                                elseif ShowContainerSellCursor then
                                    ShowContainerSellCursor(bID, sID)
                                end
                            end
                        end)
                        btn.AM_CursorHooked = true
                    end
                    
                    if item.info then
                        SetItemButtonTexture(btn, item.info.iconFileID)
                        SetItemButtonCount(btn, item.info.stackCount)
                        SetItemButtonQuality(btn, item.info.quality, item.link)
                        SetItemButtonDesaturated(btn, item.info.isLocked or item.isFiltered)
                        if item.isFiltered then btn:SetAlpha(0.2) else btn:SetAlpha(1.0) end
                    else
                        SetItemButtonTexture(btn, nil)
                        SetItemButtonCount(btn, 0)
                        SetItemButtonQuality(btn, nil, nil)
                        SetItemButtonDesaturated(btn, false)
                        btn:SetAlpha(1.0)
                    end
                    
                    local startsQuest = false
                    if not item.isEmpty then
                        local itemID = (item.info and item.info.itemID) or (item.link and tonumber(string.match(item.link, "item:(%d+)")))
                        if AM.DB and AM.DB.ItemStartsQuest then
                            startsQuest = AM.DB:ItemStartsQuest(itemID, item.link, item.bag, item.slot)
                        end
                    end
                    
                    if btn.IconQuestTexture then
                        if btn.questIcon then btn.questIcon:Hide() end
                        if startsQuest then
                            btn.IconQuestTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG or "Interface\\ContainerFrame\\UI-Icon-QuestBang")
                            btn.IconQuestTexture:Show()
                        else
                            btn.IconQuestTexture:Hide()
                        end
                    else
                        if not btn.questIcon then
                            btn.questIcon = btn:CreateTexture(nil, "OVERLAY", nil, 7)
                            btn.questIcon:SetAllPoints(btn)
                            btn.questIcon:SetTexture(TEXTURE_ITEM_QUEST_BANG or "Interface\\ContainerFrame\\UI-Icon-QuestBang")
                        end
                        if startsQuest then
                            btn.questIcon:Show()
                        else
                            btn.questIcon:Hide()
                        end
                    end
                else
                    btn = self.altButtons[btnAltIndex]
                    if not btn then
                        btn = CreateFrame("ItemButton", windowName.."AltBtn"..btnAltIndex, self)
                        btn:SetSize(37, 37)
                        
                        btn.icon = btn:CreateTexture(nil, "BORDER")
                        btn.icon:SetAllPoints()
                        
                        btn.countStr = btn:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
                        btn.countStr:SetPoint("BOTTOMRIGHT", -2, 2)
                        
                        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
                        
                        btn:SetScript("OnEnter", function(b)
                            if b.link then
                                GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                                GameTooltip:SetHyperlink(b.link)
                                GameTooltip:Show()
                            end
                        end)
                        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        self.altButtons[btnAltIndex] = btn
                    end
                    btnAltIndex = btnAltIndex + 1
                    
                    btn:SetParent(self)
                    btn.link = item.link
                    
                    btn.icon:SetTexture(item.iconFileID)
                    if item.count and item.count > 1 then
                        btn.countStr:SetText(tostring(item.count))
                    else
                        btn.countStr:SetText("")
                    end
                    
                    if not btn.questIcon then
                        btn.questIcon = btn:CreateTexture(nil, "OVERLAY", nil, 7)
                        btn.questIcon:SetAllPoints(btn)
                        btn.questIcon:SetTexture(TEXTURE_ITEM_QUEST_BANG or "Interface\\ContainerFrame\\UI-Icon-QuestBang")
                    end
                    
                    local startsQuest = false
                    if not item.isEmpty then
                        local itemID = item.itemID or (item.link and tonumber(string.match(item.link, "item:(%d+)")))
                        if AM.DB and AM.DB.ItemStartsQuest then
                            startsQuest = AM.DB:ItemStartsQuest(itemID, item.link, nil, nil)
                        end
                    end
                    if startsQuest then btn.questIcon:Show() else btn.questIcon:Hide() end
                    
                    if item.isFiltered then
                        btn.icon:SetDesaturated(true)
                        btn:SetAlpha(0.2)
                    else
                        btn.icon:SetDesaturated(false)
                        btn:SetAlpha(1.0)
                    end
                end
                
                if not btn.JunkIcon then
                    btn.JunkIcon = btn:CreateTexture(nil, "OVERLAY")
                    btn.JunkIcon:SetTexture("Interface\\BUTTONS\\UI-GroupLoot-Coin-Up")
                    btn.JunkIcon:SetSize(16, 16)
                    btn.JunkIcon:SetPoint("TOPLEFT", 1, -1)
                end
                
                local iID = nil
                if item.link then
                    iID = tonumber(string.match(item.link, "item:(%d+)"))
                end
                
                local isExplicitTrash = false
                if iID and AM.DB and AM.DB.IsTrash and AM.DB:IsTrash(win.selectedCharacter or (AM.DB.GetFullPlayerName and AM.DB:GetFullPlayerName() or ""), item.bag, item.slot, iID) then
                    isExplicitTrash = true
                end
                
                if (isExplicitTrash or (item.rarity and item.rarity == 0)) and not item.isEmpty then
                    btn.JunkIcon:Show()
                else
                    btn.JunkIcon:Hide()
                end
                
                if not btn.UpgradeText then
                    btn.UpgradeText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
                    btn.UpgradeText:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
                    btn.UpgradeText:SetText("|cff00ff00^|r")
                    local font, size, flags = btn.UpgradeText:GetFont()
                    if font then btn.UpgradeText:SetFont(font, 18, "OUTLINE") end
                end
                
                btn.UpgradeText:Hide()
                if btn.icon then btn.icon:SetVertexColor(1, 1, 1) end
                
                if not win.selectedCharacter and item.link then
                    local _, _, _, ilvl, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID
                    if C_Item and C_Item.GetItemInfo then
                        _, _, _, ilvl, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID = C_Item.GetItemInfo(item.link)
                    elseif GetItemInfo then
                        _, _, _, ilvl, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID = GetItemInfo(item.link)
                    end
                    
                    local isUsable = true
                    if reqLevel and reqLevel > UnitLevel("player") then
                        isUsable = false
                    elseif classID == 2 and (subclassID == 14 or subclassID == 20) then
                        isUsable = true
                    elseif classID == 2 or classID == 4 then
                        local usable = true
                        if C_PlayerInfo and C_PlayerInfo.CanUseItem and iID then
                            usable = C_PlayerInfo.CanUseItem(iID)
                        elseif C_Item and C_Item.IsUsableItem then
                            usable = C_Item.IsUsableItem(item.link)
                        elseif IsUsableItem then
                            usable = IsUsableItem(item.link)
                        end
                        
                        if usable == false then
                            isUsable = false
                        end
                    end
                    
                    if not isUsable and btn.icon then
                        btn.icon:SetVertexColor(1, 0.1, 0.1)
                    end
                    
                    if ilvl and equipLoc and EQUIP_LOC_TO_SLOTS[equipLoc] and isUsable then
                        local isProfessionTool = (classID == 2 and (subclassID == 14 or subclassID == 20))
                        if not isProfessionTool then
                            local currentIlvl, currentRarity, equippedArmorType = AM_GetEquippedItemLevel(equipLoc, classID, subclassID)
                            
                            local isUpgrade = false
                            if currentIlvl and ilvl > currentIlvl then
                                isUpgrade = true
                                
                                -- Armor Downgrade Check: If we are wearing armor (classID == 4) and the bag item is a lower armor type, it's not an upgrade.
                                -- (e.g., Bag item is Leather(2), but we are wearing Mail(3))
                                if classID == 4 and equippedArmorType > 0 then
                                    -- Exempt cosmetic/misc armor types like rings/trinkets/cloaks which don't have strict progression
                                    if equipLoc ~= "INVTYPE_CLOAK" and equipLoc ~= "INVTYPE_FINGER" and equipLoc ~= "INVTYPE_TRINKET" and equipLoc ~= "INVTYPE_HOLDABLE" then
                                        if subclassID < equippedArmorType then
                                            isUpgrade = false
                                        end
                                    end
                                end
                                
                                -- Optional: If you want to allow a blue item to replace a purple item if the ilvl gap is huge, 
                                -- you can adjust this rarity rule. For now, we enforce equal or greater rarity.
                                if isUpgrade and currentRarity and item.rarity < currentRarity then
                                    -- Allow lower rarity ONLY if the ilvl difference is significant (e.g., +10 ilvl)
                                    if (ilvl - currentIlvl) < 10 then
                                        isUpgrade = false
                                    end
                                end
                            end
                            
                            if isUpgrade then
                                btn.UpgradeText:Show()
                            end
                        end
                end
                
                local col = (i - 1) % COLUMNS
                local row = math.floor((i - 1) / COLUMNS)
                rows = row + 1
                
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", self, "TOPLEFT", 45 + col * (BUTTON_SIZE + SPACING), startY - row * (BUTTON_SIZE + SPACING))
                btn:Show()
            end
            
            if rows > 0 then
                local gridWidth = COLUMNS * (BUTTON_SIZE + SPACING) - SPACING
                if rows == 1 and #secData.items < COLUMNS then
                    gridWidth = #secData.items * (BUTTON_SIZE + SPACING) - SPACING
                end
                local gridHeight = rows * (BUTTON_SIZE + SPACING) - SPACING
                
                if not self.sectionBGs[bgIndex] then
                    self.sectionBGs[bgIndex] = self.bgContainer:CreateTexture(nil, "BACKGROUND")
                end
                local bg = self.sectionBGs[bgIndex]
                bg:SetColorTexture(secData.config.r, secData.config.g, secData.config.b, secData.config.a)
                bg:ClearAllPoints()
                bg:SetPoint("TOPLEFT", self, "TOPLEFT", 40, startY + 5)
                bg:SetSize(gridWidth + 10, gridHeight + 10)
                bg:Show()
                
                bgIndex = bgIndex + 1
                yOffset = startY - gridHeight - 20
            end
        end
        
        local minHeight = 260
        local finalHeight = math.abs(yOffset) + 20
        if finalHeight < minHeight then finalHeight = minHeight end
        self:SetSize(COLUMNS * (BUTTON_SIZE + SPACING) + 60, finalHeight)
    end
    
    local updateTimer = nil
    local function RequestUpdate(delay)
        if not win:IsShown() then return end
        if updateTimer then return end
        updateTimer = C_Timer.NewTimer(delay or 0.1, function()
            updateTimer = nil
            if win:IsShown() then win:Update() end
        end)
    end
    win.RequestUpdate = RequestUpdate

    win:SetScript("OnEvent", function(self, event, ...)
        if not self:IsShown() then return end
        if event == "PLAYER_MONEY" then
            if not self.selectedCharacter then
                self.moneyText:SetText(AM_FormatGold(GetMoney()))
            end
            return
        end
        if event == "BAG_UPDATE_DELAYED" then
            if updateTimer then
                updateTimer:Cancel()
                updateTimer = nil
            end
            self:Update()
        else
            RequestUpdate(0.1)
        end
    end)
    if storageType == "bags" or storageType == "combined" then
        win:RegisterEvent("BAG_UPDATE")
    end
    if storageType == "bank" or storageType == "combined" then
        win:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    end
    pcall(win.RegisterEvent, win, "BAG_UPDATE_DELAYED")
    win:RegisterEvent("BAG_UPDATE_COOLDOWN")
    win:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    win:RegisterEvent("PLAYER_MONEY")
    
    win:SetScript("OnShow", function(self) self:Update() end)
    win:SetScript("OnHide", function(self)
        self.selectedCharacter = nil
        self.searchQuery = ""
    end)
    
    table.insert(AM.Windows, win)
    return win
end

local bankBagList = AM:GetLiveBankBags()

AM.BagUI = AM:CreateInventoryWindow("AltManagerBagUI", "Bags", "bags", {
    { title = "Main Bags", bags = {0, 1, 2, 3, 4}, r=1.0, g=0.95, b=0.5, a=0.3, alwaysShow=true },
    { title = "Profession", bags = {5}, r=0.4, g=0.85, b=0.4, a=0.3 },
    { title = "Key Ring", bags = {-2}, r=0.6, g=0.8, b=1.0, a=0.3 }
}, false)

AM.BankUI = AM:CreateInventoryWindow("AltManagerBankUI", "Bank & Bags", "combined", {
    { title = "Bank", bags = bankBagList, r=0.85, g=0.85, b=0.85, a=0.3, alwaysShow=true },
    { title = "Main Bags", bags = {0, 1, 2, 3, 4}, r=1.0, g=0.95, b=0.5, a=0.3, alwaysShow=true },
    { title = "Profession", bags = {5}, r=0.4, g=0.85, b=0.4, a=0.3 },
    { title = "Key Ring", bags = {-2}, r=0.6, g=0.8, b=1.0, a=0.3 }
}, true)

local function AreDefaultBagsOpen()
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then return true end
    if ContainerFrame1 and ContainerFrame1:IsShown() then return true end
    return false
end

local function HideDefaultBags()
    if AM.forceBlizz then return end
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
        ContainerFrameCombinedBags:Hide()
    end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then f:Hide() end
    end
end

if hooksecurefunc then
    hooksecurefunc("OpenAllBags", function(frame)
        if not AM.forceBlizz then
            HideDefaultBags()
            if (BankFrame and BankFrame:IsShown()) or (AM.BankUI and AM.BankUI:IsShown()) then
                if AM.BankUI then AM.BankUI:Show() end
            else
                if AM.BagUI then AM.BagUI:Show() end
            end
        end
    end)
    
    hooksecurefunc("CloseAllBags", function(frame)
        if not AM.forceBlizz then
            if AM.BagUI and AM.BagUI:IsShown() then AM.BagUI:Hide() end
            if AM.BankUI and AM.BankUI:IsShown() then AM.BankUI:Hide() end
            AM.forceBlizz = false
        end
    end)
    
    hooksecurefunc("ToggleAllBags", function()
        if not AM.forceBlizz then
            HideDefaultBags()
            if (BankFrame and BankFrame:IsShown()) or (AM.BankUI and AM.BankUI:IsShown()) then
                if AM.BankUI:IsShown() then AM.BankUI:Hide() else AM.BankUI:Show() end
            else
                if AM.BagUI:IsShown() then AM.BagUI:Hide() else AM.BagUI:Show() end
            end
        else
            if not AreDefaultBagsOpen() then
                AM.forceBlizz = false
            end
        end
    end)
    
    hooksecurefunc("ToggleBackpack", function()
        if not AM.forceBlizz then
            HideDefaultBags()
            if (BankFrame and BankFrame:IsShown()) or (AM.BankUI and AM.BankUI:IsShown()) then
                if AM.BankUI:IsShown() then AM.BankUI:Hide() else AM.BankUI:Show() end
            else
                if AM.BagUI:IsShown() then AM.BagUI:Hide() else AM.BagUI:Show() end
            end
        else
            if not AreDefaultBagsOpen() then
                AM.forceBlizz = false
            end
        end
    end)
    
    hooksecurefunc("ToggleBag", function(id)
        if not AM.forceBlizz then
            HideDefaultBags()
            if (BankFrame and BankFrame:IsShown()) or (AM.BankUI and AM.BankUI:IsShown()) then
                if AM.BankUI:IsShown() then AM.BankUI:Hide() else AM.BankUI:Show() end
            else
                if AM.BagUI:IsShown() then AM.BagUI:Hide() else AM.BagUI:Show() end
            end
        else
            if not AreDefaultBagsOpen() then
                AM.forceBlizz = false
            end
        end
    end)
end

local bankEventFrame = CreateFrame("Frame")
bankEventFrame:RegisterEvent("BANKFRAME_OPENED")
bankEventFrame:RegisterEvent("BANKFRAME_CLOSED")
bankEventFrame:SetScript("OnEvent", function(self, event)
    if event == "BANKFRAME_OPENED" then
        if not AM.forceBlizz then
            if BankFrame and BankFrame:IsShown() then
                BankFrame:Hide()
            end
            HideDefaultBags()
        end
        if AM.BankUI then
            AM.BankUI:Show()
            AM.BankUI:Update()
        end
    elseif event == "BANKFRAME_CLOSED" then
        if AM.BankUI then
            AM.BankUI:Hide()
        end
    end
end)