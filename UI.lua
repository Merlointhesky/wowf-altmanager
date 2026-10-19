local addonName, AM = ...

AM.UI = {}

local function FormatGold(money)
    money = tonumber(money) or 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(money)
    elseif GetCoinTextureString then
        return GetCoinTextureString(money)
    end
    
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    
    local str = ""
    if gold > 0 then
        str = str .. gold .. " |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t "
    end
    if silver > 0 then
        str = str .. silver .. " |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t "
    end
    if copper > 0 or money == 0 then
        str = str .. copper .. " |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
    end
    
    return str
end

-- 1. Minimap Button
local minimapButton = CreateFrame("Button", "AltManagerMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0) -- default position
local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 6, -5)

local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT", 0, 0)

minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

minimapButton:SetScript("OnClick", function()
    AM.UI:ToggleMainFrame()
end)
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Alt Manager")
    GameTooltip:AddLine("Click to toggle the interface.", 1, 1, 1)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

minimapButton:SetMovable(true)
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(self)
        local xpos, ypos = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        local dx, dy = (xpos / scale) - cx, (ypos / scale) - cy
        
        local angle = math.atan2(dy, dx)
        local radius = (Minimap:GetWidth() / 2) + (self:GetWidth() / 3)
        
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end)
end)
minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    if type(AltManagerDB) == "table" then
        local xpos, ypos = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        local dx, dy = (xpos / scale) - cx, (ypos / scale) - cy
        AltManagerDB.minimapAngle = math.atan2(dy, dx)
    end
end)

function AM.UI:LoadMinimapPosition()
    if type(AltManagerDB) == "table" and AltManagerDB.minimapAngle then
        local angle = AltManagerDB.minimapAngle
        local radius = (Minimap:GetWidth() / 2) + (minimapButton:GetWidth() / 3)
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end
end

-- 2. Main Interface Frame
AM.UI.MainFrame = CreateFrame("Frame", "AltManagerMainFrame", UIParent, "BasicFrameTemplateWithInset")
local frame = AM.UI.MainFrame
frame:SetSize(750, 450)
frame:SetPoint("CENTER")
frame:Hide()
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
-- Hide Item Viewer when Main Frame is hidden
frame:SetScript("OnHide", function()
    if AM.UI.ItemViewer then
        AM.UI.ItemViewer:Hide()
    end
end)

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
frame.title:SetText("Alt Manager")

-- Register for Escape Key closure
tinsert(UISpecialFrames, "AltManagerMainFrame")

-- Total Gold Footer
frame.totalGoldText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.totalGoldText:SetPoint("BOTTOMLEFT", 15, 12)
frame.totalGoldText:SetText("Account Wealth:")

frame.totalGoldValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.totalGoldValue:SetPoint("LEFT", frame.totalGoldText, "RIGHT", 5, 0)
frame.totalGoldValue:SetText("0")

-- Show Ignored Checkbox
frame.showIgnoredCheck = CreateFrame("CheckButton", "AltManagerShowIgnoredCheck", frame, "UICheckButtonTemplate")
frame.showIgnoredCheck:SetSize(20, 20)
frame.showIgnoredCheck:SetPoint("BOTTOMRIGHT", -120, 8)
frame.showIgnoredCheck.text = frame.showIgnoredCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.showIgnoredCheck.text:SetPoint("LEFT", frame.showIgnoredCheck, "RIGHT", 2, 0)
frame.showIgnoredCheck.text:SetText("Show Ignored")
frame.showIgnoredCheck:SetChecked(false)
frame.showIgnoredCheck:SetScript("OnClick", function(self)
    AM.UI.showIgnored = self:GetChecked()
    AM.UI:RefreshData()
end)

-- Container for character rows
frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
frame.scrollFrame:SetPoint("TOPLEFT", 10, -30)
frame.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 30)
frame.scrollChild = CreateFrame("Frame")
frame.scrollChild:SetSize(710, 1)
frame.scrollFrame:SetScrollChild(frame.scrollChild)

-- 3. Item Viewer Sub-Frame
AM.UI.ItemViewer = CreateFrame("Frame", "AltManagerItemViewer", frame, "BasicFrameTemplateWithInset")
local viewer = AM.UI.ItemViewer
viewer:SetSize(400, 450)
viewer:SetPoint("TOPLEFT", frame, "TOPRIGHT", 5, 0)
viewer:Hide()

viewer.title = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
viewer.title:SetPoint("CENTER", viewer.TitleBg, "CENTER", 0, 0)

viewer.scrollFrame = CreateFrame("ScrollFrame", nil, viewer, "UIPanelScrollFrameTemplate")
viewer.scrollFrame:SetPoint("TOPLEFT", 10, -30)
viewer.scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
viewer.scrollChild = CreateFrame("Frame")
viewer.scrollChild:SetSize(340, 1)
viewer.scrollFrame:SetScrollChild(viewer.scrollChild)

viewer.sortBtn = CreateFrame("Button", nil, viewer, "UIPanelButtonTemplate")
viewer.sortBtn:SetSize(90, 22)
viewer.sortBtn:SetPoint("TOPRIGHT", viewer, "TOPRIGHT", -30, -4)
viewer.sortBtn:SetText("Sort: Rarity")
viewer.sortMode = "RARITY"
viewer.sortBtn:Hide()

viewer.sortBtn:SetScript("OnClick", function()
    if viewer.sortMode == "RARITY" then
        viewer.sortMode = "NAME"
        viewer.sortBtn:SetText("Sort: A-Z")
    elseif viewer.sortMode == "NAME" then
        viewer.sortMode = "LEVEL"
        viewer.sortBtn:SetText("Sort: Level")
    else
        viewer.sortMode = "RARITY"
        viewer.sortBtn:SetText("Sort: Rarity")
    end
    if viewer.activeChar and viewer.activeProf then
        AM.UI:ShowRecipes(viewer.activeChar, viewer.activeProf)
    end
end)

local itemButtons = {}

function AM.UI:ClearViewer()
    for _, btn in ipairs(itemButtons) do
        btn:Hide()
        btn:SetScript("OnClick", nil)
    end
    if AM.UI.recipeRows then
        for _, row in ipairs(AM.UI.recipeRows) do
            row:Hide()
        end
    end
    if AM.UI.auctionRows then
        for _, row in ipairs(AM.UI.auctionRows) do
            row:Hide()
        end
    end
end

function AM.UI:ShowItems(charName, storageType)
    viewer:Show()
    if viewer.sortBtn then viewer.sortBtn:Hide() end
    viewer.title:SetText(charName .. "'s " .. storageType)
    
    local ruleset = AM.DB:GetRuleset()
    local faction = AM.DB:GetFaction()
    local charData = AltManagerDB[ruleset][faction][charName]
    
    local items = {}
    if storageType == "Bags" then
        items = charData.bags or {}
    elseif storageType == "Bank" then
        items = charData.bank or {}
    elseif storageType == "Mail" then
        items = charData.mail or {}
    end
    
    AM.UI:ClearViewer()
    
    local index = 1
    local col = 0
    local row = 0
    local maxCols = 5
    local iconSize = 37
    local padding = 4
    
    -- Helper for getting icon robustly
    local function GetIcon(itemID)
        if C_Item and C_Item.GetItemIconByID then
            return C_Item.GetItemIconByID(itemID)
        end
        return GetItemIcon(itemID)
    end
    
    for itemID, count in pairs(items) do
        local btn = itemButtons[index]
        if not btn then
            btn = CreateFrame("Button", nil, viewer.scrollChild)
            btn:SetSize(iconSize, iconSize)
            
            btn.icon = btn:CreateTexture(nil, "BORDER")
            btn.icon:SetAllPoints()
            
            btn.countText = btn:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
            btn.countText:SetPoint("BOTTOMRIGHT", -2, 2)
            
            btn.border = btn:CreateTexture(nil, "OVERLAY")
            btn.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            btn.border:SetSize(iconSize * 1.6, iconSize * 1.6)
            btn.border:SetPoint("CENTER", 0, 0)
            
            btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
            btn:SetHighlightTexture("Interface\\Buttons\\Button-Hilight-Square", "ADD")
            
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            
            table.insert(itemButtons, btn)
        end
        
        btn.itemID = itemID
        btn.icon:SetTexture(GetIcon(itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
        
        -- Color border based on quality if available
        local quality = nil
        if C_Item and C_Item.GetItemInfo then
            local _, _, q = C_Item.GetItemInfo(itemID)
            quality = q
        end
        
        if quality and quality > 1 then
            local r, g, b = 1, 1, 1
            if C_Item and C_Item.GetItemQualityColor then
                r, g, b = C_Item.GetItemQualityColor(quality)
            end
            btn.border:SetVertexColor(r, g, b)
        else
            btn.border:SetVertexColor(1, 1, 1) -- default white/grey
        end
        
        if count > 1 then
            btn.countText:SetText(count)
        else
            btn.countText:SetText("")
        end
        
        local x = col * (iconSize + padding) + padding
        local y = -(row * (iconSize + padding)) - padding
        btn:SetPoint("TOPLEFT", x, y)
        
        col = col + 1
        if col >= maxCols then
            col = 0
            row = row + 1
        end
        
        btn:Show()
        index = index + 1
    end
    
    local totalRows = math.ceil((index - 1) / maxCols)
    viewer.scrollChild:SetHeight(totalRows * (iconSize + padding) + padding)
end

-- ShowProfessions has been removed as they are now listed in the row directly.

function AM.UI:ShowRecipes(charName, profName)
    local viewer = AM.UI.ItemViewer
    viewer:Show()
    viewer.activeChar = charName
    viewer.activeProf = profName
    if viewer.sortBtn then viewer.sortBtn:Show() end
    viewer.title:SetText(profName .. " Recipes")
    
    local ruleset = AM.DB:GetRuleset()
    local faction = AM.DB:GetFaction()
    local charData = AltManagerDB[ruleset][faction][charName]
    
    local recipes = {}
    if charData.professions then
        for _, p in ipairs(charData.professions) do
            if p.name == profName then
                recipes = p.recipes or {}
                break
            end
        end
    end
    
    local function getQualityFromLink(link)
        if not link then return 1 end
        
        local itemID = string.match(link, "item:(%d+)")
        
        if C_Item and C_Item.GetItemInfo then
            local _, _, q = C_Item.GetItemInfo(link)
            if q then return q end
            if itemID then C_Item.GetItemInfo(itemID) end -- Force cache
        end
        
        local color = string.match(link, "|c(%x+)")
        if not color then return 1 end
        color = string.lower(color)
        
        if string.find(color, "a335ee") then return 4 -- Epic
        elseif string.find(color, "0070dd") then return 3 -- Rare
        elseif string.find(color, "1eff00") then return 2 -- Uncommon
        elseif string.find(color, "ffffff") then return 1 -- Common
        elseif string.find(color, "9d9d9d") then return 0 -- Poor
        elseif string.find(color, "ff8000") then return 5 -- Legendary
        else return 1 end
    end
    
    local function cleanName(n)
        if not n then return "" end
        local s = string.gsub(n, "|c%x%x%x%x%x%x%x%x(.-)|r", "%1")
        s = string.gsub(s, "^%[%s*(.-)%s*%]$", "%1")
        s = string.gsub(s, "^%s*(.-)%s*$", "%1")
        return string.lower(s)
    end
    
    if recipes and #recipes > 0 then
        table.sort(recipes, function(a, b)
            if viewer.sortMode == "RARITY" then
                local qA = getQualityFromLink(a.link)
                local qB = getQualityFromLink(b.link)
                if qA == qB then
                    return cleanName(a.name) < cleanName(b.name)
                end
                return qA > qB
            elseif viewer.sortMode == "LEVEL" then
                local dA = a.difficulty or 1
                local dB = b.difficulty or 1
                if dA == dB then
                    return cleanName(a.name) < cleanName(b.name)
                end
                return dA < dB
            else
                -- Sort by Name
                return cleanName(a.name) < cleanName(b.name)
            end
        end)
    end
    
    AM.UI:ClearViewer()
    if not AM.UI.recipeRows then AM.UI.recipeRows = {} end
    local recipeRows = AM.UI.recipeRows
    
    local rowHeight = 24
    local index = 1
    
    for _, recipe in ipairs(recipes) do
        local row = recipeRows[index]
        if not row then
            row = CreateFrame("Button", nil, viewer.scrollChild)
            row:SetSize(viewer:GetWidth() - 20, rowHeight)
            row:RegisterForClicks("AnyUp")
            
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(18, 18)
            row.icon:SetPoint("LEFT", 5, 0)
            
            row.checkIcon = row:CreateTexture(nil, "ARTWORK")
            row.checkIcon:SetSize(20, 20)
            row.checkIcon:SetPoint("RIGHT", -30, 0)
            row.checkIcon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            row.checkIcon:Hide()
            
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
            row.nameText:SetPoint("RIGHT", row.checkIcon, "LEFT", -5, 0)
            row.nameText:SetJustifyH("LEFT")
            
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            table.insert(recipeRows, row)
        end
        
        row.recipeName = recipe.name
        row.link = recipe.link
        row.reagents = recipe.reagents
        
        row.icon:SetTexture(recipe.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        if recipe.link then
            row.nameText:SetText(recipe.link)
        else
            row.nameText:SetText(recipe.name)
        end
        
        -- Check if craftable
        local canCraft = false
        if recipe.reagents and #recipe.reagents > 0 then
            canCraft = true
            local ruleset = AM.DB:GetRuleset()
            local faction = AM.DB:GetFaction()
            for _, r in ipairs(recipe.reagents) do
                local totalOwned = 0
                if AltManagerDB[ruleset] and AltManagerDB[ruleset][faction] then
                    for cName, cData in pairs(AltManagerDB[ruleset][faction]) do
                        local bagCount = cData.bags and r.itemID and cData.bags[r.itemID] or 0
                        local bankCount = cData.bank and r.itemID and cData.bank[r.itemID] or 0
                        totalOwned = totalOwned + bagCount + bankCount
                    end
                end
                local reqCount = r.count or 1
                if totalOwned < reqCount then
                    canCraft = false
                    break
                end
            end
        end
        
        if row.checkIcon then
            if canCraft then
                row.checkIcon:Show()
            else
                row.checkIcon:Hide()
            end
        end
        
        row:SetPoint("TOPLEFT", 0, -(index - 1) * rowHeight)
        row:Show()
        
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.link then
                GameTooltip:SetHyperlink(self.link)
            else
                GameTooltip:AddLine(self.recipeName, 1, 1, 1)
            end
            
            if self.reagents and #self.reagents > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Required Materials:")
                for _, r in ipairs(self.reagents) do
                    local totalOwned = 0
                    local locations = {}
                    if AltManagerDB[ruleset] and AltManagerDB[ruleset][faction] then
                        for cName, cData in pairs(AltManagerDB[ruleset][faction]) do
                            local bagCount = 0
                            local bankCount = 0
                            if cData.bags and r.itemID and cData.bags[r.itemID] then
                                bagCount = cData.bags[r.itemID]
                            end
                            if cData.bank and r.itemID and cData.bank[r.itemID] then
                                bankCount = cData.bank[r.itemID]
                            end
                            local charTotal = bagCount + bankCount
                            if charTotal > 0 then
                                totalOwned = totalOwned + charTotal
                                local locStr = {}
                                if bagCount > 0 then table.insert(locStr, "Bags: " .. bagCount) end
                                if bankCount > 0 then table.insert(locStr, "Bank: " .. bankCount) end
                                table.insert(locations, string.format("  > %s: %s", cName, table.concat(locStr, ", ")))
                            end
                        end
                    end
                    local reqCount = r.count or 1
                    local rName = r.name or "Unknown"
                    if string.match(rName, "^Item %d+$") and r.itemID then
                        local cachedName = nil
                        if C_Item and C_Item.GetItemInfo then cachedName = C_Item.GetItemInfo(r.itemID) end
                        
                        if cachedName then
                            r.name = cachedName; rName = cachedName
                        else
                            if Item and Item.CreateFromItemID then
                                local itemObj = Item:CreateFromItemID(r.itemID)
                                itemObj:ContinueOnItemLoad(function()
                                    if itemObj:GetItemName() then
                                        r.name = itemObj:GetItemName()
                                        if GameTooltip:GetOwner() == self then
                                            self:GetScript("OnEnter")(self)
                                        end
                                    end
                                end)
                            elseif C_Item and C_Item.RequestLoadItemDataByID then
                                C_Item.RequestLoadItemDataByID(r.itemID)
                            end
                        end
                    end
                    local color = (totalOwned >= reqCount) and "|cFF00FF00" or "|cFFFF0000"
                    GameTooltip:AddLine(string.format("- %s x%d (Owned: %s%d|r)", rName, reqCount, color, totalOwned))
                    for _, loc in ipairs(locations) do
                        GameTooltip:AddLine(loc, 0.7, 0.7, 0.7)
                    end
                end
            end
            GameTooltip:Show()
        end)
        
        row:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        

        
        index = index + 1
    end
    
    viewer.scrollChild:SetHeight((index - 1) * rowHeight)
end

function AM.UI:ShowAuctions(charName)
    local viewer = AM.UI.ItemViewer
    viewer:Show()
    viewer.currentChar = charName
    if viewer.sortBtn then viewer.sortBtn:Hide() end
    viewer.title:SetText(charName .. "'s Auctions")
    
    local myName = AM.DB:GetFullPlayerName()
    if (charName == myName or charName == UnitName("player")) then
        if (AuctionFrame and AuctionFrame:IsShown()) or (GetNumAuctionItems and GetNumAuctionItems("owner") > 0) then
            AM.DB:UpdateAuctions()
        end
    end
    
    local ruleset = AM.DB:GetRuleset()
    local faction = AM.DB:GetFaction()
    local charData = AltManagerDB[ruleset][faction][charName]
    local auctions = charData.auctions or {}
    
    AM.UI:ClearViewer()
    if not AM.UI.auctionRows then AM.UI.auctionRows = {} end
    local auctionRows = AM.UI.auctionRows
    
    local rowHeight = 30
    local index = 1
    
    table.sort(auctions, function(a, b)
        local timeA = a.expires or 0
        local timeB = b.expires or 0
        return timeA < timeB
    end)
    
    local function FormatTimeLeft(expires, status)
        if status == 1 then
            return "|cFF00FF00Sold|r"
        end
        local diff = (expires or 0) - time()
        if diff <= 60 then return "|cFF00FF00Expired / Sold|r" end
        if diff < 3600 then return "Expires in: " .. string.format("%dm", math.floor(diff/60)) end
        if diff < 86400 then return "Expires in: " .. string.format("%dh %dm", math.floor(diff/3600), math.floor((diff%3600)/60)) end
        return "Expires in: " .. string.format("%dd %dh", math.floor(diff/86400), math.floor((diff%86400)/3600))
    end
    
    for _, auc in ipairs(auctions) do
        local row = auctionRows[index]
        if not row then
            row = CreateFrame("Button", nil, viewer.scrollChild)
            row:SetSize(viewer:GetWidth() - 20, rowHeight)
            row:RegisterForClicks("AnyUp")
            
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(24, 24)
            row.icon:SetPoint("LEFT", 5, 0)
            
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 5, 5)
            row.nameText:SetPoint("RIGHT", -150, 5)
            row.nameText:SetJustifyH("LEFT")
            
            row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.timeText:SetPoint("LEFT", row.icon, "RIGHT", 5, -8)
            row.timeText:SetPoint("RIGHT", -150, -8)
            row.timeText:SetJustifyH("LEFT")
            
            row.priceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.priceText:SetPoint("RIGHT", -5, 5)
            row.priceText:SetJustifyH("RIGHT")
            
            row.cutText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.cutText:SetPoint("RIGHT", -5, -8)
            row.cutText:SetJustifyH("RIGHT")
            row.cutText:SetTextColor(0.5, 1, 0.5)
            
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            table.insert(auctionRows, row)
        end
        
        local itemID = auc.itemID
        local link = auc.link
        local itemName = auc.name
        local tex = auc.icon
        
        if not itemID and link then
            if type(link) == "number" then
                itemID = link
            elseif type(link) == "string" then
                local foundID = string.match(link, "item:(%d+)")
                if foundID then itemID = tonumber(foundID) end
            end
        end
        
        -- If itemName is missing or Unknown, check link for item name
        if (not itemName or itemName == "" or itemName == "Unknown Item") and link and link ~= "Unknown Item" then
            if string.find(tostring(link), "|h%[(.-)%]|h") then
                itemName = string.match(tostring(link), "|h%[(.-)%]|h")
            elseif not string.find(tostring(link), "item:") then
                itemName = link
            end
        end
        
        -- If itemID is known, query item details
        if itemID then
            if C_Item and C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(itemID)
            end
            if not tex or tex == "Interface\\Icons\\INV_Misc_QuestionMark" then
                if C_Item and C_Item.GetItemInfoInstant then
                    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
                    if icon then tex = icon end
                elseif GetItemIcon then
                    local icon = GetItemIcon(itemID)
                    if icon then tex = icon end
                end
            end
            if not itemName or itemName == "" or itemName == "Unknown Item" then
                if C_Item and C_Item.GetItemInfo then
                    local n = C_Item.GetItemInfo(itemID)
                    if n then itemName = n end
                elseif GetItemInfo then
                    local n = GetItemInfo(itemID)
                    if n then itemName = n end
                end
            end
        end
        
        local query = link or itemID or itemName
        if query and (not itemName or itemName == "" or itemName == "Unknown Item" or not tex or tex == "Interface\\Icons\\INV_Misc_QuestionMark") then
            local n, l, q, _, _, _, _, _, _, t = nil
            if C_Item and C_Item.GetItemInfo then
                n, l, q, _, _, _, _, _, _, t = C_Item.GetItemInfo(query)
            elseif GetItemInfo then
                n, l, q, _, _, _, _, _, _, t = GetItemInfo(query)
            end
            if n and (not itemName or itemName == "Unknown Item" or itemName == "") then itemName = n end
            if l and (not link or link == "Unknown Item") then link = l end
            if t and (not tex or tex == "Interface\\Icons\\INV_Misc_QuestionMark") then tex = t end
            if l and not itemID then
                local foundID = string.match(l, "item:(%d+)")
                if foundID then itemID = tonumber(foundID) end
            end
        end
        
        -- Healing in-memory object so database recovers
        if itemName and itemName ~= "Unknown Item" and itemName ~= "" then
            auc.name = itemName
        end
        if itemID and not auc.itemID then
            auc.itemID = itemID
        end
        if link and link ~= "Unknown Item" and (not auc.link or auc.link == "Unknown Item") then
            auc.link = link
        end
        if tex and tex ~= "Interface\\Icons\\INV_Misc_QuestionMark" and not auc.icon then
            auc.icon = tex
        end
        
        if not tex then
            tex = "Interface\\Icons\\INV_Misc_QuestionMark"
        end
        
        if not itemName or itemName == "" then
            if link and string.find(tostring(link), "|h") then
                itemName = link
            elseif link and link ~= "Unknown Item" and not string.find(tostring(link), "item:") then
                itemName = link
            elseif itemID then
                itemName = "Item #" .. itemID
            else
                itemName = "Unknown Item"
            end
        elseif link and string.find(tostring(link), "|h") then
            itemName = link
        end
        
        row.link = link
        row.itemID = itemID
        
        row.icon:SetTexture(tex)
        row.nameText:SetText(itemName .. (auc.count and auc.count > 1 and (" x" .. auc.count) or ""))
        
        row.timeText:SetText(FormatTimeLeft(auc.expires, auc.status))
        row.priceText:SetText(FormatGold(auc.buyout or 0))
        row.cutText:SetText("Net: " .. FormatGold(math.floor((auc.buyout or 0) * 0.95)))
        
        row:SetPoint("TOPLEFT", 0, -(index - 1) * rowHeight)
        row:Show()
        
        row:SetScript("OnEnter", function(self)
            if self.link and string.find(tostring(self.link), "|h") then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.link)
                GameTooltip:Show()
            elseif self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self.itemID)
                GameTooltip:Show()
            end
        end)
        
        row:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        index = index + 1
    end
    
    viewer.scrollChild:SetHeight((index - 1) * rowHeight)
end

function AM.UI:ToggleMainFrame()
    if AM.UI.MainFrame:IsShown() then
        AM.UI.MainFrame:Hide()
    else
        AM.UI:RefreshData()
        AM.UI.MainFrame:Show()
    end
end

local rows = {}

local function CreateCharacterRow(index)
    local row = CreateFrame("Frame", nil, AM.UI.MainFrame.scrollChild)
    row:SetSize(710, 40)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 40)
    
    -- Background for alternating colors
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    row.bg = bg
    if index % 2 == 0 then
        bg:SetColorTexture(1, 1, 1, 0.05)
    else
        bg:SetColorTexture(0, 0, 0, 0)
    end
    
    -- Class Icon
    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(18, 18)
    row.classIcon:SetPoint("LEFT", 10, 0)
    row.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    
    -- Name & Level Text
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row.classIcon, "RIGHT", 5, 0)
    row.nameText:SetWidth(130)
    row.nameText:SetJustifyH("LEFT")
    
    -- Rest XP Text
    row.restXPText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.restXPText:SetPoint("BOTTOMLEFT", row.nameText, "BOTTOMRIGHT", -130, -12)
    row.restXPText:SetWidth(130)
    row.restXPText:SetJustifyH("LEFT")
    row.restXPText:SetTextColor(0.5, 0.5, 1) -- Light blue for Rest XP
    
    -- Inventory (Bank/Bags) Button
    row.bankBtn = CreateFrame("Button", nil, row)
    row.bankBtn:SetSize(24, 24)
    row.bankBtn:SetPoint("LEFT", 170, 0)
    row.bankBtn:SetNormalTexture("Interface\\Icons\\INV_Box_01")
    row.bankBtn:SetHighlightTexture("Interface\\Buttons\\Button-Hilight-Square", "ADD")
    row.bankBtn:SetScript("OnClick", function()
        if not AM.UI.AltInventoryWindow then
            AM.UI.AltInventoryWindow = AM:CreateInventoryWindow("AltManagerAltInventory", "Inventory", "combined", nil, true)
        end
        AM.UI.AltInventoryWindow.selectedCharacter = row.charName
        AM.UI.AltInventoryWindow.title:SetText("Alt Manager - Inventory (" .. row.charName .. ")")
        AM.UI.AltInventoryWindow:Update()
        AM.UI.AltInventoryWindow:Show()
    end)
    row.bankBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("View Combined Inventory (Bags & Bank)")
        GameTooltip:Show()
    end)
    row.bankBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    
    -- Mail Button
    row.mailBtn = CreateFrame("Button", nil, row)
    row.mailBtn:SetSize(24, 24)
    row.mailBtn:SetPoint("LEFT", 200, 0)
    row.mailBtn:SetNormalTexture("Interface\\Minimap\\Tracking\\Mailbox")
    row.mailBtn:SetHighlightTexture("Interface\\Buttons\\Button-Hilight-Square", "ADD")
    row.mailBtn:SetScript("OnClick", function() AM.UI:ShowItems(row.charName, "Mail") end)
    row.mailBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ruleset = AM.DB:GetRuleset()
        local faction = AM.DB:GetFaction()
        local charData = AltManagerDB and AltManagerDB[ruleset] and AltManagerDB[ruleset][faction] and AltManagerDB[ruleset][faction][row.charName]
        if charData and charData.hasNewMail then
            GameTooltip:AddLine("Mailbox (Unread Mail)", 1, 0.82, 0)
        else
            GameTooltip:AddLine("Mailbox", 1, 1, 1)
        end
        GameTooltip:AddLine("Click to view stored mail items", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    row.mailBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    
    -- Glow for new/cached mail
    row.mailGlow = row.mailBtn:CreateTexture(nil, "OVERLAY")
    row.mailGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    row.mailGlow:SetBlendMode("ADD")
    row.mailGlow:SetSize(36, 36)
    row.mailGlow:SetPoint("CENTER", 0, 0)
    row.mailGlow:SetVertexColor(1, 1, 0, 0.8) -- Yellow glow
    row.mailGlow:Hide()
    
    -- Auctions Button
    row.aucBtn = CreateFrame("Button", nil, row)
    row.aucBtn:SetSize(24, 24)
    row.aucBtn:SetPoint("LEFT", 230, 0)
    row.aucBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_Coin_02")
    row.aucBtn:SetHighlightTexture("Interface\\Buttons\\Button-Hilight-Square", "ADD")
    row.aucBtn:SetScript("OnClick", function() AM.UI:ShowAuctions(row.charName) end)
    row.aucBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ruleset = AM.DB:GetRuleset()
        local faction = AM.DB:GetFaction()
        local charData = AltManagerDB and AltManagerDB[ruleset] and AltManagerDB[ruleset][faction] and AltManagerDB[ruleset][faction][row.charName]
        local count = (charData and charData.auctions) and #charData.auctions or 0
        GameTooltip:AddLine("View Auctions (" .. count .. " active)")
        GameTooltip:Show()
    end)
    row.aucBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    
    -- Profession Container (Dynamic)
    row.profContainer = CreateFrame("Frame", nil, row)
    row.profContainer:SetSize(300, 30)
    row.profContainer:SetPoint("LEFT", 270, 0)
    
    -- Gold Text
    row.goldText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.goldText:SetPoint("RIGHT", -10, 0)
    row.goldText:SetWidth(150)
    row.goldText:SetJustifyH("RIGHT")

    -- Ignore Button (hide alt)
    row.ignoreBtn = CreateFrame("Button", nil, row)
    row.ignoreBtn:SetSize(24, 24)
    row.ignoreBtn:SetPoint("RIGHT", row.goldText, "LEFT", -5, 0)
    row.ignoreBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    row.ignoreBtn:SetHighlightTexture("Interface\\Buttons\\Button-Hilight-Square", "ADD")
    row.ignoreBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ruleset = AM.DB:GetRuleset()
        local faction = AM.DB:GetFaction()
        local charData = AltManagerDB and AltManagerDB[ruleset] and AltManagerDB[ruleset][faction] and AltManagerDB[ruleset][faction][row.charName]
        if charData and charData.isIgnored then
            GameTooltip:AddLine("Unignore Character (show again)")
        else
            GameTooltip:AddLine("Ignore Character (hide from list)")
        end
        GameTooltip:Show()
    end)
    row.ignoreBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    row.ignoreBtn:SetScript("OnClick", function(self)
        local ruleset = AM.DB:GetRuleset()
        local faction = AM.DB:GetFaction()
        if AltManagerDB and AltManagerDB[ruleset] and AltManagerDB[ruleset][faction] and AltManagerDB[ruleset][faction][row.charName] then
            local char = AltManagerDB[ruleset][faction][row.charName]
            char.isIgnored = not char.isIgnored
        end
        AM.UI:RefreshData()
    end)

    -- Delete Button (remove from DB)
    row.deleteBtn = CreateFrame("Button", nil, row)
    row.deleteBtn:SetSize(24, 24)
    row.deleteBtn:SetPoint("RIGHT", row.ignoreBtn, "LEFT", -5, 0)
    row.deleteBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_Horn_01")
    row.deleteBtn:SetHighlightTexture("Interface\\Buttons\\Button-Hilight-Square", "ADD")
    row.deleteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Delete Character (remove all data)")
        GameTooltip:Show()
    end)
    row.deleteBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    row.deleteBtn:SetScript("OnClick", function(self)
        local targetName = row.charName
        if not targetName or targetName == "" then return end
        local dialog = StaticPopup_Show("AM_DELETE_CHARACTER", targetName, nil, targetName)
        if dialog then
            dialog.data = targetName
        end
    end)
    
    return row
end

-- Confirmation dialogs for ignore and delete actions
StaticPopupDialogs["AM_IGNORE_CHARACTER"] = {
    text = "Ignore %s? This will hide the character from the list and account wealth.",
    button1 = "Ignore",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local targetName = data or (self and self.data)
        if not targetName then return end
        if targetName == AM.DB:GetFullPlayerName() then
            UIErrorsFrame:AddMessage("You cannot ignore your own character.", 1.0, 0.0, 0.0)
            return
        end
        local ruleset = AM.DB:GetRuleset()
        local faction = AM.DB:GetFaction()
        if AltManagerDB and AltManagerDB[ruleset] and AltManagerDB[ruleset][faction] and AltManagerDB[ruleset][faction][targetName] then
            AltManagerDB[ruleset][faction][targetName].isIgnored = true
        end
        AM.UI:RefreshData()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["AM_DELETE_CHARACTER"] = {
    text = "Delete %s? This will permanently remove all saved data for this character.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local targetName = data or (self and self.data)
        if not targetName then return end
        local myName = AM.DB:GetFullPlayerName()
        if targetName == myName then
            UIErrorsFrame:AddMessage("You cannot delete the character you are currently playing.", 1, 0, 0)
            return
        end
        local ruleset = AM.DB:GetRuleset()
        local faction = AM.DB:GetFaction()
        if AltManagerDB and AltManagerDB[ruleset] and AltManagerDB[ruleset][faction] then
            AltManagerDB[ruleset][faction][targetName] = nil
        end
        if AM.DB.data and AM.DB.data[ruleset] and AM.DB.data[ruleset][faction] then
            AM.DB.data[ruleset][faction][targetName] = nil
        end
        if AM.UI.AltInventoryWindow and AM.UI.AltInventoryWindow.selectedCharacter == targetName then
            AM.UI.AltInventoryWindow:Hide()
        end
        if AM.UI.ItemViewer and AM.UI.ItemViewer:IsShown() then
            AM.UI.ItemViewer:Hide()
        end
        AM.UI:RefreshData()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function AM.UI:RefreshData()
    local ruleset = AM.DB:GetRuleset()
    local faction = AM.DB:GetFaction()
    
    if not AltManagerDB or not AltManagerDB[ruleset] or not AltManagerDB[ruleset][faction] then return end
    
    local chars = AltManagerDB[ruleset][faction]
    local myName = AM.DB:GetFullPlayerName()
    
    -- Hide all existing rows initially
    for _, row in ipairs(rows) do
        row:Hide()
    end
    
    local charNames = {}
    for charName in pairs(chars) do
        table.insert(charNames, charName)
    end
    
    -- Sort by Level (Highest First)
    table.sort(charNames, function(a, b)
        local lvlA = chars[a].level or 0
        local lvlB = chars[b].level or 0
        if lvlA == lvlB then return a < b end
        return lvlA > lvlB
    end)
    
    local index = 1
    local totalGold = 0
    
    for _, charName in ipairs(charNames) do
        local charData = chars[charName]
        local isCurrentPlayer = (charName == myName)
        local isIgnored = charData.isIgnored and not isCurrentPlayer
        
        if not isIgnored or AM.UI.showIgnored then
            local row = rows[index]
            if not row then
                row = CreateCharacterRow(index)
                table.insert(rows, row)
            end
            
            row.charName = charName
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 40)
            
            if row.bg then
                if index % 2 == 0 then
                    row.bg:SetColorTexture(1, 1, 1, 0.05)
                else
                    row.bg:SetColorTexture(0, 0, 0, 0)
                end
            end
            
            if isIgnored then
                row:SetAlpha(0.5)
            else
                row:SetAlpha(1.0)
            end
            
            -- Hide ignore and delete buttons for current character
            if isCurrentPlayer then
                row.deleteBtn:Hide()
                row.ignoreBtn:Hide()
            else
                row.deleteBtn:Show()
                row.ignoreBtn:Show()
            end
            
            -- Apply Class Color & Icon
            local classColor = charData.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[charData.class]
            local ignoredSuffix = isIgnored and " |cffff5555[Ignored]|r" or ""
            if classColor then
                row.nameText:SetText(string.format("|cff%02x%02x%02x%s|r (Lvl %d)%s", classColor.r*255, classColor.g*255, classColor.b*255, charName, charData.level or 0, ignoredSuffix))
            else
                row.nameText:SetText(string.format("%s (Lvl %d)%s", charName, charData.level or 0, ignoredSuffix))
            end
            
            if charData.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[charData.class] then
                row.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[charData.class]))
                row.classIcon:Show()
            else
                row.classIcon:Hide()
            end
            
            -- Add Rest XP rendering
            local restXP = AM.DB:GetRealtimeRestXP(charName)
            if restXP > 0 then
                local maxXP = charData.maxXP or 1
                if maxXP < 1 then maxXP = 1 end
                local bars = (restXP / maxXP) * 20
                row.restXPText:SetText(string.format("Rest: %.1f Bars", bars))
            else
                row.restXPText:SetText("")
            end
            
            -- Check if professions exist and spawn icons dynamically
            if not row.profButtons then row.profButtons = {} end
            for _, pb in ipairs(row.profButtons) do pb:Hide() end
            
            local currentX = 0
            if charData.professions and #charData.professions > 0 then
                -- Cleanup bugged blank professions that were mistakenly saved
                for i = #charData.professions, 1, -1 do
                    local p = charData.professions[i]
                    if not p.name or p.name == "" then
                        table.remove(charData.professions, i)
                    end
                end
                
                for i, prof in ipairs(charData.professions) do
                    -- Ensure recipes for this character are up-to-date
                    AM.DB:UpdateRecipes()
                    local pBtn = row.profButtons[i]
                    if not pBtn then
                        pBtn = CreateFrame("Button", nil, row.profContainer)
                        pBtn:SetSize(20, 20)
                        
                        pBtn.icon = pBtn:CreateTexture(nil, "BORDER")
                        pBtn.icon:SetAllPoints()
                        
                        pBtn.rankText = pBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        pBtn.rankText:SetPoint("LEFT", pBtn, "RIGHT", 3, 0)
                        pBtn.rankText:SetTextColor(0.8, 0.8, 0.8)
                        
                        pBtn:SetHighlightTexture("Interface\\Buttons\\Button-Hilight-Square", "ADD")
                        
                        pBtn:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:AddLine(self.profName, 1, 1, 1)
                            GameTooltip:AddLine("Level: " .. self.profRank .. " / " .. self.profMax, 1, 0.82, 0)
                            GameTooltip:AddLine("<Click to view recipes>", 0, 1, 0)
                            GameTooltip:Show()
                        end)
                        pBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
                        
                        row.profButtons[i] = pBtn
                    end
                    
                    pBtn.profName = prof.name
                    pBtn.profRank = prof.rank
                    pBtn.profMax = prof.maxRank
                    
                    pBtn:SetScript("OnClick", function(self)
                        AM.UI:ShowRecipes(row.charName, self.profName)
                    end)
                    
                    pBtn.icon:SetTexture(prof.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
                    pBtn.rankText:SetText(prof.rank)
                    
                    pBtn:SetPoint("LEFT", row.profContainer, "LEFT", currentX, 0)
                    currentX = currentX + 20 + pBtn.rankText:GetStringWidth() + 10
                    
                    pBtn:Show()
                end
            end
            
            -- Check if auctions exist to show the button
            if charData.auctions and #charData.auctions > 0 then
                row.aucBtn:Show()
            else
                row.aucBtn:Hide()
            end
            
            -- Check if mail exists to show the button, and if unread mail exists for the yellow glow
            local hasMail = false
            local hasNewMail = false
            
            if charData.hasNewMail then
                hasNewMail = true
            end
            
            if charData.mail then
                for k, v in pairs(charData.mail) do
                    if v > 0 then
                        hasMail = true
                        break
                    end
                end
            end
            
            if charData.mailCount and charData.mailCount > 0 then
                hasMail = true
            end
            
            -- Check for expired auctions
            if charData.auctions then
                for _, auc in ipairs(charData.auctions) do
                    if auc.expires and time() >= (auc.expires + 3600) then
                        local deliveryTime = auc.expires + 3600
                        if not charData.lastMailCheck or charData.lastMailCheck < deliveryTime then
                            hasMail = true
                            hasNewMail = true
                            break
                        end
                    end
                end
            end
            
            if hasNewMail then
                hasMail = true
            end
            
            if hasMail then
                row.mailBtn:Show()
            else
                row.mailBtn:Hide()
            end
            
            if hasNewMail then
                row.mailGlow:Show()
            else
                row.mailGlow:Hide()
            end
            
            -- Set Gold & Calculate Total Wealth (excluded if ignored)
            local money = charData.money or 0
            row.goldText:SetText(FormatGold(money))
            if not isIgnored then
                totalGold = totalGold + money
            end
            
            row:Show()
            index = index + 1
        end
    end
    
    -- Hide remaining unused rows
    for i = index, #rows do
        rows[i]:Hide()
    end
    
    -- Update Total Wealth Footer
    AM.UI.MainFrame.totalGoldValue:SetText(FormatGold(totalGold))
end

SLASH_ALTMANAGER1 = "/altmanager"
SLASH_ALTMANAGER2 = "/am"
SLASH_ALTMANAGER3 = "/foreveraltmanager"
SLASH_ALTMANAGER4 = "/fam"
SlashCmdList["ALTMANAGER"] = function(msg)
    AM.UI:ToggleMainFrame()
end

-- Global Tooltip Injection for Alt Materials
function AM.UI:InjectItemTooltip(tooltip)
    if tooltip:IsForbidden() then return end
    if tooltip.AM_Injected then return end
    
    local _, link = tooltip:GetItem()
    if not link then return end
    
    local itemID = tonumber(string.match(link, "item:(%d+)"))
    if not itemID then return end
    
    local ruleset = AM.DB:GetRuleset()
    local faction = AM.DB:GetFaction()
    
    if not AltManagerDB[ruleset] or not AltManagerDB[ruleset][faction] then return end
    
    local totalOwned = 0
    local locations = {}
    
    for cName, cData in pairs(AltManagerDB[ruleset][faction]) do
        local bagCount = cData.bags and cData.bags[itemID] or 0
        local bankCount = cData.bank and cData.bank[itemID] or 0
        local charTotal = bagCount + bankCount
        if charTotal > 0 then
            totalOwned = totalOwned + charTotal
            local locStr = {}
            if bagCount > 0 then table.insert(locStr, "Bags: " .. bagCount) end
            if bankCount > 0 then table.insert(locStr, "Bank: " .. bankCount) end
            table.insert(locations, string.format("  > %s: %s", cName, table.concat(locStr, ", ")))
        end
    end
    
    if totalOwned > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("AltManager:", 1, 0.82, 0)
        for _, loc in ipairs(locations) do
            tooltip:AddLine(loc, 1, 1, 1)
        end
        tooltip.AM_Injected = true
    end
end

local function ClearInjection(tooltip)
    tooltip.AM_Injected = nil
end

GameTooltip:HookScript("OnTooltipCleared", ClearInjection)
ItemRefTooltip:HookScript("OnTooltipCleared", ClearInjection)

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip == GameTooltip or tooltip == ItemRefTooltip then
            AM.UI:InjectItemTooltip(tooltip)
        end
    end)
else
    GameTooltip:HookScript("OnTooltipSetItem", function(self)
        AM.UI:InjectItemTooltip(self)
    end)
    ItemRefTooltip:HookScript("OnTooltipSetItem", function(self)
        AM.UI:InjectItemTooltip(self)
    end)
end

-- Money Frame Injection for Alt Wealth Tracking
local function InjectMoneyTooltip(frame)
    if not frame then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine("AltManager Wealth", 1, 0.82, 0)
    
    local ruleset = AM.DB:GetRuleset()
    local faction = AM.DB:GetFaction()
    if not AltManagerDB[ruleset] or not AltManagerDB[ruleset][faction] then return end
    
    local totalGold = 0
    local chars = {}
    for cName, cData in pairs(AltManagerDB[ruleset][faction]) do
        table.insert(chars, {name = cName, money = cData.money or 0})
        totalGold = totalGold + (cData.money or 0)
    end
    table.sort(chars, function(a, b) return a.money > b.money end)
    
    for _, c in ipairs(chars) do
        if c.money > 0 then
            GameTooltip:AddDoubleLine(c.name, FormatGold(c.money), 1, 1, 1, 1, 1, 1)
        end
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Total Account Wealth:", FormatGold(totalGold), 0, 1, 0, 0, 1, 0)
    GameTooltip:Show()
end

local function HookFrameAndChildren(f)
    if not f or f.AM_Hooked then return end
    f:EnableMouse(true)
    if f:GetScript("OnEnter") then
        f:HookScript("OnEnter", InjectMoneyTooltip)
    else
        f:SetScript("OnEnter", InjectMoneyTooltip)
    end
    if f:GetScript("OnLeave") then
        f:HookScript("OnLeave", function() GameTooltip:Hide() end)
    else
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    f.AM_Hooked = true
end

local function HookMoneyFrames()
    local framesToHook = {}
    if ContainerFrame1MoneyFrame then table.insert(framesToHook, ContainerFrame1MoneyFrame) end
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags.MoneyFrame then table.insert(framesToHook, ContainerFrameCombinedBags.MoneyFrame) end
    if CharacterFrameMoneyFrame then table.insert(framesToHook, CharacterFrameMoneyFrame) end
    
    for _, f in ipairs(framesToHook) do
        HookFrameAndChildren(f)
        for _, child in ipairs({f:GetChildren()}) do
            HookFrameAndChildren(child)
        end
    end
end

-- Hook bags when they are opened
if OpenAllBags then hooksecurefunc("OpenAllBags", HookMoneyFrames) end
if ToggleAllBags then hooksecurefunc("ToggleAllBags", HookMoneyFrames) end
if ToggleBackpack then hooksecurefunc("ToggleBackpack", HookMoneyFrames) end
if OpenBackpack then hooksecurefunc("OpenBackpack", HookMoneyFrames) end

-- Try to hook them right away too
C_Timer.After(1, HookMoneyFrames)
