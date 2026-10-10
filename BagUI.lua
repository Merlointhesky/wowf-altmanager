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

function AM:SellTrashItems()
    local totalSold = 0
    local soldItems = 0
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
                    if (rarity == 0 or AM.DB:IsTrash(AM.DB:GetFullPlayerName(), bag, slot, itemID)) and (sellPrice and sellPrice > 0) then
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        if info and not info.isLocked then
                            totalSold = totalSold + (sellPrice * info.stackCount)
                            soldItems = soldItems + 1
                            C_Container.UseContainerItem(bag, slot)
                        end
                    end
                end
            end
        end
    end
    if soldItems > 0 then
        print(string.format("|cffffff00AltManager|r: Sold %d trash items for %s", soldItems, AM_FormatGold(totalSold)))
    end
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

local function AM_GetEquippedItemLevel(equipLoc)
    local slots = EQUIP_LOC_TO_SLOTS[equipLoc]
    if not slots then return nil end
    
    local lowestILvl = 99999
    local lowestRarity = 999
    local has2H = false
    local mainHandILvl = nil
    local mainHandRarity = nil
    
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
            local ilvl, rarity
            if C_Item and C_Item.GetItemInfo then
                _, _, rarity, ilvl = C_Item.GetItemInfo(link)
            elseif GetItemInfo then
                _, _, rarity, ilvl = GetItemInfo(link)
            end
            
            if ilvl and ilvl < lowestILvl then
                lowestILvl = ilvl
                lowestRarity = rarity or 0
            end
        else
            if slot == 17 and has2H then
                if mainHandILvl and mainHandILvl < lowestILvl then
                    lowestILvl = mainHandILvl
                    lowestRarity = mainHandRarity or 0
                end
            else
                return 0, 0
            end
        end
    end
    
    if lowestILvl == 99999 then return 0, 0 end
    return lowestILvl, lowestRarity
end

local trashEventFrame = CreateFrame("Frame")
trashEventFrame:RegisterEvent("MERCHANT_SHOW")
trashEventFrame:SetScript("OnEvent", function()
    if AM.DB and AM.DB:IsAutoSellTrashEnabled() then
        AM:SellTrashItems()
    end
    if AM.DB and AM.DB:IsAutoRepairEnabled() and CanMerchantRepair() then
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
    
    -- Blizz UI Button (only on bags)
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
    local btnAuto = CreateIconButton(win, windowName.."SortAuto", "Interface\\Icons\\INV_Pet_Broom", "Auto Sort", "TOPLEFT", win, "TOPLEFT", 10, -60, function()
        if not win.selectedCharacter and C_Container and C_Container.SortBags then
            if storageType == "bags" then
                C_Container.SortBags()
            elseif storageType == "bank" then
                if C_Container.SortBankBags then C_Container.SortBankBags() end
            end
        end
    end)
    
    local btnRarity = CreateIconButton(win, windowName.."SortRarity", "Interface\\Icons\\INV_Misc_Gem_Diamond_02", "Sort by Rarity", "TOPLEFT", win, "TOPLEFT", 10, -90, function()
        win.currentSort = "rarity"
        win:Update()
    end)
    
    local btnValue = CreateIconButton(win, windowName.."SortValue", "Interface\\Icons\\INV_Misc_Coin_02", "Sort by Value", "TOPLEFT", win, "TOPLEFT", 10, -120, function()
        win.currentSort = "value"
        win:Update()
    end)
    
    local btnName = CreateIconButton(win, windowName.."SortName", "Interface\\Icons\\INV_Misc_Note_01", "Sort by Name", "TOPLEFT", win, "TOPLEFT", 10, -150, function()
        win.currentSort = "name"
        win:Update()
    end)
    
    local btnTrashSort = CreateIconButton(win, windowName.."SortTrash", "Interface\\Icons\\INV_Box_03", "Trash Sort", "TOPLEFT", win, "TOPLEFT", 10, -180, function()
        win.currentSort = "trash"
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

    -- Character Selection Icon (Bottom Left)
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
                local ruleset = AM.DB:GetRuleset()
                local faction = AM.DB:GetFaction()
                local chars = AM.DB.data[ruleset] and AM.DB.data[ruleset][faction]
                if chars then
                    for charName, _ in pairs(chars) do
                        if charName ~= AM.DB:GetFullPlayerName() then
                            AddOption(charName, false)
                        end
                    end
                end
            end
            
            dd:SetHeight(math.abs(yOff) + 10)
            dd:Show()
        end
    end)
    
    -- Money Text (Bottom Right)
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
            self:SetChecked(AM.DB:IsAutoSellTrashEnabled())
        end)
        chkAutoSell:SetScript("OnClick", function(self)
            AM.DB:SetAutoSellTrashEnabled(self:GetChecked())
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
            self:SetChecked(AM.DB:IsAutoRepairEnabled())
        end)
        chkAutoRepair:SetScript("OnClick", function(self)
            AM.DB:SetAutoRepairEnabled(self:GetChecked())
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
        
        local ruleset = AM.DB:GetRuleset()
        local faction = AM.DB:GetFaction()
        if not AM.DB.data[ruleset] or not AM.DB.data[ruleset][faction] then return end
        
        local totalGold = 0
        local chars = {}
        for cName, cData in pairs(AM.DB.data[ruleset][faction]) do
            table.insert(chars, {name = cName, money = cData.money or 0})
            totalGold = totalGold + (cData.money or 0)
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
    
    -- Prepare dummies for live bags
    win.bagDummies = {}
    if liveSections then
        for _, sec in ipairs(liveSections) do
            for _, bag in ipairs(sec.bags) do
                local dummy = CreateFrame("Frame", nil, win)
                dummy:SetID(bag)
                dummy:SetAllPoints()
                dummy:SetFrameLevel(win:GetFrameLevel() + 5)
                win.bagDummies[bag] = dummy
            end
        end
    end
    
    -- Update function
    win.Update = function(self)
        local allSectionsData = {}
        
        -- Gather data
        if not self.selectedCharacter then
            for _, sec in ipairs(self.liveSections) do
                local secItems = {}
                for _, bag in ipairs(sec.bags) do
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
                            
                            table.insert(secItems, {
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
        else
            local ruleset = AM.DB:GetRuleset()
            local faction = AM.DB:GetFaction()
            local charDB = AM.DB.data[ruleset] and AM.DB.data[ruleset][faction] and AM.DB.data[ruleset][faction][self.selectedCharacter]
            
            if charDB then
                local typesToRead = {}
                if storageType == "combined" then
                    table.insert(typesToRead, "bank")
                    table.insert(typesToRead, "bags")
                    table.insert(typesToRead, "profession")
                elseif charDB[storageType] then
                    table.insert(typesToRead, storageType)
                    if storageType == "bags" then
                        table.insert(typesToRead, "profession")
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
                    elseif sType == "bags" and charDB.bagCapacity then capacity = charDB.bagCapacity
                    elseif sType == "profession" and charDB.profCapacity then capacity = charDB.profCapacity
                    end
                    
                    local emptySlots = capacity - #secItems
                    if emptySlots > 0 then
                        for i = 1, emptySlots do
                            table.insert(secItems, { isEmpty = true, isLive = false })
                        end
                    end
                    
                    if #secItems > 0 then
                        local sTitle = (sType == "bank") and "Cached Bank" or ((sType == "profession") and "Cached Profession" or ("Cached " .. titleText))
                        local bgR, bgG, bgB = 0.8, 0.8, 0.8
                        if sType == "bank" then
                            bgR, bgG, bgB = 0.8, 0.8, 0.9 -- Bluish grey for bank
                        elseif sType == "bags" then
                            bgR, bgG, bgB = 1.0, 0.95, 0.5 -- Yellowish for bags
                        elseif sType == "profession" then
                            bgR, bgG, bgB = 0.4, 0.85, 0.4 -- Greenish for profession
                        end
                        
                        table.insert(allSectionsData, {
                            config = { title = sTitle, r = bgR, g = bgG, b = bgB, a = 0.3, alwaysShow = true },
                            items = secItems
                        })
                    end
                end
            end
        end
        
        -- Filter & Sort
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
                    
                    local aTrash = aID and (a.rarity == 0 or AM.DB:IsTrash(win.selectedCharacter or AM.DB:GetFullPlayerName(), a.bag, a.slot, aID))
                    local bTrash = bID and (b.rarity == 0 or AM.DB:IsTrash(win.selectedCharacter or AM.DB:GetFullPlayerName(), b.bag, b.slot, bID))
                    
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
        
        -- Update Money
        local displayMoney = 0
        if not self.selectedCharacter then
            displayMoney = GetMoney()
        else
            local ruleset = AM.DB:GetRuleset()
            local faction = AM.DB:GetFaction()
            local charDB = AM.DB.data[ruleset] and AM.DB.data[ruleset][faction] and AM.DB.data[ruleset][faction][self.selectedCharacter]
            if charDB then
                displayMoney = charDB.money or 0
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
                        
                        if (rarity == 0 or AM.DB:IsTrash(self.selectedCharacter or AM.DB:GetFullPlayerName(), item.bag, item.slot, itemID)) and (sellPrice and sellPrice > 0) then
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
        
        -- Layout Grid
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
                    
                    -- Clear "New Item" glow
                    if C_NewItems and C_NewItems.RemoveNewItem then
                        C_NewItems.RemoveNewItem(item.bag, item.slot)
                    end
                    if btn.NewItemTexture then btn.NewItemTexture:Hide() end
                    if btn.BattlepayItemTexture then btn.BattlepayItemTexture:Hide() end
                    if btn.flash then btn.flash:Hide() end
                    
                    if not btn.AM_TrashHooked then
                        -- Securely block the default action for Alt-RightClick to prevent using/drinking items
                        btn:SetAttribute("alt-type2", "macro")
                        btn:SetAttribute("macrotext-alt-type2", "")
                        
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
                                        AM.DB:ToggleTrash(bID, sID, iID)
                                        AM.BagUI:Update()
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
                if iID and AM.DB:IsTrash(win.selectedCharacter or AM.DB:GetFullPlayerName(), item.bag, item.slot, iID) then
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
                btn.icon:SetVertexColor(1, 1, 1)
                
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
                    
                    if not isUsable then
                        btn.icon:SetVertexColor(1, 0.1, 0.1)
                    end
                    
                    if ilvl and equipLoc and EQUIP_LOC_TO_SLOTS[equipLoc] and isUsable then
                        local isProfessionTool = (classID == 2 and (subclassID == 14 or subclassID == 20))
                        if not isProfessionTool then
                            local currentIlvl, currentRarity = AM_GetEquippedItemLevel(equipLoc)
                            if currentIlvl and ilvl > currentIlvl and (not currentRarity or item.rarity >= currentRarity) then
                                btn.UpgradeText:Show()
                            end
                        end
                    end
                end
                
                local col = (i - 1) % COLUMNS
                local row = math.floor((i - 1) / COLUMNS)
                rows = row + 1
                
                btn:ClearAllPoints()
                -- Shift grid to the right to make room for the left column icons
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
                -- Shift background right as well
                bg:SetPoint("TOPLEFT", self, "TOPLEFT", 40, startY + 5)
                bg:SetSize(gridWidth + 10, gridHeight + 10)
                bg:Show()
                
                bgIndex = bgIndex + 1
                yOffset = startY - gridHeight - 20
            end
        end
        
        -- Ensure minimum height to fit the left column icons (6 icons + bottom icon)
        local minHeight = 260
        local finalHeight = math.abs(yOffset) + 20
        if finalHeight < minHeight then finalHeight = minHeight end
        -- Increase width to accommodate left column
        self:SetSize(COLUMNS * (BUTTON_SIZE + SPACING) + 60, finalHeight)
    end
    
    win:SetScript("OnEvent", function(self, event, ...)
        if self:IsShown() then self:Update() end
    end)
    if storageType == "bags" then
        win:RegisterEvent("BAG_UPDATE")
    else
        win:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    end
    win:RegisterEvent("ITEM_LOCK_CHANGED")
    win:RegisterEvent("BAG_UPDATE_COOLDOWN")
    win:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    
    win:SetScript("OnShow", function(self) self:Update() end)
    win:SetScript("OnHide", function(self)
        self.selectedCharacter = nil
        self.searchQuery = ""
    end)
    
    table.insert(AM.Windows, win)
    return win
end

local bankStart = 6
local bankEnd = bankStart + (NUM_BANKBAGSLOTS or 7) - 1
local bankBagList = {}
for i = bankStart, bankEnd do table.insert(bankBagList, i) end

local mainBankID = (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or -1

-- Create the Windows
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

-- Hooks for Bags
local function AreDefaultBagsOpen()
    if ContainerFrame1 and ContainerFrame1:IsShown() then return true end
    return false
end

if not AM.originalToggleAllBags then
    AM.originalToggleAllBags = ToggleAllBags
    ToggleAllBags = function()
        if AM.forceBlizz then 
            AM.originalToggleAllBags()
            -- If user closes default bags via keybind, break out of forceBlizz
            if not AreDefaultBagsOpen() then
                AM.forceBlizz = false
            end
            return 
        end
        if AM.BagUI:IsShown() then AM.BagUI:Hide() else AM.BagUI:Show() end
    end
    AM.originalOpenAllBags = OpenAllBags
    OpenAllBags = function()
        if AM.forceBlizz then AM.originalOpenAllBags() return end
        AM.BagUI:Show()
    end
    AM.originalCloseAllBags = CloseAllBags
    CloseAllBags = function()
        if AM.forceBlizz then 
            AM.originalCloseAllBags() 
            AM.forceBlizz = false
            return 
        end
        AM.BagUI:Hide()
    end
    AM.originalToggleBackpack = ToggleBackpack
    ToggleBackpack = function()
        if AM.forceBlizz then 
            AM.originalToggleBackpack() 
            if not AreDefaultBagsOpen() then
                AM.forceBlizz = false
            end
            return 
        end
        ToggleAllBags()
    end
    AM.originalToggleBag = ToggleBag
    ToggleBag = function(id)
        if AM.forceBlizz then 
            AM.originalToggleBag(id)
            if not AreDefaultBagsOpen() then
                AM.forceBlizz = false
            end
            return 
        end
        ToggleAllBags()
    end
end

-- Hooks for Bank
local bankEventFrame = CreateFrame("Frame")
bankEventFrame:RegisterEvent("BANKFRAME_OPENED")
bankEventFrame:RegisterEvent("BANKFRAME_CLOSED")
bankEventFrame:SetScript("OnEvent", function(self, event)
    if event == "BANKFRAME_OPENED" then
        AM.BankUI:Show()
        AM.BankUI:Update()
    elseif event == "BANKFRAME_CLOSED" then
        AM.BankUI:Hide()
    end
end)
