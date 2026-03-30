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
                muted = {
                    order = 1,
                    name = "Mute Announcements",
                    desc = "Mute all raid/guild/instance announcements",
                    type = "toggle",
                    width = "full",
                },
                scheduleHeader = {
                    order = 10,
                    name = "Raid Schedule",
                    type = "header",
                },
                raidHour = {
                    order = 11,
                    name = "Raid Start Hour",
                    desc = "Server time, 24-hour format (20 = 8 PM)",
                    type = "range",
                    min = 0, max = 23, step = 1,
                },
                raidMinute = {
                    order = 12,
                    name = "Raid Start Minute",
                    type = "range",
                    min = 0, max = 55, step = 5,
                },
                daysHeader = {
                    order = 20,
                    name = "Raid Days",
                    type = "header",
                },
                raidDays = {
                    order = 21,
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
                    order = 30,
                    name = "Typography",
                    type = "header",
                },
                fontFace = {
                    order = 31,
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
                },
                autoInviteEnabled = {
                    order = 11,
                    name = "Automatically send invite before raid",
                    type = "toggle",
                    width = "full",
                },
                autoInviteMinutes = {
                    order = 12,
                    name = "Minutes Before Raid",
                    type = "range",
                    min = 5, max = 60, step = 5,
                },
                commandsHeader = {
                    order = 20,
                    name = "Commands",
                    type = "header",
                },
                commandsDesc = {
                    order = 21,
                    name = "/grt inv [n]  -- Send invite to guild chat\n"
                        .. "/grt render [n]  -- Preview invite locally\n"
                        .. "/grt flavor  -- Copyable flavor list\n"
                        .. "/grt unseen  -- Show pool status\n"
                        .. "/grt clear  -- Reset unseen pool",
                    type = "description",
                    fontSize = "medium",
                },
                flavorHeader = {
                    order = 30,
                    name = "Flavor Text",
                    type = "header",
                },
                flavorDesc = {
                    order = 31,
                    name = "|cff888888Checked = in rotation, Unchecked = skipped|r",
                    type = "description",
                },
                flavorSelect = {
                    order = 32,
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
                countdownWindow = {
                    order = 1,
                    name = "Countdown Start (minutes before raid)",
                    type = "range",
                    min = 5, max = 120, step = 5,
                },
                broadcastHeader = {
                    order = 10,
                    name = "Broadcast",
                    type = "header",
                },
                broadcastInstance = {
                    order = 11,
                    name = "Instance Chat",
                    type = "toggle",
                },
                broadcastGuild = {
                    order = 12,
                    name = "Guild Chat",
                    type = "toggle",
                },
                milestoneAnnounce = {
                    order = 13,
                    name = "Milestone broadcasts (10m, 5m, 2m, pull)",
                    type = "toggle",
                    width = "full",
                },
                tickerHeader = {
                    order = 20,
                    name = "Ticker",
                    type = "header",
                },
                tickerStrata = {
                    order = 21,
                    name = "Frame Strata",
                    type = "select",
                    values = STRATA_VALUES,
                    sorting = STRATA_ORDER,
                    set = SetWith(ns.ApplyTickerStrata),
                },
                countdownFontSize = {
                    order = 22,
                    name = "Font Size",
                    type = "range",
                    min = 14, max = 100, step = 1,
                    set = SetWith(ns.ApplyCountdownFont),
                },
            },
        },
        -----------------------------------------------------------------
        -- Tab 4: Dispatch
        -----------------------------------------------------------------
        dispatch = {
            name = "Dispatch",
            order = 4,
            type = "group",
            args = {
                dispatchEnabled = {
                    order = 1,
                    name = "Enable Dispatch Display",
                    type = "toggle",
                    width = "full",
                    set = SetWith(ns.EvaluateDispatchVisibility),
                },
                rcHeader = {
                    order = 10,
                    name = "RC Rotate",
                    type = "header",
                },
                rcRotateEnabled = {
                    order = 11,
                    name = "Auto-trigger /rc rotate at raid start",
                    type = "toggle",
                    width = "full",
                },
                rcRotateDesc = {
                    order = 12,
                    name = "|cff888888Requires RCLootCouncil + CouncilRotation addon|r",
                    type = "description",
                },
                typoHeader = {
                    order = 20,
                    name = "Typography",
                    type = "header",
                },
                dispatchFontFace = {
                    order = 21,
                    name = "Font",
                    type = "select",
                    values = BuildFontValues,
                    set = SetWith(ns.ApplyDispatchFont),
                },
                dispatchFontSize = {
                    order = 22,
                    name = "Font Size",
                    type = "range",
                    min = 10, max = 40, step = 1,
                    set = SetWith(ns.ApplyDispatchFont),
                },
                previewHeader = {
                    order = 30,
                    name = "Preview",
                    type = "header",
                },
                testMode = {
                    order = 31,
                    name = "Test Mode",
                    desc = "Shows ticker + dispatch for 15s, cycles through states",
                    type = "execute",
                    func = function()
                        if ns.testMode then
                            if ns.ExitTestMode then ns.ExitTestMode() end
                        else
                            if ns.EnterTestMode then ns.EnterTestMode() end
                        end
                    end,
                },
            },
        },
        -----------------------------------------------------------------
        -- Tab 5: Audit
        -----------------------------------------------------------------
        audit = {
            name = "Audit",
            order = 5,
            type = "group",
            args = {
                auditDesc = {
                    order = 0,
                    name = "|cff888888These settings are also toggleable in the audit window|r",
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
                summaryDesc = {
                    order = 10,
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
