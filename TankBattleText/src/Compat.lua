local _ = ...

-- BCM positions frames incorrectly on login/reload. Opening and closing its
-- settings GUI triggers the fix via OnClose -> BCDM:UpdateBCDM().
-- BCDMG is BCM's public API table with Open/CloseBCDMGUI methods.

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(7, function()
        local bcdmg = _G["BCDMG"]
        if bcdmg and bcdmg.OpenBCDMGUI and bcdmg.CloseBCDMGUI then
            bcdmg:OpenBCDMGUI()
            bcdmg:CloseBCDMGUI()
        end
    end)
end)
