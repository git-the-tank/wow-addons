local _, ns = ...

local LibEditMode = LibStub("LibEditMode")

local function RestorePosition(frame, dbKey)
    if not ns.db or not ns.db[dbKey] then return end
    local pos = ns.db[dbKey]
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
end

-- Apply all defaults from both tables
local function ApplyDefaults()
    -- Global defaults from Options
    if ns.GLOBAL_DEFAULTS then
        for key, val in pairs(ns.GLOBAL_DEFAULTS) do
            if key ~= "enabled" and ns.db[key] == nil then
                ns.db[key] = type(val) == "table" and {unpack(val)} or val
            end
        end
    end
    -- DTPS bar defaults
    if ns.DTPS_BAR_DEFAULTS then
        for key, val in pairs(ns.DTPS_BAR_DEFAULTS) do
            if ns.db[key] == nil then
                ns.db[key] = type(val) == "table" and {unpack(val)} or val
            end
        end
    end
    -- Split bar defaults
    if ns.db.showSplitBorder == nil then ns.db.showSplitBorder = true end
    -- Durability defaults
    if ns.DURABILITY_DEFAULTS then
        for key, val in pairs(ns.DURABILITY_DEFAULTS) do
            if ns.db[key] == nil then
                ns.db[key] = type(val) == "table" and {unpack(val)} or val
            end
        end
    end
end

------------------------------------------------------------
-- Expander section state persistence
------------------------------------------------------------
local function EnsureSections()
    if type(ns.db.editModeSections) ~= "table" then
        ns.db.editModeSections = {
            layout = true,
            appearance = false,
            typography = false,
        }
    end
    local s = ns.db.editModeSections
    if s.layout == nil then s.layout = true end
    if s.appearance == nil then s.appearance = false end
    if s.typography == nil then s.typography = false end
    return s
end

local function IsSectionExpanded(sectionKey, defaultExpanded)
    local sections = EnsureSections()
    local value = sections[sectionKey]
    if value == nil then
        value = defaultExpanded == true
        sections[sectionKey] = value
    end
    return value == true
end

local function CreateSectionExpander(sectionKey, label, defaultExpanded)
    return {
        name = label,
        kind = LibEditMode.SettingType.Expander,
        default = defaultExpanded == true,
        expandedLabel = label,
        collapsedLabel = label,
        get = function()
            return IsSectionExpanded(sectionKey, defaultExpanded)
        end,
        set = function(_, value)
            EnsureSections()[sectionKey] = value and true or false
        end,
    }
end

local function SectionHidden(sectionKey, defaultExpanded)
    return function()
        return not IsSectionExpanded(sectionKey, defaultExpanded)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    C_Timer.After(0, function()
        ApplyDefaults()

        local damageFrame = TankBattleTextFrame
        local statsFrame = TankBattleTextStatsFrame

        RestorePosition(damageFrame, "damagePos")
        RestorePosition(statsFrame, "statsPos")

        -- Hide frames if toggled off
        if ns.db.showDamageText == false then
            damageFrame:Hide()
        end
        if ns.db.showStats == false then
            statsFrame:Hide()
        end

        local damageDefault = {
            point = "RIGHT",
            x = -100,
            y = 0,
        }

        local statsDefault = {
            point = "RIGHT",
            x = -100,
            y = 155,
        }

        LibEditMode:AddFrame(damageFrame, function(_, _, point, x, y)
            if ns.db then
                ns.db.damagePos = { point = point, x = x, y = y }
            end
        end, damageDefault, "TBT: Damage Text")

        LibEditMode:AddFrame(statsFrame, function(_, _, point, x, y)
            if ns.db then
                ns.db.statsPos = { point = point, x = x, y = y }
            end
        end, statsDefault, "TBT: Tank Stats")

        -- DTPS Bar
        local dtpsBar = TankBattleTextDTPSBar

        if ns.db.showDTPSBar == false then
            dtpsBar:Hide()
        end

        -- Only restore free position if not anchored to another frame
        local anchorName = ns.db.dtpsBarAnchorFrame or ""
        if anchorName == "" then
            RestorePosition(dtpsBar, "dtpsBarPos")
        end

        ns.ApplyGlobalFont()
        if ns.ApplyFadeDuration then ns.ApplyFadeDuration() end

        -- Delay bar settings so anchor targets are fully positioned
        C_Timer.After(0, function()
            ns.ApplyGlobalBarTexture()
            ns.ApplyDTPSBarSettings()
            ns.UpdateDTPSBar()
        end)

        local dtpsBarDefault = {
            point = "RIGHT",
            x = -100,
            y = 131,
        }

        LibEditMode:AddFrame(dtpsBar, function(_, _, point, x, y)
            if ns.db then
                ns.db.dtpsBarPos = { point = point, x = x, y = y }
            end
        end, dtpsBarDefault, "TBT: DTPS Bar")

        local ST = LibEditMode.SettingType

        -- Known anchor targets: Blizzard frames and popular addons
        -- Each entry is only shown if _G[value] exists at runtime
        local KNOWN_ANCHORS = {
            -- Blizzard
            { value = "PlayerFrame",              label = "|cFF00AEF7Blizzard|r: Player Frame" },
            { value = "TargetFrame",              label = "|cFF00AEF7Blizzard|r: Target Frame" },
            { value = "EssentialCooldownViewer",  label = "|cFF00AEF7Blizzard|r: Essential Cooldown Viewer" },
            { value = "BuffIconCooldownViewer",   label = "|cFF00AEF7Blizzard|r: Tracked Buffs" },
            { value = "UtilityCooldownViewer",    label = "|cFF00AEF7Blizzard|r: Utility Cooldown Viewer" },
            -- BetterCooldownManager (BCDM)
            { value = "BCDM_PowerBar",                      label = "|cFF8080FFBCDM|r: Power Bar" },
            { value = "BCDM_SecondaryPowerBar",             label = "|cFF8080FFBCDM|r: Secondary Power Bar" },
            { value = "BCDM_CastBar",                       label = "|cFF8080FFBCDM|r: Cast Bar" },
            { value = "BCDM_CustomCooldownViewer",          label = "|cFF8080FFBCDM|r: Custom Bar" },
            { value = "BCDM_AdditionalCustomCooldownViewer", label = "|cFF8080FFBCDM|r: Additional Custom Bar" },
            { value = "BCDM_CustomItemBar",                 label = "|cFF8080FFBCDM|r: Item Bar" },
            { value = "BCDM_CustomItemSpellBar",            label = "|cFF8080FFBCDM|r: Items/Spells Bar" },
            { value = "BCDM_TrinketBar",                    label = "|cFF8080FFBCDM|r: Trinket Bar" },
            -- UnhaltedUnitFrames
            { value = "UUF_Player",  label = "|cFF8080FFUnhalted|rUnitFrames: Player Frame" },
            { value = "UUF_Target",  label = "|cFF8080FFUnhalted|rUnitFrames: Target Frame" },
            -- TwintopsResourceBar (TRB): wrapper frames (Edit Mode) and container frames
            { value = "TRB_EditModeWrapper_primary",              label = "|cFF8080FFTRB|r: Primary Bar" },
            { value = "TRB_EditModeWrapper_secondary",            label = "|cFF8080FFTRB|r: Secondary Bar" },
            { value = "TRB_EditModeWrapper_health",               label = "|cFF8080FFTRB|r: Health Bar" },
            { value = "TRB_EditModeWrapper_mana",                 label = "|cFF8080FFTRB|r: Mana Bar" },
            { value = "TRB_EditModeWrapper_stagger",              label = "|cFF8080FFTRB|r: Stagger Bar" },
            { value = "TRB_EditModeWrapper_defensives",           label = "|cFF8080FFTRB|r: Defensives Bar" },
            { value = "TwintopResourceBarFrame",                  label = "|cFF8080FFTRB|r: Primary Bar" },
            { value = "TwintopResourceBarFrame_Secondary_Group",  label = "|cFF8080FFTRB|r: Secondary Bar" },
            { value = "TwintopResourceBarFrame_Health_Group",     label = "|cFF8080FFTRB|r: Health Bar" },
            { value = "TwintopResourceBarFrame_Mana_Group",       label = "|cFF8080FFTRB|r: Mana Bar" },
            { value = "TwintopResourceBarFrame_Stagger_Group",    label = "|cFF8080FFTRB|r: Stagger Bar" },
            { value = "TwintopResourceBarFrame_Defensives_Group", label = "|cFF8080FFTRB|r: Defensives Bar" },
        }

        -- Build anchor dropdown from LibEditMode-registered frames + known addon frames
        local function BuildAnchorValues()
            local values = {}
            local seen = {}
            -- "None" always first
            values[#values + 1] = { text = "None (Free Position)", value = "" }
            seen[""] = true

            -- All LibEditMode-registered frames (from any addon sharing the lib)
            for frame, sel in pairs(LibEditMode.frameSelections or {}) do
                local frameName = frame:GetName()
                if frameName and frameName ~= dtpsBar:GetName() and frameName ~= "TankBattleTextSchoolSplitBar" and not seen[frameName] then
                    local displayName = frameName
                    if sel and sel.system and sel.system.GetSystemName then
                        displayName = sel.system.GetSystemName()
                    end
                    seen[frameName] = true
                    values[#values + 1] = { text = displayName, value = frameName }
                end
            end

            -- Known frames from Blizzard and popular addons (only if installed)
            for _, anchor in ipairs(KNOWN_ANCHORS) do
                if not seen[anchor.value] and _G[anchor.value] then
                    seen[anchor.value] = true
                    values[#values + 1] = { text = anchor.label, value = anchor.value }
                end
            end

            -- BetterTrackedBars: dynamic per-character bars (BetterTrackedBarsFrame_*)
            for key, obj in pairs(_G) do
                if type(key) == "string"
                    and key:find("^BetterTrackedBarsFrame_")
                    and type(obj) == "table"
                    and type(obj.GetName) == "function"
                    and not seen[key]
                then
                    local label = key:gsub("^BetterTrackedBarsFrame_", ""):gsub("_", " ")
                    seen[key] = true
                    values[#values + 1] = { text = "|cFFFF7C0ABT|rB: " .. label, value = key }
                end
            end

            return values
        end

        local pointValues = {}
        for _, p in ipairs(ns.ANCHOR_POINTS) do
            pointValues[#pointValues + 1] = { text = p, value = p }
        end

        local growthValues = {
            { text = "Left to Right", value = "RIGHT" },
            { text = "Right to Left", value = "LEFT" },
            { text = "Bottom to Top", value = "UP" },
            { text = "Top to Bottom", value = "DOWN" },
        }

        local function fontValues()
            local list = ns.BuildFontList()
            local values = {}
            for _, f in ipairs(list) do
                values[#values + 1] = { text = f.name, value = f.value }
            end
            return values
        end

        local outlineValues = {
            { text = "None", value = "NONE" },
            { text = "Outline", value = "OUTLINE" },
            { text = "Thick Outline", value = "THICKOUTLINE" },
        }

        local layoutHidden = SectionHidden("layout", true)
        local appearanceHidden = SectionHidden("appearance", false)
        local typographyHidden = SectionHidden("typography", false)

        -- DTPS Bar Edit Mode settings
        LibEditMode:AddFrameSettings(dtpsBar, {
            -- Layout & Anchoring
            CreateSectionExpander("layout", "Layout & Anchoring", true),
            {
                kind = ST.Dropdown,
                name = "Anchor To",
                default = "TankBattleTextStatsFrame",
                values = BuildAnchorValues,
                get = function() return ns.db.dtpsBarAnchorFrame or "" end,
                set = function(_, v) ns.db.dtpsBarAnchorFrame = v; ns.ApplyDTPSBarSettings(); ns.ShowDTPSBarPreview() end,
                height = 500,
                hidden = layoutHidden,
            },
            {
                kind = ST.Dropdown,
                name = "Bar Point",
                default = "TOP",
                values = pointValues,
                get = function() return ns.db.dtpsBarAnchorFrom or "TOP" end,
                set = function(_, v) ns.db.dtpsBarAnchorFrom = v; ns.ApplyDTPSBarSettings(); ns.ShowDTPSBarPreview() end,
                hidden = layoutHidden,
            },
            {
                kind = ST.Dropdown,
                name = "Target Point",
                default = "BOTTOM",
                values = pointValues,
                get = function() return ns.db.dtpsBarAnchorTo or "BOTTOM" end,
                set = function(_, v) ns.db.dtpsBarAnchorTo = v; ns.ApplyDTPSBarSettings(); ns.ShowDTPSBarPreview() end,
                hidden = layoutHidden,
            },
            {
                kind = ST.Slider,
                name = "X Offset",
                default = 0,
                minValue = -1000,
                maxValue = 1000,
                valueStep = 1,
                get = function() return ns.db.dtpsBarAnchorOffX or 0 end,
                set = function(_, v) ns.db.dtpsBarAnchorOffX = v; ns.ApplyDTPSBarSettings(); ns.ShowDTPSBarPreview() end,
                formatter = function(value) return string.format("%d px", value) end,
                hidden = layoutHidden,
            },
            {
                kind = ST.Slider,
                name = "Y Offset",
                default = -2,
                minValue = -1000,
                maxValue = 1000,
                valueStep = 1,
                get = function() return ns.db.dtpsBarAnchorOffY or -2 end,
                set = function(_, v) ns.db.dtpsBarAnchorOffY = v; ns.ApplyDTPSBarSettings(); ns.ShowDTPSBarPreview() end,
                formatter = function(value) return string.format("%d px", value) end,
                hidden = layoutHidden,
            },
            {
                kind = ST.Checkbox,
                name = "Match Target Width",
                default = true,
                get = function() return ns.db.dtpsBarMatchWidth end,
                set = function(_, v) ns.db.dtpsBarMatchWidth = v; ns.ApplyDTPSBarSettings(); ns.ShowDTPSBarPreview() end,
                hidden = layoutHidden,
            },
            {
                kind = ST.Slider,
                name = "Width",
                default = 200,
                minValue = 50,
                maxValue = 400,
                valueStep = 10,
                get = function() return ns.db.dtpsBarWidth or 200 end,
                set = function(_, v) ns.db.dtpsBarWidth = v; ns.ApplyDTPSBarSettings(); ns.ShowDTPSBarPreview() end,
                formatter = function(value) return string.format("%d px", value) end,
                disabled = function() return ns.db.dtpsBarMatchWidth end,
                hidden = layoutHidden,
            },
            {
                kind = ST.Slider,
                name = "Height",
                default = 16,
                minValue = 8,
                maxValue = 40,
                valueStep = 2,
                get = function() return ns.db.dtpsBarHeight or 16 end,
                set = function(_, v) ns.db.dtpsBarHeight = v; ns.ApplyDTPSBarSettings(); ns.ShowDTPSBarPreview() end,
                formatter = function(value) return string.format("%d px", value) end,
                hidden = layoutHidden,
            },

            -- Appearance
            CreateSectionExpander("appearance", "Appearance", false),
            {
                kind = ST.Dropdown,
                name = "Growth Direction",
                default = "RIGHT",
                values = growthValues,
                get = function() return ns.db.dtpsBarGrowth or "RIGHT" end,
                set = function(_, v) ns.db.dtpsBarGrowth = v; ns.ApplyDTPSBarSettings(); ns.ShowDTPSBarPreview() end,
                hidden = appearanceHidden,
            },
            {
                kind = ST.ColorPicker,
                name = "Background",
                hasOpacity = true,
                default = CreateColor(0, 0, 0, 0.6),
                get = function()
                    local c = ns.db.dtpsBarBGColor or {0, 0, 0, 0.6}
                    return CreateColor(c[1], c[2], c[3], c[4] or 0.6)
                end,
                set = function(_, color)
                    local r, g, b, a = color:GetRGBA()
                    ns.db.dtpsBarBGColor = {r, g, b, a}
                    ns.ApplyDTPSBarSettings(); ns.ShowDTPSBarPreview()
                end,
                hidden = appearanceHidden,
            },

            -- Typography
            CreateSectionExpander("typography", "Typography", false),
            {
                kind = ST.Dropdown,
                name = "Font Family",
                default = ns.GLOBAL_DEFAULTS.fontFace,
                values = fontValues,
                get = function()
                    return ns.db.dtpsBarFontFace or ns.db.fontFace or ns.GLOBAL_DEFAULTS.fontFace
                end,
                set = function(_, v)
                    ns.db.dtpsBarFontFace = v
                    ns.ApplyDTPSBarFont(
                        ns.FindFontPath(v),
                        ns.db.dtpsBarFontSize or ns.db.fontSize or ns.GLOBAL_DEFAULTS.fontSize,
                        ns.db.dtpsBarFontOutline or ns.db.fontOutline or ns.GLOBAL_DEFAULTS.fontOutline
                    )
                end,
                hidden = typographyHidden,
            },
            {
                kind = ST.Slider,
                name = "Font Size",
                default = ns.GLOBAL_DEFAULTS.fontSize,
                minValue = 8,
                maxValue = 24,
                valueStep = 1,
                get = function()
                    return ns.db.dtpsBarFontSize or ns.db.fontSize or ns.GLOBAL_DEFAULTS.fontSize
                end,
                set = function(_, v)
                    ns.db.dtpsBarFontSize = v
                    ns.ApplyDTPSBarFont(
                        ns.FindFontPath(ns.db.dtpsBarFontFace or ns.db.fontFace or ns.GLOBAL_DEFAULTS.fontFace),
                        v,
                        ns.db.dtpsBarFontOutline or ns.db.fontOutline or ns.GLOBAL_DEFAULTS.fontOutline
                    )
                end,
                formatter = function(value) return string.format("%d pt", value) end,
                hidden = typographyHidden,
            },
            {
                kind = ST.Dropdown,
                name = "Font Outline",
                default = ns.GLOBAL_DEFAULTS.fontOutline,
                values = outlineValues,
                get = function()
                    return ns.db.dtpsBarFontOutline or ns.db.fontOutline or ns.GLOBAL_DEFAULTS.fontOutline
                end,
                set = function(_, v)
                    ns.db.dtpsBarFontOutline = v
                    ns.ApplyDTPSBarFont(
                        ns.FindFontPath(ns.db.dtpsBarFontFace or ns.db.fontFace or ns.GLOBAL_DEFAULTS.fontFace),
                        ns.db.dtpsBarFontSize or ns.db.fontSize or ns.GLOBAL_DEFAULTS.fontSize,
                        v
                    )
                end,
                hidden = typographyHidden,
            },
        })

        -- Settings for damage text frame
        LibEditMode:AddFrameSettings(damageFrame, {
            {
                kind = ST.Checkbox,
                name = "Show Damage Text",
                default = true,
                get = function() return ns.db.showDamageText ~= false end,
                set = function(_, value)
                    ns.db.showDamageText = value
                    if value then damageFrame:Show() else damageFrame:Hide() end
                end,
            },
            {
                kind = ST.Checkbox,
                name = "Collapse Routine Hits",
                default = true,
                get = function() return ns.db.showCollapseMode ~= false end,
                set = function(_, value)
                    ns.db.showCollapseMode = value
                end,
            },
            {
                kind = ST.Slider,
                name = "Collapse Font Size",
                default = ns.GLOBAL_DEFAULTS.fontSize,
                minValue = 8,
                maxValue = 24,
                valueStep = 1,
                get = function()
                    return ns.db.collapseFontSize or ns.db.fontSize or ns.GLOBAL_DEFAULTS.fontSize
                end,
                set = function(_, v)
                    ns.db.collapseFontSize = v
                    ns.ApplyGlobalFont()
                end,
                formatter = function(value) return string.format("%d pt", value) end,
            },
            {
                kind = ST.Slider,
                name = "Display Duration",
                default = 4,
                minValue = 2,
                maxValue = 15,
                valueStep = 1,
                get = function() return ns.db.fadeTimeVisible or 4 end,
                set = function(_, v)
                    ns.db.fadeTimeVisible = v
                    if ns.ApplyFadeDuration then ns.ApplyFadeDuration() end
                end,
                formatter = function(value) return string.format("%d sec", value) end,
            },
        })

        -- Settings checkboxes for stats frame
        LibEditMode:AddFrameSettings(statsFrame, {
            {
                kind = ST.Checkbox,
                name = "Show Stats Frame",
                default = true,
                get = function() return ns.db.showStats ~= false end,
                set = function(_, value)
                    ns.db.showStats = value
                    if value then statsFrame:Show() else statsFrame:Hide() end
                    ns.ShowStatsPreview()
                end,
            },
            {
                kind = ST.Checkbox,
                name = "Show Avoidance",
                default = true,
                get = function() return ns.db.showAvoid end,
                set = function(_, value)
                    ns.db.showAvoid = value
                    ns.ShowStatsPreview()
                end,
            },
            {
                kind = ST.Checkbox,
                name = "Show DTPS",
                default = true,
                get = function() return ns.db.showDTPS end,
                set = function(_, value)
                    ns.db.showDTPS = value
                    ns.ShowStatsPreview()
                end,
            },
            {
                kind = ST.Checkbox,
                name = "Show Rolling DPS",
                default = true,
                get = function() return ns.db.showRollingDPS end,
                set = function(_, value)
                    ns.db.showRollingDPS = value
                    ns.ShowStatsPreview()
                end,
            },
            {
                kind = ST.Checkbox,
                name = "Show Combat DPS",
                default = true,
                get = function() return ns.db.showCombatDPS end,
                set = function(_, value)
                    ns.db.showCombatDPS = value
                    ns.ShowStatsPreview()
                end,
            },
        })

        -- School Split Bar
        local splitBar = TankBattleTextSchoolSplitBar

        if ns.db.showSchoolSplit == false then
            splitBar:Hide()
        end

        local splitAnchorName = ns.db.schoolSplitAnchorFrame or ""
        if splitAnchorName == "" then
            RestorePosition(splitBar, "schoolSplitPos")
        end

        C_Timer.After(0, function()
            ns.ApplySchoolSplitBarSettings()
        end)

        local splitBarDefault = {
            point = "RIGHT",
            x = -100,
            y = 140,
        }

        LibEditMode:AddFrame(splitBar, function(_, _, point, x, y)
            if ns.db then
                ns.db.schoolSplitPos = { point = point, x = x, y = y }
            end
        end, splitBarDefault, "TBT: Damage Split")

        -- Build anchor values excluding the split bar itself
        local function BuildSplitBarAnchorValues()
            local values = {}
            local seen = {}
            values[#values + 1] = { text = "None (Free Position)", value = "" }
            seen[""] = true

            for frame, sel in pairs(LibEditMode.frameSelections or {}) do
                local frameName = frame:GetName()
                if frameName and frameName ~= splitBar:GetName() and not seen[frameName] then
                    local displayName = frameName
                    if sel and sel.system and sel.system.GetSystemName then
                        displayName = sel.system.GetSystemName()
                    end
                    seen[frameName] = true
                    values[#values + 1] = { text = displayName, value = frameName }
                end
            end

            for _, anchor in ipairs(KNOWN_ANCHORS) do
                if not seen[anchor.value] and _G[anchor.value] then
                    seen[anchor.value] = true
                    values[#values + 1] = { text = anchor.label, value = anchor.value }
                end
            end

            for key, obj in pairs(_G) do
                if type(key) == "string"
                    and key:find("^BetterTrackedBarsFrame_")
                    and type(obj) == "table"
                    and type(obj.GetName) == "function"
                    and not seen[key]
                then
                    local label = key:gsub("^BetterTrackedBarsFrame_", ""):gsub("_", " ")
                    seen[key] = true
                    values[#values + 1] = { text = "|cFFFF7C0ABT|rB: " .. label, value = key }
                end
            end

            return values
        end

        LibEditMode:AddFrameSettings(splitBar, {
            {
                kind = ST.Checkbox,
                name = "Show Damage Split",
                default = true,
                get = function() return ns.db.showSchoolSplit end,
                set = function(_, v)
                    ns.db.showSchoolSplit = v
                    if v then ns.ShowSchoolSplitBarPreview() else splitBar:Hide() end
                end,
            },
            {
                kind = ST.Checkbox,
                name = "Show DTPS Border",
                default = true,
                get = function() return ns.db.showSplitBorder end,
                set = function(_, v)
                    ns.db.showSplitBorder = v
                    ns.ShowSchoolSplitBarPreview()
                end,
            },
            {
                kind = ST.Dropdown,
                name = "Anchor To",
                default = "TankBattleTextStatsFrame",
                values = BuildSplitBarAnchorValues,
                get = function() return ns.db.schoolSplitAnchorFrame or "" end,
                set = function(_, v) ns.db.schoolSplitAnchorFrame = v; ns.ApplySchoolSplitBarSettings(); ns.ShowSchoolSplitBarPreview() end,
                height = 500,
            },
            {
                kind = ST.Dropdown,
                name = "Bar Point",
                default = "TOPLEFT",
                values = pointValues,
                get = function() return ns.db.schoolSplitAnchorFrom or "TOPLEFT" end,
                set = function(_, v) ns.db.schoolSplitAnchorFrom = v; ns.ApplySchoolSplitBarSettings(); ns.ShowSchoolSplitBarPreview() end,
            },
            {
                kind = ST.Dropdown,
                name = "Target Point",
                default = "BOTTOMLEFT",
                values = pointValues,
                get = function() return ns.db.schoolSplitAnchorTo or "BOTTOMLEFT" end,
                set = function(_, v) ns.db.schoolSplitAnchorTo = v; ns.ApplySchoolSplitBarSettings(); ns.ShowSchoolSplitBarPreview() end,
            },
            {
                kind = ST.Slider,
                name = "Padding",
                default = 2,
                minValue = 0,
                maxValue = 20,
                valueStep = 1,
                get = function() return ns.db.schoolSplitAnchorPad or 2 end,
                set = function(_, v) ns.db.schoolSplitAnchorPad = v; ns.ApplySchoolSplitBarSettings(); ns.ShowSchoolSplitBarPreview() end,
                formatter = function(value) return string.format("%d px", value) end,
            },
            {
                kind = ST.Checkbox,
                name = "Match Target Width",
                default = true,
                get = function() return ns.db.schoolSplitMatchWidth end,
                set = function(_, v) ns.db.schoolSplitMatchWidth = v; ns.ApplySchoolSplitBarSettings(); ns.ShowSchoolSplitBarPreview() end,
            },
            {
                kind = ST.Slider,
                name = "Width",
                default = 200,
                minValue = 50,
                maxValue = 400,
                valueStep = 10,
                get = function() return ns.db.schoolSplitWidth or 200 end,
                set = function(_, v) ns.db.schoolSplitWidth = v; ns.ApplySchoolSplitBarSettings(); ns.ShowSchoolSplitBarPreview() end,
                formatter = function(value) return string.format("%d px", value) end,
                disabled = function() return ns.db.schoolSplitMatchWidth end,
            },
            {
                kind = ST.Slider,
                name = "Height",
                default = 6,
                minValue = 2,
                maxValue = 20,
                valueStep = 1,
                get = function() return ns.db.schoolSplitHeight or 6 end,
                set = function(_, v) ns.db.schoolSplitHeight = v; ns.ApplySchoolSplitBarSettings(); ns.ShowSchoolSplitBarPreview() end,
                formatter = function(value) return string.format("%d px", value) end,
            },
        })

        -- Durability frame
        local durFrame = TankBattleTextDurabilityFrame

        if ns.db.showDurability == false then
            durFrame:Hide()
        end

        RestorePosition(durFrame, "durabilityPos")

        C_Timer.After(0, function()
            ns.ApplyDurabilitySize(ns.db.durabilitySize or 40)
            ns.UpdateDurability()
        end)

        local durabilityDefault = {
            point = "CENTER",
            x     = 200,
            y     = -100,
        }

        LibEditMode:AddFrame(durFrame, function(_, _, point, x, y)
            if ns.db then
                ns.db.durabilityPos = { point = point, x = x, y = y }
            end
        end, durabilityDefault, "TBT: Durability")

        LibEditMode:AddFrameSettings(durFrame, {
            {
                kind    = ST.Checkbox,
                name    = "Show Durability",
                default = true,
                get     = function() return ns.db.showDurability ~= false end,
                set     = function(_, v)
                    ns.db.showDurability = v
                    if v then ns.ShowDurabilityPreview() else durFrame:Hide() end
                end,
            },
            {
                kind      = ST.Slider,
                name      = "Box Size",
                default   = 40,
                minValue  = 20,
                maxValue  = 100,
                valueStep = 2,
                get       = function() return ns.db.durabilitySize or 40 end,
                set       = function(_, v)
                    ns.db.durabilitySize = v
                    ns.ApplyDurabilitySize(v)
                    ns.ShowDurabilityPreview()
                end,
                formatter = function(value) return string.format("%d px", value) end,
            },
            {
                kind    = ST.Dropdown,
                name    = "Font Family",
                default = ns.GLOBAL_DEFAULTS.fontFace,
                values  = fontValues,
                get     = function()
                    return ns.db.durabilityFontFace or ns.db.fontFace or ns.GLOBAL_DEFAULTS.fontFace
                end,
                set     = function(_, v)
                    ns.db.durabilityFontFace = v
                    ns.ApplyDurabilityFont(
                        ns.FindFontPath(v),
                        ns.db.durabilityFontSize or ns.DURABILITY_DEFAULTS.durabilityFontSize,
                        ns.db.fontOutline or ns.GLOBAL_DEFAULTS.fontOutline
                    )
                end,
            },
            {
                kind      = ST.Slider,
                name      = "Font Size",
                default   = 12,
                minValue  = 8,
                maxValue  = 24,
                valueStep = 1,
                get       = function() return ns.db.durabilityFontSize or ns.DURABILITY_DEFAULTS.durabilityFontSize end,
                set       = function(_, v)
                    ns.db.durabilityFontSize = v
                    ns.ApplyDurabilityFont(
                        ns.FindFontPath(ns.db.durabilityFontFace or ns.db.fontFace or ns.GLOBAL_DEFAULTS.fontFace),
                        v,
                        ns.db.fontOutline or ns.GLOBAL_DEFAULTS.fontOutline
                    )
                end,
                formatter = function(value) return string.format("%d pt", value) end,
            },
        })

        -- Show placeholder text during Edit Mode
        LibEditMode:RegisterCallback("enter", function()
            ns.ShowDamagePreview()
            ns.ShowStatsPreview()
            ns.ShowDTPSBarPreview()
            ns.ShowSchoolSplitBarPreview()
            ns.ShowDurabilityPreview()
        end)

        LibEditMode:RegisterCallback("exit", function()
            ns.HideDamagePreview()
            ns.HideStatsPreview()
            ns.HideDTPSBarPreview()
            ns.HideSchoolSplitBarPreview()
            ns.HideDurabilityPreview()
        end)
    end)
end)
