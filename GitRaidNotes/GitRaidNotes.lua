local _, ns = ...

------------------------------------------------------------
-- Shared configuration (defaults)
------------------------------------------------------------
ns.CONFIG = {
    frameWidth   = 350,
    fontSize     = 11,
    frameAlpha   = 0.85,
    locked       = false,
    showInCombat = true,
}

------------------------------------------------------------
-- DB init (called from Detection.lua on PLAYER_LOGIN)
------------------------------------------------------------
function ns.InitDB()
    GitRaidNotesDB = GitRaidNotesDB or {}
    ns.db = GitRaidNotesDB

    -- Apply defaults for any missing keys
    for k, v in pairs(ns.CONFIG) do
        if ns.db[k] == nil then
            ns.db[k] = v
        end
    end

    ns.db.currentBoss = ns.db.currentBoss or 1
    ns.db.currentTab = ns.db.currentTab or "tank"
    ns.db.manualDifficulty = ns.db.manualDifficulty or "heroic"
    ns.db.notes = ns.db.notes or {}
    ns.db.pos = ns.db.pos or { point = "CENTER", x = 0, y = 0 }
end

------------------------------------------------------------
-- Content resolution: user override > addon default
------------------------------------------------------------
function ns.GetNoteContent(bossKey, tabKey, difficulty)
    -- User override
    local userNotes = ns.db and ns.db.notes and ns.db.notes[bossKey]
    if userNotes and userNotes[tabKey] then
        local text = userNotes[tabKey]
        if text ~= nil then return text end
    end

    -- Addon defaults
    local defaults = ns.DEFAULT_NOTES and ns.DEFAULT_NOTES[bossKey]
    if not defaults or not defaults[tabKey] then return "" end

    local base = defaults[tabKey].default or ""
    if difficulty == "mythic" and defaults[tabKey].mythic then
        return base .. "\n\n" .. defaults[tabKey].mythic
    end
    return base
end

------------------------------------------------------------
-- Slash command: /grn
------------------------------------------------------------
SLASH_GITRAIDNOTES1 = "/grn"
SlashCmdList["GITRAIDNOTES"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "" then
        -- Toggle frame
        if ns.frame then
            if ns.frame:IsShown() then
                ns.frame:Hide()
            else
                ns.frame:Show()
            end
        end
    elseif cmd == "show" then
        if ns.frame then ns.frame:Show() end
    elseif cmd == "hide" then
        if ns.frame then ns.frame:Hide() end
    elseif cmd == "edit" then
        if ns.OpenEditor then ns.OpenEditor() end
    elseif cmd == "lock" then
        if ns.db then
            ns.db.locked = not ns.db.locked
            local state = ns.db.locked and "locked" or "unlocked"
            print("|cff00ccffGRN:|r Frame " .. state)
            if ns.ApplyLock then ns.ApplyLock() end
        end
    elseif cmd == "reset" then
        if ns.db and ns.BOSSES then
            local boss = ns.BOSSES[ns.db.currentBoss]
            if boss then
                local tab = ns.db.currentTab
                if ns.db.notes[boss.key] then
                    ns.db.notes[boss.key][tab] = nil
                end
                print("|cff00ccffGRN:|r Reset " .. boss.short .. " / " .. tab .. " to default")
                if ns.RefreshContent then ns.RefreshContent() end
            end
        end
    elseif cmd == "next" then
        if ns.NextBoss then ns.NextBoss() end
    elseif cmd == "prev" then
        if ns.PrevBoss then ns.PrevBoss() end
    elseif cmd:match("^boss ") then
        local arg = cmd:match("^boss (.+)")
        local idx = tonumber(arg)
        if idx and ns.BOSSES and ns.BOSSES[idx] then
            ns.db.currentBoss = idx
            if ns.RefreshContent then ns.RefreshContent() end
        else
            -- Try matching by key
            for i, boss in ipairs(ns.BOSSES) do
                if boss.key == arg then
                    ns.db.currentBoss = i
                    if ns.RefreshContent then ns.RefreshContent() end
                    break
                end
            end
        end
    elseif cmd:match("^diff ") then
        local arg = cmd:match("^diff (.+)"):upper()
        local map = { N = "normal", H = "heroic", M = "mythic" }
        if map[arg] then
            ns.db.manualDifficulty = map[arg]
            print("|cff00ccffGRN:|r Difficulty set to " .. map[arg])
            if ns.RefreshContent then ns.RefreshContent() end
        end
    elseif cmd:match("^width ") then
        local w = tonumber(cmd:match("^width (%d+)"))
        if w and w >= 200 and w <= 600 then
            ns.db.frameWidth = w
            if ns.frame then
                ns.frame:SetWidth(w)
                if ns.RefreshContent then ns.RefreshContent() end
            end
            print("|cff00ccffGRN:|r Width set to " .. w)
        end
    else
        print("|cff00ccffGRN:|r Commands:")
        print("  /grn          -- toggle frame")
        print("  /grn edit     -- edit current note")
        print("  /grn lock     -- toggle click-through")
        print("  /grn reset    -- reset current note to default")
        print("  /grn next     -- next boss")
        print("  /grn prev     -- previous boss")
        print("  /grn boss N   -- jump to boss (1-9 or key)")
        print("  /grn diff N|H|M -- set difficulty")
        print("  /grn width N  -- set frame width (200-600)")
    end
end
