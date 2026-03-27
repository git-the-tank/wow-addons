--- @class RCLootCouncil
local addon = LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil")
---@class RCCouncilRotation : AceModule, AceEvent-3.0, AceTimer-3.0
local CR = addon:NewModule("RCCouncilRotation", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("RCCouncilRotation")

local tinsert, tremove, pairs, ipairs, wipe = table.insert, table.remove, pairs, ipairs, wipe
local tIndexOf = tIndexOf
local GetNumGuildMembers, GetGuildRosterInfo = GetNumGuildMembers, GetGuildRosterInfo
local GetNumGroupMembers, GetRaidRosterInfo = GetNumGroupMembers, GetRaidRosterInfo
local IsInRaid, UnitIsGroupLeader = IsInRaid, UnitIsGroupLeader
local SendChatMessage = SendChatMessage
local date, time, random = date, time, math.random

local testMode = false

function CR:OnInitialize()
    self.version = C_AddOns.GetAddOnMetadata("RCLootCouncil_CouncilRotation", "Version")

    self.defaults = {
        profile = {
            enabled = true,
            seats = 2,
            eligibleRanks = {},        -- {[rankIndex] = true} guild ranks in the pool
            permanentRanksEnabled = false, -- auto-add members of certain ranks to council
            permanentRanks = {},       -- {[rankIndex] = true} ranks always on council
            announceToRaid = true,
            whisperInstructions = true,
            announceTemplate = L["default_announce"],
            instructionMessage = L["default_instructions"],
            -- Persistent tracking
            currentRotating = {},      -- GUIDs added by this addon for current session
            selectedHistory = {},      -- {[guid] = true} GUIDs selected this cycle
            history = {},              -- {{date=str, timestamp=num, members={{name,guid,class},...}}, ...}
        },
    }

    addon.db:RegisterNamespace("CouncilRotation", self.defaults)
    self.db = addon.db:GetNamespace("CouncilRotation").profile

    -- AceDB defaults for tables are read-only references. Force mutable tables
    -- into the profile so writes to nested keys persist across calls.
    if not rawget(self.db, "currentRotating") then self.db.currentRotating = {} end
    if not rawget(self.db, "selectedHistory") then self.db.selectedHistory = {} end
    if not rawget(self.db, "history") then self.db.history = {} end
    if not rawget(self.db, "eligibleRanks") then self.db.eligibleRanks = {} end
    if not rawget(self.db, "permanentRanks") then self.db.permanentRanks = {} end

    -- Register chat command: /rc rotate [test]
    addon:ModuleChatCmd(self, "HandleSlashCmd", nil, L["chat_cmd_desc"], "rotate", "councilrotation")

    self:ScheduleTimer("Enable", 0) -- Delay to let guild data load
end

function CR:OnEnable()
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    -- Request guild roster so rank data is available
    C_GuildInfo.GuildRoster()

    -- Setup options UI
    self:OptionsTable()

end

function CR:OnDisable()
    self:UnregisterAllEvents()
    self:CancelAllTimers()
end

---------------------------------------------------------------------------
-- Guild Roster
---------------------------------------------------------------------------
function CR:GUILD_ROSTER_UPDATE()
    -- Guild data is now available for rank queries
end

---------------------------------------------------------------------------
-- Slash Command Handler
---------------------------------------------------------------------------
function CR:DoTestRotate()
    testMode = true
    addon:Print(L["test_mode_on"])
    self:DoRotate()
    testMode = false
end

function CR:HandleSlashCmd(arg)
    if arg == "test" then
        self:DoTestRotate()
    elseif arg == "" or not arg then
        self:DoRotate()
    else
        addon:Print(format(L["unknown_arg"], arg))
    end
end

---------------------------------------------------------------------------
-- Permanent Council Ranks
---------------------------------------------------------------------------
--- Ensure all raid members with permanent ranks are on the council.
--- Returns the number of members added.
function CR:EnforcePermanentRanks()
    if not self.db.permanentRanksEnabled then return 0 end
    if not testMode and not IsInRaid() then return 0 end

    -- Build set of GUIDs currently in raid (or online guild members in test mode)
    local raidGUIDs = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name then
                local guid = UnitGUID("raid" .. i)
                if guid then
                    raidGUIDs[guid] = true
                end
            end
        end
    elseif testMode then
        local numGuild = GetNumGuildMembers()
        for i = 1, numGuild do
            local _, _, _, _, _, _, _, _, online, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            if guid and online then
                raidGUIDs[guid] = true
            end
        end
    end

    -- Find guild members with permanent ranks who are in raid but not on council
    local council = {}
    for _, guid in ipairs(addon.db.profile.council) do
        council[guid] = true
    end

    local added = 0
    local numGuild = GetNumGuildMembers()
    for i = 1, numGuild do
        local _, _, rankIndex, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if guid and self.db.permanentRanks[rankIndex + 1] and raidGUIDs[guid] and not council[guid] then
            tinsert(addon.db.profile.council, guid)
            council[guid] = true
            added = added + 1
        end
    end

    if added > 0 then
        addon:CouncilChanged()
        addon:Print(format(L["permanent_ranks_synced"], added))
    end
    return added
end

---------------------------------------------------------------------------
-- Core Rotation Logic
---------------------------------------------------------------------------
function CR:DoRotate()
    if not self.db.enabled then
        return addon:Print(L["rotation_disabled"])
    end

    if not testMode then
        if not IsInRaid() then
            return addon:Print(L["rotation_not_in_raid"])
        end
        if not self:IsML() then
            return addon:Print(L["rotation_not_ml"])
        end
    end

    -- Ensure permanent rank members are on council first
    self:EnforcePermanentRanks()

    -- Build eligible pool from raid members matching selected guild ranks
    local pool = self:BuildEligiblePool()

    if #pool == 0 then
        return addon:Print(L["rotation_no_eligible"])
    end

    local seats = self.db.seats
    if #pool < seats then
        addon:Print(format(L["rotation_not_enough"], #pool, seats))
        seats = #pool
    end

    -- Select candidate members
    local selected = self:SelectMembers(pool, seats)

    -- Capture testMode for the async dialog (Risk #2: async testMode lifecycle)
    self._capturedTestMode = testMode

    -- Show confirmation dialog instead of immediately applying
    self:ShowConfirmationDialog(selected, pool)
end

---------------------------------------------------------------------------
-- Pool Building
---------------------------------------------------------------------------
function CR:BuildEligiblePool()
    local pool = {}

    -- Build set of GUIDs currently in group
    local raidGUIDs = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name then
                local guid = UnitGUID("raid" .. i)
                if guid then
                    raidGUIDs[guid] = name
                end
            end
        end
    elseif testMode then
        -- In test mode, use guild members directly as the "raid" pool
        local numGuild = GetNumGuildMembers()
        for i = 1, numGuild do
            local name, _, rankIndex, _, _, _, _, _, online, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            if guid and online and self.db.eligibleRanks[rankIndex + 1] then
                raidGUIDs[guid] = Ambiguate(name, "short")
            end
        end
    end

    -- Build set of guild members with eligible ranks
    local eligibleGuildGUIDs = {}
    local numGuild = GetNumGuildMembers()
    for i = 1, numGuild do
        local name, _, rankIndex, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if guid and self.db.eligibleRanks[rankIndex + 1] then -- rankIndex is 0-based, UI is 1-based
            eligibleGuildGUIDs[guid] = {
                name = Ambiguate(name, "short"),
                guid = guid,
                class = select(11, GetGuildRosterInfo(i)),
            }
        end
    end

    -- Intersect: must be in raid AND have an eligible guild rank
    -- Exclude permanent council members (those not added by this addon)
    -- Exclude self (ML stays on council automatically)
    local myGUID = UnitGUID("player")
    local permanentCouncil = self:GetPermanentCouncilGUIDs()

    for guid, info in pairs(eligibleGuildGUIDs) do
        if raidGUIDs[guid]
            and guid ~= myGUID
            and not permanentCouncil[guid]
            and not self.db.selectedHistory[guid] then
            tinsert(pool, info)
        end
    end

    -- If pool is empty because everyone has been selected, reset cycle
    if #pool == 0 then
        local poolBeforeReset = {}
        for guid, info in pairs(eligibleGuildGUIDs) do
            if raidGUIDs[guid]
                and guid ~= myGUID
                and not permanentCouncil[guid] then
                tinsert(poolBeforeReset, info)
            end
        end
        if #poolBeforeReset > 0 then
            addon:Print(L["rotation_cycle_reset"])
            wipe(self.db.selectedHistory)
            pool = poolBeforeReset
        end
    end

    return pool
end

--- Get GUIDs of council members NOT added by this addon (permanent members).
function CR:GetPermanentCouncilGUIDs()
    local permanent = {}
    local rotating = {}
    for _, guid in ipairs(self.db.currentRotating) do
        rotating[guid] = true
    end
    for _, guid in ipairs(addon.db.profile.council) do
        if not rotating[guid] then
            permanent[guid] = true
        end
    end
    return permanent
end

---------------------------------------------------------------------------
-- Member Selection
---------------------------------------------------------------------------
function CR:SelectMembers(pool, count)
    -- Shallow copy so we never mutate the caller's pool (Risk #1)
    local copy = {}
    for i = 1, #pool do copy[i] = pool[i] end

    -- Fisher-Yates shuffle the copy, then take the first `count`
    local n = #copy
    for i = n, 2, -1 do
        local j = random(1, i)
        copy[i], copy[j] = copy[j], copy[i]
    end

    local selected = {}
    for i = 1, count do
        tinsert(selected, copy[i])
    end
    return selected
end

---------------------------------------------------------------------------
-- Council Modification
---------------------------------------------------------------------------
function CR:RemoveCurrentRotating()
    for _, guid in ipairs(self.db.currentRotating) do
        local idx = tIndexOf(addon.db.profile.council, guid)
        if idx then
            tremove(addon.db.profile.council, idx)
        end
    end
    wipe(self.db.currentRotating)
end

function CR:ApplyToCouncil(selected)
    for _, member in ipairs(selected) do
        tinsert(addon.db.profile.council, member.guid)
        tinsert(self.db.currentRotating, member.guid)
        -- Mark as selected in this cycle
        self.db.selectedHistory[member.guid] = true
    end
    addon:CouncilChanged()
end

---------------------------------------------------------------------------
-- History
---------------------------------------------------------------------------
function CR:RecordHistory(approved, deferred, satOut)
    local members = {}
    for _, member in ipairs(approved) do
        tinsert(members, { name = member.name, guid = member.guid, class = member.class })
    end

    local entry = {
        type = "rotation",
        date = date("%Y-%m-%d"),
        timestamp = time(),
        members = members,
    }

    if deferred and #deferred > 0 then
        entry.deferred = {}
        for _, member in ipairs(deferred) do
            tinsert(entry.deferred, { name = member.name, guid = member.guid, class = member.class })
        end
    end

    if satOut and #satOut > 0 then
        entry.satOut = {}
        for _, member in ipairs(satOut) do
            tinsert(entry.satOut, { name = member.name, guid = member.guid, class = member.class })
        end
    end

    tinsert(self.db.history, 1, entry)
end

---------------------------------------------------------------------------
-- Announcements
---------------------------------------------------------------------------
function CR:AnnounceRotation(approved, isTestMode)

    -- Build full council roster filtered to raid attendance
    local raidGUIDs = self:GetRaidGUIDs(isTestMode)

    local rotatingSet = {}
    for _, guid in ipairs(self.db.currentRotating) do
        rotatingSet[guid] = true
    end

    local permanentNames = {}
    local rotatingNames = {}
    for _, guid in ipairs(addon.db.profile.council) do
        if raidGUIDs[guid] then
            local name = raidGUIDs[guid]
            if rotatingSet[guid] then
                tinsert(rotatingNames, name)
            else
                tinsert(permanentNames, name)
            end
        end
    end

    -- Build announcement lines
    if self.db.announceToRaid then
        local lines = { L["announce_header"] }
        if #permanentNames > 0 then
            tinsert(lines, L["announce_permanent"] .. table.concat(permanentNames, ", "))
        end
        if #rotatingNames > 0 then
            tinsert(lines, L["announce_rotating"] .. table.concat(rotatingNames, ", "))
        end

        for _, line in ipairs(lines) do
            if isTestMode then
                addon:Print("|cFF888888[TEST RAID]|r " .. line)
            elseif IsInRaid() then
                local channel = IsInInstance() and "INSTANCE_CHAT" or "RAID"
                pcall(SendChatMessage, line, channel)
            end
        end
    end

    -- Whisper instructions to each approved member
    if self.db.whisperInstructions then
        for _, member in ipairs(approved) do
            for line in self.db.instructionMessage:gmatch("[^\n]+") do
                if isTestMode then
                    addon:Print("|cFF888888[TEST WHISPER \226\134\146 " .. member.name .. "]|r " .. line)
                else
                    pcall(SendChatMessage, line, "WHISPER", nil, member.name)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Raid GUID Helper
---------------------------------------------------------------------------
--- Build a map of {[guid] = name} for all members in the current raid (or
--- online guild members in test mode). Shared by multiple functions.
function CR:GetRaidGUIDs(isTestMode)
    local raidGUIDs = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name then
                local guid = UnitGUID("raid" .. i)
                if guid then
                    raidGUIDs[guid] = Ambiguate(name, "short")
                end
            end
        end
    elseif isTestMode then
        local numGuild = GetNumGuildMembers()
        for i = 1, numGuild do
            local name, _, _, _, _, _, _, _, online, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            if guid and online then
                raidGUIDs[guid] = Ambiguate(name, "short")
            end
        end
    end
    return raidGUIDs
end

---------------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------------
function CR:IsML()
    -- Check if we're the master looter or the group leader (for personal loot councils)
    if addon.masterLooter and addon:UnitIsUnit(addon.masterLooter, "player") then
        return true
    end
    -- Fallback: group leader can also manage council
    return UnitIsGroupLeader("player")
end

function CR:FormatNames(selected)
    local names = {}
    for _, member in ipairs(selected) do
        tinsert(names, member.name)
    end
    return table.concat(names, ", ")
end

function CR:OpenOptions()
    -- Open to the Council Rotation options panel
    Settings.OpenToCategory(addon.optionsFrame.name)
end

function CR:ResetCycle()
    wipe(self.db.selectedHistory)
    addon:Print(L["rotation_cycle_reset"])
end

function CR:ClearHistory()
    wipe(self.db.history)
end
