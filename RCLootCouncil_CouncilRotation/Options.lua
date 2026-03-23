---@class RCLootCouncil
local addon = LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil")
---@class RCCouncilRotation
local CR = addon:GetModule("RCCouncilRotation")
local L = LibStub("AceLocale-3.0"):GetLocale("RCCouncilRotation")

local grtLoaded = C_AddOns.IsAddOnLoaded("GitRaidTools")

------ Options ------
function CR:OptionsTable()
    local options = {
        name = L["Council Rotation"],
        order = 1,
        type = "group",
        childGroups = "tab",
        args = {
            desc = {
                name = format(L["addon_desc"], self.version),
                order = 0,
                type = "description",
            },
            -----------------------------------------------------------------
            -- Tab 1: General
            -----------------------------------------------------------------
            general = {
                name = _G.GENERAL,
                order = 1,
                type = "group",
                args = {
                    settings = {
                        name = L["Council Rotation"],
                        order = 1,
                        type = "group",
                        inline = true,
                        args = {
                            enabled = {
                                order = 1,
                                name = L["Enable"],
                                desc = L["enable_desc"],
                                type = "toggle",
                                width = "full",
                                get = function() return self.db.enabled end,
                                set = function(_, val) self.db.enabled = val end,
                            },
                            seats = {
                                order = 2,
                                name = L["Rotating Seats"],
                                desc = L["seats_desc"],
                                type = "range",
                                min = 1,
                                max = 5,
                                step = 1,
                                get = function() return self.db.seats end,
                                set = function(_, val) self.db.seats = val end,
                            },
                            autoRotate = {
                                order = 3,
                                name = L["Auto-Rotate"],
                                desc = grtLoaded and L["auto_rotate_desc"] or L["grt_not_installed"],
                                type = "toggle",
                                disabled = not grtLoaded,
                                get = function() return self.db.autoRotate end,
                                set = function(_, val)
                                    self.db.autoRotate = val
                                    if val then
                                        self:ScheduleAutoRotation()
                                    end
                                end,
                            },
                            rotateHeader = {
                                order = 4,
                                name = "",
                                type = "header",
                            },
                            rotate = {
                                order = 5,
                                name = L["Rotate Now"],
                                desc = L["rotate_now_desc"],
                                type = "execute",
                                confirm = true,
                                func = function() self:DoRotate() end,
                            },
                            rotateCmd = {
                                order = 6,
                                name = L["rotate_cmd_hint"],
                                type = "description",
                                fontSize = "medium",
                            },
                        },
                    },
                    ranks = {
                        name = L["Eligible Guild Ranks"],
                        desc = L["ranks_desc"],
                        order = 2,
                        type = "group",
                        inline = true,
                        args = {
                            rankSelect = {
                                order = 1,
                                name = "",
                                type = "multiselect",
                                width = "full",
                                values = function()
                                    local vals = {}
                                    for i = 1, GuildControlGetNumRanks() do
                                        vals[i] = i .. " - " .. (GuildControlGetRankName(i) or "Unknown")
                                    end
                                    return vals
                                end,
                                get = function(_, key) return self.db.eligibleRanks[key] end,
                                set = function(_, key, val) self.db.eligibleRanks[key] = val or nil end,
                            },
                        },
                    },
                    permanentRanks = {
                        name = L["Permanent Council Ranks"],
                        desc = L["permanent_ranks_desc"],
                        order = 2,
                        type = "group",
                        inline = true,
                        args = {
                            enabled = {
                                order = 0,
                                name = L["Enable Permanent Ranks"],
                                desc = L["permanent_ranks_enable_desc"],
                                type = "toggle",
                                width = "full",
                                get = function() return self.db.permanentRanksEnabled end,
                                set = function(_, val) self.db.permanentRanksEnabled = val end,
                            },
                            rankSelect = {
                                order = 1,
                                name = "",
                                type = "multiselect",
                                width = "full",
                                disabled = function() return not self.db.permanentRanksEnabled end,
                                values = function()
                                    local vals = {}
                                    for i = 1, GuildControlGetNumRanks() do
                                        vals[i] = i .. " - " .. (GuildControlGetRankName(i) or "Unknown")
                                    end
                                    return vals
                                end,
                                get = function(_, key) return self.db.permanentRanks[key] end,
                                set = function(_, key, val) self.db.permanentRanks[key] = val or nil end,
                            },
                        },
                    },
                },
            },
            -----------------------------------------------------------------
            -- Tab 2: Announcements
            -----------------------------------------------------------------
            announcements = {
                name = L["Announcements"],
                order = 2,
                type = "group",
                args = {
                    muteWarning = {
                        order = 0,
                        name = "|cFFFF4444" .. L["Mute Active"] .. "|r",
                        desc = L["mute_active_desc"],
                        type = "description",
                        fontSize = "medium",
                        hidden = function() return not CR:IsMuted() end,
                    },
                    raidAnnounce = {
                        name = L["Raid Announcement"],
                        order = 1,
                        type = "group",
                        inline = true,
                        args = {
                            enabled = {
                                order = 1,
                                name = L["Raid Announcement"],
                                desc = L["raid_announce_desc"],
                                type = "toggle",
                                get = function() return self.db.announceToRaid end,
                                set = function(_, val) self.db.announceToRaid = val end,
                            },
                            template = {
                                order = 2,
                                name = L["Announcement Template"],
                                desc = L["announce_template_desc"],
                                type = "input",
                                width = "full",
                                multiline = 2,
                                get = function() return self.db.announceTemplate end,
                                set = function(_, val) self.db.announceTemplate = val end,
                            },
                        },
                    },
                    whisper = {
                        name = L["Whisper Instructions"],
                        order = 2,
                        type = "group",
                        inline = true,
                        args = {
                            enabled = {
                                order = 1,
                                name = L["Whisper Instructions"],
                                desc = L["whisper_desc"],
                                type = "toggle",
                                get = function() return self.db.whisperInstructions end,
                                set = function(_, val) self.db.whisperInstructions = val end,
                            },
                            message = {
                                order = 2,
                                name = L["Instruction Message"],
                                desc = L["instruction_msg_desc"],
                                type = "input",
                                width = "full",
                                multiline = 8,
                                get = function() return self.db.instructionMessage end,
                                set = function(_, val) self.db.instructionMessage = val end,
                            },
                        },
                    },
                },
            },
            -----------------------------------------------------------------
            -- Tab 3: History
            -----------------------------------------------------------------
            history = {
                name = L["History"],
                order = 3,
                type = "group",
                args = {
                    actions = {
                        name = "",
                        order = 0,
                        type = "group",
                        inline = true,
                        args = {
                            clearHistory = {
                                order = 1,
                                name = L["Clear History"],
                                desc = L["clear_history_desc"],
                                type = "execute",
                                confirm = true,
                                func = function()
                                    self:ClearHistory()
                                    LibStub("AceConfigRegistry-3.0"):NotifyChange("RCLootCouncil - Council Rotation")
                                end,
                            },
                            resetCycle = {
                                order = 2,
                                name = L["Reset Cycle"],
                                desc = L["reset_cycle_desc"],
                                type = "execute",
                                confirm = true,
                                func = function() self:ResetCycle() end,
                            },
                        },
                    },
                    entries = {
                        order = 1,
                        name = function()
                            return self:FormatHistoryText()
                        end,
                        type = "description",
                        fontSize = "medium",
                        width = "full",
                    },
                },
            },
        },
    }

    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("RCLootCouncil - Council Rotation", options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
        "RCLootCouncil - Council Rotation",
        L["Council Rotation"],
        "RCLootCouncil"
    )
end

---------------------------------------------------------------------------
-- Dynamic Display
---------------------------------------------------------------------------

--- Format history entries as a single text block for the description element.
function CR:FormatHistoryText()
    if #self.db.history == 0 then
        return L["No history entries."]
    end
    local lines = {}
    for _, entry in ipairs(self.db.history) do
        local memberNames = {}
        for _, member in ipairs(entry.members) do
            local classColor = addon:GetClassColor(member.class)
            local hex = classColor and ("|cFF" .. addon.Utils:RGBToHex(classColor.r, classColor.g, classColor.b)) or "|cFFFFFFFF"
            tinsert(memberNames, hex .. member.name .. "|r")
        end
        tinsert(lines, entry.date .. "  —  " .. table.concat(memberNames, ", "))
    end
    return table.concat(lines, "\n")
end

