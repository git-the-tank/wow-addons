local _, ns = ...

------------------------------------------------------------
-- Difficulty Detection
------------------------------------------------------------
-- DifficultyIDs: 14=Normal, 15=Heroic, 16=Mythic (raids)
local DIFF_MAP = {
    [14] = "normal",
    [15] = "heroic",
    [16] = "mythic",
}

local function UpdateDifficulty()
    local _, _, difficultyID = GetInstanceInfo()
    local mapped = DIFF_MAP[difficultyID]
    ns.currentDifficulty = mapped  -- nil if not in a raid
    if ns.RefreshContent then ns.RefreshContent() end
end

------------------------------------------------------------
-- Boss Auto-Selection via ENCOUNTER_START
------------------------------------------------------------
local function OnEncounterStart(encounterID)
    if not ns.db or not ns.ENCOUNTER_TO_BOSS then return end
    local idx = ns.ENCOUNTER_TO_BOSS[encounterID]
    if idx then
        ns.db.currentBoss = idx
        if ns.RefreshContent then ns.RefreshContent() end
    end
end

------------------------------------------------------------
-- Event Frame
------------------------------------------------------------
local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ENCOUNTER_START")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        ns.InitDB()
        -- Defer frame creation slightly so all files are loaded
        C_Timer.After(0, function()
            ns.CreateFrame()
            UpdateDifficulty()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        UpdateDifficulty()
    elseif event == "ENCOUNTER_START" then
        local encounterID = ...
        OnEncounterStart(encounterID)
        UpdateDifficulty()
    end
end)
