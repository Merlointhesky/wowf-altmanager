local addonName, AM = ...
AM.Core = CreateFrame("Frame")
AM.Events = {}

function AM.Core:OnEvent(event, ...)
    if AM.Events[event] then
        AM.Events[event](self, ...)
    end
end

AM.Core:SetScript("OnEvent", AM.Core.OnEvent)

function AM:DebugLog(msg)
    local timestamp = date("%m/%d/%y %H:%M:%S")
    local logString = "[" .. timestamp .. "] " .. tostring(msg)
    
    -- Live chat printing disabled (silent mode)
    -- print("|cFF999999[AM Debug]|r " .. tostring(msg))
    
    if type(AltManagerDebugLog) ~= "table" then
        AltManagerDebugLog = {}
    end
    
    table.insert(AltManagerDebugLog, logString)
    if #AltManagerDebugLog > 500 then
        table.remove(AltManagerDebugLog, 1)
    end
end
function AM.Core:RegisterEventSafe(event)
    pcall(self.RegisterEvent, self, event)
end

AM.Core:RegisterEventSafe("OWNED_AUCTIONS_UPDATED")
AM.Core:RegisterEventSafe("AUCTION_OWNED_LIST_UPDATE")
AM.Core:RegisterEventSafe("NEW_AUCTION_UPDATE")
AM.Core:RegisterEventSafe("AUCTION_HOUSE_SHOW")
AM.Core:RegisterEventSafe("AUCTION_HOUSE_CLOSED")
AM.Core:RegisterEventSafe("UI_ERROR_MESSAGE")
AM.Core:RegisterEventSafe("CHAT_MSG_SYSTEM")
AM.Core:RegisterEventSafe("AUCTION_MULTISELL_UPDATE")

AM.Events["GET_ITEM_INFO_RECEIVED"] = function(self, itemID, success)
    if AM.UI and AM.UI.ItemViewer and AM.UI.ItemViewer:IsShown() and AM.UI.ItemViewer.currentChar then
        AM.UI:ShowAuctions(AM.UI.ItemViewer.currentChar)
    end
end
AM.Core:RegisterEventSafe("GET_ITEM_INFO_RECEIVED")

