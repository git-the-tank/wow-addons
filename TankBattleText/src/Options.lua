local _, ns = ...

-- LibSharedMedia (optional — provides fonts/textures from other addons)
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
ns.LSM = LSM

-- Built-in WoW fonts (fallback when LSM unavailable)
local BUILTIN_FONTS = {
    { name = "Friz Quadrata",   path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow",    path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus",        path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri",          path = "Fonts\\SKURRI.TTF" },
    { name = "2002",            path = "Fonts\\2002.TTF" },
    { name = "2002 Bold",       path = "Fonts\\2002B.TTF" },
}
ns.BUILTIN_FONTS = BUILTIN_FONTS

-- Build font list: LSM fonts if available, otherwise built-ins
local function BuildFontList()
    if LSM then
        local list = LSM:List("font")
        if list and #list > 0 then
            local fonts = {}
            for _, name in ipairs(list) do
                fonts[#fonts + 1] = { name = name, label = name, value = name }
            end
            return fonts
        end
    end
    local fonts = {}
    for _, f in ipairs(BUILTIN_FONTS) do
        fonts[#fonts + 1] = { name = f.name, label = f.name, value = f.name }
    end
    return fonts
end

-- Build texture list: LSM textures if available, otherwise built-ins
local function BuildTextureList()
    if LSM then
        local list = LSM:List("statusbar")
        if list and #list > 0 then
            local textures = {}
            for _, name in ipairs(list) do
                textures[#textures + 1] = { name = name, label = name, value = name }
            end
            return textures
        end
    end
    local textures = {}
    for _, t in ipairs(ns.BAR_TEXTURES) do
        local name = type(t) == "table" and (t.name or t.label) or t
        textures[#textures + 1] = { name = name, label = name, value = name }
    end
    return textures
end

ns.BuildFontList = BuildFontList
ns.BuildTextureList = BuildTextureList

-- Resolve a texture name to a file path (LSM first, then built-ins)
function ns.FindTexturePath(name)
    if LSM and LSM:IsValid("statusbar", name) then
        return LSM:Fetch("statusbar", name)
    end
    for _, t in ipairs(ns.BAR_TEXTURES) do
        if t.name == name then return t.path end
    end
    return ns.BAR_TEXTURES[1].path
end

local OUTLINES = { "NONE", "OUTLINE", "THICKOUTLINE" }

-- Global defaults
local GLOBAL_DEFAULTS = {
    enabled        = true,
    showDamageText = true,
    showStats      = true,
    showAvoid      = true,
    showDTPS       = true,
    showRollingDPS = true,
    showCombatDPS  = true,
    showSchoolSplit = true,
    showDTPSBar    = true,
    showCollapseMode = true,
    fadeTimeVisible = 8,
    schoolSplitWidth       = 200,
    schoolSplitHeight      = 6,
    schoolSplitAnchorFrame = "TankBattleTextStatsFrame",
    schoolSplitAnchorFrom  = "TOPLEFT",
    schoolSplitAnchorTo    = "BOTTOMLEFT",
    schoolSplitAnchorPad   = 2,
    schoolSplitMatchWidth  = true,
    barTexture     = "Blizzard Raid Bar",
    fontFace       = "Friz Quadrata",
    fontSize       = 14,
    fontOutline    = "OUTLINE",
}
ns.GLOBAL_DEFAULTS = GLOBAL_DEFAULTS

-- Apply the global bar texture to all bar frames
function ns.ApplyGlobalBarTexture()
    if not ns.db then return end
    local texturePath = ns.FindTexturePath(ns.db.barTexture or GLOBAL_DEFAULTS.barTexture)
    if ns.ApplyDTPSBarSettings then ns.ApplyDTPSBarSettings() end
    if ns.ApplyDamageBarTexture then ns.ApplyDamageBarTexture(texturePath) end
    if ns.ApplySchoolSplitBarTexture then ns.ApplySchoolSplitBarTexture(texturePath) end
end

function ns.FindFontPath(name)
    if LSM and LSM:IsValid("font", name) then
        return LSM:Fetch("font", name)
    end
    for _, f in ipairs(BUILTIN_FONTS) do
        if f.name == name then return f.path end
    end
    return BUILTIN_FONTS[1].path
end

function ns.ApplyGlobalFont()
    if not ns.db then return end
    local path = ns.FindFontPath(ns.db.fontFace or GLOBAL_DEFAULTS.fontFace)
    local size = ns.db.fontSize or GLOBAL_DEFAULTS.fontSize
    local outline = ns.db.fontOutline or GLOBAL_DEFAULTS.fontOutline
    if outline == "NONE" then outline = "" end

    -- Let each module apply the font to its own elements
    if ns.ApplyDamageFont then ns.ApplyDamageFont(path, size, outline) end
    if ns.ApplyStatsFont then ns.ApplyStatsFont(path, size, outline) end
    if ns.ApplyDTPSBarFont then ns.ApplyDTPSBarFont(path, size, outline) end
    if ns.ApplyCollapseFont then ns.ApplyCollapseFont(path, size, outline) end
end

function ns.ResetDefaults()
    if not ns.db then return end
    for key, val in pairs(GLOBAL_DEFAULTS) do
        if type(val) == "table" then
            ns.db[key] = {unpack(val)}
        else
            ns.db[key] = val
        end
    end
    for key, val in pairs(ns.DTPS_BAR_DEFAULTS) do
        if type(val) == "table" then
            ns.db[key] = {unpack(val)}
        else
            ns.db[key] = val
        end
    end
    ns.enabled = true
    ns.ApplyGlobalBarTexture()
    ns.ApplyDTPSBarSettings()
    ns.ApplySchoolSplitBarSettings()
    ns.ApplyGlobalFont()
    if ns.ApplyFadeDuration then ns.ApplyFadeDuration() end

    TankBattleTextFrame:Show()
    TankBattleTextStatsFrame:Show()
end

------------------------------------------------------------
-- UI Helpers (parameterized by parent + cursor)
------------------------------------------------------------
local function MakeHeader(parent, cur, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 16, cur.y)
    fs:SetText(text)
    cur.y = cur.y - 24
    return fs
end

local function MakeSpacer(cur, h)
    cur.y = cur.y - (h or 10)
end

local function MakeCheckbox(parent, cur, label, getVal, setVal)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, cur.y)
    cb.Text:SetText(label)
    cb:SetScript("OnClick", function(self) setVal(self:GetChecked()) end)
    cb._get = getVal
    cur.y = cur.y - 26
    return cb
end

local function MakeSlider(parent, cur, label, minVal, maxVal, step, getVal, setVal, fmtFn)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 20, cur.y)
    slider:SetSize(180, 17)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(tostring(minVal))
    slider.High:SetText(tostring(maxVal))
    slider.Text:SetText(label)

    local valText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valText:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    local fmt = fmtFn or tostring
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value / step + 0.5) * step
        setVal(value)
        valText:SetText(fmt(value))
    end)

    slider._get = getVal
    slider._valText = valText
    slider._fmt = fmt
    cur.y = cur.y - 42
    return slider
end

local function MakeDropdown(parent, cur, label, options, getVal, setVal)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 16, cur.y)
    fs:SetText(label)
    cur.y = cur.y - 18

    local btn = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    btn:SetPoint("TOPLEFT", 16, cur.y)
    btn:SetWidth(180)

    btn:SetupMenu(function(_, rootDescription)
        local opts = type(options) == "function" and options() or options
        for _, opt in ipairs(opts) do
            local text = type(opt) == "table" and (opt.label or opt.name) or opt
            local value = type(opt) == "table" and opt.value or opt
            rootDescription:CreateRadio(text, function() return getVal() == value end, function()
                setVal(value)
            end)
        end
    end)

    cur.y = cur.y - 30
    return btn
end

local function MakeTextureDropdown(parent, cur, label, getVal, setVal)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 16, cur.y)
    fs:SetText(label)
    cur.y = cur.y - 18

    local btn = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    btn:SetPoint("TOPLEFT", 16, cur.y)
    btn:SetWidth(220)

    btn:SetupMenu(function(_, rootDescription)
        local textures = BuildTextureList()
        for _, opt in ipairs(textures) do
            local texturePath = ns.FindTexturePath(opt.value)
            local radio = rootDescription:CreateRadio(
                opt.label,
                function() return getVal() == opt.value end,
                function() setVal(opt.value) end
            )
            radio:AddInitializer(function(button)
                local rightTexture = button:AttachTexture()
                rightTexture:SetSize(1, 18)
                rightTexture:SetPoint("RIGHT")

                local bgTexture = button:AttachTexture()
                bgTexture:SetTexture(texturePath)
                bgTexture:SetDrawLayer("BACKGROUND")
                bgTexture:SetPoint("LEFT", button.fontString, "LEFT")
                bgTexture:SetPoint("RIGHT", rightTexture, "LEFT")
                bgTexture:SetSize(button.fontString:GetUnboundedStringWidth(), 16)

                button.fontString:SetDrawLayer("OVERLAY")

                local width = button.fontString:GetUnboundedStringWidth() + rightTexture:GetWidth()
                return width, 20
            end)
        end
        rootDescription:SetScrollMode(400)
    end)

    cur.y = cur.y - 30
    return btn
end

------------------------------------------------------------
-- Scrollable panel factory
------------------------------------------------------------
local function CreateScrollPanel()
    local p = CreateFrame("Frame")
    p:Hide()
    local sf = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, -4)
    sf:SetPoint("BOTTOMRIGHT", -26, 4)
    local cont = CreateFrame("Frame", nil, sf)
    cont:SetSize(370, 800)
    sf:SetScrollChild(cont)
    return p, cont
end

------------------------------------------------------------
-- Preview management
------------------------------------------------------------
local allPanels = {}

local function ShowAllPreviews()
    if ns.ShowDamagePreview then ns.ShowDamagePreview() end
    if ns.ShowStatsPreview then ns.ShowStatsPreview() end
    if ns.ShowDTPSBarPreview then ns.ShowDTPSBarPreview() end
    if ns.ShowSchoolSplitBarPreview then ns.ShowSchoolSplitBarPreview() end
end

local function HideAllPreviews()
    C_Timer.After(0.1, function()
        for _, p in ipairs(allPanels) do
            if p:IsShown() then return end
        end
        if ns.HideDamagePreview then ns.HideDamagePreview() end
        if ns.HideStatsPreview then ns.HideStatsPreview() end
        if ns.HideDTPSBarPreview then ns.HideDTPSBarPreview() end
        if ns.HideSchoolSplitBarPreview then ns.HideSchoolSplitBarPreview() end
        end)
end

local function RefreshControls(checkboxes, sliders)
    for _, cb in ipairs(checkboxes) do
        cb:SetChecked(cb._get())
    end
    for _, s in ipairs(sliders or {}) do
        local v = s._get()
        s:SetValue(v)
        s._valText:SetText(s._fmt(v))
    end
end

local function SetupPanel(p, checkboxes, sliders)
    allPanels[#allPanels + 1] = p
    p:SetScript("OnShow", function()
        if not ns.db then return end
        RefreshControls(checkboxes, sliders)
        ShowAllPreviews()
    end)
    p:SetScript("OnHide", function()
        HideAllPreviews()
    end)
end

------------------------------------------------------------
-- Panel 1: General
------------------------------------------------------------
local generalPanel, gc_content = CreateScrollPanel()
local gc = { y = -16 }

MakeHeader(gc_content, gc, "TankBattleText")
MakeSpacer(gc, 4)

local enabledCB = MakeCheckbox(gc_content, gc, "Enabled",
    function() return ns.enabled end,
    function(v) ns.enabled = v end)

MakeSpacer(gc, 8)
MakeHeader(gc_content, gc, "Appearance")

MakeTextureDropdown(gc_content, gc, "Bar Texture",
    function() return ns.db and ns.db.barTexture or GLOBAL_DEFAULTS.barTexture end,
    function(v) if ns.db then ns.db.barTexture = v; ns.ApplyGlobalBarTexture() end end)

MakeSpacer(gc, 8)
MakeHeader(gc_content, gc, "Typography")

MakeDropdown(gc_content, gc, "Font", BuildFontList,
    function() return ns.db and ns.db.fontFace or GLOBAL_DEFAULTS.fontFace end,
    function(v) if ns.db then ns.db.fontFace = v; ns.ApplyGlobalFont() end end)

local fontSizeSlider = MakeSlider(gc_content, gc, "Font Size", 8, 24, 1,
    function() return ns.db and ns.db.fontSize or GLOBAL_DEFAULTS.fontSize end,
    function(v) if ns.db then ns.db.fontSize = v; ns.ApplyGlobalFont() end end,
    function(v) return string.format("%d pt", v) end)

MakeDropdown(gc_content, gc, "Outline", OUTLINES,
    function() return ns.db and ns.db.fontOutline or GLOBAL_DEFAULTS.fontOutline end,
    function(v) if ns.db then ns.db.fontOutline = v; ns.ApplyGlobalFont() end end)

MakeSpacer(gc, 16)
local defaultsBtn = CreateFrame("Button", nil, gc_content, "UIPanelButtonTemplate")
defaultsBtn:SetPoint("TOPLEFT", 16, gc.y)
defaultsBtn:SetSize(140, 24)
defaultsBtn:SetText("Reset to Defaults")
defaultsBtn:SetScript("OnClick", function() StaticPopup_Show("TBT_RESET_DEFAULTS") end)
gc.y = gc.y - 32

StaticPopupDialogs["TBT_RESET_DEFAULTS"] = {
    text = "Reset all TankBattleText settings to defaults?",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function() ns.ResetDefaults() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

gc_content:SetHeight(math.abs(gc.y) + 16)
SetupPanel(generalPanel, { enabledCB }, { fontSizeSlider })

------------------------------------------------------------
-- Panel 2: Damage Text
------------------------------------------------------------
local damagePanel, dc_content = CreateScrollPanel()
local dc = { y = -16 }

MakeHeader(dc_content, dc, "Damage Text")
MakeSpacer(dc, 4)

local showDamageCB = MakeCheckbox(dc_content, dc, "Show Damage Text",
    function() return ns.db and ns.db.showDamageText end,
    function(v) ns.db.showDamageText = v; if v then TankBattleTextFrame:Show() else TankBattleTextFrame:Hide() end end)

local collapseCB = MakeCheckbox(dc_content, dc, "Collapse Routine Hits",
    function() return ns.db and ns.db.showCollapseMode ~= false end,
    function(v) ns.db.showCollapseMode = v end)

local collapseFontSlider = MakeSlider(dc_content, dc, "Collapse Font Size", 8, 24, 1,
    function() return ns.db and (ns.db.collapseFontSize or ns.db.fontSize or GLOBAL_DEFAULTS.fontSize) end,
    function(v) if ns.db then ns.db.collapseFontSize = v; ns.ApplyGlobalFont() end end,
    function(v) return string.format("%d pt", v) end)

local fadeSlider = MakeSlider(dc_content, dc, "Display Duration", 2, 15, 1,
    function() return ns.db and (ns.db.fadeTimeVisible or 4) end,
    function(v) if ns.db then ns.db.fadeTimeVisible = v; if ns.ApplyFadeDuration then ns.ApplyFadeDuration() end end end,
    function(v) return string.format("%d sec", v) end)

dc_content:SetHeight(math.abs(dc.y) + 16)
SetupPanel(damagePanel, { showDamageCB, collapseCB }, { collapseFontSlider, fadeSlider })

------------------------------------------------------------
-- Panel 3: Stats
------------------------------------------------------------
local statsPanel, sc_content = CreateScrollPanel()
local sc = { y = -16 }

MakeHeader(sc_content, sc, "Tank Stats")
MakeSpacer(sc, 4)

local showStatsCB = MakeCheckbox(sc_content, sc, "Show Stats Frame",
    function() return ns.db and ns.db.showStats end,
    function(v) ns.db.showStats = v; if v then TankBattleTextStatsFrame:Show() else TankBattleTextStatsFrame:Hide() end end)

local showAvoidCB = MakeCheckbox(sc_content, sc, "Avoidance",
    function() return ns.db and ns.db.showAvoid end,
    function(v) ns.db.showAvoid = v; ns.UpdateStats() end)

local showDTPSCB = MakeCheckbox(sc_content, sc, "DTPS",
    function() return ns.db and ns.db.showDTPS end,
    function(v) ns.db.showDTPS = v; ns.UpdateStats() end)

local showRollingCB = MakeCheckbox(sc_content, sc, "Rolling DPS",
    function() return ns.db and ns.db.showRollingDPS end,
    function(v) ns.db.showRollingDPS = v; ns.UpdateStats() end)

local showCombatCB = MakeCheckbox(sc_content, sc, "Combat DPS",
    function() return ns.db and ns.db.showCombatDPS end,
    function(v) ns.db.showCombatDPS = v; ns.UpdateStats() end)

sc_content:SetHeight(math.abs(sc.y) + 16)
SetupPanel(statsPanel, { showStatsCB, showAvoidCB, showDTPSCB, showRollingCB, showCombatCB }, {})

------------------------------------------------------------
-- Panel 4: DTPS Bar
------------------------------------------------------------
local dtpsPanel, dtc_content = CreateScrollPanel()
local dtc = { y = -16 }

MakeHeader(dtc_content, dtc, "DTPS Bar")
MakeSpacer(dtc, 4)

local showBarCB = MakeCheckbox(dtc_content, dtc, "Show DTPS Bar",
    function() return ns.db and ns.db.showDTPSBar end,
    function(v) ns.db.showDTPSBar = v; if v then ns.ApplyDTPSBarSettings() else TankBattleTextDTPSBar:Hide() end end)

MakeSpacer(dtc, 8)
MakeHeader(dtc_content, dtc, "Position Offset")

local dtpsOffXSlider = MakeSlider(dtc_content, dtc, "X Offset", -1000, 1000, 1,
    function() return ns.db and (ns.db.dtpsBarAnchorOffX or ns.DTPS_BAR_DEFAULTS.dtpsBarAnchorOffX) end,
    function(v) if ns.db then ns.db.dtpsBarAnchorOffX = v; ns.ApplyDTPSBarSettings() end end,
    function(v) return string.format("%d", v) end)

local dtpsOffYSlider = MakeSlider(dtc_content, dtc, "Y Offset", -1000, 1000, 1,
    function() return ns.db and (ns.db.dtpsBarAnchorOffY or ns.DTPS_BAR_DEFAULTS.dtpsBarAnchorOffY) end,
    function(v) if ns.db then ns.db.dtpsBarAnchorOffY = v; ns.ApplyDTPSBarSettings() end end,
    function(v) return string.format("%d", v) end)

dtc_content:SetHeight(math.abs(dtc.y) + 16)
SetupPanel(dtpsPanel, { showBarCB }, { dtpsOffXSlider, dtpsOffYSlider })

------------------------------------------------------------
-- Panel 5: Split Bar
------------------------------------------------------------
local splitPanel, spc_content = CreateScrollPanel()
local spc = { y = -16 }

MakeHeader(spc_content, spc, "Damage Split")
MakeSpacer(spc, 4)

local showSplitCB = MakeCheckbox(spc_content, spc, "Show Damage Split",
    function() return ns.db and ns.db.showSchoolSplit end,
    function(v) ns.db.showSchoolSplit = v; if v then ns.ApplySchoolSplitBarSettings() else TankBattleTextSchoolSplitBar:Hide() end end)

local showBorderCB = MakeCheckbox(spc_content, spc, "Show DTPS Border",
    function() return ns.db and ns.db.showSplitBorder end,
    function(v) ns.db.showSplitBorder = v; if ns.ShowSchoolSplitBarPreview then ns.ShowSchoolSplitBarPreview() end end)

spc_content:SetHeight(math.abs(spc.y) + 16)
SetupPanel(splitPanel, { showSplitCB, showBorderCB }, {})

------------------------------------------------------------
-- Register categories
------------------------------------------------------------
local mainCategory = Settings.RegisterCanvasLayoutCategory(generalPanel, "TankBattleText")
Settings.RegisterAddOnCategory(mainCategory)
ns.settingsCategoryID = mainCategory:GetID()

Settings.RegisterCanvasLayoutSubcategory(mainCategory, damagePanel, "Damage Text")
Settings.RegisterCanvasLayoutSubcategory(mainCategory, statsPanel, "Stats")
Settings.RegisterCanvasLayoutSubcategory(mainCategory, dtpsPanel, "DTPS Bar")
Settings.RegisterCanvasLayoutSubcategory(mainCategory, splitPanel, "Split Bar")
