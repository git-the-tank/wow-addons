local _, ns = ...

local sqrt = math.sqrt

local Tracker = {}
ns.Tracker = Tracker

-- Circular buffer: last 50 hits
local BUFFER_SIZE = 50
local buffer = {}
local bufferIndex = 0
local bufferCount = 0

-- Rolling window for average: 30s
local AVERAGE_WINDOW = 30

-- Spike detection: 4s window, 30% max HP threshold
local SPIKE_WINDOW = 4
local SPIKE_THRESHOLD = 0.30

function Tracker.Record(amount, school)
    bufferIndex = (bufferIndex % BUFFER_SIZE) + 1
    buffer[bufferIndex] = { amount = amount, school = school or 0x1, timestamp = GetTime() }
    if bufferCount < BUFFER_SIZE then
        bufferCount = bufferCount + 1
    end
end

function Tracker.GetAverage()
    local now = GetTime()
    local cutoff = now - AVERAGE_WINDOW
    local total, count = 0, 0

    for i = 1, bufferCount do
        local entry = buffer[i]
        if entry.timestamp >= cutoff then
            total = total + entry.amount
            count = count + 1
        end
    end

    return count > 0 and (total / count) or 0
end

function Tracker.GetOutlierInfo(amount)
    local now = GetTime()
    local cutoff = now - AVERAGE_WINDOW
    local sum, sumSq, count = 0, 0, 0

    for i = 1, bufferCount do
        local entry = buffer[i]
        if entry.timestamp >= cutoff then
            sum = sum + entry.amount
            sumSq = sumSq + entry.amount * entry.amount
            count = count + 1
        end
    end

    -- Fallback to ratio-based detection with < 5 hits
    if count < 5 then
        local mean = count > 0 and (sum / count) or 0
        local ratio = mean > 0 and (amount / mean) or 1
        return {
            sigma = 0,
            isOutlierHigh = ratio >= 1.5,
            isOutlierExtreme = false,
            isOutlierLow = ratio <= 0.5,
            fallback = true,
        }
    end

    local mean = sum / count
    local variance = (sumSq / count) - mean * mean
    if variance < 0 then variance = 0 end
    local stddev = sqrt(variance)

    -- Floor: stddev must be at least 20% of mean to prevent lull-adapted false outliers
    local minStddev = mean * 0.20
    if stddev < minStddev then stddev = minStddev end

    local sigma = stddev > 0 and ((amount - mean) / stddev) or 0

    return {
        sigma = sigma,
        isOutlierHigh = sigma >= 2,
        isOutlierExtreme = sigma >= 3,
        isOutlierLow = sigma <= -1.5,
        fallback = false,
    }
end

function Tracker.GetHPPercent(amount)
    local maxHP = UnitHealthMax("player")
    if maxHP == 0 then return 0 end
    return (amount / maxHP) * 100
end

function Tracker.GetDTPS(window)
    local now = GetTime()
    local cutoff = now - window
    local total = 0

    for i = 1, bufferCount do
        local entry = buffer[i]
        if entry.timestamp >= cutoff then
            total = total + entry.amount
        end
    end

    return total / window
end

-- Rolling mitigation tracking (10s window — tuned for M+ trash packs)
local MITIGATION_EVENTS = {
    DODGE = true,
    PARRY = true,
    BLOCK = true,
    MISS  = true,
}

local MITIGATION_WINDOW = 10
local EVENT_BUFFER_SIZE = 100
local eventBuffer = {}
local eventIndex = 0
local eventCount = 0

function Tracker.RecordEvent(event)
    -- Only track events relevant to avoidance rate
    local mitigated
    if event == "WOUND" then
        mitigated = false
    elseif MITIGATION_EVENTS[event] then
        mitigated = true
    else
        return -- ABSORB, RESIST, IMMUNE, REFLECT, DEFLECT ignored
    end

    eventIndex = (eventIndex % EVENT_BUFFER_SIZE) + 1
    eventBuffer[eventIndex] = { mitigated = mitigated, timestamp = GetTime() }
    if eventCount < EVENT_BUFFER_SIZE then
        eventCount = eventCount + 1
    end
end

function Tracker.GetMitigationRate()
    local now = GetTime()
    local cutoff = now - MITIGATION_WINDOW
    local total, mitigated = 0, 0

    for i = 1, eventCount do
        local entry = eventBuffer[i]
        if entry.timestamp >= cutoff then
            total = total + 1
            if entry.mitigated then
                mitigated = mitigated + 1
            end
        end
    end

    if total == 0 then return 0 end
    return (mitigated / total) * 100
end

function Tracker.GetSchoolSplit(window)
    local now = GetTime()
    local cutoff = now - window
    local phys, magic = 0, 0

    for i = 1, bufferCount do
        local entry = buffer[i]
        if entry.timestamp >= cutoff then
            if entry.school == 0x1 then
                phys = phys + entry.amount
            else
                magic = magic + entry.amount
            end
        end
    end

    local total = phys + magic
    if total == 0 then return 0, 0 end
    return (phys / total) * 100, (magic / total) * 100
end

function Tracker.GetSchoolDTPS(window)
    local now = GetTime()
    local cutoff = now - window
    local phys, magic = 0, 0

    for i = 1, bufferCount do
        local entry = buffer[i]
        if entry.timestamp >= cutoff then
            if entry.school == 0x1 then
                phys = phys + entry.amount
            else
                magic = magic + entry.amount
            end
        end
    end

    return phys / window, magic / window
end

function Tracker.IsSpike()
    local now = GetTime()
    local cutoff = now - SPIKE_WINDOW
    local total = 0

    for i = 1, bufferCount do
        local entry = buffer[i]
        if entry.timestamp >= cutoff then
            total = total + entry.amount
        end
    end

    local maxHP = UnitHealthMax("player")
    if maxHP == 0 then return false, 0 end

    local pct = total / maxHP
    return pct > SPIKE_THRESHOLD, total
end

-- Outgoing damage tracking
local DPS_BUFFER_SIZE = 50
local dpsBuffer = {}
local dpsIndex = 0
local dpsCount = 0

local combatStartTime = nil
local combatTotalDamage = 0
local lastKnownTotal = nil

function Tracker.RecordDamageDealt(totalAmount)
    if totalAmount <= 0 then return end

    -- Delta tracking: handles external resets (e.g. MidnightBattleText calling ResetAllCombatSessions)
    local delta
    if not lastKnownTotal or totalAmount < lastKnownTotal then
        -- First read or external reset — treat totalAmount as delta
        delta = totalAmount
    else
        delta = totalAmount - lastKnownTotal
    end
    lastKnownTotal = totalAmount

    if delta <= 0 then return end

    dpsIndex = (dpsIndex % DPS_BUFFER_SIZE) + 1
    dpsBuffer[dpsIndex] = { amount = delta, timestamp = GetTime() }
    if dpsCount < DPS_BUFFER_SIZE then
        dpsCount = dpsCount + 1
    end

    combatTotalDamage = combatTotalDamage + delta
end

function Tracker.GetRollingDPS(window)
    local now = GetTime()
    local cutoff = now - window
    local total = 0

    for i = 1, dpsCount do
        local entry = dpsBuffer[i]
        if entry.timestamp >= cutoff then
            total = total + entry.amount
        end
    end

    return total / window
end

function Tracker.GetCombatDPS()
    if not combatStartTime then return 0 end
    local duration = GetTime() - combatStartTime
    if duration < 1 then return 0 end
    return combatTotalDamage / duration
end

function Tracker.StartCombat()
    combatStartTime = GetTime()
    combatTotalDamage = 0
    lastKnownTotal = nil
    dpsCount = 0
    dpsIndex = 0
end

function Tracker.EndCombat()
    -- Keep final values for display; combatStartTime stays for GetCombatDPS
end
