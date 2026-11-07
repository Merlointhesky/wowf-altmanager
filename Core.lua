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

AM.Events["GET_ITEM_INFO_RECEIVED"] = function(self, itemID, success)
    if AM.UI and AM.UI.ItemViewer and AM.UI.ItemViewer:IsShown() then
        if AM.UI.ItemViewer.mode == "AUCTIONS" and AM.UI.ItemViewer.currentChar then
            AM.UI:ShowAuctions(AM.UI.ItemViewer.currentChar)
        elseif AM.UI.ItemViewer.mode == "SEARCH" and AM.UI.ItemViewer.searchQuery then
            AM.UI:ShowSearchResults(AM.UI.ItemViewer.searchQuery)
        end
    end
end
AM.Core:RegisterEventSafe("GET_ITEM_INFO_RECEIVED")


