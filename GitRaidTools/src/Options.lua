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

function ns.FindFontPath(name)
    if LSM and LSM:IsValid("font", name) then
        return LSM:Fetch("font", name)
    end
    for _, f in ipairs(BUILTIN_FONTS) do
        if f.name == name then return f.path end
    end
    return BUILTIN_FONTS[1].path
end

local function BuildFontValues()
    local vals = {}
    if LSM then
        local list = LSM:List("font")
        if list and #list > 0 then
            for _, name in ipairs(list) do
                vals[name] = name
            end
            return vals
        end
    end
    for _, f in ipairs(BUILTIN_FONTS) do
        vals[f.name] = f.name
    end
    return vals
end

local DAY_VALUES = {
    [1] = "Sunday", [2] = "Monday", [3] = "Tuesday", [4] = "Wednesday",
    [5] = "Thursday", [6] = "Friday", [7] = "Saturday",
}

local STRATA_VALUES = {
    BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium",
    HIGH = "High", DIALOG = "Dialog",
}
local STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }

local Q1I = ns.Q1_ICON or ""
local Q2I = ns.Q2_ICON or ""

local THRESH_VALUES = {
    any = "Any (accept anything)",
    high_q1 = "High " .. Q1I,
    high_q2 = "High " .. Q2I .. " (max)",
}
local THRESH_ORDER = { "any", "high_q1", "high_q2" }

local EPIC_VALUES = {
    [1] = Q1I .. "+ (any epic)",
    [2] = Q2I .. " (max quality)",
}

local function InvitesDisabled()
    if not ns.db then return false end
    return ns.db.invitesEnabled == false
end

-- Set handler that writes to ns.db and fires an optional callback
local function SetWith(callback)
    return function(info, val)
        if ns.db then ns.db[info[#info]] = val end
        if callback then callback() end
    end
end

------------------------------------------------------------
-- AceConfig Options Table
------------------------------------------------------------
local options = {
    name = "Git's Raid Tools",
    type = "group",
    childGroups = "tab",
    get = function(info)
        if not ns.db then return ns.CONFIG[info[#info]] end
        local v = ns.db[info[#info]]
        if v ~= nil then return v end
        return ns.CONFIG[info[#info]]
    end,
    set = function(info, val)
        if ns.db then ns.db[info[#info]] = val end
    end,
    args = {
        -----------------------------------------------------------------
        -- Tab 1: General
        -----------------------------------------------------------------
        general = {
            name = "General",
            order = 1,
            type = "group",
            args = {
                quickActionsHeader = {
                    order = 1,
                    name = "Quick Actions",
                    type = "header",
                },
                btnInviteNow = {
                    order = 2,
                    name = "Invite Now",
                    type = "execute",
                    width = "normal",
                    func = function()
                        if ns.RaidTimeInvite then ns.RaidTimeInvite() end
                    end,
                },
                btnGearAudit = {
                    order = 3,
                    name = "Gear Audit",
                    type = "execute",
                    width = "normal",
                    func = function()
                        if ns.ToggleAuditWindow then ns.ToggleAuditWindow() end
                    end,
                },
                btnMoveCountdown = {
                    order = 4,
                    name = "Move Countdown",
                    type = "execute",
                    width = "normal",
                    func = function()
                        ShowUIPanel(EditModeManagerFrame) -- luacheck: ignore 113
                    end,
                },
                btnTestCountdown = {
                    order = 5,
                    name = "Test Countdown",
                    type = "execute",
                    width = "normal",
                    func = function()
                        if ns.testMode then
                            if ns.ExitTestMode then ns.ExitTestMode() end
                        else
                            if ns.EnterTestMode then ns.EnterTestMode() end
                        end
                    end,
                },
                muted = {
                    order = 10,
                    name = "Mute Announcements",
                    desc = "Mute all raid/guild/instance announcements",
                    type = "toggle",
                    width = "full",
                },
                scheduleHeader = {
                    order = 20,
                    name = "Raid Schedule",
                    type = "header",
                },
                raidHour = {
                    order = 21,
                    name = "Raid Start Hour",
                    desc = "Server time, 24-hour format (20 = 8 PM)",
                    type = "range",
                    min = 0, max = 23, step = 1,
                },
                raidMinute = {
                    order = 22,
                    name = "Raid Start Minute",
                    type = "range",
                    min = 0, max = 55, step = 5,
                },
                daysHeader = {
                    order = 30,
                    name = "Raid Days",
                    type = "header",
                },
                raidDays = {
                    order = 31,
                    name = "",
                    type = "multiselect",
                    values = DAY_VALUES,
                    get = function(_, key)
                        if not ns.db then return false end
                        for _, d in ipairs(ns.db.raidDays) do
                            if d == key then return true end
                        end
                        return false
                    end,
                    set = function(_, key, val)
                        if not ns.db then return end
                        local days = ns.db.raidDays
                        if val then
                            for _, d in ipairs(days) do if d == key then return end end
                            days[#days + 1] = key
                        else
                            for j = #days, 1, -1 do
                                if days[j] == key then table.remove(days, j) end
                            end
                        end
                    end,
                },
                typoHeader = {
                    order = 40,
                    name = "Typography",
                    type = "header",
                },
                fontFace = {
                    order = 41,
                    name = "Font",
                    type = "select",
                    values = BuildFontValues,
                    set = SetWith(ns.ApplyCountdownFont),
                },
            },
        },
        -----------------------------------------------------------------
        -- Tab 2: Invites
        -----------------------------------------------------------------
        invites = {
            name = "Invites",
            order = 2,
            type = "group",
            args = {
                mrtStatus = {
                    order = 0,
                    name = function()
                        local loaded = C_AddOns.IsAddOnLoaded("MRT")
                        if loaded then
                            return "|cff00ff00MRT detected|r — /grt inv will auto-invite guild members via MRT"
                        else
                            return "|cffff4444MRT not installed|r — /grt inv will post to guild chat but cannot mass-invite"
                        end
                    end,
                    type = "description",
                    fontSize = "medium",
                },
                invitesEnabled = {
                    order = 1,
                    name = "Enable Invite Commands",
                    type = "toggle",
                    width = "full",
                },
                autoHeader = {
                    order = 10,
                    name = "Auto-Invite",
                    type = "header",
                    disabled = InvitesDisabled,
                },
                autoInviteEnabled = {
                    order = 11,
                    name = "Automatically send invite before raid",
                    type = "toggle",
                    width = "full",
                    disabled = InvitesDisabled,
                },
                autoInviteMinutes = {
                    order = 12,
                    name = "Minutes Before Raid",
                    type = "range",
                    min = 5, max = 60, step = 5,
                    disabled = InvitesDisabled,
                },
                commandsHeader = {
                    order = 20,
                    name = "Commands",
                    type = "header",
                    disabled = InvitesDisabled,
                },
                commandsDesc = {
                    order = 21,
                    name = "/grt inv  -- Send invite to guild chat",
                    type = "description",
                    fontSize = "medium",
                    disabled = InvitesDisabled,
                },
                keyword = {
                    order = 22,
                    name = "Invite Keyword",
                    desc = "Word raiders whisper to get an invite",
                    type = "input",
                    disabled = InvitesDisabled,
                },
                inviteTemplate = {
                    order = 23,
                    name = "Message Template",
                    type = "input",
                    multiline = 8,
                    width = "full",
                    disabled = InvitesDisabled,
                },
                templateVars = {
                    order = 24,
                    name = "Variables: %name% = your character  |  %keyword% = invite keyword  |  %flavor% = flavor text line",
                    type = "description",
                    disabled = InvitesDisabled,
                },
                flavorHeader = {
                    order = 30,
                    name = "Flavor Text",
                    type = "header",
                    disabled = InvitesDisabled,
                },
                flavorDesc = {
                    order = 31,
                    name = "Flavor lines rotate through all checked variations before any repeat. "
                        .. "Uncheck a variation to remove it from rotation permanently. "
                        .. "Use |cffffffff/grt flavor reset|r to restart the rotation from the beginning.",
                    type = "description",
                    disabled = InvitesDisabled,
                },
                flavorSelect = {
                    order = 32,
                    disabled = InvitesDisabled,
                    name = "",
                    type = "multiselect",
                    width = "full",
                    values = function()
                        local vals = {}
                        for i, v in ipairs(ns.VARIATIONS or {}) do
                            vals[i] = "[" .. (i - 1) .. "] " .. table.concat(v, " | ")
                        end
                        return vals
                    end,
                    get = function(_, key)
                        if not ns.GetUnseenSet then return true end
                        return ns.GetUnseenSet()[key] == true
                    end,
                    set = function(_, key, val)
                        if ns.SetVariationUnseen then
                            ns.SetVariationUnseen(key, val)
                        end
                    end,
                },
            },
        },
        -----------------------------------------------------------------
        -- Tab 3: Countdown
        -----------------------------------------------------------------
        countdown = {
            name = "Countdown",
            order = 3,
            type = "group",
            args = {
                countdownEnabled = {
                    order = 1,
                    name = "Enable Countdown",
                    type = "toggle",
                    width = "full",
                    set = SetWith(ns.EvaluateCountdownVisibility),
                },
                actionsHeader = {
                    order = 5,
                    name = "Actions",
                    type = "header",
                },
                openEditMode = {
                    order = 6,
                    name = "Open Edit Mode",
                    desc = "Reposition the ticker and dispatch widget. Dispatch docks below the ticker by default.",
                    type = "execute",
                    func = function()
                        ShowUIPanel(EditModeManagerFrame) -- luacheck: ignore 113
                    end,
                },
                testMode = {
                    order = 7,
                    name = "Test Mode",
                    desc = "Show ticker + dispatch for 15s and cycle through states",
                    type = "execute",
                    func = function()
                        if ns.testMode then
                            if ns.ExitTestMode then ns.ExitTestMode() end
                        else
                            if ns.EnterTestMode then ns.EnterTestMode() end
                        end
                    end,
                },
                settingsHeader = {
                    order = 10,
                    name = "Settings",
                    type = "header",
                },
                countdownWindow = {
                    order = 11,
                    name = "Countdown Start (minutes before raid)",
                    type = "range",
                    min = 5, max = 120, step = 5,
                },
                broadcastHeader = {
                    order = 20,
                    name = "Broadcast",
                    type = "header",
                },
                broadcastRaid = {
                    order = 21,
                    name = "Raid",
                    type = "toggle",
                },
                broadcastGuild = {
                    order = 22,
                    name = "Guild Chat",
                    type = "toggle",
                },
                milestoneAnnounce = {
                    order = 23,
                    name = "Milestone broadcasts (10m, 5m, 2m, pull)",
                    type = "toggle",
                    width = "full",
                },
                dispatchHeader = {
                    order = 30,
                    name = "Dispatch",
                    type = "header",
                },
                dispatchDesc = {
                    order = 31,
                    name = "Dispatch is a small status widget that docks below the countdown ticker. "
                        .. "It shows checkmarks for raid milestones — whether the invite has been sent "
                        .. "and whether RC Rotate has been triggered — so you can see at a glance what "
                        .. "still needs to happen before pull.",
                    type = "description",
                },
                dispatchEnabled = {
                    order = 32,
                    name = "Enable Dispatch",
                    type = "toggle",
                    width = "full",
                    set = SetWith(ns.EvaluateDispatchVisibility),
                },
                rcHeader = {
                    order = 33,
                    name = "RC Rotate",
                    type = "header",
                },
                rcRotateEnabled = {
                    order = 34,
                    name = "Auto-trigger /rc rotate before raid",
                    type = "toggle",
                    width = "full",
                    disabled = function()
                        return not C_AddOns.IsAddOnLoaded("RCLootCouncil_CouncilRotation")
                    end,
                },
                rcRotateMinutes = {
                    order = 35,
                    name = "Minutes before raid",
                    type = "range",
                    min = 1, max = 60, step = 1,
                    disabled = function()
                        return not ns.db.rcRotateEnabled or not C_AddOns.IsAddOnLoaded("RCLootCouncil_CouncilRotation")
                    end,
                },
                rcRotateDesc = {
                    order = 36,
                    name = function()
                        if C_AddOns.IsAddOnLoaded("RCLootCouncil_CouncilRotation") then
                            return "|cff00ff00RCLootCouncil_CouncilRotation detected|r"
                        else
                            return "|cffff4444RCLootCouncil_CouncilRotation not found|r — install the addon to enable this option"
                        end
                    end,
                    type = "description",
                },
                typoHeader = {
                    order = 40,
                    name = "Typography",
                    type = "header",
                },
                tickerFontSizeLabel = {
                    order = 41,
                    name = "Ticker",
                    type = "description",
                },
                tickerStrata = {
                    order = 42,
                    name = "Frame Strata",
                    type = "select",
                    values = STRATA_VALUES,
                    sorting = STRATA_ORDER,
                    set = SetWith(ns.ApplyTickerStrata),
                },
                countdownFontSize = {
                    order = 43,
                    name = "Font Size",
                    type = "range",
                    min = 14, max = 100, step = 1,
                    set = SetWith(ns.ApplyCountdownFont),
                },
                dispatchFontLabel = {
                    order = 44,
                    name = "Dispatch",
                    type = "description",
                },
                dispatchFontFace = {
                    order = 45,
                    name = "Font",
                    type = "select",
                    values = BuildFontValues,
                    set = SetWith(ns.ApplyDispatchFont),
                },
                dispatchFontSize = {
                    order = 46,
                    name = "Font Size",
                    type = "range",
                    min = 10, max = 40, step = 1,
                    set = SetWith(ns.ApplyDispatchFont),
                },
            },
        },
        -----------------------------------------------------------------
        -- Tab 4: Audit
        -----------------------------------------------------------------
        audit = {
            name = "Audit",
            order = 4,
            type = "group",
            args = {
                openAudit = {
                    order = 0,
                    name = "Open Audit Window",
                    desc = "Also accessible via /grt audit",
                    type = "execute",
                    func = function()
                        if ns.ToggleAuditWindow then ns.ToggleAuditWindow() end
                    end,
                },
                auditDesc = {
                    order = 1,
                    name = "|cff888888These settings are also adjustable in the audit window|r",
                    type = "description",
                },
                auditEnchantThreshold = {
                    order = 1,
                    name = "Enchant Threshold",
                    type = "select",
                    values = THRESH_VALUES,
                    sorting = THRESH_ORDER,
                    set = SetWith(ns.RefreshAuditUI),
                },
                auditGemThreshold = {
                    order = 2,
                    name = "Gem Threshold",
                    type = "select",
                    values = THRESH_VALUES,
                    sorting = THRESH_ORDER,
                    set = SetWith(ns.RefreshAuditUI),
                },
                auditEpicGemMin = {
                    order = 3,
                    name = "Epic Gem Minimum",
                    type = "select",
                    values = EPIC_VALUES,
                    sorting = { 1, 2 },
                    set = SetWith(ns.RefreshAuditUI),
                },
                reportHeader = {
                    order = 9,
                    name = "Report To",
                    type = "header",
                },
                auditReportGroup = {
                    order = 10,
                    name = "Party/Raid",
                    type = "toggle",
                },
                auditReportWhisper = {
                    order = 11,
                    name = "Whisper",
                    type = "toggle",
                },
                auditReportGuild = {
                    order = 12,
                    name = "Guild",
                    type = "toggle",
                },
                summaryDesc = {
                    order = 20,
                    name = function()
                        if not ns.db then return "" end
                        local e = THRESH_VALUES[ns.db.auditEnchantThreshold] or THRESH_VALUES.high_q1
                        local g = THRESH_VALUES[ns.db.auditGemThreshold] or THRESH_VALUES.high_q1
                        local ep = EPIC_VALUES[ns.db.auditEpicGemMin] or EPIC_VALUES[1]
                        return string.format("|cff888888Ench: %s, Gems: %s, Epic: %s|r", e, g, ep)
                    end,
                    type = "description",
                    fontSize = "medium",
                },
            },
        },
    },
}

------------------------------------------------------------
-- Register with AceConfig
------------------------------------------------------------
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

AceConfigRegistry:RegisterOptionsTable("GitRaidTools", options)
local _, categoryID = AceConfigDialog:AddToBlizOptions("GitRaidTools", "Git's Raid Tools")
ns.settingsCategoryID = categoryID
