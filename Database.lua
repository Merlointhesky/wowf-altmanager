local addonName, AM = ...
AM.DB = {}

-- Initialize DB
function AM.DB:Init()
    if not AltManagerDB then
        AltManagerDB = {}
    end
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

function AM.DB:GetCurrentCharacterDB()
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
            professions = {},
            restXP = 0,
            maxXP = 1,
            isResting = false,
            logoutTime = 0
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

function AM.DB:UpdateBags()
    local charDB = self:GetCurrentCharacterDB()
    charDB.bags = {}
    
    local numBags = NUM_BAG_SLOTS or 4
    local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    
    local bagsToScan = {0}
    for i = 1, numBags do table.insert(bagsToScan, i) end
    if reagentBag then table.insert(bagsToScan, reagentBag) end
    
    charDB.bagCapacity = 0
    for _, bag in ipairs(bagsToScan) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            charDB.bagCapacity = charDB.bagCapacity + numSlots
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink then
                    local itemID = info.itemID
                    if not charDB.bags[itemID] then charDB.bags[itemID] = 0 end
                    charDB.bags[itemID] = charDB.bags[itemID] + info.stackCount
                end
            end
        end
    end
    
    -- Profession Bag (Hardcoded Bag 5)
    charDB.profession = {}
    local profNumSlots = C_Container.GetContainerNumSlots(5)
    charDB.profCapacity = profNumSlots or 0
    if profNumSlots then
        for slot = 1, profNumSlots do
            local info = C_Container.GetContainerItemInfo(5, slot)
            if info and info.hyperlink then
                local itemID = info.itemID
                if not charDB.profession[itemID] then charDB.profession[itemID] = 0 end
                charDB.profession[itemID] = charDB.profession[itemID] + info.stackCount
            end
        end
    end
end

function AM.DB:UpdateBank()
    local charDB = self:GetCurrentCharacterDB()
    charDB.bank = {}
    
    charDB.bankCapacity = 0
    -- Main bank
    local bankID = Enum.BagIndex.Bank or -1
    local bankSlots = C_Container.GetContainerNumSlots(bankID)
    if bankSlots then
        charDB.bankCapacity = charDB.bankCapacity + bankSlots
        for slot = 1, bankSlots do
            local info = C_Container.GetContainerItemInfo(bankID, slot)
            if info and info.hyperlink then
                local itemID = info.itemID
                if not charDB.bank[itemID] then charDB.bank[itemID] = 0 end
                charDB.bank[itemID] = charDB.bank[itemID] + info.stackCount
            end
        end
    end
    
    -- Bank bags (Force skip 5)
    local startBag = 6

    
    local endBag = startBag + (NUM_BANKBAGSLOTS or 7) - 1
    
    for bag = startBag, endBag do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            charDB.bankCapacity = charDB.bankCapacity + numSlots
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink then
                    local itemID = info.itemID
                    if not charDB.bank[itemID] then charDB.bank[itemID] = 0 end
                    charDB.bank[itemID] = charDB.bank[itemID] + info.stackCount
                end
            end
        end
    end
end

function AM.DB:UpdateMail()
    local charDB = self:GetCurrentCharacterDB()
    charDB.mail = {}
    
    local numItems = GetInboxNumItems()
    if not numItems or numItems == 0 then return end
    
    for i = 1, numItems do
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
end

function AM.DB:UpdateProfessions()
    local charDB = self:GetCurrentCharacterDB()
    if not charDB.professions then charDB.professions = {} end
    
    if not GetProfessions then return end
    
    local profs = { GetProfessions() }
    
    for _, profIndex in pairs(profs) do
        if profIndex and type(profIndex) == "number" then
            local name, texture, rank, maxRank = GetProfessionInfo(profIndex)
            if name then
                local found = false
                for _, op in ipairs(charDB.professions) do
                    if op.name == name then
                        found = true
                        if texture and texture ~= "" and (not op.texture or op.texture == "Interface\\Icons\\INV_Misc_QuestionMark") then
                            op.texture = texture
                        end
                        if rank and (not op.rank or rank > op.rank) then
                            op.rank = rank
                        end
                        if maxRank and (not op.maxRank or maxRank > op.maxRank) then
                            op.maxRank = maxRank
                        end
                        break
                    end
                end
                
                if not found then
                    table.insert(charDB.professions, {
                        name = name,
                        texture = texture,
                        rank = rank,
                        maxRank = maxRank,
                        recipes = {}
                    })
                end
            end
        end
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
            AM.DB:UpdateBank()
        end
    else
        AM.DB:UpdateBags()
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

AM.Events["PLAYER_ENTERING_WORLD"] = function(self)
    AM.DB:UpdateCharacterInfo()
    AM.DB:UpdateProfessions()
end

AM.Events["TRADE_SKILL_SHOW"] = function(self)
    AM.DB:UpdateRecipes()
end

AM.Events["TRADE_SKILL_LIST_UPDATE"] = function(self)
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
    
    if not profName or profName == "Unknown" then return end
    
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

AM.Core:RegisterEvent("ADDON_LOADED")
AM.Core:RegisterEvent("PLAYER_LOGOUT")
AM.Core:RegisterEvent("PLAYER_ENTERING_WORLD")
AM.Core:RegisterEvent("PLAYER_UPDATE_RESTING")
AM.Core:RegisterEvent("UPDATE_EXHAUSTION")
AM.Core:RegisterEvent("PLAYER_MONEY")
AM.Core:RegisterEvent("BAG_UPDATE")
AM.Core:RegisterEvent("BANKFRAME_OPENED")
AM.Core:RegisterEvent("BANKFRAME_CLOSED")
AM.Core:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
AM.Core:RegisterEvent("MAIL_SHOW")
AM.Core:RegisterEvent("MAIL_INBOX_UPDATE")
AM.Core:RegisterEvent("SKILL_LINES_CHANGED")
AM.Core:RegisterEvent("TRADE_SKILL_SHOW")
AM.Core:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
