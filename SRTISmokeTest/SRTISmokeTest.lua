local _ = ...

-- Simple marker button: always visible in center of screen when enabled
-- Click it with a target selected → /tm 1 fires → target gets star
local marker = CreateFrame("Button", "SRTISmokeTestMarker", UIParent, "SecureActionButtonTemplate")
marker:SetSize(48, 48)
marker:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
marker:SetFrameStrata("TOOLTIP")
marker:SetAttribute("type", "macro")
marker:SetAttribute("macrotext", "/tm 1")
marker:RegisterForClicks("AnyDown", "AnyUp")
marker:Hide()

-- Star icon texture
local tex = marker:CreateTexture(nil, "ARTWORK")
tex:SetAllPoints()
tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")

-- State tracking
local enabled = false

local function Enable()
    marker:Show()
    enabled = true
    print("|cff00ff00[SmokeTest]|r Enabled — star button visible. Target something and click it.")
    print("|cff00ff00[SmokeTest]|r Key test: does it work IN COMBAT?")
end

local function Disable()
    marker:Hide()
    enabled = false
    print("|cffff0000[SmokeTest]|r Disabled")
end

-- Slash command
SLASH_SMOKETEST1 = "/smoketest"
SlashCmdList["SMOKETEST"] = function()
    if enabled then
        Disable()
    else
        Enable()
    end
end

print("|cff00ff00[SmokeTest]|r Loaded — type /smoketest to toggle")
