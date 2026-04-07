local _, ns = ...

-- Each variation is just the flavor lines between the borders.
-- Use %name% as a placeholder for the player name.
local VARIATIONS = {
    { '(V) (;,,;) (V)  The loot is not going to drop itself. Probably.' },
    { '>o.o<  Do not worry, the healers have already lowered their expectations.' },
    { '<(^.^)>  First pull in 5. Last pull in "we will see."' },
    { '( . Y . )  Get in here, we got bosses to spank.' },
    { '(@_@)  We wiped last week but our memories are short. Get in here.' },
    { '(x_x)  Loot is temporary. Trauma is forever. Raid time.' },
    { '>=)  Come watch the tank face pull while "checking something real quick."' },
    { '(/o.o)/  Stand in fire, DPS higher. You know the rules.' },
    { 'o_O  If we one-shot everything I will be suspicious.' },
    { '<{o.o}>  Time to turn our addons into a Christmas tree and pretend we know the fight.' },
    { '(;-;)  Bring flasks. Bring food. Bring excuses for dying.' },
    { '(o_o")  We are not a casual guild. We are a guild that casually wipes.' },
    { '~(^.^)~  New strat: just do more damage than we take. How hard can it be.' },
    { '(>_<)  The boss has mechanics. We have vibes. Let us see who wins.' },
    { '(-_-)zzZ  AFK for 2 min means 10 min and we all know it. Get in now.' },
    { '(^_^)7  Tanks: please use cooldowns this time. Not just your personality.' },
    { '(/o.o)>  Healers: you can not dispel stupidity but we believe in you.' },
    { '(>.<)  DPS: the boss is not the meter. Hit the right target.' },
    { '(-_-;)  Tanks: if you die it is a wipe. If DPS dies it is a parse.' },
    { '(;_;)  Healers wanted. Therapy skills a bonus. Raid in 5.' },
    -- class jokes
    { '(o.o)>  Hunters: please dismiss your pets before the jump. Please.' },
    { '(*_*)  Mages: we need a table not a portal to Theramore.' },
    { '(=_=)  Warlocks: yes you have to make healthstones. Every. Time.' },
    { '(o_O)  Someone will pull before the countdown. It is tradition at this point.' },
    { '<(-.-)>  DKs: grip the add not the boss. We talked about this.' },
    { '(~_~)  Paladins: bubble hearth is not a raid cooldown.' },
    { '(>o<)  Lust on pull means ON PULL. Not "when I feel like it."' },
    { '(-_-)  Druids: pick a form and commit. This is not a costume party.' },
    { '(o.O)?  Monks: please stop rolling off the platform.' },
    { '(._.)  Priests: life grip is for saving people not trolling the tank.' },
    { '(^.^;)  Evokers: nobody knows what augmentation does and at this point we are afraid to ask.' },
    { '(@.@)  Warriors: heroic leap has a 100% success rate on flat ground. Try it sometime.' },
    { '(-.-)  DHs: "I sacrificed everything" except your parse apparently.' },
    -- more general
    { '(o_o)  "Just one more pull" -- us 45 minutes ago.' },
    { '>=D  Tonight on the menu: boss tears and floor tanking.' },
    { '(^o^)  Log out of your alt and get on your main. Yes, you.' },
    { '(-_-;)  "I disconnected" is not a mechanic and we all saw you stand in fire.' },
    { '(/o_o)/  Soulstone the healer. Or the warlock. They will argue about it either way.' },
    { '(o.o)  Do not release. Do not run back. Just lie there and think about what you did.' },
    { '(>_>)  "Bio break" is not a 15-minute Netflix episode.' },
    { '(*o*)  Remember: dying to trash is more embarrassing than wiping on the boss.' },
    { '(=.=)  If your BigWigs is outdated you are the mechanic now.' },
    { '<(o.o<)  "Which boss is this?" -- someone who did not read the strat and will not admit it.' },
    { '(x_x)  Floor tanks needed. Just kidding. Stop dying.' },
    { '(^_~)  If you did not prepot did you even show up.' },
    { '(o_o)b  Interrupts are not on the meters but they are on my heart. Use them.' },
    { '(>.<)  We do not talk about last week. Fresh start. New wipes.' },
    { '(-_-)7  The raid comp is "good enough." The skill comp is "we will see."' },
    { '(;o;)  Somewhere a boss is buffing up for us right now. Do not keep them waiting.' },
}

-- Expose for Options panel
ns.VARIATIONS = VARIATIONS

function ns.GetUnseenSet()
    if not ns.db then return {} end
    -- nil means pool not initialized yet = all unseen
    if not ns.db.raidTimeUnseen then
        local set = {}
        for i = 1, #VARIATIONS do set[i] = true end
        return set
    end
    local set = {}
    for _, v in ipairs(ns.db.raidTimeUnseen) do set[v] = true end
    return set
end

function ns.SetVariationUnseen(idx, unseen)
    if not ns.db then return end
    -- Ensure pool is initialized
    if not ns.db.raidTimeUnseen then
        ns.db.raidTimeUnseen = {}
        for i = 1, #VARIATIONS do ns.db.raidTimeUnseen[i] = i end
    end
    local pool = ns.db.raidTimeUnseen
    if unseen then
        -- Add back if not already there
        for _, v in ipairs(pool) do
            if v == idx then return end
        end
        pool[#pool + 1] = idx
    else
        -- Remove from pool
        for i, v in ipairs(pool) do
            if v == idx then
                pool[i] = pool[#pool]
                pool[#pool] = nil
                return
            end
        end
    end
end

local function GetUnseen()
    local db = ns.db
    if not db.raidTimeUnseen or #db.raidTimeUnseen == 0 then
        db.raidTimeUnseen = {}
        for i = 1, #VARIATIONS do db.raidTimeUnseen[i] = i end
    end
    return db.raidTimeUnseen
end

local function MarkSeen(variationIdx)
    local unseen = GetUnseen()
    for i, v in ipairs(unseen) do
        if v == variationIdx then
            unseen[i] = unseen[#unseen]
            unseen[#unseen] = nil
            return true
        end
    end
    return false
end

local function PickVariation()
    local unseen = GetUnseen()
    local pick = math.random(#unseen)
    local idx = unseen[pick]
    unseen[pick] = unseen[#unseen]
    unseen[#unseen] = nil
    return VARIATIONS[idx]
end

local function BuildLines(index)
    local name = UnitName("player")
    local keyword = ns.db and ns.db.keyword or ns.CONFIG.keyword
    local template = (ns.db and ns.db.inviteTemplate) or ns.CONFIG.inviteTemplate

    local flavorText = nil
    if template:find("%%flavor%%") then
        local variation
        if index then
            variation = VARIATIONS[index + 1]
            if not variation then
                print("|cff00ccffGRT:|r Invalid variation index. Valid range: 0-" .. (#VARIATIONS - 1))
                return nil
            end
            if not MarkSeen(index + 1) then
                print("|cff00ccffGRT:|r Variation " .. index .. " already used. Pool resets when all are seen.")
                return nil
            end
        else
            variation = PickVariation()
        end
        flavorText = table.concat(variation, " | "):gsub("%%name%%", name)
    end

    local lines = {}
    for line in (template .. "\n"):gmatch("([^\n]*)\n") do
        if line == "%flavor%" then
            if flavorText then
                lines[#lines + 1] = flavorText
            end
        else
            line = line:gsub("%%name%%", name)
            line = line:gsub("%%keyword%%", keyword)
            lines[#lines + 1] = line
        end
    end
    return lines
end

-- Run a list of functions with a fixed delay between each
local function RunSequence(steps, delay)
    for i, step in ipairs(steps) do
        C_Timer.After(delay * (i - 1), step)
    end
end

local function InvokeMRTInvite()
    local handler = SlashCmdList["mrtSlash"]
    if handler then
        handler("inv")
    else
        print("|cff00ccffGRT:|r MRT not loaded, could not run invite command.")
    end
end

-- Copyable text popup
local copyFrame

local function ShowCopyFrame(text)
    if not copyFrame then
        copyFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        copyFrame:SetSize(600, 400)
        copyFrame:SetPoint("CENTER")
        copyFrame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        copyFrame:SetBackdropColor(0, 0, 0, 0.9)
        copyFrame:SetFrameStrata("DIALOG")
        copyFrame:EnableMouse(true)
        copyFrame:SetMovable(true)
        copyFrame:SetResizable(true)
        copyFrame:SetResizeBounds(300, 200, 900, 700)
        copyFrame:RegisterForDrag("LeftButton")
        copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
        copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)

        local grip = CreateFrame("Button", nil, copyFrame)
        grip:SetSize(16, 16)
        grip:SetPoint("BOTTOMRIGHT", -4, 4)
        grip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
        grip:SetScript("OnMouseDown", function() copyFrame:StartSizing("BOTTOMRIGHT") end)
        grip:SetScript("OnMouseUp", function() copyFrame:StopMovingOrSizing() end)

        local scroll = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -28, 8)

        local editbox = CreateFrame("EditBox", nil, scroll)
        editbox:SetMultiLine(true)
        editbox:SetAutoFocus(false)
        editbox:SetFontObject(ChatFontNormal)
        editbox:SetWidth(scroll:GetWidth() or 440)
        editbox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
        scroll:SetScrollChild(editbox)
        copyFrame.editbox = editbox
    end
    copyFrame.editbox:SetText(text)
    copyFrame:Show()
    copyFrame.editbox:HighlightText()
    copyFrame.editbox:SetFocus()
end

function ns.RaidTimeFlavor()
    local output = {}
    for i, variation in ipairs(VARIATIONS) do
        output[#output + 1] = "[" .. (i - 1) .. "] " .. table.concat(variation, " | ")
    end
    ShowCopyFrame(table.concat(output, "\n"))
end

function ns.RaidTimeClear()
    ns.db.raidTimeUnseen = nil
    print("|cff00ccffGRT:|r Unseen pool reset.")
end

function ns.RaidTimeUnseen()
    local unseen = GetUnseen()
    local seen = {}
    local unseenSet = {}
    for _, v in ipairs(unseen) do unseenSet[v] = true end
    for i = 1, #VARIATIONS do
        if not unseenSet[i] then
            seen[#seen + 1] = tostring(i - 1)
        end
    end
    local usedStr = #seen > 0 and table.concat(seen, ", ") or "none"
    print("|cff00ccffGRT:|r " .. #unseen .. "/" .. #VARIATIONS .. " unseen — used: " .. usedStr)
end

function ns.RaidTimeRender(arg)
    local index = tonumber(arg)
    local lines = BuildLines(index)
    if not lines then return end
    for _, line in ipairs(lines) do
        print(line)
    end
end

function ns.RaidTimeInvite(arg)
    if ns.db and ns.db.invitesEnabled == false then
        print("|cff00ccffGRT:|r Invites are disabled. Enable in /grt config.")
        return
    end
    local index = tonumber(arg)
    local lines = BuildLines(index)
    if not lines then return end
    local steps = {}
    for _, line in ipairs(lines) do
        local msg = line
        steps[#steps + 1] = function() ns.Announce(msg, "GUILD") end
    end
    steps[#steps + 1] = InvokeMRTInvite
    local delay = ns.db and ns.db.inviteDelay or ns.CONFIG.inviteDelay
    RunSequence(steps, delay)

    if ns.db then
        ns.db.dispatchInvSent = true
        if ns.EvaluateDispatchVisibility then ns.EvaluateDispatchVisibility() end
    end
end
