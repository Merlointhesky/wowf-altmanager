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
