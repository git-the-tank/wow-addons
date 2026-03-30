local _, ns = ...

-- LibSharedMedia (optional — provides fonts from other addons)
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Built-in WoW fonts (fallback when LSM unavailable)
local BUILTIN_FONTS = {
    { name = "Friz Quadrata",   path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow",    path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus",        path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri",          path = "Fonts\\SKURRI.TTF" },
    { name = "2002",            path = "Fonts\\2002.TTF" },
    { name = "2002 Bold",       path = "Fonts\\2002B.TTF" },
}

local function BuildFontList()
    local fonts = {}
    if LSM then
        local list = LSM:List("font")
        if list and #list > 0 then
            for _, name in ipairs(list) do
                fonts[#fonts + 1] = { name = name, value = name }
            end
            table.sort(fonts, function(a, b) return a.name:lower() < b.name:lower() end)
            return fonts
        end
    end
    for _, f in ipairs(BUILTIN_FONTS) do
        fonts[#fonts + 1] = { name = f.name, value = f.name }
    end
    table.sort(fonts, function(a, b) return a.name:lower() < b.name:lower() end)
    return fonts
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

local DAY_NAMES = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

------------------------------------------------------------
-- UI Helpers
------------------------------------------------------------
local function MakeHeader(parent, cur, label)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 16, cur.y)
    fs:SetText(label)
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
            local optLabel = type(opt) == "table" and (opt.label or opt.name) or opt
            local value = type(opt) == "table" and opt.value or opt
            rootDescription:CreateRadio(optLabel, function() return getVal() == value end, function()
                setVal(value)
            end)
        end
    end)

    cur.y = cur.y - 30
    return btn
end

local function MakeFontDropdown(parent, cur, label, getVal, setVal)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 16, cur.y)
    fs:SetText(label)
    cur.y = cur.y - 18

    local btn = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    btn:SetPoint("TOPLEFT", 16, cur.y)
    btn:SetWidth(220)

    btn:SetupMenu(function(_, rootDescription)
        local fonts = BuildFontList()
        for _, opt in ipairs(fonts) do
            rootDescription:CreateRadio(
                opt.name,
                function() return getVal() == opt.value end,
                function() setVal(opt.value) end
            )
        end
        rootDescription:SetScrollMode(400)
    end)

    cur.y = cur.y - 30
    return btn
end

local function MakeLabel(parent, cur, label)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 20, cur.y)
    fs:SetText(label)
    cur.y = cur.y - 16
    return fs
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
-- Panel management
------------------------------------------------------------
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

local function SetupPanel(p, checkboxes, sliders, onShowExtra)
    p:SetScript("OnShow", function()
        if not ns.db then return end
        RefreshControls(checkboxes, sliders)
        if onShowExtra then onShowExtra() end
    end)
end

-- Helper: format hour as "HH (h AM/PM)"
local function FormatHour(h)
    if h == 0 then return "00 (12 AM)"
    elseif h < 12 then return string.format("%02d (%d AM)", h, h)
    elseif h == 12 then return "12 (12 PM)"
    else return string.format("%02d (%d PM)", h, h - 12)
    end
end

------------------------------------------------------------
-- Panel 1: General
------------------------------------------------------------
local generalPanel, gc = CreateScrollPanel()
local gy = { y = -16 }

MakeHeader(gc, gy, "Git's Raid Tools")
MakeSpacer(gy, 4)

local mutedCB = MakeCheckbox(gc, gy, "Mute Announcements (raid/guild/instance)",
    function() return ns.db and ns.db.muted == true end,
    function(v) if ns.db then ns.db.muted = v end end)

MakeSpacer(gy, 8)
MakeHeader(gc, gy, "Raid Schedule")
MakeSpacer(gy, 4)

local hourSlider = MakeSlider(gc, gy, "Raid Start Hour", 0, 23, 1,
    function() return ns.db and ns.db.raidHour or ns.CONFIG.raidHour end,
    function(v) if ns.db then ns.db.raidHour = v end end,
    FormatHour)

local minuteSlider = MakeSlider(gc, gy, "Raid Start Minute", 0, 55, 5,
    function() return ns.db and ns.db.raidMinute or ns.CONFIG.raidMinute end,
    function(v) if ns.db then ns.db.raidMinute = v end end,
    function(v) return string.format(":%02d", v) end)

MakeSpacer(gy, 8)
MakeHeader(gc, gy, "Raid Days")
MakeSpacer(gy, 4)

local dayCBs = {}
for i = 1, 7 do
    local dayIdx = i
    dayCBs[i] = MakeCheckbox(gc, gy, DAY_NAMES[i],
        function()
            if not ns.db then return false end
            local days = ns.db.raidDays or ns.CONFIG.raidDays
            for _, d in ipairs(days) do
                if d == dayIdx then return true end
            end
            return false
        end,
        function(checked)
            if not ns.db then return end
            local days = ns.db.raidDays
            if not days then
                days = {}
                for _, d in ipairs(ns.CONFIG.raidDays) do days[#days + 1] = d end
                ns.db.raidDays = days
            end
            if checked then
                for _, d in ipairs(days) do
                    if d == dayIdx then return end
                end
                days[#days + 1] = dayIdx
            else
                for j = #days, 1, -1 do
                    if days[j] == dayIdx then
                        table.remove(days, j)
                    end
                end
            end
        end)
end

MakeSpacer(gy, 8)
MakeHeader(gc, gy, "Typography")
MakeSpacer(gy, 4)

MakeFontDropdown(gc, gy, "Font",
    function() return ns.db and ns.db.fontFace or ns.CONFIG.fontFace end,
    function(v)
        if ns.db then
            ns.db.fontFace = v
            if ns.ApplyCountdownFont then ns.ApplyCountdownFont() end
        end
    end)

gc:SetHeight(math.abs(gy.y) + 16)
local allGeneralCBs = { mutedCB }
for _, cb in ipairs(dayCBs) do allGeneralCBs[#allGeneralCBs + 1] = cb end
SetupPanel(generalPanel, allGeneralCBs, { hourSlider, minuteSlider })

------------------------------------------------------------
-- Panel 2: Invites
------------------------------------------------------------
local invitePanel, ic = CreateScrollPanel()
local iy = { y = -16 }

MakeHeader(ic, iy, "Invites")
MakeSpacer(iy, 4)

local inviteEnabledCB = MakeCheckbox(ic, iy, "Enable Invite Commands",
    function() return ns.db and ns.db.invitesEnabled ~= false end,
    function(v) if ns.db then ns.db.invitesEnabled = v end end)

MakeSpacer(iy, 8)
MakeHeader(ic, iy, "Auto-Invite")
MakeSpacer(iy, 4)

local autoInviteCB = MakeCheckbox(ic, iy, "Automatically send invite before raid",
    function() return ns.db and ns.db.autoInviteEnabled == true end,
    function(v) if ns.db then ns.db.autoInviteEnabled = v end end)

local autoInviteSlider = MakeSlider(ic, iy, "Minutes Before Raid", 5, 60, 5,
    function() return ns.db and ns.db.autoInviteMinutes or ns.CONFIG.autoInviteMinutes end,
    function(v) if ns.db then ns.db.autoInviteMinutes = v end end,
    function(v) return string.format("%d min", v) end)

MakeSpacer(iy, 8)
MakeHeader(ic, iy, "Commands")
MakeSpacer(iy, 4)

MakeLabel(ic, iy, "/grt inv [n]  — Send invite to guild chat")
MakeLabel(ic, iy, "/grt render [n]  — Preview invite locally")
MakeLabel(ic, iy, "/grt flavor  — Copyable flavor list")
MakeLabel(ic, iy, "/grt unseen  — Show pool status")
MakeLabel(ic, iy, "/grt clear  — Reset unseen pool")

MakeSpacer(iy, 8)
MakeHeader(ic, iy, "Flavor Text")
MakeSpacer(iy, 4)

MakeLabel(ic, iy, "|cff888888Checked = in rotation, Unchecked = skipped|r")
MakeSpacer(iy, 4)

-- Create flavor text checkboxes
local flavorCBs = {}
local variations = ns.VARIATIONS or {}
for i, variation in ipairs(variations) do
    local varIdx = i
    local label = "[" .. (i - 1) .. "] " .. table.concat(variation, " | ")
    local cb = CreateFrame("CheckButton", nil, ic, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, iy.y)
    cb.Text:SetFontObject(GameFontHighlightSmall)
    cb.Text:SetText(label)
    cb.Text:SetWidth(310)
    cb.Text:SetWordWrap(true)
    cb._get = function()
        if not ns.GetUnseenSet then return true end
        return ns.GetUnseenSet()[varIdx] == true
    end
    cb:SetScript("OnClick", function(self)
        if ns.SetVariationUnseen then
            ns.SetVariationUnseen(varIdx, self:GetChecked())
        end
    end)
    flavorCBs[i] = cb
    iy.y = iy.y - 26
end

local function RefreshFlavorCBs()
    if not ns.GetUnseenSet then return end
    local unseenSet = ns.GetUnseenSet()
    for i, cb in ipairs(flavorCBs) do
        cb:SetChecked(unseenSet[i] == true)
    end
end

ic:SetHeight(math.abs(iy.y) + 16)
SetupPanel(invitePanel, { inviteEnabledCB, autoInviteCB }, { autoInviteSlider }, RefreshFlavorCBs)

------------------------------------------------------------
-- Panel 3: Countdown
------------------------------------------------------------
local countdownPanel, cc = CreateScrollPanel()
local cy = { y = -16 }

MakeHeader(cc, cy, "Countdown")
MakeSpacer(cy, 4)

local windowSlider = MakeSlider(cc, cy, "Countdown Start", 5, 120, 5,
    function() return ns.db and ns.db.countdownWindow or ns.CONFIG.countdownWindow end,
    function(v) if ns.db then ns.db.countdownWindow = v end end,
    function(v) return string.format("%d min before", v) end)

MakeSpacer(cy, 8)

MakeSpacer(cy, 8)
MakeHeader(cc, cy, "Broadcast")
MakeSpacer(cy, 4)

local broadcastInstanceCB = MakeCheckbox(cc, cy, "Instance Chat",
    function() return ns.db and ns.db.broadcastInstance == true end,
    function(v) if ns.db then ns.db.broadcastInstance = v end end)

local broadcastGuildCB = MakeCheckbox(cc, cy, "Guild Chat",
    function() return ns.db and ns.db.broadcastGuild == true end,
    function(v) if ns.db then ns.db.broadcastGuild = v end end)

local milestoneCB = MakeCheckbox(cc, cy, "Milestone broadcasts (10m, 5m, 2m, pull)",
    function() return ns.db and ns.db.milestoneAnnounce == true end,
    function(v) if ns.db then ns.db.milestoneAnnounce = v end end)

MakeSpacer(cy, 8)
MakeHeader(cc, cy, "Ticker")
MakeSpacer(cy, 4)

local STRATA_OPTIONS = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }

MakeDropdown(cc, cy, "Frame Strata",
    STRATA_OPTIONS,
    function() return ns.db and ns.db.tickerStrata or ns.CONFIG.tickerStrata end,
    function(v)
        if ns.db then
            ns.db.tickerStrata = v
            if ns.ApplyTickerStrata then ns.ApplyTickerStrata() end
        end
    end)

MakeSpacer(cy, 8)

local fontSizeSlider = MakeSlider(cc, cy, "Font Size", 14, 100, 1,
    function() return ns.db and ns.db.countdownFontSize or ns.CONFIG.countdownFontSize end,
    function(v)
        if ns.db then
            ns.db.countdownFontSize = v
            if ns.ApplyCountdownFont then ns.ApplyCountdownFont() end
        end
    end,
    function(v) return string.format("%d pt", v) end)

cc:SetHeight(math.abs(cy.y) + 16)
SetupPanel(countdownPanel, { broadcastInstanceCB, broadcastGuildCB, milestoneCB }, { windowSlider, fontSizeSlider })

------------------------------------------------------------
-- Panel 4: Dispatch
------------------------------------------------------------
local dispatchPanel, dc = CreateScrollPanel()
local dy = { y = -16 }

MakeHeader(dc, dy, "Dispatch Status")
MakeSpacer(dy, 4)

MakeLabel(dc, dy, "|cff888888Shows checkmarks for automated raid-day actions|r")
MakeSpacer(dy, 4)

local dispatchEnabledCB = MakeCheckbox(dc, dy, "Enable Dispatch Display",
    function() return ns.db and ns.db.dispatchEnabled ~= false end,
    function(v)
        if ns.db then
            ns.db.dispatchEnabled = v
            if ns.EvaluateDispatchVisibility then ns.EvaluateDispatchVisibility() end
        end
    end)

MakeSpacer(dy, 8)
MakeHeader(dc, dy, "RC Rotate")
MakeSpacer(dy, 4)

local rcRotateEnabledCB = MakeCheckbox(dc, dy, "Auto-trigger /rc rotate at raid start",
    function() return ns.db and ns.db.rcRotateEnabled == true end,
    function(v) if ns.db then ns.db.rcRotateEnabled = v end end)

MakeLabel(dc, dy, "|cff888888Requires RCLootCouncil + CouncilRotation addon|r")

MakeSpacer(dy, 8)
MakeHeader(dc, dy, "Typography")
MakeSpacer(dy, 4)

MakeFontDropdown(dc, dy, "Font",
    function() return ns.db and ns.db.dispatchFontFace or ns.CONFIG.dispatchFontFace end,
    function(v)
        if ns.db then
            ns.db.dispatchFontFace = v
            if ns.ApplyDispatchFont then ns.ApplyDispatchFont() end
        end
    end)

local dispatchFontSizeSlider = MakeSlider(dc, dy, "Font Size", 10, 40, 1,
    function() return ns.db and ns.db.dispatchFontSize or ns.CONFIG.dispatchFontSize end,
    function(v)
        if ns.db then
            ns.db.dispatchFontSize = v
            if ns.ApplyDispatchFont then ns.ApplyDispatchFont() end
        end
    end,
    function(v) return string.format("%d pt", v) end)

MakeSpacer(dy, 12)
MakeHeader(dc, dy, "Preview")
MakeSpacer(dy, 4)

local testBtn = CreateFrame("Button", nil, dc, "UIPanelButtonTemplate")
testBtn:SetPoint("TOPLEFT", 16, dy.y)
testBtn:SetSize(120, 24)
testBtn:SetText("Test Mode")
testBtn:SetScript("OnClick", function()
    if ns.testMode then
        if ns.ExitTestMode then ns.ExitTestMode() end
    else
        if ns.EnterTestMode then ns.EnterTestMode() end
    end
end)
dy.y = dy.y - 28

MakeLabel(dc, dy, "|cff888888Shows ticker + dispatch for 15s, cycles through states|r")

dc:SetHeight(math.abs(dy.y) + 16)
SetupPanel(dispatchPanel, { dispatchEnabledCB, rcRotateEnabledCB }, { dispatchFontSizeSlider })

------------------------------------------------------------
-- Panel 5: Audit
------------------------------------------------------------
local auditPanel, ac = CreateScrollPanel()
local ay = { y = -16 }

MakeHeader(ac, ay, "Gear Audit")
MakeSpacer(ay, 4)

MakeLabel(ac, ay, "|cff888888These settings are also toggleable in the audit window|r")
MakeSpacer(ay, 8)

local Q1I = ns.Q1_ICON or ""
local Q2I = ns.Q2_ICON or ""

local THRESH_OPTIONS = {
    { label = "Any (accept anything)", value = "any" },
    { label = "High " .. Q1I, value = "high_q1" },
    { label = "High " .. Q2I .. " (max)", value = "high_q2" },
}

local EPIC_OPTIONS = {
    { label = Q1I .. "+ (any epic)", value = 1 },
    { label = Q2I .. " (max quality)", value = 2 },
}

MakeDropdown(ac, ay, "Enchant Threshold",
    THRESH_OPTIONS,
    function() return ns.db and ns.db.auditEnchantThreshold or ns.CONFIG.auditEnchantThreshold end,
    function(v)
        if ns.db then
            ns.db.auditEnchantThreshold = v
            if ns.RefreshAuditUI then ns.RefreshAuditUI() end
        end
    end)

MakeSpacer(ay, 4)

MakeDropdown(ac, ay, "Gem Threshold",
    THRESH_OPTIONS,
    function() return ns.db and ns.db.auditGemThreshold or ns.CONFIG.auditGemThreshold end,
    function(v)
        if ns.db then
            ns.db.auditGemThreshold = v
            if ns.RefreshAuditUI then ns.RefreshAuditUI() end
        end
    end)

MakeSpacer(ay, 4)

MakeDropdown(ac, ay, "Epic Gem Minimum",
    EPIC_OPTIONS,
    function() return ns.db and ns.db.auditEpicGemMin or ns.CONFIG.auditEpicGemMin end,
    function(v)
        if ns.db then
            ns.db.auditEpicGemMin = v
            if ns.RefreshAuditUI then ns.RefreshAuditUI() end
        end
    end)

MakeSpacer(ay, 12)

-- Dynamic summary label
local auditSummaryLabel = MakeLabel(ac, ay, "")

local THRESH_LABELS = { any = "Any", high_q1 = "High " .. Q1I, high_q2 = "High " .. Q2I }

local function UpdateAuditSummary()
    if not ns.db then return end
    local e = THRESH_LABELS[ns.db.auditEnchantThreshold] or ("High " .. Q1I)
    local g = THRESH_LABELS[ns.db.auditGemThreshold] or ("High " .. Q1I)
    local ep = ns.db.auditEpicGemMin == 2 and Q2I or (Q1I .. "+")
    auditSummaryLabel:SetText(string.format(
        "|cff888888Ench: %s, Gems: %s, Epic: %s|r", e, g, ep))
end

ac:SetHeight(math.abs(ay.y) + 16)
SetupPanel(auditPanel, {}, {}, UpdateAuditSummary)

------------------------------------------------------------
-- Register categories
------------------------------------------------------------
local mainCategory = Settings.RegisterCanvasLayoutCategory(generalPanel, "Git's Raid Tools")
Settings.RegisterAddOnCategory(mainCategory)
ns.settingsCategoryID = mainCategory:GetID()

Settings.RegisterCanvasLayoutSubcategory(mainCategory, invitePanel, "Invites")
Settings.RegisterCanvasLayoutSubcategory(mainCategory, countdownPanel, "Countdown")
Settings.RegisterCanvasLayoutSubcategory(mainCategory, dispatchPanel, "Dispatch")
Settings.RegisterCanvasLayoutSubcategory(mainCategory, auditPanel, "Audit")
