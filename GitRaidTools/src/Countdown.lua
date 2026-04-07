local _, ns = ...

------------------------------------------------------------
-- State
------------------------------------------------------------
local editModeActive = false

-- Dismissed state is persisted in ns.db.tickerDismissed
local function IsDismissed()
    return ns.db and ns.db.tickerDismissed == true
end

local function SetDismissed(val)
    if ns.db then ns.db.tickerDismissed = val end
end
local MODE_COUNTDOWN = 1
local MODE_OVERTIME = 2

-- Colors
local COLOR_GOLD = { 1, 0.82, 0 }
local COLOR_GREEN = { 0.2, 1, 0.2 }

------------------------------------------------------------
-- Broadcast: sends messages to configured chat channels
------------------------------------------------------------
local function Broadcast(msg)
    if not ns.db then return end
    if ns.db.broadcastRaid then
        ns.Announce(msg, "RAID")
    end
    if ns.db.broadcastGuild then
        ns.Announce(msg, "GUILD")
    end
end

------------------------------------------------------------
-- Ticker: on-screen countdown/overtime display
------------------------------------------------------------
local CLOSE_SIZE = 24
local GAP = 4
local BTN_GAP = 2

local ticker = CreateFrame("Frame", "GitRaidToolsCountdown", UIParent)
ticker:SetPoint("TOP", 0, -200)
ticker:SetFrameStrata("MEDIUM")
ticker:Hide()

-- Button column (left side of ticker)
local btnColumn = CreateFrame("Frame", nil, ticker)
btnColumn:SetPoint("LEFT", 0, 0)

local closeBtn = CreateFrame("Button", nil, btnColumn, "UIPanelCloseButtonNoScripts")
closeBtn:SetSize(CLOSE_SIZE, CLOSE_SIZE)
closeBtn:SetPoint("TOPLEFT", 0, 0)
closeBtn:SetScript("OnClick", function()
    SetDismissed(true)
    ticker:Hide()
    if ns.EvaluateDispatchVisibility then ns.EvaluateDispatchVisibility() end
end)
closeBtn:SetScript("OnMouseDown", function(self)
    self:GetNormalTexture():SetVertexColor(0.8, 0.2, 0.2) -- red on press
end)
closeBtn:SetScript("OnMouseUp", function(self)
    self:GetNormalTexture():SetVertexColor(1, 1, 1)
end)

-- Broadcast button (below close — same style as close button)
local broadcastBtn = CreateFrame("Button", nil, btnColumn, "UIPanelCloseButtonNoScripts")
broadcastBtn:SetSize(CLOSE_SIZE, CLOSE_SIZE)
broadcastBtn:SetPoint("TOP", closeBtn, "BOTTOM", 0, -BTN_GAP)
-- Replace the X texture with a broadcast icon (>>)
broadcastBtn:GetNormalTexture():SetTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")
broadcastBtn:GetPushedTexture():SetTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Down")

-- Tooltip set dynamically in SetMode (after GetSecondsUntilRaid is defined)
local broadcastTooltip = "Broadcast to chat"
broadcastBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(broadcastTooltip)
    GameTooltip:Show()
end)
broadcastBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

btnColumn:SetSize(CLOSE_SIZE, CLOSE_SIZE * 2 + BTN_GAP)

-- Ticker text (right of button column)
local tickerText = ticker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tickerText:SetPoint("LEFT", btnColumn, "RIGHT", GAP, 0)
tickerText:SetJustifyH("LEFT")

-- Fixed width based on widest possible ticker text to prevent bouncing
local maxTextWidth = 0

local function UpdateMaxWidth()
    local prev = tickerText:GetText()
    tickerText:SetText("Raid in 00:00")
    maxTextWidth = tickerText:GetStringWidth()
    if prev then tickerText:SetText(prev) else tickerText:SetText("") end
end

local function ResizeTicker()
    local textH = tickerText:GetStringHeight()
    local btnH = CLOSE_SIZE * 2 + BTN_GAP
    local w = maxTextWidth > 0 and maxTextWidth or tickerText:GetStringWidth()
    ticker:SetSize(CLOSE_SIZE + GAP + w, math.max(textH, btnH))
end

-- Font application (called from Options when font/size changes)
function ns.ApplyCountdownFont()
    if not ns.db or not ns.FindFontPath then return end
    local path = ns.FindFontPath(ns.db.fontFace or ns.CONFIG.fontFace)
    local size = ns.db.countdownFontSize or ns.CONFIG.countdownFontSize
    tickerText:SetFont(path, size, "OUTLINE")
    UpdateMaxWidth()
    ResizeTicker()
end

-- Strata application (called from Options when strata changes)
function ns.ApplyTickerStrata()
    if not ns.db then return end
    local strata = ns.db.tickerStrata or ns.CONFIG.tickerStrata
    ticker:SetFrameStrata(strata)
    local df = _G["GitRaidToolsDispatch"]
    if df then df:SetFrameStrata(strata) end
end

------------------------------------------------------------
-- Timer logic
------------------------------------------------------------
local function IsRaidDay()
    local days = ns.db and ns.db.raidDays or ns.CONFIG.raidDays
    local wday = date("*t").wday
    for _, d in ipairs(days) do
        if d == wday then return true end
    end
    return false
end

-- Max overtime before we consider it "next day's raid" and wrap
local OVERTIME_MAX = 5400 -- 90 minutes

-- Local time with seconds via date("*t") — matches the user's system clock
-- and Prat timestamps. GetGameTime() is realm time which may differ.
function ns.GetTimeSec()
    local t = date("*t")
    return t.hour, t.min, t.sec
end

local function GetSecondsUntilRaid()
    local h, m, s = ns.GetTimeSec()
    local nowSec = h * 3600 + m * 60 + s
    local raidHour = ns.db and ns.db.raidHour or ns.CONFIG.raidHour
    local raidMinute = ns.db and ns.db.raidMinute or ns.CONFIG.raidMinute
    local raidSec = raidHour * 3600 + raidMinute * 60
    local diff = raidSec - nowSec
    if diff < -OVERTIME_MAX then diff = diff + 86400 end
    return diff
end
ns.GetSecondsUntilRaid = GetSecondsUntilRaid

local function IsMuted()
    return ns.db and ns.db.muted == true
end

------------------------------------------------------------
-- Broadcast button handler
------------------------------------------------------------
broadcastBtn:SetScript("OnClick", function()
    local diff = GetSecondsUntilRaid()
    if diff <= 0 then
        -- Overtime: broadcast and dismiss
        local overSec = -diff
        Broadcast(string.format("First pull — started %d:%02d after raid time.", math.floor(overSec / 60), overSec % 60))
        SetDismissed(true)
        ticker:Hide()
        if ns.EvaluateDispatchVisibility then ns.EvaluateDispatchVisibility() end
    elseif diff > 0 then
        -- Countdown: broadcast only
        Broadcast("COUNTDOWN: First pull in " .. ns.FormatTimeString(diff) .. ".")
    end
end)

-- Ticker frame is click-through; buttons handle all interaction
ticker:EnableMouse(false)

------------------------------------------------------------
-- Milestone broadcasts (10m, 5m, 2m, pull)
------------------------------------------------------------
local MILESTONES = { 600, 300, 120, 0 } -- seconds
local milestoneFired = {}

-- Pre-populate milestones already past so we don't re-announce on reload
local function SeedMilestones()
    local diff = GetSecondsUntilRaid()
    for _, threshold in ipairs(MILESTONES) do
        if diff <= threshold then
            milestoneFired[threshold] = true
        end
    end
end

local function CheckMilestones(diff)
    if not ns.db or ns.db.milestoneAnnounce ~= true then return end
    if IsMuted() then return end

    for _, threshold in ipairs(MILESTONES) do
        if not milestoneFired[threshold] and diff <= threshold then
            milestoneFired[threshold] = true
            if threshold == 0 then
                Broadcast("COUNTDOWN: Pull time!")
            else
                Broadcast("COUNTDOWN: First pull in " .. ns.FormatTimeString(threshold) .. ".")
            end
            return -- only fire one per tick
        end
    end
end

------------------------------------------------------------
-- Ticker visibility / mode switching
------------------------------------------------------------
local function SetMode(mode)
    if mode == MODE_COUNTDOWN then
        tickerText:SetTextColor(unpack(COLOR_GOLD))
        broadcastTooltip = "Broadcast to chat"
    else
        tickerText:SetTextColor(unpack(COLOR_GREEN))
        broadcastTooltip = "Broadcast and dismiss"
    end
end

local function EvaluateVisibility()
    if editModeActive then return end
    if ns.testMode then return end

    if ns.db and ns.db.countdownEnabled == false then
        ticker:Hide()
        if ns.EvaluateDispatchVisibility then ns.EvaluateDispatchVisibility() end
        return
    end

    local diff = GetSecondsUntilRaid()
    local windowSec = (ns.db and ns.db.countdownWindow or ns.CONFIG.countdownWindow) * 60

    if not IsRaidDay() or IsDismissed() then
        ticker:Hide()
        if ns.EvaluateDispatchVisibility then ns.EvaluateDispatchVisibility() end
        return
    end

    -- Overtime: raid time has passed, ticker counts up (green)
    -- Persists until manually dismissed — only GetSecondsUntilRaid wraps past OVERTIME_MAX
    if diff <= 0 then
        CheckMilestones(0)
        local overSec = -diff
        SetMode(MODE_OVERTIME)
        tickerText:SetText(string.format("Started %d:%02d", math.floor(overSec / 60), overSec % 60))
        ResizeTicker()
        ticker:Show()
        if ns.EvaluateDispatchVisibility then ns.EvaluateDispatchVisibility() end
        return
    end

    -- Countdown: ticker counts down (gold)
    if diff > windowSec then
        ticker:Hide()
        if ns.EvaluateDispatchVisibility then ns.EvaluateDispatchVisibility() end
        return
    end

    CheckMilestones(diff)
    SetMode(MODE_COUNTDOWN)
    tickerText:SetText(string.format("Raid in %d:%02d", math.floor(diff / 60), diff % 60))
    ResizeTicker()
    ticker:Show()
    if ns.EvaluateDispatchVisibility then ns.EvaluateDispatchVisibility() end
end

-- OnUpdate: re-evaluate every second (only fires while ticker is shown)
local elapsed = 0
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 1 then return end
    elapsed = elapsed - 1
    EvaluateVisibility()
end)

------------------------------------------------------------
-- Test mode: shows ticker + dispatch with sample data
------------------------------------------------------------
local testTimer
local TEST_DURATION = 15

function ns.EnterTestMode()
    ns.testMode = true

    -- Show ticker with sample countdown
    SetMode(MODE_COUNTDOWN)
    tickerText:SetText("Raid in 12:34")
    ResizeTicker()
    ticker:Show()

    -- Show dispatch with sample data
    if ns.EnterDispatchTestMode then ns.EnterDispatchTestMode() end

    -- Cancel previous timer if re-entering
    if testTimer then testTimer:Cancel() end

    print("|cff00ccffGRT:|r Test mode — showing for " .. TEST_DURATION .. "s")

    testTimer = C_Timer.NewTimer(TEST_DURATION, function()
        ns.testMode = false
        testTimer = nil
        if ns.ExitDispatchTestMode then ns.ExitDispatchTestMode() end
        EvaluateVisibility()
        print("|cff00ccffGRT:|r Test mode ended")
    end)
end

function ns.EvaluateCountdownVisibility()
    EvaluateVisibility()
end

function ns.ExitTestMode()
    if testTimer then testTimer:Cancel() end
    testTimer = nil
    ns.testMode = false
    if ns.ExitDispatchTestMode then ns.ExitDispatchTestMode() end
    EvaluateVisibility()
end

------------------------------------------------------------
-- Auto-invite: fires at configured minutes before raid
------------------------------------------------------------
local autoInviteFired = false

local function ScheduleAutoInvite()
    if not ns.db or ns.db.autoInviteEnabled == false then return end
    if ns.db.invitesEnabled == false then return end
    if autoInviteFired then return end
    if IsMuted() then return end

    local diff = GetSecondsUntilRaid()
    local triggerSec = (ns.db.autoInviteMinutes or ns.CONFIG.autoInviteMinutes) * 60

    if diff <= 0 or diff > triggerSec then return end

    autoInviteFired = true
    print("|cff00ccffGRT:|r Auto-invite triggered")
    if ns.RaidTimeInvite then
        ns.RaidTimeInvite()
    end
end

------------------------------------------------------------
-- RC Rotate: fires at configured minutes before raid
------------------------------------------------------------
local rcRotateScheduleFired = false

local function ScheduleRcRotate()
    if not ns.db or ns.db.rcRotateEnabled == false then return end
    if rcRotateScheduleFired then return end

    local diff = GetSecondsUntilRaid()
    local triggerSec = (ns.db.rcRotateMinutes or ns.CONFIG.rcRotateMinutes) * 60

    if diff <= 0 or diff > triggerSec then return end

    rcRotateScheduleFired = true
    if ns.TriggerRcRotate then ns.TriggerRcRotate() end
end

local function SeedRcRotateSchedule()
    rcRotateScheduleFired = ns.db and ns.db.dispatchRcRotated == true
end

------------------------------------------------------------
-- Smart scheduler
------------------------------------------------------------
local function ScheduleNextCheck()
    if not IsRaidDay() then
        print("|cff00ccffGRT:|r Not a raid day — no check scheduled")
        return
    end

    local diff = GetSecondsUntilRaid()
    local windowSec = (ns.db and ns.db.countdownWindow or ns.CONFIG.countdownWindow) * 60

    if diff <= 0 then
        print("|cff00ccffGRT:|r Raid time has passed — showing overtime")
        EvaluateVisibility()
        return
    end

    if diff <= windowSec then
        print("|cff00ccffGRT:|r Already in countdown window — showing now")
        EvaluateVisibility()
        ScheduleAutoInvite()
        ScheduleRcRotate()
        return
    end

    local delaySec = diff - windowSec
    local delayMin = math.floor(delaySec / 60)
    local delaySecRem = delaySec % 60
    print(string.format("|cff00ccffGRT:|r Next check in %dm %ds (countdown window opens)", delayMin, delaySecRem))
    C_Timer.After(delaySec, function()
        if not IsDismissed() and not editModeActive then
            EvaluateVisibility()
        end
    end)

    -- Schedule auto-invite
    if ns.db and ns.db.autoInviteEnabled ~= false and ns.db.invitesEnabled ~= false then
        local inviteTriggerSec = (ns.db.autoInviteMinutes or ns.CONFIG.autoInviteMinutes) * 60
        if diff > inviteTriggerSec and not autoInviteFired then
            local inviteDelay = diff - inviteTriggerSec
            local invDelayMin = math.floor(inviteDelay / 60)
            local invDelaySecRem = inviteDelay % 60
            print(string.format("|cff00ccffGRT:|r Auto-invite in %dm %ds", invDelayMin, invDelaySecRem))
            C_Timer.After(inviteDelay, function()
                if not autoInviteFired then
                    ScheduleAutoInvite()
                end
            end)
        end
    end

    -- Schedule RC rotate
    if ns.db and ns.db.rcRotateEnabled ~= false and not rcRotateScheduleFired then
        local rcTriggerSec = (ns.db.rcRotateMinutes or ns.CONFIG.rcRotateMinutes) * 60
        if diff > rcTriggerSec then
            local rcDelay = diff - rcTriggerSec
            local rcDelayMin = math.floor(rcDelay / 60)
            local rcDelaySecRem = rcDelay % 60
            print(string.format("|cff00ccffGRT:|r RC Rotate in %dm %ds", rcDelayMin, rcDelaySecRem))
            C_Timer.After(rcDelay, function()
                if not rcRotateScheduleFired then
                    ScheduleRcRotate()
                end
            end)
        end
    end
end

------------------------------------------------------------
-- Position restore
------------------------------------------------------------
local function RestorePosition()
    if not ns.db or not ns.db.countdownPos then return end
    local pos = ns.db.countdownPos
    ticker:ClearAllPoints()
    ticker:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        RestorePosition()

        C_Timer.After(0, function()
            ns.ApplyCountdownFont()
            ns.ApplyTickerStrata()

            local LibEditMode = LibStub("LibEditMode")
            local defaultPos = { point = "TOP", x = 0, y = -200 }

            LibEditMode:AddFrame(ticker, function(_, _, point, x, y)
                if ns.db then
                    ns.db.countdownPos = { point = point, x = x, y = y }
                end
            end, defaultPos, "GRT: Raid Countdown")

            LibEditMode:AddFrameSettings(ticker, {
                {
                    name = "Font Size",
                    kind = LibEditMode.SettingType.Slider,
                    default = ns.CONFIG.countdownFontSize,
                    get = function()
                        return ns.db and ns.db.countdownFontSize or ns.CONFIG.countdownFontSize
                    end,
                    set = function(_, value)
                        if ns.db then
                            ns.db.countdownFontSize = math.floor(value + 0.5)
                            ns.ApplyCountdownFont()
                        end
                    end,
                    minValue = 14,
                    maxValue = 100,
                    valueStep = 1,
                    formatter = function(value)
                        return string.format("%d pt", value)
                    end,
                },
            })

            LibEditMode:RegisterCallback("enter", function()
                editModeActive = true
                SetMode(MODE_COUNTDOWN)
                tickerText:SetText("Raid in 12:34")
                ResizeTicker()
                ticker:Show()
            end)
            LibEditMode:RegisterCallback("exit", function()
                editModeActive = false
                EvaluateVisibility()
            end)
        end)

        -- Clear dismiss only if countdown hasn't started yet (pre-window)
        -- If already in overtime and user dismissed, respect that through reload
        local diff = GetSecondsUntilRaid()
        if diff > 0 then
            SetDismissed(false)
        end
        SeedMilestones()
        SeedRcRotateSchedule()
        EvaluateVisibility()
        ScheduleNextCheck()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- Zone change re-shows during countdown, but respects dismiss during overtime
        local diff = GetSecondsUntilRaid()
        if diff > 0 then
            SetDismissed(false)
        end
        EvaluateVisibility()
    end
end)
