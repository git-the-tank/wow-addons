local _, ns = ...

-- Shared configuration (defaults — overridden by SavedVariables)
ns.CONFIG = {
    raidHour = 20,          -- raid start time in realm time (24h)
    raidMinute = 0,
    countdownWindow = 30,   -- show countdown this many minutes before raid
    raidDays = { 3, 5 },   -- days of the week (1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat)
    inviteDelay = 0.2,      -- seconds between invite message lines
    keyword = "lust",
    autoInviteEnabled = false,
    autoInviteMinutes = 15,
    milestoneAnnounce = false,
    broadcastInstance = true,
    broadcastGuild = false,
    tickerStrata = "MEDIUM",
    muted = false,
    fontFace = "Friz Quadrata",
    countdownFontSize = 28,
    invitesEnabled = true,
}

-- Shared time string: "X minutes and Y seconds", omits zero components
function ns.FormatTimeString(totalSec)
    local m = math.floor(totalSec / 60)
    local s = totalSec % 60
    if m > 0 and s > 0 then
        return string.format("%d %s and %d %s",
            m, m == 1 and "minute" or "minutes",
            s, s == 1 and "second" or "seconds")
    elseif m > 0 then
        return string.format("%d %s", m, m == 1 and "minute" or "minutes")
    else
        return string.format("%d %s", s, s == 1 and "second" or "seconds")
    end
end

-- Init
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    GitRaidToolsDB = GitRaidToolsDB or {}
    ns.db = GitRaidToolsDB

    -- Apply defaults for any missing keys
    for key, val in pairs(ns.CONFIG) do
        if ns.db[key] == nil then
            if type(val) == "table" then
                ns.db[key] = {}
                for i, v in ipairs(val) do ns.db[key][i] = v end
            else
                ns.db[key] = val
            end
        end
    end

    print("|cff00ccffGitRaidTools|r loaded — /grt for help")
end)

-- Slash command
SLASH_GITRAIDTOOLS1 = "/grt"
SlashCmdList["GITRAIDTOOLS"] = function(msg)
    msg = strtrim(msg or "")
    local cmd, arg = msg:match("^(%S+)%s*(.*)")
    cmd = cmd or msg
    if cmd == "inv" then
        ns.RaidTimeInvite(arg)
    elseif cmd == "render" then
        ns.RaidTimeRender(arg)
    elseif cmd == "flavor" then
        ns.RaidTimeFlavor()
    elseif cmd == "unseen" then
        ns.RaidTimeUnseen()
    elseif cmd == "clear" then
        ns.RaidTimeClear()
    elseif cmd == "mute" then
        if ns.db then ns.db.muted = true end
        print("|cff00ccffGRT:|r Muted — announcements to raid/guild disabled")
    elseif cmd == "unmute" then
        if ns.db then ns.db.muted = false end
        print("|cff00ccffGRT:|r Unmuted — announcements to raid/guild enabled")
    elseif cmd == "time" then
        local h, m, s = ns.GetTimeSec()
        local rh = ns.db and ns.db.raidHour or ns.CONFIG.raidHour
        local rm = ns.db and ns.db.raidMinute or ns.CONFIG.raidMinute
        print(string.format("|cff00ccffGRT:|r Now: %d:%02d:%02d — Raid: %d:%02d:00", h, m, s, rh, rm))
        if ns.GetSecondsUntilRaid then
            local diff = ns.GetSecondsUntilRaid()
            if diff > 0 then
                print(string.format("|cff00ccffGRT:|r %s until raid", ns.FormatTimeString(diff)))
            elseif diff == 0 then
                print("|cff00ccffGRT:|r Raid time is now!")
            else
                print(string.format("|cff00ccffGRT:|r Raid started %s ago", ns.FormatTimeString(-diff)))
            end
        end
    elseif cmd == "config" then
        C_Timer.After(0, function()
            Settings.OpenToCategory(ns.settingsCategoryID)
        end)
    else
        print("|cff00ccffGitRaidTools|r commands:")
        print("  /grt config     — Open settings")
        print("  /grt inv [n]    — Send raid invite to guild chat")
        print("  /grt render [n] — Preview invite locally")
        print("  /grt flavor     — Show all flavor text variations")
        print("  /grt unseen     — Show unseen variation pool status")
        print("  /grt clear      — Reset unseen pool")
        print("  /grt time       — Show raid time info")
        print("  /grt mute       — Mute announcements")
        print("  /grt unmute     — Unmute announcements")
    end
end
