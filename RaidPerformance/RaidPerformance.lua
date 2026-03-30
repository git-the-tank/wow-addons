local AddonName, ns = ...

-- SavedVariables (written by companion CLI)
-- RaidPerformanceData is global, loaded from SavedVariables
-- RaidPerformanceDB is per-character settings

ns.CONFIG = {
    tooltipEnabled = true,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        -- Initialize per-character settings
        RaidPerformanceDB = RaidPerformanceDB or {}
        ns.db = RaidPerformanceDB
        for key, val in pairs(ns.CONFIG) do
            if ns.db[key] == nil then
                ns.db[key] = val
            end
        end

        -- Store reference to WCL data (written by companion CLI)
        ns.data = RaidPerformanceData

        if ns.data then
            local playerCount = 0
            for _ in pairs(ns.data.players or {}) do
                playerCount = playerCount + 1
            end
            local age = time() - (ns.data.generatedAt or 0)
            local ageDays = math.floor(age / 86400)
            local ageStr = ageDays == 0 and "today" or (ageDays .. "d ago")
            print("|cff00ccffRaidPerformance|r loaded: " .. playerCount .. " raiders, data from " .. ageStr)
        else
            print("|cff00ccffRaidPerformance|r loaded (no data yet - run companion CLI)")
        end
    end

    if event == "PLAYER_LOGIN" then
        ns.InitTooltip()
    end
end)

-- Slash commands
SLASH_RAIDPERF1 = "/rp"
SLASH_RAIDPERF2 = "/raidperf"
SlashCmdList["RAIDPERF"] = function(msg)
    local cmd, arg = msg:match("^(%S+)%s*(.*)")
    cmd = cmd or msg

    if cmd == "" or cmd == "toggle" then
        ns.ToggleDashboard()
    elseif cmd == "boss" and arg ~= "" then
        ns.ShowBossView(arg)
    elseif cmd == "player" and arg ~= "" then
        ns.ShowPlayerView(arg)
    elseif cmd == "roster" then
        ns.ShowRosterView()
    elseif cmd == "help" then
        print("|cff00ccffRaidPerformance|r commands:")
        print("  /rp - Toggle dashboard")
        print("  /rp roster - Roster overview")
        print("  /rp boss <name> - Boss detail view")
        print("  /rp player <name> - Player detail view")
    else
        ns.ToggleDashboard()
    end
end
