local _, ns = ...

------------------------------------------------------------
-- Constants
------------------------------------------------------------
local FONT_PATH = "Interface\\AddOns\\GitRaidTools\\font\\dejavu-sans-mono-bold.TTF"

-- T uses a smaller font so it matches the visual height of the other glyphs
local SYMBOLS = {
    { char = "●", fontScale = 1.0, color = { 1.0, 0.5, 0.0 } },   -- Circle (orange)
    { char = "x", fontScale = 1.0, color = { 1.0, 0.2, 0.2 } },   -- Cross (red)
    { char = "▼", fontScale = 1.0, color = { 0.2, 1.0, 0.3 } },   -- Triangle (green)
    { char = "T", fontScale = 0.75, color = { 1.0, 1.0, 1.0 } },  -- Skull (white)
    { char = "◆", fontScale = 1.0, color = { 0.7, 0.3, 1.0 } },   -- Diamond (purple)
}
local MAX_SLOTS = #SYMBOLS

local DISPLAY_SIZE = 48
local DISPLAY_FONT = 36
local BUTTON_SIZE = 28
local BUTTON_FONT = 18
local SPACING = 4
local PADDING = 8

-- Colors
local MUTED = { 0.5, 0.5, 0.5 }       -- button row (subdued)
local DIM = { 0.3, 0.3, 0.3 }          -- unfilled placeholder

------------------------------------------------------------
-- State
------------------------------------------------------------
local sequence = {}
local editModeActive = false

------------------------------------------------------------
-- Frame
------------------------------------------------------------
local lura = CreateFrame("Frame", "GitRaidToolsLura", UIParent)
lura:SetFrameStrata("MEDIUM")
lura:SetPoint("CENTER")
lura:Hide()
lura:EnableMouse(true)
lura:SetMovable(true)
lura:SetClampedToScreen(true)

-- Background
local bg = lura:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.7)

------------------------------------------------------------
-- Dragging
------------------------------------------------------------
local function UpdateDraggable()
    if not ns.db then return end
    if ns.db.luraLocked then
        lura:RegisterForDrag()
    else
        lura:RegisterForDrag("LeftButton")
    end
end
ns.UpdateLuraDraggable = UpdateDraggable

lura:SetScript("OnDragStart", function(self)
    if ns.db and ns.db.luraLocked then return end
    self:StartMoving()
end)
lura:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if ns.db then
        local point, _, _, x, y = self:GetPoint(1)
        ns.db.luraPos = { point = point, x = x, y = y }
    end
end)

------------------------------------------------------------
-- Top row: large sequence display slots
------------------------------------------------------------
local displaySlots = {}

for i = 1, MAX_SLOTS do
    local slot = CreateFrame("Frame", nil, lura)
    slot:SetSize(DISPLAY_SIZE, DISPLAY_SIZE)
    if i == 1 then
        slot:SetPoint("TOPLEFT", lura, "TOPLEFT", PADDING, -PADDING)
    else
        slot:SetPoint("LEFT", displaySlots[i - 1], "RIGHT", SPACING, 0)
    end

    local slotBg = slot:CreateTexture(nil, "BACKGROUND", nil, 1)
    slotBg:SetAllPoints()
    slotBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    local text = slot:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT_PATH, DISPLAY_FONT, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetText(".")
    text:SetTextColor(DIM[1], DIM[2], DIM[3])

    slot.text = text
    displaySlots[i] = slot
end

------------------------------------------------------------
-- Bottom row: small clickable buttons + reset
------------------------------------------------------------
local buttons = {}

for i = 1, MAX_SLOTS do
    local btn = CreateFrame("Button", nil, lura)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    if i == 1 then
        btn:SetPoint("TOPLEFT", displaySlots[1], "BOTTOMLEFT", 0, -SPACING)
    else
        btn:SetPoint("LEFT", buttons[i - 1], "RIGHT", SPACING, 0)
    end

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints()
    btnBg:SetColorTexture(0.15, 0.15, 0.15, 1)

    local label = btn:CreateFontString(nil, "OVERLAY")
    local btnFont = math.floor(BUTTON_FONT * SYMBOLS[i].fontScale + 0.5)
    label:SetFont(FONT_PATH, btnFont, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(SYMBOLS[i].char)
    label:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

    btn:SetScript("OnEnter", function()
        btnBg:SetColorTexture(0.3, 0.3, 0.3, 1)
    end)
    btn:SetScript("OnLeave", function()
        btnBg:SetColorTexture(0.15, 0.15, 0.15, 1)
    end)
    btn:SetScript("OnClick", function()
        if #sequence >= MAX_SLOTS then return end
        table.insert(sequence, i)
        ns.UpdateLuraDisplay()
    end)

    buttons[i] = btn
end

-- Reset button (right side of button row)
local resetBtn = CreateFrame("Button", nil, lura)
resetBtn:SetSize(BUTTON_SIZE * 2, BUTTON_SIZE)
resetBtn:SetPoint("LEFT", buttons[MAX_SLOTS], "RIGHT", SPACING * 2, 0)

local resetBg = resetBtn:CreateTexture(nil, "BACKGROUND")
resetBg:SetAllPoints()
resetBg:SetColorTexture(0.3, 0.05, 0.05, 1)

local resetLabel = resetBtn:CreateFontString(nil, "OVERLAY")
resetLabel:SetFont(FONT_PATH, BUTTON_FONT, "OUTLINE")
resetLabel:SetPoint("CENTER")
resetLabel:SetText("R")
resetLabel:SetTextColor(1, 0.3, 0.3)

resetBtn:SetScript("OnEnter", function()
    resetBg:SetColorTexture(0.5, 0.1, 0.1, 1)
end)
resetBtn:SetScript("OnLeave", function()
    resetBg:SetColorTexture(0.3, 0.05, 0.05, 1)
end)
resetBtn:SetScript("OnClick", function()
    wipe(sequence)
    ns.UpdateLuraDisplay()
end)

------------------------------------------------------------
-- Sizing
------------------------------------------------------------
local displayRowW = (MAX_SLOTS * DISPLAY_SIZE) + ((MAX_SLOTS - 1) * SPACING)
local buttonRowW = (MAX_SLOTS * BUTTON_SIZE) + ((MAX_SLOTS - 1) * SPACING) + (SPACING * 2) + (BUTTON_SIZE * 2)
local panelW = PADDING + math.max(displayRowW, buttonRowW) + PADDING
local panelH = PADDING + DISPLAY_SIZE + SPACING + BUTTON_SIZE + PADDING
lura:SetSize(panelW, panelH)

------------------------------------------------------------
-- Display update
------------------------------------------------------------
function ns.UpdateLuraDisplay()
    for i = 1, MAX_SLOTS do
        local slot = displaySlots[i]
        if sequence[i] then
            local sym = SYMBOLS[sequence[i]]
            slot.text:SetFont(FONT_PATH, math.floor(DISPLAY_FONT * sym.fontScale + 0.5), "OUTLINE")
            slot.text:SetText(sym.char)
            slot.text:SetTextColor(sym.color[1], sym.color[2], sym.color[3])
        else
            slot.text:SetFont(FONT_PATH, DISPLAY_FONT, "OUTLINE")
            slot.text:SetText(".")
            slot.text:SetTextColor(DIM[1], DIM[2], DIM[3])
        end
    end
end

------------------------------------------------------------
-- Scale — preserves visual center when changing scale
------------------------------------------------------------
function ns.ApplyLuraScale()
    if not ns.db then return end
    local scale = (ns.db.luraScale or ns.CONFIG.luraScale) / 100
    if scale <= 0 then scale = 1 end

    -- GetCenter returns UIParent-space coords (unscaled)
    local cx, cy = lura:GetCenter()
    lura:SetScale(scale)
    if cx and cy then
        -- SetPoint offsets are in the frame's scaled space, so divide by scale
        lura:ClearAllPoints()
        lura:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
        local point, _, _, x, y = lura:GetPoint(1)
        ns.db.luraPos = { point = point, x = x, y = y }
    end
end

------------------------------------------------------------
-- Visibility
------------------------------------------------------------
function ns.EvaluateLuraVisibility()
    if not ns.db then return end
    if ns.db.luraEnabled == false then
        lura:Hide()
        return
    end
    if editModeActive then
        lura:Show()
        return
    end
    if ns.db.luraShown then
        lura:Show()
    else
        lura:Hide()
    end
end

function ns.ToggleLura()
    if not ns.db then return end
    ns.db.luraShown = not ns.db.luraShown
    ns.EvaluateLuraVisibility()
    if ns.db.luraShown then
        print("|cff00ccffGRT:|r L'ura helper shown")
    else
        print("|cff00ccffGRT:|r L'ura helper hidden")
    end
end

------------------------------------------------------------
-- Position restore
------------------------------------------------------------
local function RestorePosition()
    if not ns.db then return end
    local scale = (ns.db.luraScale or ns.CONFIG.luraScale) / 100
    if scale <= 0 then scale = 1 end
    lura:SetScale(scale)

    if ns.db.luraPos then
        local pos = ns.db.luraPos
        lura:ClearAllPoints()
        lura:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end
end

------------------------------------------------------------
-- Init
------------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    RestorePosition()
    UpdateDraggable()
    ns.EvaluateLuraVisibility()

    -- LibEditMode
    local LibEditMode = LibStub("LibEditMode")

    LibEditMode:AddFrame(lura, function(_, _, point, x, y)
        if ns.db then
            ns.db.luraPos = { point = point, x = x, y = y }
        end
    end, { point = "CENTER", x = 0, y = 0 }, "GRT: L'ura Helper")

    LibEditMode:AddFrameSettings(lura, {
        {
            name = "Scale",
            kind = LibEditMode.SettingType.Slider,
            default = ns.CONFIG.luraScale,
            get = function() return ns.db and ns.db.luraScale or ns.CONFIG.luraScale end,
            set = function(_, value)
                if ns.db then
                    ns.db.luraScale = math.floor(value + 0.5)
                    ns.ApplyLuraScale()
                end
            end,
            minValue = 20,
            maxValue = 300,
            valueStep = 10,
            formatter = function(value) return string.format("%d%%", value) end,
        },
    })

    LibEditMode:RegisterCallback("enter", function()
        editModeActive = true
        lura:Show()
    end)
    LibEditMode:RegisterCallback("exit", function()
        editModeActive = false
        ns.EvaluateLuraVisibility()
    end)
end)
