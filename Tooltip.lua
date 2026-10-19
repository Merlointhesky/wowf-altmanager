local addonName, AM = ...

local function AddItemDataToTooltip(tooltip, itemID)
    if not itemID then return end
    
    if not AM.DB then return end
    
    local ruleset = AM.DB:GetRuleset()
    local faction = AM.DB:GetFaction()
    local myName = UnitName("player")
    
    if not AltManagerDB or not AltManagerDB[ruleset] or not AltManagerDB[ruleset][faction] then return end
    
    local addedHeader = false
    
    for charName, charData in pairs(AltManagerDB[ruleset][faction]) do
        if charName ~= myName and not charData.isIgnored then
            local inBags = charData.bags and charData.bags[itemID] or 0
            local inProf = charData.profession and charData.profession[itemID] or 0
            local inQuiv = charData.quiver and charData.quiver[itemID] or 0
            local inBank = charData.bank and charData.bank[itemID] or 0
            local inMail = charData.mail and charData.mail[itemID] or 0
            
            local total = inBags + inProf + inQuiv + inBank + inMail
            if total > 0 then
                if not addedHeader then
                    tooltip:AddLine(" ")
                    tooltip:AddLine("AltManager:", 0.2, 0.8, 0.8)
                    addedHeader = true
                end
                
                local details = {}
                if inBags > 0 then table.insert(details, "Bags: " .. inBags) end
                if inProf > 0 then table.insert(details, "Profession: " .. inProf) end
                if inQuiv > 0 then table.insert(details, "Quiver: " .. inQuiv) end
                if inBank > 0 then table.insert(details, "Bank: " .. inBank) end
                if inMail > 0 then table.insert(details, "Mail: " .. inMail) end
                
                tooltip:AddDoubleLine(charName, string.join(", ", unpack(details)), 0.5, 0.8, 0.2, 1, 1, 1)
            end
        end
    end
end

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if data and data.id then
            AddItemDataToTooltip(tooltip, data.id)
        end
    end)
else
    -- Fallback for environments without TooltipDataProcessor
    local function OnTooltipSetItem(tooltip)
        local _, link = tooltip:GetItem()
        if link then
            local itemID = tonumber(string.match(link, "item:(%d+)"))
            if itemID then
                AddItemDataToTooltip(tooltip, itemID)
            end
        end
    end
    GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
end
