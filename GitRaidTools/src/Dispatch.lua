local _, ns = ...

------------------------------------------------------------
-- State
------------------------------------------------------------
local dispatchInitialized = false
local editModeActive = false
local rcRotateFired = false

-- Ready check textures (scale with font via :0 height)
local CHECK = "|TInterface/RaidFrame/ReadyCheck-Ready:0|t"
local CROSS = "|TInterface/RaidFrame/ReadyCheck-NotReady:0|t"

------------------------------------------------------------
-- Raid day reset
------------------------------------------------------------
local function GetRaidDayKey()
    return date("%Y-%m-%d")
end

local function ResetIfNewRaidDay()
    if not ns.db then return end
    local today = GetRaidDayKey()
    if ns.db.dispatchRaidDay == today then return end

    -- Only reset if before next countdown window (diff > 0)
    -- Prevents clearing flags at midnight during an active raid
    if ns.GetSecondsUntilRaid then
        local diff = ns.GetSecondsUntilRaid()
        if diff <= 0 then return end
    end

    ns.db.dispatchRaidDay = today
    ns.db.dispatchInvSent = false
    ns.db.dispatchRcRotated = false
end

------------------------------------------------------------
-- Frame
------------------------------------------------------------
local dispatch = CreateFrame("Frame", "GitRaidToolsDispatch", UIParent)
dispatch:SetFrameStrata("MEDIUM")
dispatch:Hide()
dispatch:EnableMouse(false)

local dispatchText = dispatch:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dispatchText:SetPoint("CENTER")
dispatchText:SetJustifyH("CENTER")

------------------------------------------------------------
-- Text update
------------------------------------------------------------
local function UpdateDispatchText()
    if not ns.db then return end

    local invMark = ns.db.dispatchInvSent and CHECK or CROSS
    local rcMark = ns.db.dispatchRcRotated and CHECK or CROSS

    local parts = { invMark .. " Inv" }
    if ns.db.rcRotateEnabled then
        parts[#parts + 1] = rcMark .. " RC Rotate"
    end

    dispatchText:SetText(table.concat(parts, "  "))

    local w = dispatchText:GetStringWidth()
    local h = dispatchText:GetStringHeight()
    dispatch:SetSize(w + 8, h + 4)
end

------------------------------------------------------------
-- Font
------------------------------------------------------------
function ns.ApplyDispatchFont()
    if not ns.db or not ns.FindFontPath then return end
    local path = ns.FindFontPath(ns.db.dispatchFontFace or ns.CONFIG.dispatchFontFace)
    local size = ns.db.dispatchFontSize or ns.CONFIG.dispatchFontSize
    dispatchText:SetFont(path, size, "OUTLINE")
    UpdateDispatchText()
end

------------------------------------------------------------
-- Docking / position
------------------------------------------------------------
local function IsDocked()
    return not ns.db or ns.db.dispatchPos == nil
end

local function ApplyPosition()
    dispatch:ClearAllPoints()
    if IsDocked() then
        local ticker = GitRaidToolsCountdown
        if ticker then
            dispatch:SetPoint("TOP", ticker, "BOTTOM", 0, -2)
        else
            dispatch:SetPoint("TOP", UIParent, "TOP", 0, -250)
        end
    else
        local pos = ns.db.dispatchPos
        dispatch:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end
end

local function RestorePosition()
    ApplyPosition()
end

------------------------------------------------------------
-- Test mode
------------------------------------------------------------
local TEST_STATES = {
    { inv = false, rc = false },
    { inv = true,  rc = false },
    { inv = true,  rc = true },
}
local testStateIdx = 0
local testCycleTimer

function ns.EnterDispatchTestMode()
    if not dispatchInitialized then return end
    testStateIdx = 0

    local function CycleState()
        testStateIdx = testStateIdx % #TEST_STATES + 1
        local state = TEST_STATES[testStateIdx]

        local invMark = state.inv and CHECK or CROSS
        local rcMark = state.rc and CHECK or CROSS
        dispatchText:SetText(invMark .. " Inv  " .. rcMark .. " RC Rotate")

        local w = dispatchText:GetStringWidth()
        local h = dispatchText:GetStringHeight()
        dispatch:SetSize(w + 8, h + 4)
        ApplyPosition()
        dispatch:Show()
    end

    CycleState()
    testCycleTimer = C_Timer.NewTicker(3, CycleState)
end

function ns.ExitDispatchTestMode()
    if testCycleTimer then testCycleTimer:Cancel() end
    testCycleTimer = nil
    ns.EvaluateDispatchVisibility()
end

------------------------------------------------------------
-- Visibility (mirrors ticker)
------------------------------------------------------------
function ns.EvaluateDispatchVisibility()
    if not dispatchInitialized then return end
    if ns.testMode then return end
    if not ns.db or ns.db.dispatchEnabled == false then
        dispatch:Hide()
        return
    end
    if editModeActive then return end

    local ticker = GitRaidToolsCountdown
    if ticker and ticker:IsShown() then
        ResetIfNewRaidDay()
        UpdateDispatchText()
        ApplyPosition()
        dispatch:Show()
    else
        dispatch:Hide()
    end
end

------------------------------------------------------------
-- RC Rotate trigger
------------------------------------------------------------
local function FindRcHandler()
    return SlashCmdList["ACECONSOLE_RC"]
        or SlashCmdList["RCLOOTCOUNCIL"]
end

local function TriggerRcRotate()
    if not ns.db or not ns.db.rcRotateEnabled then return end
    if ns.db.dispatchRcRotated then return end

    local loaded = C_AddOns.IsAddOnLoaded("RCLootCouncil")
    if not loaded then
        print("|cff00ccffGRT:|r RC Rotate skipped \226\128\148 RCLootCouncil not loaded")
        ns.db.dispatchRcRotated = true
        UpdateDispatchText()
        return
    end

    local handler = FindRcHandler()
    if not handler then
        print("|cff00ccffGRT:|r RC Rotate skipped \226\128\148 /rc command not found")
        ns.db.dispatchRcRotated = true
        UpdateDispatchText()
        return
    end

    local ok, err = pcall(handler, "rotate")
    if ok then
        print("|cff00ccffGRT:|r RC Rotate triggered")
    else
        print("|cff00ccffGRT:|r RC Rotate error: " .. tostring(err))
    end

    ns.db.dispatchRcRotated = true
    UpdateDispatchText()
end

function ns.OnRaidTimeZero()
    if rcRotateFired then return end
    rcRotateFired = true
    TriggerRcRotate()
end

-- Seed: only skip if already attempted this raid day
local function SeedRcRotateState()
    rcRotateFired = ns.db and ns.db.dispatchRcRotated == true
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    ResetIfNewRaidDay()
    SeedRcRotateState()
    RestorePosition()

    C_Timer.After(0, function()
        ns.ApplyDispatchFont()

        -- Sync strata with ticker
        local strata = ns.db and ns.db.tickerStrata or ns.CONFIG.tickerStrata
        dispatch:SetFrameStrata(strata)

        local LibEditMode = LibStub("LibEditMode")
        local defaultPos = { point = "TOP", x = 0, y = -250 }

        LibEditMode:AddFrame(dispatch, function(_, _, point, x, y)
            if ns.db then
                ns.db.dispatchPos = { point = point, x = x, y = y }
            end
        end, defaultPos, "GRT: Dispatch Status")

        LibEditMode:AddFrameSettings(dispatch, {
            {
                name = "Font Size",
                kind = LibEditMode.SettingType.Slider,
                default = ns.CONFIG.dispatchFontSize,
                get = function()
                    return ns.db and ns.db.dispatchFontSize or ns.CONFIG.dispatchFontSize
                end,
                set = function(_, value)
                    if ns.db then
                        ns.db.dispatchFontSize = math.floor(value + 0.5)
                        ns.ApplyDispatchFont()
                    end
                end,
                minValue = 10,
                maxValue = 40,
                valueStep = 1,
                formatter = function(value)
                    return string.format("%d pt", value)
                end,
            },
        })

        LibEditMode:AddFrameSettingsButton(dispatch, {
            name = "Dock to Ticker",
            onClick = function()
                if ns.db then
                    ns.db.dispatchPos = nil
                    ApplyPosition()
                end
            end,
        })

        LibEditMode:RegisterCallback("enter", function()
            editModeActive = true
            UpdateDispatchText()
            dispatch:Show()
        end)
        LibEditMode:RegisterCallback("exit", function()
            editModeActive = false
            ns.EvaluateDispatchVisibility()
        end)

        dispatchInitialized = true
        ns.EvaluateDispatchVisibility()
    end)
end)
