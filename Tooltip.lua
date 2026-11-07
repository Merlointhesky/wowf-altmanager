local addonName, AM = ...

function AM:GetCharacterItemCounts(charData, itemID)
    if not charData or not itemID then return 0, 0, 0, 0, 0, 0 end
    local inBags = (charData.bags and charData.bags[itemID] or 0)
    local inProf = (charData.profession and charData.profession[itemID] or 0) + (charData.bankProfession and charData.bankProfession[itemID] or 0)
    local inQuiv = (charData.quiver and charData.quiver[itemID] or 0) + (charData.bankQuiver and charData.bankQuiver[itemID] or 0)
    local inBank = (charData.bank and charData.bank[itemID] or 0)
    local inMail = (charData.mail and charData.mail[itemID] or 0)
    local inAuc = 0
    if charData.auctions then
        for _, auc in ipairs(charData.auctions) do
            if auc.itemID == itemID and auc.status ~= 1 then
                inAuc = inAuc + (auc.count or 1)
            end
        end
    end
    local total = inBags + inProf + inQuiv + inBank + inMail + inAuc
    return total, inBags, inBank, inProf, inQuiv, inMail, inAuc
end

local function AddItemDataToTooltip(tooltip, itemID)
    if not tooltip or not itemID then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    if tooltip.AM_InjectedItem == itemID then return end
    
    if not AM.DB then return end
    
    local ruleset = AM.DB:GetRuleset()
    local faction = AM.DB:GetFaction()
    
    if not AltManagerDB or not AltManagerDB[ruleset] or not AltManagerDB[ruleset][faction] then return end
    
    local rows = {}
    local grandTotal = 0
    
    for charName, charData in pairs(AltManagerDB[ruleset][faction]) do
        if type(charData) == "table" and not charData.isIgnored then
            local total, inBags, inBank, inProf, inQuiv, inMail, inAuc = AM:GetCharacterItemCounts(charData, itemID)
            if total > 0 then
                grandTotal = grandTotal + total
                local details = {}
                if inBags > 0 then table.insert(details, "Bags: " .. inBags) end
                if inBank > 0 then table.insert(details, "Bank: " .. inBank) end
                if inProf > 0 then table.insert(details, "Prof: " .. inProf) end
                if inQuiv > 0 then table.insert(details, "Quiver: " .. inQuiv) end
                if inMail > 0 then table.insert(details, "Mail: " .. inMail) end
                if inAuc > 0 then table.insert(details, "AH: " .. inAuc) end
                
                table.insert(rows, {
                    name = charName,
                    class = charData.class,
                    total = total,
                    detailStr = table.concat(details, ", ")
                })
            end
        end
    end
    
    if #rows > 0 then
        table.sort(rows, function(a, b)
            if a.total ~= b.total then return a.total > b.total end
            return a.name < b.name
        end)
        
        tooltip:AddLine(" ")
        if #rows > 1 then
            tooltip:AddDoubleLine("AltManager:", "Total: " .. grandTotal, 0.2, 0.8, 0.8, 1, 0.82, 0)
        else
            tooltip:AddLine("AltManager:", 0.2, 0.8, 0.8)
        end
        
        for _, r in ipairs(rows) do
            local cr, cg, cb = 0.5, 0.8, 0.2
            local classColor = r.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[r.class]
            if classColor then
                cr, cg, cb = classColor.r, classColor.g, classColor.b
            end
            tooltip:AddDoubleLine(r.name, r.detailStr, cr, cg, cb, 1, 1, 1)
        end
        
        tooltip.AM_InjectedItem = itemID
    end
end

local function ClearTooltipFlag(tooltip)
    if tooltip then
        tooltip.AM_InjectedItem = nil
    end
end

if GameTooltip then GameTooltip:HookScript("OnTooltipCleared", ClearTooltipFlag) end
if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipCleared", ClearTooltipFlag) end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
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
    if GameTooltip then GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem) end
    if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem) end
end

