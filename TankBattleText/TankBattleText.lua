local _, ns = ...

-- Toggle state
ns.enabled = true

-- School colors (r, g, b)
ns.schoolColors = {
    [0x1]  = { 1.0, 1.0, 0.0 },   -- Physical (yellow)
    [0x2]  = { 1.0, 0.9, 0.5 },   -- Holy
    [0x4]  = { 1.0, 0.5, 0.0 },   -- Fire
    [0x8]  = { 0.3, 1.0, 0.3 },   -- Nature
    [0x10] = { 0.5, 0.8, 1.0 },   -- Frost
    [0x20] = { 0.7, 0.5, 1.0 },   -- Shadow
    [0x40] = { 1.0, 0.5, 1.0 },   -- Arcane
}
ns.defaultDamageColor = { 1.0, 0.2, 0.2 } -- Red fallback

-- Avoidance colors
ns.avoidanceColors = {
    DODGE   = { 1.0, 1.0, 1.0 }, -- White
    PARRY   = { 1.0, 1.0, 1.0 },
    MISS    = { 0.8, 0.8, 0.8 },
    BLOCK   = { 0.4, 0.6, 1.0 }, -- Blue (full block)
    ABSORB  = { 1.0, 1.0, 0.3 }, -- Yellow
    RESIST  = { 1.0, 0.6, 0.2 }, -- Orange
    IMMUNE  = { 1.0, 1.0, 0.3 }, -- Yellow
    DEFLECT = { 1.0, 1.0, 1.0 },
    REFLECT = { 0.3, 1.0, 0.3 }, -- Green
}

-- Init
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    TankBattleTextDB = TankBattleTextDB or {}
    ns.db = TankBattleTextDB
    print("|cff00ccffTankBattleText|r loaded — /tbt for options")
end)

-- Slash command
SLASH_TANKBATTLETEXT1 = "/tbt"
SlashCmdList["TANKBATTLETEXT"] = function(msg)
    msg = strtrim(msg or "")
    local cmd = msg:match("^(%S+)")
    cmd = cmd or msg
    if cmd == "log" then
        ns.ToggleLog()
    else
        -- Defer to escape chat frame's secure execution path (OpenSettingsPanel is protected)
        C_Timer.After(0, function()
            Settings.OpenToCategory(ns.settingsCategoryID)
        end)
    end
end
