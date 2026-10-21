local addonName, AM = ...
AM.DB = {}

-- Initialize DB
local function GetScanTooltip()
    if not AM.ScanTooltip then
        AM.ScanTooltip = _G["AltManagerScanTooltip"] or CreateFrame("GameTooltip", "AltManagerScanTooltip", UIParent, "GameTooltipTemplate")
        AM.ScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return AM.ScanTooltip
end

function AM.DB:ItemStartsQuest(itemID, itemLink, bag, slot)
    if not itemID and itemLink then
        itemID = tonumber(string.match(itemLink, "item:(%d+)"))
    end
    
    AltManagerDB = AltManagerDB or {}
    AltManagerDB.QuestStarts = AltManagerDB.QuestStarts or {}
    
    if itemID and AltManagerDB.QuestStarts[itemID] then
        return true
    end
    
    -- 1. Check C_Container.GetContainerItemQuestInfo (handles both table struct and multi-value returns)
    if bag and slot and C_Container and C_Container.GetContainerItemQuestInfo then
        local qInfo, qId, isAct = C_Container.GetContainerItemQuestInfo(bag, slot)
        local questId, isActive
        if type(qInfo) == "table" then
            questId = qInfo.questID
            isActive = qInfo.isActive
        else
            questId = qId
            isActive = isAct
        end
        if questId and not isActive then
            if itemID then AltManagerDB.QuestStarts[itemID] = true end
            return true
        end
    end
    
    -- 2. Modern C_TooltipInfo scan (Retail engine)
    if C_TooltipInfo then
        local data = nil
        if bag and slot and C_TooltipInfo.GetBagItem then
            data = C_TooltipInfo.GetBagItem(bag, slot)
        elseif itemLink and C_TooltipInfo.GetHyperlink then
            data = C_TooltipInfo.GetHyperlink(itemLink)
        elseif itemID and C_TooltipInfo.GetHyperlink then
            data = C_TooltipInfo.GetHyperlink("item:" .. itemID)
        end
        
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                local left = line.leftText
                if left and type(left) == "string" then
                    local lower = left:lower()
                    if (ITEM_STARTS_QUEST and string.find(left, ITEM_STARTS_QUEST, 1, true)) or
                       string.find(lower, "begins a quest", 1, true) or
                       string.find(lower, "starts a quest", 1, true) or
                       string.find(lower, "startet eine quest", 1, true) or
                       string.find(lower, "lancer une quête", 1, true) then
                        if itemID then AltManagerDB.QuestStarts[itemID] = true end
                        return true
                    end
                end
                if line.args then
                    for _, arg in ipairs(line.args) do
                        if type(arg) == "table" and arg.stringVal and type(arg.stringVal) == "string" then
                            local lower = arg.stringVal:lower()
                            if (ITEM_STARTS_QUEST and string.find(arg.stringVal, ITEM_STARTS_QUEST, 1, true)) or
                               string.find(lower, "begins a quest", 1, true) or
                               string.find(lower, "starts a quest", 1, true) then
                                if itemID then AltManagerDB.QuestStarts[itemID] = true end
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- 3. Fallback scan tooltip
    local tip = GetScanTooltip()
    tip:ClearLines()
    local ok = false
    if bag and slot then
        ok = pcall(tip.SetBagItem, tip, bag, slot)
    elseif itemLink then
        ok = pcall(tip.SetHyperlink, tip, itemLink)
    elseif itemID then
        ok = pcall(tip.SetHyperlink, tip, "item:" .. itemID)
    end
    
    if ok then
        local numLines = tip:NumLines()
        for i = 1, numLines do
            local fontStr = _G["AltManagerScanTooltipTextLeft" .. i]
            local text = fontStr and fontStr:GetText()
            if text and type(text) == "string" then
                local lower = text:lower()
                if (ITEM_STARTS_QUEST and string.find(text, ITEM_STARTS_QUEST, 1, true)) or
                   string.find(lower, "begins a quest", 1, true) or
                   string.find(lower, "starts a quest", 1, true) or
                   string.find(lower, "startet eine quest", 1, true) or
                   string.find(lower, "lancer une quête", 1, true) then
                    if itemID then AltManagerDB.QuestStarts[itemID] = true end
                    return true
                end
            end
        end
    end
    
    return false
end

function AM.DB:Init()
    if not AltManagerDB then
        AltManagerDB = {}
    end
    AltManagerDB.QuestStarts = AltManagerDB.QuestStarts or {}
    -- Seed known classic quest starters
    AltManagerDB.QuestStarts[2039] = true -- An Unsent Letter
    self.data = AltManagerDB
    
    -- Cleanup phantom duplicate entries (first-name only vs full-name)
    for ruleset, factions in pairs(self.data) do
        if type(factions) == "table" then
            for faction, chars in pairs(factions) do
                if type(chars) == "table" and (faction == "Horde" or faction == "Alliance") then
                    local toRemove = {}
                    for charName, _ in pairs(chars) do
                        -- The beta mandates last names; anything without a space is legacy data.
                        if not string.find(charName, " ") then
                            table.insert(toRemove, charName)
                        end
                    end
                    for _, oldName in ipairs(toRemove) do
                        chars[oldName] = nil
                    end
                    
                    -- Cleanup duplicate profession bag items in regular bags table
                    for charName, charData in pairs(chars) do
                        if type(charData) == "table" and charData.profession then
                            if not charData.profCapacity or charData.profCapacity == 0 then
                                local pCount = 0
                                for _ in pairs(charData.profession) do pCount = pCount + 1 end
                                charData.profCapacity = math.max(pCount, 4)
                            end
                            if charData.bags and not charData.profMigrated then
                                charData.profMigrated = true
                                for itemID, pCount in pairs(charData.profession) do
                                    if charData.bags[itemID] then
                                        charData.bags[itemID] = charData.bags[itemID] - pCount
                                        if charData.bags[itemID] <= 0 then
                                            charData.bags[itemID] = nil
                                        end
                                    end
                                end
                                if charData.bagCapacity and charData.profCapacity and charData.bagCapacity > charData.profCapacity then
                                    if charData.bagCapacity == 56 and charData.profCapacity == 4 then
                                        charData.bagCapacity = 52
                                    elseif charData.bagCapacity > 16 then
                                        charData.bagCapacity = charData.bagCapacity - charData.profCapacity
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function AM.DB:GetRuleset()
    -- Beta workaround: since standard realms are replaced by rulesets
    -- For now we'll use GetRealmName() which likely returns the ruleset name in WoW Forever
    return GetRealmName() or "Unknown"
end

function AM.DB:GetFaction()
    return UnitFactionGroup("player") or "Unknown"
end

function AM.DB:GetFullPlayerName()
    local name, arg2, arg3 = UnitName("player")
    local lastName = nil
    
    -- In standard WoW, UnitName("player") returns (name, nil).
    -- If the Beta injected a last name, it will appear as arg2.
    if type(arg2) == "string" and arg2 ~= "" and arg2 ~= GetRealmName() then
        lastName = arg2
    end
    
    if not lastName and UnitLastName then
        local last = UnitLastName("player")
        if type(last) == "string" and last ~= "" then lastName = last end
    end
    
    if not lastName and GetUnitName then
        local full = GetUnitName("player", false)
        if type(full) == "string" and full ~= name and not string.find(full, "-") then
            return full
        end
    end
    
    if lastName then
        return name .. " " .. lastName
    end
    
    return name or "Unknown"
end

function AM.DB:IsTrash(charName, bag, slot, itemID)
    if not charName or not bag or not slot or not itemID then return false end
    local ruleset = self:GetRuleset()
    local faction = self:GetFaction()
    local charDB = self.data[ruleset] and self.data[ruleset][faction] and self.data[ruleset][faction][charName]
    if not charDB then return false end
    
    if charDB.globalTrash and charDB.globalTrash[itemID] then
        return true
    end
    
    if not charDB.trashSlots then return false end
    return charDB.trashSlots[bag .. "_" .. slot] == itemID
end

function AM.DB:ToggleTrash(bag, slot, itemID)
    if not bag or not slot or not itemID then return end
    local charDB = self:GetCurrentCharacterDB()
    if not charDB then return end
    
    local maxStack = 1
    if C_Item and C_Item.GetItemInfo then
        local _, _, _, _, _, _, _, stack = C_Item.GetItemInfo(itemID)
        maxStack = stack or 1
    elseif GetItemInfo then
        local _, _, _, _, _, _, _, stack = GetItemInfo(itemID)
        maxStack = stack or 1
    end
    
    if maxStack > 1 then
        if not charDB.globalTrash then charDB.globalTrash = {} end
        if charDB.globalTrash[itemID] then
            charDB.globalTrash[itemID] = nil
        else
            charDB.globalTrash[itemID] = true
        end
    else
        if not charDB.trashSlots then charDB.trashSlots = {} end
        local key = bag .. "_" .. slot
        if charDB.trashSlots[key] == itemID then
            charDB.trashSlots[key] = nil
        else
            charDB.trashSlots[key] = itemID
        end
    end
end

function AM.DB:IsAutoSellTrashEnabled()
    local ruleset = self:GetRuleset()
    if not self.data[ruleset] then self.data[ruleset] = {} end
    return self.data[ruleset].autoSellTrash == true
end

function AM.DB:SetAutoSellTrashEnabled(val)
    local ruleset = self:GetRuleset()
    if not self.data[ruleset] then self.data[ruleset] = {} end
    self.data[ruleset].autoSellTrash = val
end

function AM.DB:IsAutoRepairEnabled()
    local ruleset = self:GetRuleset()
    if not self.data[ruleset] then self.data[ruleset] = {} end
    return self.data[ruleset].autoRepair == true
end

function AM.DB:SetAutoRepairEnabled(val)
    local ruleset = self:GetRuleset()
    if not self.data[ruleset] then self.data[ruleset] = {} end
    self.data[ruleset].autoRepair = val
end

function AM:IsItemStackable(itemID, info)
    if info and info.stackCount and info.stackCount > 1 then
        return true
    end
    if not itemID then return false end
    local maxStack = 1
    if C_Item and C_Item.GetItemMaxStackSizeByID then
        maxStack = C_Item.GetItemMaxStackSizeByID(itemID) or 1
    elseif C_Item and C_Item.GetItemInfo then
        local _, _, _, _, _, _, _, stack = C_Item.GetItemInfo(itemID)
        maxStack = stack or 1
    elseif GetItemInfo then
        local _, _, _, _, _, _, _, stack = GetItemInfo(itemID)
        maxStack = stack or 1
    end
    return maxStack > 1
end

 function AM:GetItemSeenKey(itemID, info, link)
    if not itemID then return nil end
    local isStackable = AM:IsItemStackable(itemID, info)
    
    if isStackable then
        return "stack:" .. itemID
    else
        -- Non-stackable items strip the volatile unique ID but keep enchant/gem data
        if link then
            local parts = {strsplit(":", link)}
            if #parts >= 9 then
                parts[9] = "0"
            end
            return table.concat(parts, ":")
        end
        return "item:" .. itemID
    end
end

function AM.DB:GetCurrentCharacterDB()
    if not self.data then
        self:Init()
    end
    local ruleset = self:GetRuleset()
    local faction = self:GetFaction()
    local name = self:GetFullPlayerName()
    
    if not self.data[ruleset] then self.data[ruleset] = {} end
    if not self.data[ruleset][faction] then self.data[ruleset][faction] = {} end
    if not self.data[ruleset][faction][name] then
        self.data[ruleset][faction][name] = {
            class = UnitClassBase("player"),
            level = UnitLevel("player"),
            money = 0,
            bags = {},
            bank = {},
            mail = {},
            hasNewMail = false,
            mailCount = 0,
            lastMailCheck = 0,
            professions = {},
            auctions = {},
            restXP = 0,
            maxXP = 1,
            isResting = false,
            logoutTime = 0,
            seenItems = {}
        }
    end
    
    return self.data[ruleset][faction][name]
end

function AM.DB:UpdateCharacterInfo()
    local charDB = self:GetCurrentCharacterDB()
    
    local class = UnitClassBase("player")
    if class then charDB.class = class end
    
    local level = UnitLevel("player")
    if level and level > 0 then charDB.level = level end
    
    local money = GetMoney()
    if money then charDB.money = money end
    
    local restXP = GetXPExhaustion()
    if restXP then charDB.restXP = restXP end
    
    local maxXP = UnitXPMax("player")
    if maxXP and maxXP > 0 then charDB.maxXP = maxXP end
    
    charDB.isResting = IsResting()
    charDB.logoutTime = time()
end

function AM.DB:IsQuiver(bag)
    if bag == 0 or bag == 5 or bag == -2 then return false end
    
    if C_Container and C_Container.GetContainerNumFreeSlots then
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if family == 1 or family == 2 then return true end
    elseif GetContainerNumFreeSlots then
        local free, family = GetContainerNumFreeSlots(bag)
        if family == 1 or family == 2 then return true end
    end
    
    local invID = ContainerIDToInventoryID and ContainerIDToInventoryID(bag)
    if invID then
        local itemID = GetInventoryItemID("player", invID)
        if itemID then
            local _, _, _, _, _, _, itemSubType
            if C_Item and C_Item.GetItemInfo then
                _, _, _, _, _, _, itemSubType = C_Item.GetItemInfo(itemID)
            else
                _, _, _, _, _, _, itemSubType = GetItemInfo(itemID)
            end
            if itemSubType == "Quiver" or itemSubType == "Ammo Pouch" or itemSubType == "Ammo" then
                return true
            end
        end
    end
    
    return false
end

function AM.DB:IsProfessionBag(bag)
    if bag == 5 or (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag and bag == Enum.BagIndex.ReagentBag) then
        return true
    end
    if bag == 0 or bag == -1 or bag == -2 then return false end
    
    if C_Container and C_Container.GetContainerNumFreeSlots then
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if family and family > 2 then
            return true
        end
    elseif GetContainerNumFreeSlots then
        local free, family = GetContainerNumFreeSlots(bag)
        if family and family > 2 then
            return true
        end
    end
    
    local invID = ContainerIDToInventoryID and ContainerIDToInventoryID(bag)
    if invID then
        local itemID = GetInventoryItemID("player", invID)
        if itemID then
            local _, _, _, _, _, _, itemSubType
            if C_Item and C_Item.GetItemInfo then
                _, _, _, _, _, _, itemSubType = C_Item.GetItemInfo(itemID)
            else
                _, _, _, _, _, _, itemSubType = GetItemInfo(itemID)
            end
            if itemSubType and (
                string.find(itemSubType, "Mining") or 
                string.find(itemSubType, "Herb") or 
                string.find(itemSubType, "Engineering") or 
                string.find(itemSubType, "Enchanting") or 
                string.find(itemSubType, "Gem") or 
                string.find(itemSubType, "Leatherworking") or 
                string.find(itemSubType, "Inscription") or 
                string.find(itemSubType, "Soul")
            ) then
                return true
            end
        end
    end
    
    return false
end

function AM.DB:UpdateBags()
    local charDB = self:GetCurrentCharacterDB()
    charDB.bags = {}
    charDB.quiver = {}
    charDB.profession = {}
    charDB.bagCapacity = 0
    charDB.quiverCapacity = 0
    charDB.profCapacity = 0
    
    local numBags = NUM_BAG_SLOTS or 4
    local reagentBag = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    
    local bagsToScan = {0}
    for i = 1, numBags do table.insert(bagsToScan, i) end
    if reagentBag then table.insert(bagsToScan, reagentBag) end
    
    local activeSeenKeys = {}
    for _, bag in ipairs(bagsToScan) do
        local isQuiv = self:IsQuiver(bag)
        local isProf = self:IsProfessionBag(bag)
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            if isQuiv then
                charDB.quiverCapacity = charDB.quiverCapacity + numSlots
            elseif isProf then
                charDB.profCapacity = charDB.profCapacity + numSlots
            else
                charDB.bagCapacity = charDB.bagCapacity + numSlots
            end
            
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink then
                    local itemID = info.itemID
                    
                    self:ItemStartsQuest(itemID, info.hyperlink, bag, slot)
                    
                    if isQuiv then
                        if not charDB.quiver[itemID] then charDB.quiver[itemID] = 0 end
                        charDB.quiver[itemID] = charDB.quiver[itemID] + info.stackCount
                    elseif isProf then
                        if not charDB.profession[itemID] then charDB.profession[itemID] = 0 end
                        charDB.profession[itemID] = charDB.profession[itemID] + info.stackCount
                    else
                        if not charDB.bags[itemID] then charDB.bags[itemID] = 0 end
                        charDB.bags[itemID] = charDB.bags[itemID] + info.stackCount
                    end
                    
                    local seenKey = AM:GetItemSeenKey(itemID, info, info.hyperlink)
                    if seenKey then
                        activeSeenKeys[seenKey] = true
                    end
                end
            end
        end
    end
    
    -- Cache management for seen items (only applies to player bags)
    if not charDB.seenItems then
        charDB.seenItems = {}
        for key in pairs(activeSeenKeys) do
            charDB.seenItems[key] = true
        end
    else
        -- Purge items that have been sold or deleted from bags
        for key in pairs(charDB.seenItems) do
            if not activeSeenKeys[key] then
                charDB.seenItems[key] = nil
            end
        end
    end
end

function AM.DB:UpdateBank()
    local charDB = self:GetCurrentCharacterDB()
    charDB.bank = {}
    charDB.bankCapacity = 0
    charDB.bankQuiver = {}
    charDB.bankQuiverCapacity = 0
    
    local bankBags = (AM.GetLiveBankBags and AM:GetLiveBankBags()) or { (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or -1 }
    for _, bag in ipairs(bankBags) do
        local isQuiv = self:IsQuiver(bag)
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            if isQuiv then
                charDB.bankQuiverCapacity = charDB.bankQuiverCapacity + numSlots
            else
                charDB.bankCapacity = charDB.bankCapacity + numSlots
            end
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink then
                    local itemID = info.itemID
                    
                    self:ItemStartsQuest(itemID, info.hyperlink, bag, slot)
                    
                    if isQuiv then
                        if not charDB.bankQuiver[itemID] then charDB.bankQuiver[itemID] = 0 end
                        charDB.bankQuiver[itemID] = charDB.bankQuiver[itemID] + info.stackCount
                    else
                        if not charDB.bank[itemID] then charDB.bank[itemID] = 0 end
                        charDB.bank[itemID] = charDB.bank[itemID] + info.stackCount
                    end
                end
            end
        end
    end
end

local function ExtractAuctionItemName(msg)
    if not msg then return nil end
    local link = string.match(msg, "|Hitem:.-|h%[(.-)%]|h")
    if link then return link end
    local bracketed = string.match(msg, "%[(.-)%]")
    if bracketed then return bracketed end
    local colonPart = string.match(msg, ":%s*([^%.%!]+)")
    if colonPart then return colonPart end
    local soldPart = string.match(msg, "[Aa]uction of (.+) sold")
    if soldPart then return soldPart end
    return nil
end

function AM.DB:RemoveAuction(identifier)
    if not identifier then return false end
    local charDB = self:GetCurrentCharacterDB()
    if not charDB or not charDB.auctions or #charDB.auctions == 0 then return false end
    
    local targetIndex = nil
    local matchStr = tostring(identifier):lower()
    matchStr = string.gsub(matchStr, "[%[%]]", "")
    matchStr = string.match(matchStr, "^%s*(.-)%s*$") or matchStr
    
    for i, auc in ipairs(charDB.auctions) do
        local aucName = auc.name and tostring(auc.name):lower()
        if aucName then
            aucName = string.gsub(aucName, "[%[%]]", "")
            aucName = string.match(aucName, "^%s*(.-)%s*$") or aucName
        end
        
        if (type(identifier) == "number" and auc.itemID == identifier)
           or (aucName and (aucName == matchStr or string.find(matchStr, aucName, 1, true) or string.find(aucName, matchStr, 1, true)))
           or (auc.link and string.find(auc.link:lower(), matchStr, 1, true)) then
            targetIndex = i
            break
        end
    end
    
    if targetIndex then
        local removed = table.remove(charDB.auctions, targetIndex)
        AM:DebugLog("AM.DB: Removed completed/sold auction: " .. tostring(removed.name or removed.itemID))
        
        if AM.UI and AM.UI.RefreshData then
            AM.UI:RefreshData()
        end
        if AM.UI and AM.UI.ItemViewer and AM.UI.ItemViewer:IsShown() then
            local charName = UnitName("player")
            if AM.UI.ItemViewer.title and AM.UI.ItemViewer.title:GetText() == (charName .. "'s Auctions") then
                AM.UI:ShowAuctions(charName)
            end
        end
        return true
    end
    return false
end

function AM.DB:UpdateMail()
    local charDB = self:GetCurrentCharacterDB()
    charDB.mail = {}
    charDB.lastMailCheck = time()
    
    local numItems = GetInboxNumItems()
    charDB.mailCount = numItems or 0
    if not numItems or numItems == 0 then
        charDB.hasNewMail = false
        if AM.UI and AM.UI.RefreshData then
            AM.UI:RefreshData()
        end
        return
    end
    
    local hasUnread = false
    for i = 1, numItems do
        local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead = GetInboxHeaderInfo(i)
        if not wasRead or wasRead == 0 then
            hasUnread = true
        end
        
        -- Detect completed or returned auctions from mail notifications
        if subject then
            local isAHMail = (sender and string.find(string.lower(sender), "auction"))
                or (AUCTION_SOLD_MAIL_SUBJECT and string.find(subject, "Auction successful"))
                or string.find(subject, "Auction sold")
                or string.find(subject, "Auction expired")
                or string.find(subject, "Auction cancelled")
                or string.find(subject, "Auction removed")
                or string.find(subject, "Auction successful")
            if isAHMail then
                local itemName = ExtractAuctionItemName(subject)
                if itemName then
                    AM.DB:RemoveAuction(itemName)
                end
            end
        end
        
        for attachIndex = 1, ATTACHMENTS_MAX_RECEIVE or 12 do
            local link = GetInboxItemLink(i, attachIndex)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                if itemID then
                    local name, arg2, arg3, arg4 = GetInboxItem(i, attachIndex)
                    local count
                    -- Beta Client always injects itemID as arg2 (name, itemID, texture, count)
                    count = arg4
                    
                    if not charDB.mail[itemID] then charDB.mail[itemID] = 0 end
                    charDB.mail[itemID] = charDB.mail[itemID] + (count or 1)
                end
            end
        end
    end
    
    charDB.hasNewMail = hasUnread
    
    if AM.UI and AM.UI.RefreshData then
        AM.UI:RefreshData()
    end
end

function AM.DB:UpdateProfessions()
    local charDB = self:GetCurrentCharacterDB()
    if not GetProfessions then return end

    -- Gather current professions from the game
    local p1, p2, arch, fish, cook, fa = GetProfessions()
    local profList = {
        { index = p1 },
        { index = p2 },
        { index = arch, fallbackName = "Archaeology", fallbackIcon = "Interface\\Icons\\trade_archaeology" },
        { index = fish, fallbackName = "Fishing", fallbackIcon = "Interface\\Icons\\trade_fishing" },
        { index = cook, fallbackName = "Cooking", fallbackIcon = "Interface\\Icons\\inv_misc_food_15" },
        { index = fa,   fallbackName = "First Aid", fallbackIcon = "Interface\\Icons\\spell_holy_sealofsacrifice" },
    }

    -- Map of currently learned professions
    local currentProf = {}
    for _, p in ipairs(profList) do
        local idx = p.index
        if idx and type(idx) == "number" then
            local name, tex, rank, maxRank = GetProfessionInfo(idx)
            if not name or name == "" then name = p.fallbackName end
            if not tex or tex == "" then tex = p.fallbackIcon end
            currentProf[name] = {
                name = name,
                texture = tex,
                rank = rank or 1,
                maxRank = maxRank or 300,
            }
        end
    end

    -- Preserve existing recipes for professions that remain
    local oldProf = {}
    if charDB.professions then
        for _, p in ipairs(charDB.professions) do
            oldProf[p.name] = p
        end
    end

    -- Build new list, keeping recipes for unchanged professions
    local newProfessions = {}
    for name, data in pairs(currentProf) do
        local entry = oldProf[name] or {
            name = name,
            texture = data.texture,
            rank = data.rank,
            maxRank = data.maxRank,
            recipes = {}
        }
        -- Update mutable fields in case they changed
        entry.texture = data.texture
        entry.rank = data.rank
        entry.maxRank = data.maxRank
        entry.recipes = entry.recipes or {}
        table.insert(newProfessions, entry)
    end

    charDB.professions = newProfessions
    if AM.UI and AM.UI.RefreshData then
        AM.UI:RefreshData()
    end
end

function AM.DB:GetRealtimeRestXP(charName)
    local ruleset = self:GetRuleset()
    local faction = self:GetFaction()
    if not self.data[ruleset] or not self.data[ruleset][faction] or not self.data[ruleset][faction][charName] then
        return 0
    end
    
    local charDB = self.data[ruleset][faction][charName]
    
    -- If it's the current character, just return the exact live value
    if charName == UnitName("player") then
        return GetXPExhaustion() or 0
    end
    
    -- Offline calculation
    local maxXP = charDB.maxXP or 1
    local savedRestXP = charDB.restXP or 0
    local logoutTime = charDB.logoutTime or time()
    local isResting = charDB.isResting or false
    
    local elapsed = time() - logoutTime
    if elapsed < 0 then elapsed = 0 end
    
    -- 1 bubble (5% of level) takes 8 hours resting, 32 hours not resting
    -- Max rest XP is 1.5 levels (150% of level)
    local maxRestXP = maxXP * 1.5
    
    local hoursElapsed = elapsed / 3600
    local xpPerHour
    
    if isResting then
        -- 5% of maxXP per 8 hours = maxXP * 0.05 / 8 = maxXP * 0.00625 per hour
        xpPerHour = maxXP * 0.00625
    else
        -- 5% of maxXP per 32 hours = maxXP * 0.05 / 32 = maxXP * 0.0015625 per hour
        xpPerHour = maxXP * 0.0015625
    end
    
    local accumulated = xpPerHour * hoursElapsed
    local currentRestXP = savedRestXP + accumulated
    
    if currentRestXP > maxRestXP then
        currentRestXP = maxRestXP
    end
    
    return math.floor(currentRestXP)
end

AM.Events["ADDON_LOADED"] = function(self, loadedAddon)
    if loadedAddon == addonName then
        AM.DB:Init()
        AM.DB:UpdateCharacterInfo()
        AM.DB:UpdateBags()
        if AM.UI and AM.UI.LoadMinimapPosition then
            AM.UI:LoadMinimapPosition()
        end
    end
end

AM.Events["PLAYER_LOGOUT"] = function(self)
    local charDB = AM.DB:GetCurrentCharacterDB()
    charDB.logoutTime = time()
end

AM.Events["PLAYER_UPDATE_RESTING"] = function(self)
    local charDB = AM.DB:GetCurrentCharacterDB()
    charDB.isResting = IsResting()
end

AM.Events["UPDATE_EXHAUSTION"] = function(self)
    local charDB = AM.DB:GetCurrentCharacterDB()
    local rxp = GetXPExhaustion()
    if rxp then charDB.restXP = rxp end
end

AM.Events["PLAYER_MONEY"] = function(self)
    AM.DB:UpdateCharacterInfo()
    if AM.UI and AM.UI.MainFrame and AM.UI.MainFrame:IsShown() and AM.UI.RefreshData then
        AM.UI:RefreshData()
    end
end

local pendingBagUpdate = false
function AM.DB:RequestUpdateBags()
    if pendingBagUpdate then return end
    pendingBagUpdate = true
    C_Timer.After(0.2, function()
        pendingBagUpdate = false
        AM.DB:UpdateBags()
    end)
end

local pendingBankUpdate = false
function AM.DB:RequestUpdateBank()
    if pendingBankUpdate then return end
    pendingBankUpdate = true
    C_Timer.After(0.2, function()
        pendingBankUpdate = false
        AM.DB:UpdateBank()
    end)
end

AM.Events["BAG_UPDATE"] = function(self, bagID)
    if not bagID then return end
    
    local bankID = Enum.BagIndex.Bank or -1
    local startBag = 6
    local endBag = startBag + (NUM_BANKBAGSLOTS or 7) - 1
    
    local isBank = false
    if bagID == bankID then isBank = true
    elseif bagID >= startBag and bagID <= endBag then isBank = true end
    
    if isBank then
        if AM.UI and AM.UI.bankOpen then
            AM.DB:RequestUpdateBank()
        end
    else
        AM.DB:RequestUpdateBags()
    end
end

AM.Events["PLAYERBANKSLOTS_CHANGED"] = function(self)
    if AM.UI and AM.UI.bankOpen then
        AM.DB:RequestUpdateBank()
    end
end

AM.Events["BAG_UPDATE_DELAYED"] = function(self)
    AM.DB:UpdateBags()
    if AM.UI and AM.UI.bankOpen then
        AM.DB:UpdateBank()
    end
end

AM.Events["BANKFRAME_OPENED"] = function(self)
    if not AM.UI then AM.UI = {} end
    AM.UI.bankOpen = true
    AM.DB:UpdateBank()
end

AM.Events["BANKFRAME_CLOSED"] = function(self)
    if not AM.UI then AM.UI = {} end
    AM.UI.bankOpen = false
end

AM.Events["PLAYERBANKSLOTS_CHANGED"] = function(self)
    if AM.UI and AM.UI.bankOpen then
        AM.DB:UpdateBank()
    end
end

AM.Events["MAIL_SHOW"] = function(self)
    AM.DB:UpdateMail()
end

AM.Events["MAIL_INBOX_UPDATE"] = function(self)
    AM.DB:UpdateMail()
end

AM.Events["MAIL_CLOSED"] = function(self)
    local charDB = AM.DB:GetCurrentCharacterDB()
    if HasNewMail then
        charDB.hasNewMail = (HasNewMail() and true) or false
    end
    if AM.UI and AM.UI.RefreshData then
        AM.UI:RefreshData()
    end
end

AM.Events["UPDATE_PENDING_MAIL"] = function(self)
    local charDB = AM.DB:GetCurrentCharacterDB()
    if HasNewMail then
        charDB.hasNewMail = (HasNewMail() and true) or false
        if AM.UI and AM.UI.RefreshData then
            AM.UI:RefreshData()
        end
    end
end

AM.Events["PLAYER_ENTERING_WORLD"] = function(self)
    AM.DB:UpdateCharacterInfo()
    AM.DB:UpdateProfessions()
    AM.DB:UpdateRecipes()
    if HasNewMail then
        local charDB = AM.DB:GetCurrentCharacterDB()
        charDB.hasNewMail = (HasNewMail() and true) or false
    end
end

AM.Events["TRADE_SKILL_SHOW"] = function(self)
    AM.DB:UpdateRecipes()
end

AM.Events["TRADE_SKILL_LIST_UPDATE"] = function(self)
    AM.DB:UpdateRecipes()
    AM.DB:UpdateProfessions()
    AM.DB:UpdateRecipes()
end

function AM.DB:UpdateRecipes()
    local charDB = AM.DB:GetCurrentCharacterDB()
    if not charDB.professions then AM:DebugLog("AM.DB: No professions found.") return end
    
    local profName = nil
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
        if profInfo then profName = profInfo.professionName end
    elseif C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
        local profID
        profID, profName = C_TradeSkillUI.GetTradeSkillLine()
    end
    
    AM:DebugLog("AM.DB: Event Fired! GetTradeSkillLine returned: " .. tostring(profName))
    
    if not profName or profName == "Unknown" or profName == "" then return end
    
    local profData = nil
    for _, p in ipairs(charDB.professions) do
        if p.name == profName then
            profData = p
            break
        end
    end
    
    if not profData then
        AM:DebugLog("AM.DB: " .. tostring(profName) .. " not found in charDB.professions. Creating dynamically.")
        profData = {
            name = profName,
            texture = "Interface\\Icons\\INV_Misc_QuestionMark",
            rank = 1,
            maxRank = 300,
            recipes = {}
        }
        table.insert(charDB.professions, profData)
    end
    
    -- Dynamically update rank and icon
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local pInfo = C_TradeSkillUI.GetBaseProfessionInfo()
        if pInfo then
            if pInfo.icon then profData.texture = pInfo.icon end
            if pInfo.professionLevel then profData.rank = pInfo.professionLevel end
            if pInfo.maxProfessionLevel then profData.maxRank = pInfo.maxProfessionLevel end
        end
    end
    
    profData.recipes = {}
    local addedCount = 0
    
    local recipeIDs = nil
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    elseif C_TradeSkillUI and C_TradeSkillUI.GetFilteredRecipeIDs then
        recipeIDs = C_TradeSkillUI.GetFilteredRecipeIDs()
    end
    
    if recipeIDs then
        AM:DebugLog("AM.DB: Using modern API. Found " .. tostring(#recipeIDs) .. " recipes.")
        for _, recipeID in ipairs(recipeIDs) do
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
            if recipeInfo and recipeInfo.learned then
                local link = nil
                if C_TradeSkillUI.GetRecipeItemLink then link = C_TradeSkillUI.GetRecipeItemLink(recipeID) end
                if not link and C_TradeSkillUI.GetRecipeLink then link = C_TradeSkillUI.GetRecipeLink(recipeID) end
                
                local reagents = {}
                if C_TradeSkillUI.GetRecipeSchematic then
                    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
                    if schematic and schematic.reagentSlotSchematics then
                        for _, slot in ipairs(schematic.reagentSlotSchematics) do
                            local rCount = slot.quantityRequired
                            if rCount and rCount > 0 and slot.reagents and slot.reagents[1] then
                                local rID = slot.reagents[1].itemID
                                local rName, rLink = nil, nil
                                if C_Item and C_Item.GetItemInfo then
                                    rName, rLink = C_Item.GetItemInfo(rID)
                                end
                                if not rName then rName = "Item " .. tostring(rID) end
                                table.insert(reagents, { name = rName, count = rCount, itemID = rID, link = rLink })
                            end
                        end
                    end
                elseif C_TradeSkillUI.GetRecipeNumReagents then
                    local numReagents = C_TradeSkillUI.GetRecipeNumReagents(recipeID)
                    for r = 1, numReagents do
                        local rName, _, rCount = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, r)
                        local rLink = nil
                        if C_TradeSkillUI.GetRecipeReagentItemLink then
                            rLink = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, r)
                        end
                        local rID = rLink and tonumber(string.match(rLink, "item:(%d+)"))
                        table.insert(reagents, { name = rName, count = rCount, itemID = rID, link = rLink })
                    end
                end
                
                local difficulty = 1
                if recipeInfo.relativeDifficulty then
                    if type(recipeInfo.relativeDifficulty) == "number" then
                        difficulty = recipeInfo.relativeDifficulty
                    end
                end
                
                local finalName = recipeInfo.name
                local finalIcon = recipeInfo.icon
                
                -- Repair empty links (like `[]`) caused by unindexed beta spells
                if link and string.find(link, "%[%]") then
                    local sName, sIcon
                    if C_Spell and C_Spell.GetSpellInfo then
                        local sInfo = C_Spell.GetSpellInfo(recipeID)
                        if sInfo then sName = sInfo.name; sIcon = sInfo.iconID end
                    end
                    if sName and sName ~= "" then
                        if not finalName or finalName == "" then finalName = sName end
                        if not finalIcon or finalIcon == 0 then finalIcon = sIcon end
                        link = string.gsub(link, "%[%]", "[" .. sName .. "]")
                    end
                end
                
                -- Last ditch catch-all for missing names
                if not finalName or finalName == "" then
                    local sName, sIcon
                    if C_Spell and C_Spell.GetSpellInfo then
                        local sInfo = C_Spell.GetSpellInfo(recipeID)
                        if sInfo then sName = sInfo.name; sIcon = sInfo.iconID end
                    end
                    if sName and sName ~= "" then
                        finalName = sName
                        if not finalIcon or finalIcon == 0 then finalIcon = sIcon end
                    end
                    if not finalName or finalName == "" then
                        finalName = "Recipe #" .. tostring(recipeID)
                    end
                end
                
                table.insert(profData.recipes, {
                    name = finalName,
                    icon = finalIcon,
                    link = link,
                    reagents = reagents,
                    difficulty = difficulty
                })
                addedCount = addedCount + 1
            end
        end
    end
    AM:DebugLog("AM.DB: Successfully saved " .. addedCount .. " recipes.")
end

AM.Events["SKILL_LINES_CHANGED"] = function(self)
    AM.DB:UpdateProfessions()
end

local aucScanTooltip = CreateFrame("GameTooltip", "AMAuctionScanTooltip", UIParent, "GameTooltipTemplate")
aucScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function GetAuctionScanTooltip()
    if not AM.AuctionScanTooltip then
        AM.AuctionScanTooltip = CreateFrame("GameTooltip", "AMAuctionScanTooltip", UIParent, "GameTooltipTemplate")
        AM.AuctionScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return AM.AuctionScanTooltip
end

local function GetSellSlotItemLink()
    local tip = GetAuctionScanTooltip()
    tip:ClearLines()
    if tip.SetAuctionSellItem then
        local ok = pcall(tip.SetAuctionSellItem, tip)
        if ok then
            local _, link = tip:GetItem()
            if link and link ~= "" then
                return link
            end
        end
    end
    return nil
end

AM.DB.pendingAuction = nil
AM.DB.lastSellItem = nil

function AM.DB:CaptureSellSlotItem()
    if not GetAuctionSellItemInfo then return end
    local name, texture, count, quality = GetAuctionSellItemInfo()
    if not name or name == "" then return end
    
    local link = GetSellSlotItemLink()
    local itemID = nil
    if link and type(link) == "string" then
        local id = string.match(link, "item:(%d+)")
        if id then itemID = tonumber(id) end
    end
    
    if not itemID and name then
        if C_Item and C_Item.GetItemInfo then
            local n, l = C_Item.GetItemInfo(name)
            if l then link = l end
        elseif GetItemInfo then
            local n, l = GetItemInfo(name)
            if l then link = l end
        end
        if link then
            local id = string.match(link, "item:(%d+)")
            if id then itemID = tonumber(id) end
        end
    end
    
    if itemID and (not texture or texture == "Interface\\Icons\\INV_Misc_QuestionMark") then
        if C_Item and C_Item.GetItemInfoInstant then
            local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
            if icon then texture = icon end
        end
    end
    
    AM.DB.lastSellItem = {
        name = name,
        texture = texture,
        count = count or 1,
        quality = quality,
        link = link or (itemID and ("item:" .. itemID)) or name,
        itemID = itemID,
        time = time()
    }
end

local function GetItemInfoFromLocation(itemLocation)
    if not itemLocation then return nil, nil, nil, nil end
    local itemID = C_Item and C_Item.GetItemID and C_Item.GetItemID(itemLocation)
    local link = C_Item and C_Item.GetItemLink and C_Item.GetItemLink(itemLocation)
    local name = C_Item and C_Item.GetItemName and C_Item.GetItemName(itemLocation)
    local icon = C_Item and C_Item.GetItemIcon and C_Item.GetItemIcon(itemLocation)
    
    if itemID and not icon and C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, ic = C_Item.GetItemInfoInstant(itemID)
        if ic then icon = ic end
    end
    if itemID and not name and C_Item and C_Item.GetItemInfo then
        local n, l, _, _, _, _, _, _, _, t = C_Item.GetItemInfo(itemID)
        if n then name = n end
        if l and not link then link = l end
        if t and not icon then icon = t end
    end
    if itemID and not link then
        link = "item:" .. itemID
    end
    return itemID, link, name, icon
end

local function RecordPendingPost(minBid, buyoutPrice, runTime, stackSize, numStacks)
    if GetAuctionSellItemInfo then
        local n = GetAuctionSellItemInfo()
        if n and n ~= "" then
            AM.DB:CaptureSellSlotItem()
        end
    end
    
    local sellInfo = AM.DB.lastSellItem
    local name = sellInfo and sellInfo.name
    local texture = sellInfo and sellInfo.texture
    local count = sellInfo and sellInfo.count
    local itemLink = sellInfo and sellInfo.link
    local itemID = sellInfo and sellInfo.itemID
    
    local durationSec = 24 * 3600
    if runTime == 1 then
        durationSec = 12 * 3600
    elseif runTime == 2 then
        durationSec = 24 * 3600
    elseif runTime == 3 then
        durationSec = 48 * 3600
    end
    
    local totalStacks = (type(numStacks) == "number" and numStacks > 0) and numStacks or 1
    local qty = (type(stackSize) == "number" and stackSize > 0) and stackSize or (count or 1)
    local price = (type(buyoutPrice) == "number" and buyoutPrice > 0) and buyoutPrice or (minBid or 0)
    
    AM.DB.pendingAuction = {
        itemID = itemID,
        name = name,
        icon = texture,
        link = itemLink or name or (itemID and ("item:" .. itemID)) or "Unknown Item",
        count = qty,
        numStacks = totalStacks,
        buyout = price,
        durationSec = durationSec,
        postedTime = time(),
    }
end

-- Secure hooks for auction posting
if hooksecurefunc then
    if PostAuction then
        hooksecurefunc("PostAuction", function(minBid, buyoutPrice, runTime, stackSize, numStacks)
            RecordPendingPost(minBid, buyoutPrice, runTime, stackSize, numStacks)
            AM.DB:ScheduleOwnedAuctionsRefresh()
        end)
    end
    if StartAuction then
        hooksecurefunc("StartAuction", function(minBid, buyoutPrice, runTime, stackSize, numStacks)
            RecordPendingPost(minBid, buyoutPrice, runTime, stackSize, numStacks)
            AM.DB:ScheduleOwnedAuctionsRefresh()
        end)
    end
    if C_AuctionHouse and C_AuctionHouse.PostItem then
        hooksecurefunc(C_AuctionHouse, "PostItem", function(itemLocation, duration, quantity, bidAmount, buyoutAmount)
            local itemID, link, name, icon = GetItemInfoFromLocation(itemLocation)
            local price = (type(buyoutAmount) == "number" and buyoutAmount > 0) and buyoutAmount or (bidAmount or 0)
            local durationSec = (duration == 1 and 12*3600) or (duration == 3 and 48*3600) or (24*3600)
            AM.DB.pendingAuction = {
                itemID = itemID,
                name = name,
                icon = icon,
                link = link or name or (itemID and ("item:" .. itemID)) or "Unknown Item",
                count = quantity or 1,
                numStacks = 1,
                buyout = price,
                durationSec = durationSec,
                postedTime = time(),
            }
            AM.DB:ScheduleOwnedAuctionsRefresh()
        end)
    end
    if C_AuctionHouse and C_AuctionHouse.PostCommodity then
        hooksecurefunc(C_AuctionHouse, "PostCommodity", function(itemLocation, duration, quantity, unitPrice)
            local itemID, link, name, icon = GetItemInfoFromLocation(itemLocation)
            local durationSec = (duration == 1 and 12*3600) or (duration == 3 and 48*3600) or (24*3600)
            AM.DB.pendingAuction = {
                itemID = itemID,
                name = name,
                icon = icon,
                link = link or name or (itemID and ("item:" .. itemID)) or "Unknown Item",
                count = quantity or 1,
                numStacks = 1,
                buyout = (unitPrice or 0) * (quantity or 1),
                durationSec = durationSec,
                postedTime = time(),
            }
            AM.DB:ScheduleOwnedAuctionsRefresh()
        end)
    end
end

function AM.DB:RequestOwnedAuctions()
    if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
        pcall(function()
            C_AuctionHouse.QueryOwnedAuctions({})
        end)
    end
    if GetOwnerAuctionItems then
        pcall(GetOwnerAuctionItems)
    end
end

function AM.DB:ScheduleOwnedAuctionsRefresh()
    AM.DB:RequestOwnedAuctions()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.4, function() AM.DB:RequestOwnedAuctions() end)
        C_Timer.After(1.2, function() AM.DB:RequestOwnedAuctions() end)
        C_Timer.After(2.5, function() AM.DB:RequestOwnedAuctions() end)
    end
end

function AM.DB:OnAuctionCreated()
    local charDB = AM.DB:GetCurrentCharacterDB()
    if not charDB.auctions then
        charDB.auctions = {}
    end
    
    if AM.DB.pendingAuction and (time() - (AM.DB.pendingAuction.postedTime or 0)) < 15 then
        local p = AM.DB.pendingAuction
        local stacks = p.numStacks or 1
        for s = 1, stacks do
            table.insert(charDB.auctions, {
                id = "pending_" .. time() .. "_" .. s .. "_" .. math.random(100, 999),
                itemID = p.itemID,
                name = p.name,
                icon = p.icon,
                link = p.link,
                count = p.count or 1,
                buyout = p.buyout or 0,
                expires = time() + (p.durationSec or (24*3600)),
                status = 0
            })
        end
        AM.DB.pendingAuction = nil
        
        if AM.UI and AM.UI.RefreshData then
            AM.UI:RefreshData()
        end
        if AM.UI and AM.UI.ItemViewer and AM.UI.ItemViewer:IsShown() then
            local charName = UnitName("player")
            if AM.UI.ItemViewer.title and AM.UI.ItemViewer.title:GetText() == (charName .. "'s Auctions") then
                AM.UI:ShowAuctions(charName)
            end
        end
    end
    
    AM.DB:ScheduleOwnedAuctionsRefresh()
end

function AM.DB:UpdateAuctions()
    local charDB = AM.DB:GetCurrentCharacterDB()
    local newAuctions = {}
    
    if C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions and C_AuctionHouse.GetOwnedAuctionInfo then
        local num = C_AuctionHouse.GetNumOwnedAuctions()
        for i = 1, num do
            local auc = C_AuctionHouse.GetOwnedAuctionInfo(i)
            if auc then
                local aucID = auc.auctionID
                local itemID = auc.itemID or (auc.itemKey and auc.itemKey.itemID)
                local link = auc.itemLink
                local itemName = nil
                local itemTexture = nil
                
                if auc.itemKey and C_AuctionHouse and C_AuctionHouse.GetItemKeyInfo then
                    local info = C_AuctionHouse.GetItemKeyInfo(auc.itemKey)
                    if type(info) == "table" then
                        itemName = info.itemName
                        itemTexture = info.iconFileID
                    elseif type(info) == "string" then
                        itemName = info
                    end
                end
                
                if itemID then
                    if C_Item and C_Item.RequestLoadItemDataByID then
                        C_Item.RequestLoadItemDataByID(itemID)
                    end
                    if C_Item and C_Item.GetItemInfo then
                        local n, l, _, _, _, _, _, _, _, t = C_Item.GetItemInfo(itemID)
                        if n and not itemName then itemName = n end
                        if l and not link then link = l end
                        if t and not itemTexture then itemTexture = t end
                    elseif GetItemInfo then
                        local n, l, _, _, _, _, _, _, _, t = GetItemInfo(itemID)
                        if n and not itemName then itemName = n end
                        if l and not link then link = l end
                        if t and not itemTexture then itemTexture = t end
                    end
                    if not itemTexture and C_Item and C_Item.GetItemInfoInstant then
                        local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                        if icon then itemTexture = icon end
                    end
                    if not link then
                        link = "item:" .. itemID
                    end
                end
                
                if not itemID and link and type(link) == "string" then
                    local id = string.match(link, "item:(%d+)")
                    if id then
                        itemID = tonumber(id)
                        if not itemTexture and C_Item and C_Item.GetItemInfoInstant then
                            local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                            if icon then itemTexture = icon end
                        end
                    end
                end
                
                local count = auc.quantity or 1
                local buyout = auc.buyoutAmount or auc.bidAmount or 0
                local timeLeft = auc.timeLeftSeconds
                local expires = time() + (timeLeft or (24*3600))
                
                if auc.status == 1 then
                    expires = time()
                elseif not timeLeft and charDB.auctions and aucID then
                    for _, oldAuc in ipairs(charDB.auctions) do
                        if oldAuc.id == aucID and oldAuc.expires then
                            expires = oldAuc.expires
                            break
                        end
                    end
                end
                
                table.insert(newAuctions, {
                    id = aucID,
                    itemID = itemID,
                    name = itemName,
                    icon = itemTexture,
                    link = link or (itemID and ("item:" .. itemID)) or "Unknown Item",
                    count = count,
                    buyout = buyout,
                    expires = expires,
                    status = auc.status
                })
            end
        end
    elseif C_AuctionHouse and C_AuctionHouse.GetOwnedAuctions then
        local owned = C_AuctionHouse.GetOwnedAuctions()
        if type(owned) == "table" then
            for _, auc in ipairs(owned) do
                local aucID = auc.auctionID
                local itemID = auc.itemID or (auc.itemKey and auc.itemKey.itemID)
                local link = auc.itemLink
                local itemName = nil
                local itemTexture = nil
                
                if auc.itemKey and C_AuctionHouse and C_AuctionHouse.GetItemKeyInfo then
                    local info = C_AuctionHouse.GetItemKeyInfo(auc.itemKey)
                    if type(info) == "table" then
                        itemName = info.itemName
                        itemTexture = info.iconFileID
                    elseif type(info) == "string" then
                        itemName = info
                    end
                end
                
                if itemID then
                    if C_Item and C_Item.RequestLoadItemDataByID then
                        C_Item.RequestLoadItemDataByID(itemID)
                    end
                    if C_Item and C_Item.GetItemInfo then
                        local n, l, _, _, _, _, _, _, _, t = C_Item.GetItemInfo(itemID)
                        if n and not itemName then itemName = n end
                        if l and not link then link = l end
                        if t and not itemTexture then itemTexture = t end
                    end
                    if not itemTexture and C_Item and C_Item.GetItemInfoInstant then
                        local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                        if icon then itemTexture = icon end
                    end
                    if not link then
                        link = "item:" .. itemID
                    end
                end
                
                local count = auc.quantity or 1
                local buyout = auc.buyoutAmount or auc.bidAmount or 0
                local timeLeft = auc.timeLeftSeconds
                local expires = time() + (timeLeft or (24*3600))
                
                if auc.status == 1 then
                    expires = time()
                elseif not timeLeft and charDB.auctions and aucID then
                    for _, oldAuc in ipairs(charDB.auctions) do
                        if oldAuc.id == aucID and oldAuc.expires then
                            expires = oldAuc.expires
                            break
                        end
                    end
                end
                
                table.insert(newAuctions, {
                    id = aucID,
                    itemID = itemID,
                    name = itemName,
                    icon = itemTexture,
                    link = link or (itemID and ("item:" .. itemID)) or "Unknown Item",
                    count = count,
                    buyout = buyout,
                    expires = expires,
                    status = auc.status
                })
            end
        end
    end
    
    local function ParseAuctionItemInfo(aucType, index)
        local tip = GetAuctionScanTooltip()
        tip:ClearLines()
        if tip.SetAuctionItem then
            pcall(tip.SetAuctionItem, tip, aucType, index)
        end
        local tipName, tipLink = tip:GetItem()
        local tipHeader = _G[tip:GetName() .. "TextLeft1"] and _G[tip:GetName() .. "TextLeft1"]:GetText()
        
        local link = tipLink
        if not link and GetAuctionItemLink then
            link = GetAuctionItemLink(aucType, index)
        end
        
        local itemID = nil
        if link and type(link) == "string" then
            local id = string.match(link, "item:(%d+)")
            if id then itemID = tonumber(id) end
        end
        
        local raw = {}
        if GetAuctionItemInfo then
            raw = { GetAuctionItemInfo(aucType, index) }
        end
        
        if #raw == 0 and not link and not tipHeader then
            return nil
        end
        
        local name = raw[1]
        local texture = nil
        local count = 1
        local buyoutPrice = 0
        local minBid = 0
        local saleStatus = 0
        
        -- Check for shifted parameters (e.g. itemID at index 2)
        if type(raw[2]) == "number" and raw[2] > 0 and (itemID == raw[2] or (type(raw[3]) == "string" and string.find(raw[3], "Interface")) or (type(raw[4]) == "number" and raw[4] >= 1 and raw[4] <= 200)) then
            if not itemID then itemID = raw[2] end
            texture = raw[3]
            count = type(raw[4]) == "number" and raw[4] or 1
            buyoutPrice = type(raw[11]) == "number" and raw[11] or 0
            minBid = type(raw[9]) == "number" and raw[9] or 0
            saleStatus = type(raw[17]) == "number" and raw[17] or 0
        else
            texture = raw[2]
            count = type(raw[3]) == "number" and raw[3] or 1
            buyoutPrice = type(raw[10]) == "number" and raw[10] or 0
            minBid = type(raw[8]) == "number" and raw[8] or 0
            saleStatus = type(raw[16]) == "number" and raw[16] or 0
            if not itemID and type(raw[17]) == "number" and raw[17] > 0 then
                itemID = raw[17]
            end
        end
        
        if not itemID then
            for idx = 15, #raw do
                if type(raw[idx]) == "number" and raw[idx] > 100 then
                    itemID = raw[idx]
                    break
                end
            end
        end
        
        if (not name or name == "" or name == "Unknown Item") then
            if tipHeader and tipHeader ~= "" and not string.find(tipHeader, "Unknown") then
                name = tipHeader
            elseif tipName and tipName ~= "" and not string.find(tipName, "Unknown") then
                name = tipName
            end
        end
        
        if itemID then
            if C_Item and C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(itemID)
            end
            if (not name or name == "" or name == "Unknown Item") then
                if C_Item and C_Item.GetItemInfo then
                    local n = C_Item.GetItemInfo(itemID)
                    if n then name = n end
                elseif GetItemInfo then
                    local n = GetItemInfo(itemID)
                    if n then name = n end
                end
            end
            if not texture or texture == "Interface\\Icons\\INV_Misc_QuestionMark" then
                if C_Item and C_Item.GetItemInfoInstant then
                    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                    if icon then texture = icon end
                elseif GetItemIcon then
                    local icon = GetItemIcon(itemID)
                    if icon then texture = icon end
                end
            end
            if not link or link == "Unknown Item" then
                link = "item:" .. itemID
            end
        end
        
        return {
            name = name,
            texture = texture,
            count = count,
            buyout = (buyoutPrice and buyoutPrice > 0) and buyoutPrice or (minBid or 0),
            saleStatus = saleStatus,
            itemID = itemID,
            link = link or name or (itemID and ("item:" .. itemID)) or "Unknown Item"
        }
    end
    
    if #newAuctions == 0 and GetNumAuctionItems then
        local num = GetNumAuctionItems("owner")
        for i = 1, num do
            local parsed = ParseAuctionItemInfo("owner", i)
            if parsed then
                local compKey = (parsed.itemID or "0") .. "_" .. (parsed.count or "0") .. "_" .. (parsed.buyout or "0")
                local timeLeftBand = GetAuctionItemTimeLeft and GetAuctionItemTimeLeft("owner", i)
                local durationSec = 24 * 3600
                if timeLeftBand == 1 then
                    durationSec = 1800
                elseif timeLeftBand == 2 then
                    durationSec = 2 * 3600
                elseif timeLeftBand == 3 then
                    durationSec = 8 * 3600
                elseif timeLeftBand == 4 then
                    durationSec = 24 * 3600
                end
                local expires = time() + durationSec
                
                if charDB.auctions then
                    for _, oldAuc in ipairs(charDB.auctions) do
                        if (oldAuc.id == compKey or (oldAuc.buyout == parsed.buyout and oldAuc.count == parsed.count)) and oldAuc.expires then
                            expires = oldAuc.expires
                            if (not parsed.name or parsed.name == "" or parsed.name == "Unknown Item") and oldAuc.name and oldAuc.name ~= "Unknown Item" then
                                parsed.name = oldAuc.name
                            end
                            if (not parsed.link or parsed.link == "Unknown Item") and oldAuc.link and oldAuc.link ~= "Unknown Item" then
                                parsed.link = oldAuc.link
                            end
                            if not parsed.itemID and oldAuc.itemID then
                                parsed.itemID = oldAuc.itemID
                            end
                            if (not parsed.texture or parsed.texture == "Interface\\Icons\\INV_Misc_QuestionMark") and oldAuc.icon then
                                parsed.texture = oldAuc.icon
                            end
                            break
                        end
                    end
                end
                
                table.insert(newAuctions, {
                    id = compKey,
                    itemID = parsed.itemID,
                    name = parsed.name,
                    icon = parsed.texture,
                    link = parsed.link,
                    count = parsed.count,
                    buyout = parsed.buyout,
                    expires = expires,
                    status = parsed.saleStatus
                })
            end
        end
    end
    
    -- If newAuctions has data, only overwrite if it has valid info or current is empty
    if #newAuctions > 0 then
        local hasRealInfo = false
        for _, a in ipairs(newAuctions) do
            if (a.name and a.name ~= "Unknown Item" and a.name ~= "") or a.itemID then
                hasRealInfo = true
                break
            end
        end
        if hasRealInfo or not (charDB.auctions and #charDB.auctions > 0) then
            charDB.auctions = newAuctions
        end
    elseif not (AM.DB.pendingAuction and (time() - (AM.DB.pendingAuction.postedTime or 0)) < 5) and (GetNumAuctionItems and GetNumAuctionItems("owner") == 0) then
        charDB.auctions = {}
    end
    
    if AM.UI and AM.UI.RefreshData then
        AM.UI:RefreshData()
    end
    if AM.UI and AM.UI.ItemViewer and AM.UI.ItemViewer:IsShown() then
        local charName = UnitName("player")
        if AM.UI.ItemViewer.title and AM.UI.ItemViewer.title:GetText() == (charName .. "'s Auctions") then
            AM.UI:ShowAuctions(charName)
        end
    end
end

AM.Events["OWNED_AUCTIONS_UPDATED"] = function(self)
    AM.DB:UpdateAuctions()
end

AM.Events["AUCTION_OWNED_LIST_UPDATE"] = function(self)
    AM.DB:UpdateAuctions()
end

AM.Events["NEW_AUCTION_UPDATE"] = function(self)
    AM.DB:CaptureSellSlotItem()
end

AM.Events["AUCTION_HOUSE_SHOW"] = function(self)
    AM.DB:CaptureSellSlotItem()
    if AuctionsCreateAuctionButton and not AM.DB.hookedCreateAuctionBtn then
        AM.DB.hookedCreateAuctionBtn = true
        AuctionsCreateAuctionButton:HookScript("OnClick", function()
            AM.DB:CaptureSellSlotItem()
            AM.DB:ScheduleOwnedAuctionsRefresh()
        end)
    end
    
    AM.DB:RequestOwnedAuctions()
end

AM.Events["AUCTION_HOUSE_CLOSED"] = function(self)
    AM.DB:UpdateAuctions()
    if AM.UI and AM.UI.RefreshData then
        AM.UI:RefreshData()
    end
end

AM.Events["UI_ERROR_MESSAGE"] = function(self, arg1, arg2)
    local msg = (type(arg1) == "string" and arg1) or (type(arg2) == "string" and arg2)
    local errType = (type(arg1) == "number" and arg1) or nil
    
    if (msg and (msg == ERR_AUCTION_STARTED or string.find(msg, "Auction created") or (ERR_AUCTION_STARTED and string.find(msg, ERR_AUCTION_STARTED))))
       or (errType and LE_GAME_ERR_AUCTION_STARTED and errType == LE_GAME_ERR_AUCTION_STARTED) then
        AM.DB:OnAuctionCreated()
    end
end

AM.Events["CHAT_MSG_SYSTEM"] = function(self, msg)
    if not msg then return end
    if msg == ERR_AUCTION_STARTED or string.find(msg, "Auction created") or (ERR_AUCTION_STARTED and string.find(msg, ERR_AUCTION_STARTED)) then
        AM.DB:OnAuctionCreated()
        return
    end
    
    local isSold = (ERR_AUCTION_SOLD_S and string.find(msg, string.gsub(ERR_AUCTION_SOLD_S, "%%s", ".-")))
        or string.find(msg, "Auction sold")
        or string.find(msg, "auction of .- sold")
    local isExpired = (ERR_AUCTION_EXPIRED_S and string.find(msg, string.gsub(ERR_AUCTION_EXPIRED_S, "%%s", ".-")))
        or string.find(msg, "Auction expired")
    local isRemoved = (ERR_AUCTION_REMOVED_S and string.find(msg, string.gsub(ERR_AUCTION_REMOVED_S, "%%s", ".-")))
        or string.find(msg, "Auction cancelled")
        or string.find(msg, "Auction removed")
        
    if isSold or isExpired or isRemoved then
        local itemName = ExtractAuctionItemName(msg)
        if itemName then
            AM.DB:RemoveAuction(itemName)
        end
    end
end

AM.Events["AUCTION_MULTISELL_UPDATE"] = function(self)
    AM.DB:OnAuctionCreated()
end

AM.Core:RegisterEventSafe("ADDON_LOADED")
AM.Core:RegisterEventSafe("PLAYER_LOGOUT")
AM.Core:RegisterEventSafe("PLAYER_ENTERING_WORLD")
AM.Core:RegisterEventSafe("PLAYER_UPDATE_RESTING")
AM.Core:RegisterEventSafe("UPDATE_EXHAUSTION")
AM.Core:RegisterEventSafe("PLAYER_MONEY")
AM.Core:RegisterEventSafe("BAG_UPDATE")
AM.Core:RegisterEventSafe("BAG_UPDATE_DELAYED")
AM.Core:RegisterEventSafe("BANKFRAME_OPENED")
AM.Core:RegisterEventSafe("BANKFRAME_CLOSED")
AM.Core:RegisterEventSafe("PLAYERBANKSLOTS_CHANGED")
AM.Core:RegisterEventSafe("MAIL_SHOW")
AM.Core:RegisterEventSafe("MAIL_INBOX_UPDATE")
AM.Core:RegisterEventSafe("MAIL_CLOSED")
AM.Core:RegisterEventSafe("UPDATE_PENDING_MAIL")
AM.Core:RegisterEventSafe("SKILL_LINES_CHANGED")
AM.Core:RegisterEventSafe("TRADE_SKILL_SHOW")
AM.Core:RegisterEventSafe("TRADE_SKILL_LIST_UPDATE")
AM.Core:RegisterEventSafe("AUCTION_HOUSE_SHOW")
AM.Core:RegisterEventSafe("AUCTION_HOUSE_CLOSED")
AM.Core:RegisterEventSafe("OWNED_AUCTIONS_UPDATED")
AM.Core:RegisterEventSafe("UI_ERROR_MESSAGE")
AM.Core:RegisterEventSafe("CHAT_MSG_SYSTEM")
AM.Core:RegisterEventSafe("AUCTION_MULTISELL_UPDATE")

