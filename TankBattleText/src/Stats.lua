local _, ns = ...

-- Color helper
local function Hex(color)
    return format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

-- Short number formatting
local function ShortNumber(n)
    if n >= 1000000 then
        return format("%.1fM", n / 1000000)
    elseif n >= 10000 then
        return format("%.1fK", n / 1000)
    else
        return format("%.0f", n)
    end
end

-- Mitigation color: green = good, yellow = okay, red = bad
local MIT_GREEN  = { 0.2, 1.0, 0.2 }
local MIT_YELLOW = { 1.0, 1.0, 0.0 }
local MIT_ORANGE = { 1.0, 0.5, 0.0 }
local MIT_RED    = { 1.0, 0.2, 0.2 }

local function MitigationColor(pct)
    if pct >= 50 then return MIT_GREEN
    elseif pct >= 30 then return MIT_YELLOW
    elseif pct >= 15 then return MIT_ORANGE
    else return MIT_RED end
end

-- HP% severity colors (for DTPS)
local HP_WHITE  = { 1, 1, 1 }
local HP_YELLOW = { 1, 1, 0 }
local HP_ORANGE = { 1, 0.5, 0 }
local HP_RED    = { 1, 0.2, 0.2 }

local function HPSeverityColor(pct)
    if pct > 30 then return HP_RED
    elseif pct > 15 then return HP_ORANGE
    elseif pct >= 5 then return HP_YELLOW
    else return HP_WHITE end
end

-- DPS color: white → yellow → orange as DPS climbs
local DPS_WHITE  = { 0.8, 0.8, 0.8 }
local DPS_YELLOW = { 1.0, 1.0, 0.4 }
local DPS_ORANGE = { 1.0, 0.6, 0.2 }

local function DPSColor(dps)
    if dps >= 200000 then return DPS_ORANGE
    elseif dps >= 50000 then return DPS_YELLOW
    else return DPS_WHITE end
end

-- Stats frame: side-by-side stats
local statsFrame = CreateFrame("Frame", "TankBattleTextStatsFrame", UIParent)
statsFrame:SetSize(350, 20)
statsFrame:SetPoint("RIGHT", UIParent, "CENTER", -100, 155)

local SPACING = 12

local statFontStrings = {}

function ns.ApplyStatsFont(path, size, outline)
    for _, fs in ipairs(statFontStrings) do
        fs:SetFont(path, size, outline)
    end
end

local DEFAULT_FONT, DEFAULT_SIZE, DEFAULT_FLAGS = GameFontNormal:GetFont(), 14, "OUTLINE"

-- Avoidance
local avoidText = statsFrame:CreateFontString(nil, "OVERLAY")
avoidText:SetFont(DEFAULT_FONT, DEFAULT_SIZE, DEFAULT_FLAGS)
avoidText:SetPoint("LEFT", statsFrame, "LEFT", 0, 0)
avoidText:SetJustifyH("LEFT")
avoidText:Hide()

-- DTPS
local dtpsText = statsFrame:CreateFontString(nil, "OVERLAY")
dtpsText:SetFont(DEFAULT_FONT, DEFAULT_SIZE, DEFAULT_FLAGS)
dtpsText:SetPoint("LEFT", avoidText, "RIGHT", SPACING, 0)
dtpsText:SetJustifyH("LEFT")
dtpsText:SetTextColor(0.8, 0.8, 0.8)
dtpsText:Hide()

-- Rolling DPS
local rollingDpsText = statsFrame:CreateFontString(nil, "OVERLAY")
rollingDpsText:SetFont(DEFAULT_FONT, DEFAULT_SIZE, DEFAULT_FLAGS)
rollingDpsText:SetPoint("LEFT", dtpsText, "RIGHT", SPACING, 0)
rollingDpsText:SetJustifyH("LEFT")
rollingDpsText:SetTextColor(0.8, 0.8, 0.8)
rollingDpsText:Hide()

-- Combat DPS
local combatDpsText = statsFrame:CreateFontString(nil, "OVERLAY")
combatDpsText:SetFont(DEFAULT_FONT, DEFAULT_SIZE, DEFAULT_FLAGS)
combatDpsText:SetPoint("LEFT", rollingDpsText, "RIGHT", SPACING, 0)
combatDpsText:SetJustifyH("LEFT")

statFontStrings = { avoidText, dtpsText, rollingDpsText, combatDpsText }

-- School Split Bar: yellow fill (physical) over purple background (magic)
local splitBar = CreateFrame("StatusBar", "TankBattleTextSchoolSplitBar", UIParent)
splitBar:SetSize(200, 6)
splitBar:SetPoint("RIGHT", UIParent, "CENTER", -100, 140)
splitBar:SetMinMaxValues(0, 1)
splitBar:SetValue(0)
local defaultSplitTexture = (ns.FindTexturePath and ns.FindTexturePath("Blizzard Raid Bar"))
    or "Interface\\Buttons\\WHITE8x8"
splitBar:SetStatusBarTexture(defaultSplitTexture)
splitBar:SetStatusBarColor(1, 0.85, 0) -- yellow = physical

local splitBG = splitBar:CreateTexture(nil, "BACKGROUND")
splitBG:SetAllPoints()
splitBG:SetTexture(defaultSplitTexture)
splitBG:SetVertexColor(0.7, 0.5, 1, 1) -- purple = magic
splitBar:Hide()

function ns.ApplySchoolSplitBarTexture(texturePath)
    splitBar:SetStatusBarTexture(texturePath)
    splitBG:SetTexture(texturePath)
    splitBG:SetVertexColor(0.7, 0.5, 1, 1)
end


-- DTPS border textures around split bar
local borderTextures = {}
for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
    local tex = splitBar:CreateTexture(nil, "BORDER")
    tex:SetColorTexture(0.2, 0.8, 0.2, 1)
    tex:Hide()
    borderTextures[side] = tex
end

local function AnchorBorderTextures(size)
    local top = borderTextures.TOP
    local bottom = borderTextures.BOTTOM
    local left = borderTextures.LEFT
    local right = borderTextures.RIGHT

    top:ClearAllPoints()
    top:SetPoint("BOTTOMLEFT", splitBar, "TOPLEFT", -size, 0)
    top:SetPoint("BOTTOMRIGHT", splitBar, "TOPRIGHT", size, 0)
    top:SetHeight(size)

    bottom:ClearAllPoints()
    bottom:SetPoint("TOPLEFT", splitBar, "BOTTOMLEFT", -size, 0)
    bottom:SetPoint("TOPRIGHT", splitBar, "BOTTOMRIGHT", size, 0)
    bottom:SetHeight(size)

    left:ClearAllPoints()
    left:SetPoint("TOPRIGHT", splitBar, "TOPLEFT", 0, size)
    left:SetPoint("BOTTOMRIGHT", splitBar, "BOTTOMLEFT", 0, -size)
    left:SetWidth(size)

    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", splitBar, "TOPRIGHT", 0, size)
    right:SetPoint("BOTTOMLEFT", splitBar, "BOTTOMRIGHT", 0, -size)
    right:SetWidth(size)
end

local function ShowBorderTextures(size, r, g, b)
    AnchorBorderTextures(size)
    for _, tex in pairs(borderTextures) do
        tex:SetColorTexture(r, g, b, 1)
        tex:Show()
    end
end

local function HideBorderTextures()
    for _, tex in pairs(borderTextures) do
        tex:Hide()
    end
end

combatDpsText:SetTextColor(0.8, 0.8, 0.8)
combatDpsText:Hide()

local DTPS_WINDOW = 5
local ROLLING_DPS_WINDOW = 10

-- Hide readouts when leaving combat
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function()
    if ns.db and ns.db.showAvoid then avoidText:Hide() end
    if ns.db and ns.db.showDTPS then dtpsText:Hide() end
    if ns.db and ns.db.showRollingDPS then rollingDpsText:Hide() end
    -- Combat DPS stays visible briefly after combat ends (keep showing final value)
    if ns.db and ns.db.showCombatDPS then
        -- leave visible — it shows the final combat DPS
    else
        combatDpsText:Hide()
    end

    -- Hide school split bar, border, and DTPS text after delay
    if ns.db and ns.db.showSchoolSplit then
        C_Timer.After(10, function()
            if not InCombatLockdown() then
                splitBar:Hide()
                HideBorderTextures()
            end
        end)
    end

    -- Hide DTPS bar on combat leave
    if ns.HideDTPSBar then
        ns.HideDTPSBar()
    end
end)

function ns.ShowStatsPreview()
    if ns.db and ns.db.showAvoid then
        avoidText:SetText("|cff33ff3342% avoid|r")
        avoidText:Show()
    else
        avoidText:Hide()
    end

    if ns.db and ns.db.showDTPS then
        dtpsText:SetText("|cffcccccc3.1% /s|r")
        dtpsText:Show()
    else
        dtpsText:Hide()
    end

    if ns.db and ns.db.showRollingDPS then
        rollingDpsText:SetText("|cffcccccc45.2K dps|r")
        rollingDpsText:Show()
    else
        rollingDpsText:Hide()
    end

    if ns.db and ns.db.showCombatDPS then
        combatDpsText:SetText("|cffcccccc38.1K overall|r")
        combatDpsText:Show()
    else
        combatDpsText:Hide()
    end

end

function ns.HideStatsPreview()
    if not InCombatLockdown() then
        avoidText:Hide()
        dtpsText:Hide()
        rollingDpsText:Hide()
        combatDpsText:Hide()
    end
end

function ns.UpdateStats()
    if not ns.enabled then return end

    -- Update stat text (guarded by showStats toggle)
    if not ns.db or ns.db.showStats ~= false then
        -- Update avoidance
        if ns.db and ns.db.showAvoid then
            local rate = ns.Tracker.GetMitigationRate()
            local mitColor = MitigationColor(rate)
            avoidText:SetText(format("%s%.0f%% avoid|r", Hex(mitColor), rate))
            avoidText:Show()
        else
            avoidText:Hide()
        end

        -- Update DTPS
        if ns.db and ns.db.showDTPS then
            local maxHP = UnitHealthMax("player")
            if maxHP > 0 then
                local dtps = ns.Tracker.GetDTPS(DTPS_WINDOW)
                local pctPerSec = dtps / maxHP * 100
                if pctPerSec >= 0.1 then
                    local color = HPSeverityColor(pctPerSec * 2)
                    dtpsText:SetText(format("%s%.1f%% /s|r", Hex(color), pctPerSec))
                    dtpsText:Show()
                else
                    dtpsText:Hide()
                end
            else
                dtpsText:Hide()
            end
        else
            dtpsText:Hide()
        end

        -- Update rolling DPS
        if ns.db and ns.db.showRollingDPS then
            local dps = ns.Tracker.GetRollingDPS(ROLLING_DPS_WINDOW)
            if dps >= 1 then
                local color = DPSColor(dps)
                rollingDpsText:SetText(format("%s%s dps|r", Hex(color), ShortNumber(dps)))
                rollingDpsText:Show()
            else
                rollingDpsText:Hide()
            end
        else
            rollingDpsText:Hide()
        end

        -- Update combat DPS
        if ns.db and ns.db.showCombatDPS then
            local dps = ns.Tracker.GetCombatDPS()
            if dps >= 1 then
                local color = DPSColor(dps)
                combatDpsText:SetText(format("%s%s overall|r", Hex(color), ShortNumber(dps)))
                combatDpsText:Show()
            else
                combatDpsText:Hide()
            end
        else
            combatDpsText:Hide()
        end
    end

    -- Bars update independently of stats text visibility
    if ns.UpdateSchoolSplitBar then
        ns.UpdateSchoolSplitBar()
    end
    if ns.UpdateDTPSBar then
        ns.UpdateDTPSBar()
    end
end

-- School split bar: apply anchor/size from saved vars
function ns.ApplySchoolSplitBarSettings()
    if not ns.db then return end
    local db = ns.db

    local anchorName = db.schoolSplitAnchorFrame or ""
    local anchorTarget = anchorName ~= "" and _G[anchorName] or nil

    if anchorName ~= "" and not anchorTarget then
        local retries = ns._splitAnchorRetries or 0
        if retries < 5 then
            ns._splitAnchorRetries = retries + 1
            C_Timer.After(1, function() ns.ApplySchoolSplitBarSettings() end)
        end
        return
    end
    ns._splitAnchorRetries = 0

    if anchorTarget then
        local fromPt = db.schoolSplitAnchorFrom or "TOPLEFT"
        local toPt = db.schoolSplitAnchorTo or "BOTTOMLEFT"
        local pad = db.schoolSplitAnchorPad or 2

        local xOff, yOff = 0, 0
        if toPt:find("TOP") then yOff = pad
        elseif toPt:find("BOTTOM") then yOff = -pad end
        if toPt:find("LEFT") then xOff = -pad
        elseif toPt:find("RIGHT") then xOff = pad end

        splitBar:ClearAllPoints()
        splitBar:SetPoint(fromPt, anchorTarget, toPt, xOff, yOff)
    end

    local width = db.schoolSplitWidth or 200
    if db.schoolSplitMatchWidth and anchorTarget then
        width = math.floor(anchorTarget:GetWidth() + 0.5)
    end

    splitBar:SetSize(width, db.schoolSplitHeight or 6)
end

local function UpdateSplitBarBorder()
    if ns.db and ns.db.showSplitBorder == false then
        HideBorderTextures()
        return
    end

    local maxHP = UnitHealthMax("player")
    if maxHP <= 0 then
        HideBorderTextures()
        return
    end

    local dtps = ns.Tracker.GetDTPS(DTPS_WINDOW)
    local pctPerSec = dtps / maxHP * 100
    local thickness = math.floor(pctPerSec)

    if thickness < 1 then
        HideBorderTextures()
        return
    end

    local r, g, b = ns.GetDTPSBarColor(pctPerSec)
    ShowBorderTextures(thickness, r, g, b)
end

function ns.UpdateSchoolSplitBar()
    if not ns.enabled then return end
    if not ns.db or ns.db.showSchoolSplit == false then
        splitBar:Hide()
        HideBorderTextures()
        return
    end

    -- Don't re-show after combat ends (delayed hide handles it)
    if not InCombatLockdown() and not splitBar:IsShown() then return end

    local physPct, magicPct = ns.Tracker.GetSchoolSplit(DTPS_WINDOW)
    if physPct + magicPct > 0 then
        splitBar:SetValue(physPct / 100)
        splitBar:Show()
        UpdateSplitBarBorder()
    else
        splitBar:Hide()
        HideBorderTextures()
    end
end

function ns.ShowSchoolSplitBarPreview()
    if not ns.db or ns.db.showSchoolSplit == false then
        splitBar:Hide()
        HideBorderTextures()
        return
    end
    ns.ApplySchoolSplitBarSettings()
    splitBar:SetValue(0.62) -- 62% physical preview
    splitBar:Show()

    -- Preview border: simulate ~5% DTPS
    if ns.db.showSplitBorder ~= false then
        local r, g, b = ns.GetDTPSBarColor(5)
        ShowBorderTextures(5, r, g, b)
    else
        HideBorderTextures()
    end
end

function ns.HideSchoolSplitBarPreview()
    ns.UpdateSchoolSplitBar()
end
