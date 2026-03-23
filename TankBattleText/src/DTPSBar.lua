local _, ns = ...

-- Logarithmic scale: maps 0-20% HP/s to 0-1 with log curve
local E_MINUS_1 = math.exp(1) - 1
local MAX_DTPS_PCT = 20

local function LogScale(pctPerSec)
    local ratio = pctPerSec / MAX_DTPS_PCT
    if ratio <= 0 then return 0 end
    if ratio >= 1 then return 1 end
    return math.log(1 + ratio * E_MINUS_1)
end

-- Built-in Blizzard textures
local BAR_TEXTURES = {
    { name = "Blizzard Raid Bar",  path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { name = "Blizzard",           path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { name = "Blizzard Parchment", path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    { name = "Blizzard Rock",      path = "Interface\\BarberShop\\UI-BarberShop-LevelMarker" },
    { name = "Solid",              path = "Interface\\Buttons\\WHITE8x8" },
}
ns.BAR_TEXTURES = BAR_TEXTURES

local function FindTexturePath(name)
    if ns.FindTexturePath then return ns.FindTexturePath(name) end
    local LSM = ns.LSM
    if LSM and LSM:IsValid("statusbar", name) then
        return LSM:Fetch("statusbar", name)
    end
    for _, t in ipairs(BAR_TEXTURES) do
        if t.name == name then return t.path end
    end
    return BAR_TEXTURES[1].path
end


local ANCHOR_POINTS = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}
ns.ANCHOR_POINTS = ANCHOR_POINTS

-- Defaults
local DEFAULTS = {
    showDTPSBar        = true,
    dtpsBarWidth       = 200,
    dtpsBarHeight      = 16,
    dtpsBarGrowth      = "RIGHT",
    dtpsBarBGColor     = { 0, 0, 0, 0.6 },
    dtpsBarAnchorFrame = "TankBattleTextStatsFrame",
    dtpsBarAnchorFrom  = "TOP",
    dtpsBarAnchorTo    = "BOTTOM",
    dtpsBarAnchorOffX  = 0,
    dtpsBarAnchorOffY  = -2,
    dtpsBarMatchWidth  = true,
}
ns.DTPS_BAR_DEFAULTS = DEFAULTS

-- Create bar frame
local bar = CreateFrame("StatusBar", "TankBattleTextDTPSBar", UIParent)
bar:SetSize(DEFAULTS.dtpsBarWidth, DEFAULTS.dtpsBarHeight)
bar:SetPoint("RIGHT", UIParent, "RIGHT", -100, 131)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)
local defaultBarTexture = FindTexturePath("Blizzard Raid Bar")
bar:SetStatusBarTexture(defaultBarTexture)
bar:SetStatusBarColor(0.2, 0.8, 0.2) -- initial green, updated dynamically
bar:Hide()

-- Background
local bg = bar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture(defaultBarTexture)
bg:SetVertexColor(unpack(DEFAULTS.dtpsBarBGColor))

-- Bar color thresholds: interpolate between these as DTPS increases
local BAR_COLOR_STOPS = {
    { pct = 0,  r = 0.2, g = 0.8, b = 0.2 },  -- green
    { pct = 5,  r = 0.9, g = 0.9, b = 0.0 },  -- yellow
    { pct = 10, r = 0.9, g = 0.4, b = 0.0 },  -- orange
    { pct = 15, r = 0.9, g = 0.1, b = 0.1 },  -- red
}

local function GetDTPSBarColor(pctPerSec)
    local stops = BAR_COLOR_STOPS
    if pctPerSec <= stops[1].pct then
        return stops[1].r, stops[1].g, stops[1].b
    end
    for i = 2, #stops do
        if pctPerSec <= stops[i].pct then
            local prev = stops[i - 1]
            local t = (pctPerSec - prev.pct) / (stops[i].pct - prev.pct)
            return prev.r + t * (stops[i].r - prev.r),
                   prev.g + t * (stops[i].g - prev.g),
                   prev.b + t * (stops[i].b - prev.b)
        end
    end
    local last = stops[#stops]
    return last.r, last.g, last.b
end
ns.GetDTPSBarColor = GetDTPSBarColor

-- Tick marks at 5%, 10%, 15%
local TICK_VALUES = { 5, 10, 15 }
local ticks = {}
for i = 1, #TICK_VALUES do
    local tex = bar:CreateTexture(nil, "ARTWORK")
    tex:SetColorTexture(1, 1, 1, 0.5)
    ticks[i] = { tex = tex, value = TICK_VALUES[i] }
end

-- Text overlay
local text = bar:CreateFontString(nil, "OVERLAY")
text:SetFont(GameFontNormal:GetFont(), 11, "OUTLINE")
text:SetPoint("CENTER", bar, "CENTER", 0, 0)
text:SetTextColor(1, 1, 1)

function ns.ApplyDTPSBarFont(path, size, outline)
    -- Per-frame overrides take priority over global font
    local face = ns.db and ns.db.dtpsBarFontFace
    local sz = ns.db and ns.db.dtpsBarFontSize
    local ol = ns.db and ns.db.dtpsBarFontOutline

    if face then path = ns.FindFontPath(face) end
    if sz then size = sz end
    if ol then outline = ol end
    if outline == "NONE" then outline = "" end

    -- Bar text is slightly smaller than stat text
    text:SetFont(path, math.max(size - 3, 8), outline)
end

local function ApplyGrowth(growth)
    if growth == "LEFT" then
        bar:SetOrientation("HORIZONTAL")
        bar:SetReverseFill(true)
    elseif growth == "UP" then
        bar:SetOrientation("VERTICAL")
        bar:SetReverseFill(false)
    elseif growth == "DOWN" then
        bar:SetOrientation("VERTICAL")
        bar:SetReverseFill(true)
    else -- RIGHT (default)
        bar:SetOrientation("HORIZONTAL")
        bar:SetReverseFill(false)
    end
end

local TICK_THICKNESS = 1

local function LayoutTicks(width, height, growth)
    local horizontal = (growth == "RIGHT" or growth == "LEFT")
    local reversed = (growth == "LEFT" or growth == "DOWN")
    local span = horizontal and width or height

    -- Position tick marks
    for _, t in ipairs(ticks) do
        local frac = LogScale(t.value)
        if reversed then frac = 1 - frac end

        t.tex:ClearAllPoints()
        if horizontal then
            local xPos = frac * span
            t.tex:SetPoint("TOPLEFT", bar, "TOPLEFT", xPos - TICK_THICKNESS / 2, 0)
            t.tex:SetSize(TICK_THICKNESS, height)
        else
            local yPos = frac * span
            t.tex:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, yPos - TICK_THICKNESS / 2)
            t.tex:SetSize(width, TICK_THICKNESS)
        end
    end
end

function ns.ApplyDTPSBarSettings()
    if not ns.db then return end
    local db = ns.db

    -- Anchor positioning (retry if target addon hasn't loaded yet)
    local anchorName = db.dtpsBarAnchorFrame or ""
    local anchorTarget = anchorName ~= "" and _G[anchorName] or nil

    if anchorName ~= "" and not anchorTarget then
        local retries = ns._dtpsAnchorRetries or 0
        if retries < 5 then
            ns._dtpsAnchorRetries = retries + 1
            C_Timer.After(1, function() ns.ApplyDTPSBarSettings() end)
        end
        return
    end
    ns._dtpsAnchorRetries = 0

    if anchorTarget then
        local fromPt = db.dtpsBarAnchorFrom or DEFAULTS.dtpsBarAnchorFrom
        local toPt = db.dtpsBarAnchorTo or DEFAULTS.dtpsBarAnchorTo
        local xOff = db.dtpsBarAnchorOffX or DEFAULTS.dtpsBarAnchorOffX
        local yOff = db.dtpsBarAnchorOffY or DEFAULTS.dtpsBarAnchorOffY

        bar:ClearAllPoints()
        bar:SetPoint(fromPt, anchorTarget, toPt, xOff, yOff)
    end

    -- Determine effective width (match target at display time, don't persist)
    local width = db.dtpsBarWidth or DEFAULTS.dtpsBarWidth
    if db.dtpsBarMatchWidth and anchorTarget then
        width = math.floor(anchorTarget:GetWidth() + 0.5)
    end

    bar:SetSize(width, db.dtpsBarHeight or DEFAULTS.dtpsBarHeight)

    local textureName = db.barTexture or "Blizzard Raid Bar"
    local texturePath = FindTexturePath(textureName)
    bar:SetStatusBarTexture(texturePath)
    bg:SetTexture(texturePath)

    local bgc = db.dtpsBarBGColor or DEFAULTS.dtpsBarBGColor
    bg:SetVertexColor(bgc[1], bgc[2], bgc[3], bgc[4] or 0.6)

    local growth = db.dtpsBarGrowth or DEFAULTS.dtpsBarGrowth
    ApplyGrowth(growth)

    LayoutTicks(
        db.dtpsBarWidth or DEFAULTS.dtpsBarWidth,
        db.dtpsBarHeight or DEFAULTS.dtpsBarHeight,
        growth
    )
end

local DTPS_WINDOW = 5

function ns.UpdateDTPSBar()
    if not ns.enabled then return end
    if not ns.db or ns.db.showDTPSBar == false then
        bar:Hide()
        return
    end

    -- Only show in combat
    if not InCombatLockdown() then
        bar:Hide()
        return
    end

    local maxHP = UnitHealthMax("player")
    if maxHP <= 0 then
        bar:Hide()
        return
    end

    local dtps = ns.Tracker.GetDTPS(DTPS_WINDOW)
    local pctPerSec = dtps / maxHP * 100
    local fill = LogScale(pctPerSec)

    bar:SetValue(fill)
    bar:SetStatusBarColor(GetDTPSBarColor(pctPerSec))
    text:SetText(pctPerSec >= 0.1 and format("%.1f%% /s", pctPerSec) or "0.0% /s")
    bar:Show()
end

function ns.ShowDTPSBarPreview()
    if not ns.db or ns.db.showDTPSBar == false then
        bar:Hide()
        return
    end
    ns.ApplyDTPSBarSettings()
    bar:SetValue(LogScale(6)) -- ~6% HP/s preview
    bar:SetStatusBarColor(GetDTPSBarColor(6))
    text:SetText("6.0% /s")
    bar:Show()
end

function ns.HideDTPSBar()
    bar:Hide()
end

function ns.HideDTPSBarPreview()
    -- Return to live state if in combat, otherwise hide
    ns.UpdateDTPSBar()
end
