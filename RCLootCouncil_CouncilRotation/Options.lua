---@class RCLootCouncil
local addon = LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil")
---@class RCCouncilRotation
local CR = addon:GetModule("RCCouncilRotation")
local L = LibStub("AceLocale-3.0"):GetLocale("RCCouncilRotation")

local tremove = table.remove

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
                            testRotate = {
                                order = 6,
                                name = L["Test Rotate"],
                                desc = L["test_rotate_desc"],
                                type = "execute",
                                func = function() self:DoTestRotate() end,
                            },
                            rotateCmd = {
                                order = 7,
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
                            formatDesc = {
                                order = 2,
                                name = L["announce_format_desc"],
                                type = "description",
                                fontSize = "medium",
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
                            deleteLatest = {
                                order = 2,
                                name = L["Delete Latest"],
                                desc = L["delete_latest_desc"],
                                type = "execute",
                                disabled = function() return #self.db.history == 0 end,
                                func = function()
                                    tremove(self.db.history, 1)
                                    LibStub("AceConfigRegistry-3.0"):NotifyChange("RCLootCouncil - Council Rotation")
                                end,
                            },
                            resetCycle = {
                                order = 3,
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
        local entryType = entry.type or "rotation" -- backward compat

        if entryType == "cycle_reset" then
            local reason = entry.reason == "manual" and L["manual_reset"] or L["pool_exhausted"]
            tinsert(lines, entry.date .. "  —  " .. L["Cycle Reset"] .. " (" .. reason .. ")")
        else
            local memberNames = {}
            for _, member in ipairs(entry.members or {}) do
                local classColor = addon:GetClassColor(member.class)
                local hex = classColor and ("|cFF" .. addon.Utils:RGBToHex(classColor.r, classColor.g, classColor.b)) or "|cFFFFFFFF"
                tinsert(memberNames, hex .. member.name .. "|r")
            end
            local line = entry.date .. "  —  " .. table.concat(memberNames, ", ")

            if entry.deferred and #entry.deferred > 0 then
                local dnames = {}
                for _, m in ipairs(entry.deferred) do tinsert(dnames, m.name) end
                line = line .. "  |cFFFFFF00[Deferred: " .. table.concat(dnames, ", ") .. "]|r"
            end
            if entry.satOut and #entry.satOut > 0 then
                local snames = {}
                for _, m in ipairs(entry.satOut) do tinsert(snames, m.name) end
                line = line .. "  |cFFFF4444[Sat Out: " .. table.concat(snames, ", ") .. "]|r"
            end

            tinsert(lines, line)
        end
    end
    return table.concat(lines, "\n")
end

