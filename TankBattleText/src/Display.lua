local _, ns = ...

local min = math.min
local max = math.max

-- Short number formatting (always K for 1000+)
local function ShortNumber(n)
    if n >= 1000000 then
        return format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return format("%.1fK", n / 1000)
    else
        return tostring(n)
    end
end

-- Row pool constants
local NUM_COL_WIDTH = 90
local MAX_ROWS = 15
local FADE_THROTTLE = 0.05

-- Font state for row creation
local currentFont, currentSize, currentFlags = GameFontNormal:GetFont(), 18, "OUTLINE"
local ROW_HEIGHT = currentSize + 4

-- Create display frame (plain Frame, not ScrollingMessageFrame)
local display = CreateFrame("Frame", "TankBattleTextFrame", UIParent)
display:SetSize(400, 300)
display:SetPoint("RIGHT", UIParent, "CENTER", -100, 0)

-- Row pool
local rows = {}     -- active rows, index 1 = newest (top)
local rowPool = {}  -- recycled row frames

local function CreateRow()
    local row = CreateFrame("Frame", nil, display)
    row:SetSize(400, ROW_HEIGHT)

    local numText = row:CreateFontString(nil, "OVERLAY")
    numText:SetFont(currentFont, currentSize, currentFlags)
    numText:SetWidth(NUM_COL_WIDTH)
    numText:SetJustifyH("RIGHT")
    numText:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    numText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)

    local infoText = row:CreateFontString(nil, "OVERLAY")
    infoText:SetFont(currentFont, currentSize, currentFlags)
    infoText:SetJustifyH("LEFT")
    infoText:SetPoint("LEFT", numText, "RIGHT", 6, 0)

    row.numText = numText
    row.infoText = infoText
    row.created = GetTime()
    return row
end

local function RepositionRows()
    for i, row in ipairs(rows) do
        row:ClearAllPoints()
        row:SetPoint("BOTTOMLEFT", display, "BOTTOMLEFT", 0, (i - 1) * ROW_HEIGHT)
    end
end

local function RecycleRow(index)
    local row = table.remove(rows, index)
    row:Hide()
    row:SetAlpha(1)
    table.insert(rowPool, row)
end

local function ClearRows()
    for i = #rows, 1, -1 do
        RecycleRow(i)
    end
end

local function AddRow(numStr, infoStr)
    local row
    if #rowPool > 0 then
        row = table.remove(rowPool)
    else
        row = CreateRow()
    end

    row.numText:SetText(numStr)
    row.infoText:SetText(infoStr)
    row.created = GetTime()
    row:SetAlpha(1)
    row:Show()

    table.insert(rows, 1, row)

    -- Recycle overflow
    while #rows > MAX_ROWS do
        RecycleRow(#rows)
    end

    RepositionRows()
end

-- OnUpdate fade handler
local fadeElapsed = 0
display:SetScript("OnUpdate", function(_, elapsed)
    fadeElapsed = fadeElapsed + elapsed
    if fadeElapsed < FADE_THROTTLE then return end
    fadeElapsed = 0

    local now = GetTime()
    local timeVisible = ns.db and ns.db.fadeTimeVisible or 8
    local fadeDuration = 1.5

    for i = #rows, 1, -1 do
        local row = rows[i]
        local age = now - row.created
        if age > timeVisible + fadeDuration then
            RecycleRow(i)
        elseif age > timeVisible then
            local progress = 1 - ((age - timeVisible) / fadeDuration)
            row:SetAlpha(max(0, progress))
        end
    end
end)

-- Damage meter bar: StatusBar that fills based on incoming damage severity
local dmgBar = CreateFrame("StatusBar", nil, display)
dmgBar:SetSize(300, 18)
dmgBar:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -2)
dmgBar:SetMinMaxValues(0, 1)
dmgBar:SetValue(0)
dmgBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
dmgBar:SetStatusBarColor(0.2, 0.8, 0.2)
dmgBar:Hide()

local dmgBarBG = dmgBar:CreateTexture(nil, "BACKGROUND")
dmgBarBG:SetAllPoints()
dmgBarBG:SetTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
dmgBarBG:SetVertexColor(0, 0, 0, 0.4)

function ns.ApplyDamageBarTexture(texturePath)
    dmgBar:SetStatusBarTexture(texturePath)
    dmgBarBG:SetTexture(texturePath)
end

local DEFAULT_FONT, DEFAULT_SIZE, DEFAULT_FLAGS = GameFontNormal:GetFont(), 14, "OUTLINE"

local dmgBarText = dmgBar:CreateFontString(nil, "OVERLAY")
dmgBarText:SetFont(DEFAULT_FONT, DEFAULT_SIZE, DEFAULT_FLAGS)
dmgBarText:SetPoint("LEFT", dmgBar, "LEFT", 4, 0)
dmgBarText:SetJustifyH("LEFT")
dmgBarText:SetTextColor(1, 1, 1)

local dmgBarPctText = dmgBar:CreateFontString(nil, "OVERLAY")
dmgBarPctText:SetFont(DEFAULT_FONT, DEFAULT_SIZE, DEFAULT_FLAGS)
dmgBarPctText:SetPoint("RIGHT", dmgBar, "RIGHT", -4, 0)
dmgBarPctText:SetJustifyH("RIGHT")
dmgBarPctText:SetTextColor(1, 1, 1)

-- Max %HP/s that maps to a full bar
local MAX_DTPS_PCT = 20

-- Apply global font to damage rows
function ns.ApplyDamageFont(path, size, outline)
    if outline == "NONE" then outline = "" end
    currentFont = path
    currentSize = size
    currentFlags = outline
    ROW_HEIGHT = size + 4

    -- Update all existing rows
    for _, row in ipairs(rows) do
        row.numText:SetFont(path, size, outline)
        row.infoText:SetFont(path, size, outline)
        row:SetSize(400, ROW_HEIGHT)
    end
    for _, row in ipairs(rowPool) do
        row.numText:SetFont(path, size, outline)
        row.infoText:SetFont(path, size, outline)
        row:SetSize(400, ROW_HEIGHT)
    end
    RepositionRows()
end

-- Apply global font to damage bar (with optional size override)
function ns.ApplyCollapseFont(path, size, outline)
    local sz = ns.db and ns.db.collapseFontSize or size
    if outline == "NONE" then outline = "" end
    dmgBarText:SetFont(path, sz, outline)
    dmgBarPctText:SetFont(path, sz, outline)
end

-- Apply display duration (time before fade starts) — now a no-op,
-- fade reads ns.db.fadeTimeVisible directly in OnUpdate
function ns.ApplyFadeDuration()
end

-- Color helper: returns hex string
local function Hex(color)
    return format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

-- Get school color
local function SchoolColor(school)
    return ns.schoolColors[school] or ns.defaultDamageColor
end

-- Update the damage bar fill and color
local function SetDmgBar(pctPerSec, leftText, rightText)
    local fill = min(1, max(0, pctPerSec / MAX_DTPS_PCT))
    dmgBar:SetValue(fill)
    dmgBar:SetStatusBarColor(ns.GetDTPSBarColor(pctPerSec))
    dmgBarText:SetText(leftText)
    dmgBarPctText:SetText(rightText)
    dmgBar:Show()
end

-- Collapse summary: column-aligned row for routine hits
function ns.DisplayCollapsed(total, count)
    if not ns.enabled then return end
    if ns.db and ns.db.showDamageText == false then return end

    local maxHP = UnitHealthMax("player")
    if maxHP <= 0 then return end

    local hpPct = total / maxHP * 100
    local pctPerSec = hpPct / 2 -- 2s collapse window

    local r, g, b = ns.GetDTPSBarColor(pctPerSec)
    local sevColor = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)

    local numStr = sevColor .. ShortNumber(total) .. "|r"
    local infoStr = ""
    if count > 1 then
        infoStr = sevColor .. count .. " hits|r"
    end
    AddRow(numStr, infoStr)

    if ns.LogCollapse then ns.LogCollapse(total, count, pctPerSec) end
end

-- Burst alert: fills bar higher, also adds a row
function ns.DisplayBurst(total, count, duration)
    if not ns.enabled then return end
    if ns.db and ns.db.showDamageText == false then return end

    local maxHP = UnitHealthMax("player")
    if maxHP <= 0 then return end

    local hpPct = total / maxHP * 100

    -- Fill bar to burst level
    SetDmgBar(hpPct,
        format("SPIKE  %d hits  %.1fs", count, duration),
        "")

    -- Also add a row so it's in the history
    local r, g, b = ns.GetDTPSBarColor(hpPct)
    local sevColor = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
    local numStr = sevColor .. ShortNumber(total) .. "|r"
    local infoStr = sevColor .. "SPIKE " .. count .. " hits " .. format("%.1fs", duration) .. "|r"
    AddRow(numStr, infoStr)
end

function ns.HideCollapseRow()
    dmgBar:Hide()
end

-- Preview mode
function ns.ShowDamagePreview()
    if ns.db and ns.db.showDamageText == false then
        display:Hide()
        dmgBar:Hide()
        return
    end
    ClearRows()

    -- Sample rows (added bottom-to-top, newest first)
    local cr, cg, cb = ns.GetDTPSBarColor(7.5)
    local collapseColor = format("|cff%02x%02x%02x", cr * 255, cg * 255, cb * 255)
    AddRow(collapseColor .. "42.1K|r", collapseColor .. "8 hits|r")

    AddRow("|cffffff003.2K|r", "")

    AddRow("|cffffff0015.2K|r", "|cffff4444!|r")

    AddRow("|cffff444442.8K*|r", "|cffff2222!!|r")

    local br, bg, bb = ns.GetDTPSBarColor(15)
    local burstColor = format("|cff%02x%02x%02x", br * 255, bg * 255, bb * 255)
    AddRow(burstColor .. "85.2K|r", burstColor .. "SPIKE 6 hits 0.8s|r")

    display:Show()

    -- Sample burst bar
    SetDmgBar(15,
        "SPIKE  6 hits  0.8s",
        "")
end

function ns.HideDamagePreview()
    if not InCombatLockdown() then
        ClearRows()
        dmgBar:Hide()
    end
end

function ns.Display(data)
    if not ns.enabled then return end
    if ns.db and ns.db.showDamageText == false then return end
    if data.type ~= "damage" then return end

    local color = SchoolColor(data.school)
    local num = ShortNumber(data.amount)
    local suffix = ""
    if data.critical then suffix = "*"
    elseif data.crushing then suffix = "!"
    elseif data.glancing then suffix = "~"
    end

    local numStr = Hex(color) .. num .. suffix .. "|r"

    -- Outlier indicator in info column
    local infoStr = ""
    local outlier = data.outlier
    if outlier then
        if outlier.isOutlierExtreme then
            infoStr = "|cffff2222!!|r"
        elseif outlier.isOutlierHigh then
            infoStr = "|cffff4444!|r"
        end
    end

    AddRow(numStr, infoStr)
end
