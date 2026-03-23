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
local GetGameTime, GetServerTime = GetGameTime, GetServerTime
local SendChatMessage = SendChatMessage
local date, time, random = date, time, math.random

-- Forward declarations
local grtLoaded = C_AddOns.IsAddOnLoaded("GitRaidTools")
local autoRotateScheduled = false
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
            autoRotate = false,        -- auto-rotate at raid time (requires GRT)
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

    -- Schedule auto-rotation if GRT is loaded
    if grtLoaded and self.db.autoRotate then
        self:ScheduleAutoRotation()
    end
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
-- Auto-Rotation (GitRaidTools integration)
---------------------------------------------------------------------------
function CR:ScheduleAutoRotation()
    if not grtLoaded or autoRotateScheduled then return end
    if not GitRaidToolsDB then return end

    local raidHour = GitRaidToolsDB.raidHour
    local raidMinute = GitRaidToolsDB.raidMinute
    local raidDays = GitRaidToolsDB.raidDays
    if not raidHour or not raidDays then return end

    -- Check if today is a raid day
    local currentDay = date("*t").wday
    local isRaidDay = false
    for _, day in ipairs(raidDays) do
        if day == currentDay then
            isRaidDay = true
            break
        end
    end
    if not isRaidDay then return end

    -- Calculate seconds until raid time
    local hours, minutes = GetGameTime()
    local currentSec = hours * 3600 + minutes * 60 + (GetServerTime() % 60)
    local raidSec = raidHour * 3600 + (raidMinute or 0) * 60
    local diff = raidSec - currentSec

    if diff < 0 then return end -- Raid time already passed today

    autoRotateScheduled = true
    self:ScheduleTimer("OnAutoRotateFired", diff)
end

function CR:OnAutoRotateFired()
    autoRotateScheduled = false
    if not self.db.enabled then return end
    if not self.db.autoRotate then return end

    -- TODO: remove testMode once validated in raid
    testMode = true
    addon:Print(L["rotation_auto_triggered"])
    self:DoRotate()
    testMode = false
end

---------------------------------------------------------------------------
-- Slash Command Handler
---------------------------------------------------------------------------
function CR:HandleSlashCmd(arg)
    if arg == "test" then
        testMode = true
        addon:Print(L["test_mode_on"])
        self:DoRotate()
        testMode = false
    elseif arg == "time" then
        self:PrintTimeInfo()
    elseif arg == "" or not arg then
        self:DoRotate()
    else
        addon:Print(format(L["unknown_arg"], arg))
    end
end

function CR:PrintTimeInfo()
    local hours, minutes = GetGameTime()
    local seconds = GetServerTime() % 60
    local now = format("%02d:%02d:%02d", hours, minutes, seconds)

    if not grtLoaded or not GitRaidToolsDB then
        addon:Print("Now " .. now .. " -- GitRaidTools not loaded")
        return
    end

    local rh = GitRaidToolsDB.raidHour
    local rm = GitRaidToolsDB.raidMinute or 0
    local raid = format("%02d:%02d:00", rh, rm)
    local scheduled = autoRotateScheduled and "yes" or "no"

    addon:Print("Now " .. now .. " -- Raid: " .. raid .. " -- Auto scheduled: " .. scheduled)
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

    -- Remove previous rotating members from council
    self:RemoveCurrentRotating()

    -- Select new members
    local selected = self:SelectMembers(pool, seats)

    -- Add to council
    self:ApplyToCouncil(selected)

    -- Record in history
    self:RecordHistory(selected)

    -- Announce
    self:AnnounceRotation(selected)

    -- Print confirmation
    local names = self:FormatNames(selected)
    addon:Print(format(L["rotation_success"], names))
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
    local selected = {}
    -- Fisher-Yates shuffle the pool, then take the first `count`
    local n = #pool
    for i = n, 2, -1 do
        local j = random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    for i = 1, count do
        tinsert(selected, pool[i])
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
function CR:RecordHistory(selected)
    local members = {}
    for _, member in ipairs(selected) do
        tinsert(members, {
            name = member.name,
            guid = member.guid,
            class = member.class,
        })
    end
    tinsert(self.db.history, 1, {
        date = date("%Y-%m-%d"),
        timestamp = time(),
        members = members,
    })
end

---------------------------------------------------------------------------
-- Announcements
---------------------------------------------------------------------------
function CR:IsMuted()
    return grtLoaded and GitRaidToolsDB and GitRaidToolsDB.muted
end

function CR:AnnounceRotation(selected)
    if self:IsMuted() then return end

    local names = self:FormatNames(selected)

    -- Raid announcement
    if self.db.announceToRaid then
        local msg = self.db.announceTemplate:gsub("{names}", names)
        if testMode then
            addon:Print("|cFF888888[TEST RAID]|r " .. msg)
        elseif IsInRaid() then
            local channel = IsInInstance() and "INSTANCE_CHAT" or "RAID"
            local ok, err = pcall(SendChatMessage, msg, channel)
            if not ok then
                addon:Print("|cFFFF4444Raid announce failed:|r " .. tostring(err))
            end
        end
    end

    -- Whisper instructions to each selected member
    if self.db.whisperInstructions then
        for _, member in ipairs(selected) do
            for line in self.db.instructionMessage:gmatch("[^\n]+") do
                if testMode then
                    addon:Print("|cFF888888[TEST WHISPER \226\134\146 " .. member.name .. "]|r " .. line)
                else
                    local ok, err = pcall(SendChatMessage, line, "WHISPER", nil, member.name)
                    if not ok then
                        addon:Print("|cFFFF4444Whisper failed for " .. member.name .. ":|r " .. tostring(err))
                    end
                end
            end
        end
    end
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
