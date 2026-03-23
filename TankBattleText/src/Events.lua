local _, ns = ...

--[[
    UNIT_COMBAT args: unitTarget, event, flagText, amount, schoolMask
    event types: WOUND, DODGE, PARRY, BLOCK, MISS, IMMUNE, RESIST, ABSORB, REFLECT
    flagText: "-CRITICAL" for crits, "-BLOCK" for partial blocks, etc.
    CLEU is protected in 12.x — UNIT_COMBAT is the available alternative
]]

-- Outgoing DPS: hooksecurefunc on C_DamageMeter.GetCombatSessionSourceFromType.
-- When MBT (or any addon) calls this API, our hook fires AFTER the call returns
-- but BEFORE the caller proceeds to ResetAllCombatSessions. We re-read the same
-- data in our hook. hooksecurefunc is taint-safe (official WoW hook API).
local playerGUID
local inHook = false

if C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType then
    hooksecurefunc(C_DamageMeter, "GetCombatSessionSourceFromType", function(sessionIndex, dmType, guid)
        if inHook then return end
        if dmType ~= Enum.DamageMeterType.DamageDone then return end
        if not playerGUID then playerGUID = UnitGUID("player") end
        if guid ~= playerGUID then return end

        inHook = true
        local source = C_DamageMeter.GetCombatSessionSourceFromType(sessionIndex, dmType, guid)
        inHook = false

        if source and source.totalAmount then
            local total = tonumber(tostring(source.totalAmount)) or 0
            if total > 0 then
                ns.Tracker.RecordDamageDealt(total)
                ns.UpdateStats()
            end
        end
    end)
end

-- Burst detection: short-window cumulative damage
local BURST_WINDOW = 1.5
local BURST_THRESHOLD = 0.20 -- 20% of max HP
local BURST_COOLDOWN = 3     -- min seconds between burst alerts
local burstHits = {}         -- { timestamp, amount }
local lastBurstTime = 0

local function CheckBurst(now)
    -- Prune old entries
    local cutoff = now - BURST_WINDOW
    local write = 1
    for read = 1, #burstHits do
        if burstHits[read].t >= cutoff then
            burstHits[write] = burstHits[read]
            write = write + 1
        end
    end
    for i = write, #burstHits do burstHits[i] = nil end

    -- Sum remaining
    local total, count = 0, 0
    local earliest = now
    for i = 1, #burstHits do
        total = total + burstHits[i].a
        count = count + 1
        if burstHits[i].t < earliest then earliest = burstHits[i].t end
    end

    if count < 2 then return end

    local maxHP = UnitHealthMax("player")
    if maxHP <= 0 then return end

    local hpPct = total / maxHP
    if hpPct >= BURST_THRESHOLD and (now - lastBurstTime) >= BURST_COOLDOWN then
        lastBurstTime = now
        local duration = now - earliest
        ns.DisplayBurst(total, count, duration)
        if ns.LogBurst then ns.LogBurst(total, count, duration) end
    end
end

-- Collapse accumulator for routine hits
local COLLAPSE_INTERVAL = 2
local collapseTotal = 0
local collapseCount = 0
local collapseTimer = nil
local inCombat = false

local function FlushCollapse()
    if collapseCount > 0 then
        ns.DisplayCollapsed(collapseTotal, collapseCount)
        collapseTotal = 0
        collapseCount = 0
    end
end

local function CollapseTimerTick()
    FlushCollapse()
    if inCombat then
        collapseTimer = C_Timer.NewTimer(COLLAPSE_INTERVAL, CollapseTimerTick)
    else
        collapseTimer = nil
    end
end

local function StartCollapseTimer()
    if not collapseTimer then
        collapseTimer = C_Timer.NewTimer(COLLAPSE_INTERVAL, CollapseTimerTick)
    end
end

local function ResetCollapse()
    collapseTotal = 0
    collapseCount = 0
    if collapseTimer then
        collapseTimer:Cancel()
        collapseTimer = nil
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_COMBAT")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(_, eventName, unitTarget, event, flagText, amount, schoolMask)
    if eventName == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        ResetCollapse()
        wipe(burstHits)
        lastBurstTime = 0
        if ns.ClearLog then ns.ClearLog() end
        ns.Tracker.StartCombat()
        return
    end

    if eventName == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        FlushCollapse()
        if collapseTimer then
            collapseTimer:Cancel()
            collapseTimer = nil
        end
        -- Hide static collapse row after short delay so final summary is visible
        C_Timer.After(3, function()
            if not inCombat then
                ns.HideCollapseRow()
            end
        end)
        ns.Tracker.EndCombat()
        return
    end
    if not ns.enabled then return end
    if unitTarget ~= "player" then return end

    ns.Tracker.RecordEvent(event)

    if event == "WOUND" then
        local critical = flagText == "-CRITICAL"
        local crushing = flagText == "-CRUSHING"
        local glancing = flagText == "-GLANCING"

        ns.Tracker.Record(amount, schoolMask or 0x1)
        local outlier = ns.Tracker.GetOutlierInfo(amount)

        -- Log every hit with outlier decision
        if ns.LogHit then ns.LogHit(amount, schoolMask or 0x1, critical, outlier) end

        -- Burst detection: track all hits in short window
        local now = GetTime()
        burstHits[#burstHits + 1] = { t = now, a = amount }
        CheckBurst(now)

        local collapseEnabled = not ns.db or ns.db.showCollapseMode ~= false

        -- Show first hits individually before we have enough data for stats
        if not collapseEnabled or outlier.fallback or outlier.isOutlierHigh then
            -- Display individually: outlier or collapse disabled
            ns.Display({
                type = "damage",
                amount = amount,
                school = schoolMask or 0x1,
                critical = critical,
                crushing = crushing,
                glancing = glancing,
                outlier = outlier,
            })
        else
            -- Accumulate routine hit
            collapseTotal = collapseTotal + amount
            collapseCount = collapseCount + 1
            StartCollapseTimer()
        end
        ns.UpdateStats()
    else
        -- All non-WOUND events: just update stats (avoidance tracking)
        ns.UpdateStats()
    end
end)
