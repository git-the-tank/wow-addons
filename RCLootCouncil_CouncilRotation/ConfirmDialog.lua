---@class RCLootCouncil
local addon = LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil")
---@class RCCouncilRotation
local CR = addon:GetModule("RCCouncilRotation")
local L = LibStub("AceLocale-3.0"):GetLocale("RCCouncilRotation")
local AceGUI = LibStub("AceGUI-3.0")

local tinsert, tremove, ipairs, pairs, wipe, format = table.insert, table.remove, ipairs, pairs, wipe, format
local date, time = date, time
local InCombatLockdown = InCombatLockdown

---------------------------------------------------------------------------
-- Dialog State (ephemeral, not persisted)
---------------------------------------------------------------------------
local dialogState = {
    testMode = false,
    selected = {},              -- current member list (mutated by redraws)
    pool = {},                  -- full eligible pool from BuildEligiblePool()
    sessionDeferred = {},       -- {[guid]=true} deferred this session
    memberStates = {},          -- {[guid]="approve"|"defer"|"sitout"}
    -- Test mode snapshots (for auto-cleanup on close)
    historyCountBefore = nil,
    selectedHistoryBackup = nil,
}

-- AceGUI frame reference (reused across calls)
local confirmFrame = nil
-- Widget references for targeted updates
local membersGroup = nil
local statusLabel = nil
local redrawBtn = nil
local resetBtn = nil

-- Pending dialog data when deferred by combat
local pendingDialog = nil

--- Release the dialog frame and nil out all widget references.
--- Guarded against double-release (OnClose may fire from Release's Hide).
---@param isRebuild boolean|nil Skip test cleanup when rebuilding dialog
local function CleanupDialog(isRebuild)
    local frame = confirmFrame
    confirmFrame = nil
    membersGroup = nil
    statusLabel = nil
    redrawBtn = nil
    resetBtn = nil

    -- Restore test data on final close (not rebuild)
    if not isRebuild and dialogState.testMode then
        if dialogState.historyCountBefore then
            while #CR.db.history > dialogState.historyCountBefore do
                tremove(CR.db.history, 1)
            end
        end
        if dialogState.selectedHistoryBackup then
            wipe(CR.db.selectedHistory)
            for k, v in pairs(dialogState.selectedHistoryBackup) do
                CR.db.selectedHistory[k] = v
            end
        end
    end

    if frame then
        frame:Release()
    end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local DROPDOWN_VALUES = {
    approve = L["Approve"],
    defer = L["Defer"],
    sitout = L["Sit Out Cycle"],
}

local DROPDOWN_ORDER = { "approve", "defer", "sitout" }

local function ClassColoredName(member)
    local classColor = addon:GetClassColor(member.class)
    if classColor then
        local hex = addon.Utils:RGBToHex(classColor.r, classColor.g, classColor.b)
        return "|cFF" .. hex .. member.name .. "|r"
    end
    return member.name
end

--- Count how many members in the pool are available for redraws.
local function CountAvailablePool()
    local displayedGUIDs = {}
    for _, m in ipairs(dialogState.selected) do
        displayedGUIDs[m.guid] = true
    end
    local count = 0
    for _, m in ipairs(dialogState.pool) do
        if not dialogState.sessionDeferred[m.guid] and not displayedGUIDs[m.guid] then
            count = count + 1
        end
    end
    return count
end

--- Count how many selected members are marked as "defer".
local function CountDeferred()
    local count = 0
    for _, m in ipairs(dialogState.selected) do
        if dialogState.memberStates[m.guid] == "defer" then
            count = count + 1
        end
    end
    return count
end

--- Count remaining members in the rotation cycle (not yet in selectedHistory).
--- Pool already excludes selectedHistory. Since SelectMembers copies (not
--- removes), the pool still contains the currently displayed members.
local function CountRemainingInCycle()
    return #dialogState.pool - #dialogState.selected
end

---------------------------------------------------------------------------
-- Display Update
---------------------------------------------------------------------------
local function UpdateButtonStates()
    if not confirmFrame then return end

    local hasDeferrals = CountDeferred() > 0
    local hasPool = CountAvailablePool() > 0

    redrawBtn:SetDisabled(not hasDeferrals or not hasPool)

    -- Reset cycle: enable when selectedHistory is non-empty or cycle is exhausted
    local hasHistory = next(CR.db.selectedHistory) ~= nil
    resetBtn:SetDisabled(not hasHistory and CountRemainingInCycle() > 0)

    -- Status line
    local remaining = CountRemainingInCycle()
    if remaining <= 0 and not hasPool then
        statusLabel:SetText(L["cycle_exhausted_warning"])
    elseif not hasPool and hasDeferrals then
        statusLabel:SetText(L["pool_empty_warning"])
    else
        statusLabel:SetText(format(L["members_remaining"], math.max(0, remaining)))
    end
end

local function PopulateHistory(historyGroup)
    historyGroup:ReleaseChildren()

    local history = CR.db.history
    if #history == 0 then
        local label = AceGUI:Create("Label")
        label:SetText(L["No history entries."])
        label:SetFullWidth(true)
        historyGroup:AddChild(label)
        return
    end

    local shown = 0
    for _, entry in ipairs(history) do
        if shown >= 5 then break end
        shown = shown + 1

        local entryType = entry.type or "rotation"
        local label = AceGUI:Create("Label")
        label:SetFullWidth(true)

        if entryType == "cycle_reset" then
            local reason = entry.reason == "manual" and L["manual_reset"] or L["pool_exhausted"]
            label:SetText(entry.date .. "  —  " .. L["Cycle Reset"] .. " (" .. reason .. ")")
        else
            local names = {}
            for _, member in ipairs(entry.members or {}) do
                tinsert(names, ClassColoredName(member))
            end
            local text = entry.date .. "  —  " .. table.concat(names, ", ")
            if entry.deferred and #entry.deferred > 0 then
                local dnames = {}
                for _, m in ipairs(entry.deferred) do tinsert(dnames, m.name) end
                text = text .. "  |cFFFFFF00[Deferred: " .. table.concat(dnames, ", ") .. "]|r"
            end
            if entry.satOut and #entry.satOut > 0 then
                local snames = {}
                for _, m in ipairs(entry.satOut) do tinsert(snames, m.name) end
                text = text .. "  |cFFFF4444[Sat Out: " .. table.concat(snames, ", ") .. "]|r"
            end
            label:SetText(text)
        end

        historyGroup:AddChild(label)
    end
end

local function PopulateMembers()
    membersGroup:ReleaseChildren()

    for _, member in ipairs(dialogState.selected) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")

        local nameLabel = AceGUI:Create("Label")
        nameLabel:SetText("  " .. ClassColoredName(member))
        nameLabel:SetWidth(160)
        nameLabel:SetFontObject(GameFontHighlight)
        row:AddChild(nameLabel)

        local dropdown = AceGUI:Create("Dropdown")
        dropdown:SetList(DROPDOWN_VALUES, DROPDOWN_ORDER)
        dropdown:SetValue(dialogState.memberStates[member.guid] or "approve")
        dropdown:SetWidth(140)
        dropdown:SetCallback("OnValueChanged", function(_, _, val)
            dialogState.memberStates[member.guid] = val
            UpdateButtonStates()
        end)
        row:AddChild(dropdown)

        membersGroup:AddChild(row)
    end
end

local function UpdateDialogDisplay()
    if not confirmFrame then return end
    PopulateMembers()
    UpdateButtonStates()
    confirmFrame:DoLayout()
end

---------------------------------------------------------------------------
-- Button Handlers
---------------------------------------------------------------------------
local function OnRedraw()
    -- Move deferred members to sessionDeferred, collect non-deferred
    local kept = {}
    for _, member in ipairs(dialogState.selected) do
        local state = dialogState.memberStates[member.guid]
        if state == "defer" then
            dialogState.sessionDeferred[member.guid] = true
            dialogState.memberStates[member.guid] = nil
        else
            tinsert(kept, member)
        end
    end

    local needed = #dialogState.selected - #kept
    if needed == 0 then return end

    -- Build available pool excluding sessionDeferred and currently displayed
    local displayedGUIDs = {}
    for _, m in ipairs(kept) do
        displayedGUIDs[m.guid] = true
    end
    local availablePool = {}
    for _, m in ipairs(dialogState.pool) do
        if not dialogState.sessionDeferred[m.guid] and not displayedGUIDs[m.guid] then
            tinsert(availablePool, m)
        end
    end

    -- Draw replacements
    local replacements = CR:SelectMembers(availablePool, math.min(needed, #availablePool))
    for _, member in ipairs(replacements) do
        tinsert(kept, member)
        dialogState.memberStates[member.guid] = "approve"
    end

    dialogState.selected = kept
    UpdateDialogDisplay()
end

local function OnConfirm()
    local approved = {}
    local deferred = {}
    local satOut = {}

    for _, member in ipairs(dialogState.selected) do
        local state = dialogState.memberStates[member.guid]
        if state == "approve" then
            tinsert(approved, member)
        elseif state == "defer" then
            tinsert(deferred, member)
        elseif state == "sitout" then
            tinsert(satOut, member)
        end
    end

    -- Also include session-deferred members who were replaced via Redraw
    for guid in pairs(dialogState.sessionDeferred) do
        -- Find their info from the pool
        for _, m in ipairs(dialogState.pool) do
            if m.guid == guid then
                -- Only add if not already in the deferred list
                local found = false
                for _, d in ipairs(deferred) do
                    if d.guid == guid then found = true; break end
                end
                if not found then
                    tinsert(deferred, m)
                end
                break
            end
        end
    end

    -- Warn if no one approved
    if #approved == 0 then
        StaticPopupDialogs["RCLC_CONFIRM_EMPTY_ROTATION"] = {
            text = L["no_approved_warning"],
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                CR:FinalizeRotation(approved, deferred, satOut, dialogState.testMode)
                CleanupDialog()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("RCLC_CONFIRM_EMPTY_ROTATION")
        return
    end

    CR:FinalizeRotation(approved, deferred, satOut, dialogState.testMode)
    CleanupDialog()
end

local function OnResetCycle()
    wipe(CR.db.selectedHistory)
    wipe(dialogState.sessionDeferred)

    -- Record cycle reset in history
    tinsert(CR.db.history, 1, {
        type = "cycle_reset",
        date = date("%Y-%m-%d"),
        timestamp = time(),
        reason = "manual",
    })

    -- Rebuild pool and re-select
    local pool = CR:BuildEligiblePool()
    local seats = CR.db.seats
    if #pool < seats then seats = #pool end
    local selected = CR:SelectMembers(pool, seats)

    -- Reset dialog state
    dialogState.pool = pool
    dialogState.selected = selected
    wipe(dialogState.memberStates)
    for _, member in ipairs(selected) do
        dialogState.memberStates[member.guid] = "approve"
    end

    -- Refresh the entire dialog (history changed too)
    if confirmFrame then
        -- Find and repopulate history group
        -- Since we rebuild the whole frame content, just rebuild everything
        CR:ShowConfirmationDialog(nil, nil, true) -- internal rebuild flag
    end
end

---------------------------------------------------------------------------
-- Frame Construction
---------------------------------------------------------------------------
local function CreateConfirmDialog()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(L["Council Rotation"])
    frame:SetWidth(420)
    frame:SetHeight(450)
    frame:SetLayout("Flow")
    frame:EnableResize(false)
    frame:SetCallback("OnClose", function()
        CleanupDialog()
    end)

    -- History section
    local histGroup = AceGUI:Create("InlineGroup")
    histGroup:SetTitle(L["Recent History"])
    histGroup:SetFullWidth(true)
    histGroup:SetLayout("List")
    PopulateHistory(histGroup)
    frame:AddChild(histGroup)

    -- Members section
    membersGroup = AceGUI:Create("InlineGroup")
    membersGroup:SetTitle(L["Selected for Tonight"])
    membersGroup:SetFullWidth(true)
    membersGroup:SetLayout("List")
    PopulateMembers()
    frame:AddChild(membersGroup)

    -- Status line
    statusLabel = AceGUI:Create("Label")
    statusLabel:SetFullWidth(true)
    statusLabel:SetFontObject(GameFontNormal)
    statusLabel:SetText("")
    frame:AddChild(statusLabel)

    -- Spacer
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    frame:AddChild(spacer)

    -- Button row
    local btnGroup = AceGUI:Create("SimpleGroup")
    btnGroup:SetFullWidth(true)
    btnGroup:SetLayout("Flow")

    resetBtn = AceGUI:Create("Button")
    resetBtn:SetText(L["Reset Cycle"])
    resetBtn:SetWidth(120)
    resetBtn:SetCallback("OnClick", function() OnResetCycle() end)
    btnGroup:AddChild(resetBtn)

    redrawBtn = AceGUI:Create("Button")
    redrawBtn:SetText(L["Redraw"])
    redrawBtn:SetWidth(100)
    redrawBtn:SetCallback("OnClick", function() OnRedraw() end)
    btnGroup:AddChild(redrawBtn)

    local confirmBtn = AceGUI:Create("Button")
    confirmBtn:SetText(L["Confirm"])
    confirmBtn:SetWidth(100)
    confirmBtn:SetCallback("OnClick", function() OnConfirm() end)
    btnGroup:AddChild(confirmBtn)

    frame:AddChild(btnGroup)

    UpdateButtonStates()
    return frame
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Finalize the rotation after user confirms.
---@param approved table Array of approved member info tables
---@param deferred table Array of deferred member info tables
---@param satOut table Array of sat-out member info tables
---@param isTestMode boolean Whether this rotation was triggered in test mode
function CR:FinalizeRotation(approved, deferred, satOut, isTestMode)
    -- Remove previous rotating members from council
    self:RemoveCurrentRotating()

    -- Add approved members to council
    self:ApplyToCouncil(approved)

    -- Mark sit-outs in selectedHistory (as if they served)
    for _, member in ipairs(satOut) do
        self.db.selectedHistory[member.guid] = true
    end

    -- Record enhanced history
    self:RecordHistory(approved, deferred, satOut)

    -- Announce
    self:AnnounceRotation(approved, isTestMode)

    -- Print confirmation
    if #approved > 0 then
        local names = self:FormatNames(approved)
        addon:Print(format(L["rotation_success"], names))
    end
end

--- Show the confirmation dialog for a pending rotation.
---@param selected table|nil Array of selected member info tables (nil for rebuild)
---@param pool table|nil Full eligible pool (nil for rebuild)
---@param isRebuild boolean|nil Internal flag for rebuilding after reset
function CR:ShowConfirmationDialog(selected, pool, isRebuild)
    -- Guard: block re-entry unless this is an internal rebuild
    if confirmFrame and not isRebuild then
        addon:Print(L["dialog_already_open"])
        return
    end

    -- Combat lockdown check
    if InCombatLockdown() and not isRebuild then
        addon:Print(L["dialog_combat_deferred"])
        pendingDialog = { selected = selected, pool = pool }
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
        return
    end

    -- Initialize state (skip for rebuild — state was already updated)
    if not isRebuild then
        dialogState.testMode = CR._capturedTestMode or false
        dialogState.selected = selected
        dialogState.pool = pool
        wipe(dialogState.sessionDeferred)
        wipe(dialogState.memberStates)
        for _, member in ipairs(selected) do
            dialogState.memberStates[member.guid] = "approve"
        end

        -- Snapshot for test mode auto-cleanup
        if dialogState.testMode then
            dialogState.historyCountBefore = #self.db.history
            dialogState.selectedHistoryBackup = {}
            for k, v in pairs(self.db.selectedHistory) do
                dialogState.selectedHistoryBackup[k] = v
            end
        else
            dialogState.historyCountBefore = nil
            dialogState.selectedHistoryBackup = nil
        end
    end

    -- Release existing frame if rebuilding
    if confirmFrame then
        CleanupDialog(isRebuild)
    end

    confirmFrame = CreateConfirmDialog()
end

--- Handle combat end — show deferred dialog.
function CR:OnCombatEnd()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pendingDialog then
        local pd = pendingDialog
        pendingDialog = nil
        self:ShowConfirmationDialog(pd.selected, pd.pool)
    end
end
