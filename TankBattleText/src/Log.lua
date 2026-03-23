local _, ns = ...

local log = {}
local combatStartTime = 0

-- School names for log output
local SCHOOL_NAMES = {
    [0x1]  = "Phys",
    [0x2]  = "Holy",
    [0x4]  = "Fire",
    [0x8]  = "Nature",
    [0x10] = "Frost",
    [0x20] = "Shadow",
    [0x40] = "Arcane",
}

local function SchoolName(school)
    return SCHOOL_NAMES[school] or "Unknown"
end

-- Short number formatting
local function ShortNumber(n)
    if n >= 1000000 then
        return format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return format("%.1fK", n / 1000)
    else
        return tostring(n)
    end
end

function ns.ClearLog()
    wipe(log)
    combatStartTime = GetTime()
end

function ns.LogHit(amount, school, critical, outlierInfo)
    log[#log + 1] = {
        time = GetTime() - combatStartTime,
        kind = "hit",
        amount = amount,
        school = school or 0x1,
        critical = critical or false,
        shown = outlierInfo and outlierInfo.isOutlierHigh or false,
        extreme = outlierInfo and outlierInfo.isOutlierExtreme or false,
        sigma = outlierInfo and outlierInfo.sigma or 0,
    }
end

function ns.LogBurst(total, count, duration)
    log[#log + 1] = {
        time = GetTime() - combatStartTime,
        kind = "burst",
        total = total,
        count = count,
        duration = duration,
    }
end

function ns.LogCollapse(total, count, pctPerSec)
    log[#log + 1] = {
        time = GetTime() - combatStartTime,
        kind = "collapse",
        total = total,
        count = count,
        pctPerSec = pctPerSec,
    }
end

-- Persist across reloads
local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGIN")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        TankBattleTextLog = TankBattleTextLog or {}
        -- Restore previous session log
        if #TankBattleTextLog > 0 then
            log = TankBattleTextLog
        end
    elseif event == "PLAYER_LOGOUT" then
        TankBattleTextLog = log
    end
end)

-- Format log as copyable text
local function FormatLog()
    if #log == 0 then
        return "No combat log entries. Enter combat to start logging."
    end

    local lines = {}
    for _, entry in ipairs(log) do
        local timeStr = format("[%5.1fs]", entry.time)
        if entry.kind == "hit" then
            local suffix = entry.critical and "*" or ""
            local tag
            if entry.shown then
                tag = entry.extreme and "SHOW !!" or "SHOW !"
            else
                tag = "     "
            end
            lines[#lines + 1] = format("%s  %s  -%s%s %s  (%.1f\207\131)",
                timeStr, tag, ShortNumber(entry.amount), suffix,
                SchoolName(entry.school), entry.sigma)
        elseif entry.kind == "burst" then
            lines[#lines + 1] = format("%s  BURST  -%s (%d hits %.1fs)",
                timeStr, ShortNumber(entry.total), entry.count, entry.duration)
        elseif entry.kind == "collapse" then
            local hitWord = entry.count == 1 and "hit" or "hits"
            lines[#lines + 1] = format("%s  ----  %d %s  %s  (%.1f%%/s)",
                timeStr, entry.count, hitWord, ShortNumber(entry.total), entry.pctPerSec)
        end
    end
    return table.concat(lines, "\n")
end

-- Log viewer frame
local viewer = CreateFrame("Frame", "TankBattleTextLogViewer", UIParent, "BasicFrameTemplateWithInset")
viewer:SetSize(450, 350)
viewer:SetPoint("CENTER")
viewer:SetMovable(true)
viewer:EnableMouse(true)
viewer:RegisterForDrag("LeftButton")
viewer:SetScript("OnDragStart", viewer.StartMoving)
viewer:SetScript("OnDragStop", viewer.StopMovingOrSizing)
viewer:SetFrameStrata("DIALOG")
viewer:Hide()
viewer.TitleText:SetText("TBT Combat Log")

local scrollFrame = CreateFrame("ScrollFrame", nil, viewer, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", viewer.InsetBg, "TOPLEFT", 4, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", viewer.InsetBg, "BOTTOMRIGHT", -22, 4)

local editBox = CreateFrame("EditBox", nil, scrollFrame)
editBox:SetMultiLine(true)
editBox:SetAutoFocus(false)
editBox:SetFontObject(GameFontHighlightSmall)
editBox:SetWidth(400)
editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
scrollFrame:SetScrollChild(editBox)

function ns.ShowLog()
    editBox:SetText(FormatLog())
    editBox:SetWidth(scrollFrame:GetWidth() or 400)
    viewer:Show()
end

function ns.ToggleLog()
    if viewer:IsShown() then
        viewer:Hide()
    else
        ns.ShowLog()
    end
end
