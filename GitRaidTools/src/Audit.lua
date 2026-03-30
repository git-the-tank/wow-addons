local _, ns = ...

------------------------------------------------------------
-- Constants
------------------------------------------------------------
local CHECK = "|TInterface/RaidFrame/ReadyCheck-Ready:0|t"
local CROSS = "|TInterface/RaidFrame/ReadyCheck-NotReady:0|t"
local QUESTION = "|TInterface/RaidFrame/ReadyCheck-Waiting:0|t"
local SCAN_INTERVAL = 1.0        -- seconds between inspect requests
local INSPECT_DELAY = 0.6        -- seconds after INSPECT_READY before reading items
local MAX_ROWS = 40              -- WoW raid cap
local ROW_HEIGHT = 18
local NAME_WIDTH = 105
local ILVL_WIDTH = 52
local COL_WIDTH = 34
local COL_WIDTH_NARROW = 28
local GEMS_WIDTH = 50
local FRAME_PADDING = 12
local ICON_SIZE = 24
local ICON_COL_WIDTH = 32
local NUM_ICONS = 4
local CB_WIDTH = 16

------------------------------------------------------------
-- Scan State
------------------------------------------------------------
ns.scan = {
    active = false,
    queue = {},         -- ordered list of { name, unit }
    current = nil,      -- { name, unit, guid }
    ticker = nil,
    count = 0,
    total = 0,
    units = {},         -- fullName → unitID
    paused = false,     -- combat pause
}

ns.auditData = {}       -- fullName → scan result
ns.auditSelected = {}   -- fullName → true/nil

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function FullName(unit)
    local name, realm = UnitName(unit)
    if not name then return nil end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function ShortName(fullName)
    return fullName and fullName:match("^([^-]+)") or fullName
end

local function ClassToken(unit)
    local _, token = UnitClass(unit)
    return token
end

local function GetSpecID(unit)
    if UnitIsUnit(unit, "player") then
        local specIndex = GetSpecialization()
        if specIndex then
            return (GetSpecializationInfo(specIndex))
        end
        return nil
    end
    return GetInspectSpecialization(unit)
end

------------------------------------------------------------
-- Column Definitions Per Mode
------------------------------------------------------------

-- Ench mode: name, ilvl, 9 enchant slots, gems
local function EnchColumns()
    local cols = {}
    for _, slotID in ipairs(ns.ENCHANTABLE_SLOTS) do
        local w = (slotID == 11 or slotID == 12 or slotID == 17) and COL_WIDTH_NARROW or COL_WIDTH
        cols[#cols + 1] = { label = ns.SLOT_SHORT[slotID], width = w, slotID = slotID }
    end
    cols[#cols + 1] = { label = "Gems", width = GEMS_WIDTH }
    return cols
end

-- Tier mode: name, ilvl, tier count, 5 tier slots
local function TierColumns()
    local cols = {
        { label = "Pcs", width = 32 },
    }
    for _, slotID in ipairs(ns.TIER_SLOTS) do
        cols[#cols + 1] = { label = ns.SLOT_NAMES[slotID], width = 58, slotID = slotID }
    end
    return cols
end

-- iLvl mode: name, ilvl, 4 item icon columns
local function IlvlColumns()
    return {
        { label = "Wpn",  width = ICON_COL_WIDTH, slotID = 16, isIcon = true },
        { label = "OH",   width = ICON_COL_WIDTH, slotID = 17, isIcon = true },
        { label = "Trk1", width = ICON_COL_WIDTH, slotID = 13, isIcon = true },
        { label = "Trk2", width = ICON_COL_WIDTH, slotID = 14, isIcon = true },
    }
end

local MODE_COLUMNS = {
    ench = EnchColumns,
    tier = TierColumns,
    ilvl = IlvlColumns,
}

local MODE_ROW_HEIGHT = {
    ench = ROW_HEIGHT,
    tier = ROW_HEIGHT,
    ilvl = ICON_SIZE + 6,  -- 30px to fit 24px icons with padding
}

------------------------------------------------------------
-- Data Processing
------------------------------------------------------------

local function ProcessUnitData(name, unit)
    local class = ClassToken(unit)
    local spec = GetSpecID(unit)

    local itemIlvl = {}
    local itemTracks = {}
    local itemLinks = {}
    local rawEnchantIDs = {}   -- slotID -> enchantID (for re-evaluation), -1=skip, -2=empty
    local rawGemIDs = {}       -- flat list of all gem IDs (for re-evaluation)
    local ohIsWeapon = false   -- true if slot 17 holds an actual weapon (not shield/offhand)
    local tierCount = 0
    local tierSlots = {}
    local totalIlvl = 0
    local equippedCount = 0
    local gemsSockets = 0
    local gemsFilled = 0

    for _, slotID in ipairs(ns.ALL_EQUIPMENT_SLOTS) do
        local link = GetInventoryItemLink(unit, slotID)
        if link then
            itemLinks[slotID] = link

            -- Item level + difficulty track
            local ilvl, track = ns.GetItemDetails(unit, slotID)
            itemIlvl[slotID] = ilvl
            if track then itemTracks[slotID] = track end
            if ilvl > 0 then
                totalIlvl = totalIlvl + ilvl
                equippedCount = equippedCount + 1
            end

            local itemID, enchantID, gems, bonusIDs = ns.ParseItemLink(link)

            -- Tier set check
            if itemID and ns.TIER_ITEMS[itemID] then
                tierCount = tierCount + 1
                tierSlots[slotID] = true
            end

            -- Detect if OH slot holds an actual weapon (not shield/offhand)
            if slotID == 17 then
                local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
                ohIsWeapon = (classID == 2)  -- classID 2 = Weapon
            end

            -- Store raw enchant ID for enchantable slots
            if ns.SLOT_SHORT[slotID] then
                if slotID == 17 and not ohIsWeapon then
                    rawEnchantIDs[slotID] = -1  -- skip: shield, offhand, or held item
                else
                    rawEnchantIDs[slotID] = enchantID or 0
                end
            end

            -- Store raw gem data
            local sockets = ns.CountSockets(bonusIDs)
            if sockets > 0 then
                gemsSockets = gemsSockets + sockets
                local filled = gems and #gems or 0
                gemsFilled = gemsFilled + filled
                for _, gemID in ipairs(gems or {}) do
                    rawGemIDs[#rawGemIDs + 1] = gemID
                end
            end
        else
            itemIlvl[slotID] = 0
            if ns.SLOT_SHORT[slotID] then
                if slotID == 17 then
                    rawEnchantIDs[slotID] = -1  -- empty OH = skip (2H user or no offhand)
                else
                    rawEnchantIDs[slotID] = -2  -- empty slot that should have gear
                end
            end
        end
    end

    -- 2H weapon: if no OH weapon, count MH double for ilvl average
    if not ohIsWeapon and (itemIlvl[17] or 0) == 0 and (itemIlvl[16] or 0) > 0 then
        totalIlvl = totalIlvl + itemIlvl[16]
        equippedCount = equippedCount + 1
    end

    -- Use WoW's equipped ilvl for the player (exact), manual calc for inspected
    local avgIlvl
    if UnitIsUnit(unit, "player") then
        local _, equipped = GetAverageItemLevel()
        avgIlvl = equipped or 0
    else
        avgIlvl = equippedCount > 0 and (totalIlvl / equippedCount) or 0
    end

    ns.auditData[name] = {
        name = name,
        shortName = ShortName(name),
        class = class,
        spec = spec,
        avgIlvl = avgIlvl,
        itemIlvl = itemIlvl,
        itemTracks = itemTracks,
        itemLinks = itemLinks,
        tierCount = tierCount,
        tierSlots = tierSlots,
        rawEnchantIDs = rawEnchantIDs,
        rawGemIDs = rawGemIDs,
        gems = { filled = gemsFilled, sockets = gemsSockets, passing = 0 },
        enchants = {},
        enchantDetails = {},
        bestGemRank = 0,
        failScore = 0,
        status = "scanned",
        scanTime = GetTime(),
    }

    -- Evaluate with current settings
    ns.EvaluatePlayer(ns.auditData[name])

    ns.scan.count = ns.scan.count + 1
    if ns.UpdateAuditRow then ns.UpdateAuditRow(name) end
    ns.UpdateProgress()
end

------------------------------------------------------------
-- Evaluation (runs on current settings, can re-run on toggle)
------------------------------------------------------------

function ns.EvaluatePlayer(data)
    if data.status ~= "scanned" then return end

    -- Enchants
    local enchants = {}
    local enchantDetails = {}
    local failScore = 0

    for slotID, rawID in pairs(data.rawEnchantIDs or {}) do
        if rawID == -1 then
            enchants[slotID] = "skip"
        elseif rawID == -2 then
            enchants[slotID] = "empty"
        else
            local result, detail = ns.EvaluateEnchant(rawID)
            enchants[slotID] = result
            if detail then enchantDetails[slotID] = detail end
        end
    end

    -- Gems
    local gemsPassing = 0
    local bestGemRank = 0
    for _, gemID in ipairs(data.rawGemIDs or {}) do
        local result = ns.EvaluateGem(gemID)
        if result == "pass" then gemsPassing = gemsPassing + 1 end
        local rank = ns.GetGemRank(gemID)
        if rank > bestGemRank then bestGemRank = rank end
    end

    -- Fail score
    for _, result in pairs(enchants) do
        if result == "missing" then failScore = failScore + 3
        elseif result == "low_level" then failScore = failScore + 2
        elseif result == "low_quality" or result == "unknown" then failScore = failScore + 1
        end
    end
    local g = data.gems
    failScore = failScore + (g.sockets - g.filled) * 2
    failScore = failScore + (g.filled - gemsPassing)

    data.enchants = enchants
    data.enchantDetails = enchantDetails
    data.gems.passing = gemsPassing
    data.bestGemRank = bestGemRank
    data.failScore = failScore
end

-- Re-evaluate all players with current settings (called on threshold change)
function ns.ReEvaluateAll()
    for _, data in pairs(ns.auditData) do
        ns.EvaluatePlayer(data)
    end
end

------------------------------------------------------------
-- Inspect Queue
------------------------------------------------------------

local function ScanNext()
    local scan = ns.scan
    if scan.paused then return end

    -- If still waiting on a previous inspect, check for timeout
    if scan.current then
        -- Timeout: mark failed and move on
        scan.current = nil
        -- The player whose inspect we were waiting on gets no data update
    end

    -- Find next pending
    while #scan.queue > 0 do
        local entry = table.remove(scan.queue, 1)
        local name, unit = entry.name, entry.unit

        if not UnitExists(unit) then
            -- Player left
            if not ns.auditData[name] then
                ns.auditData[name] = { name = name, shortName = ShortName(name), status = "failed" }
                scan.count = scan.count + 1
            end
            ns.UpdateProgress()
        elseif UnitIsUnit(unit, "player") then
            -- Self: read directly, no NotifyInspect needed
            ProcessUnitData(name, unit)
            return
        elseif not CanInspect(unit, false) then
            -- Out of range or not inspectable
            if not ns.auditData[name] then
                ns.auditData[name] = {
                    name = name, shortName = ShortName(name),
                    class = ClassToken(unit), status = "failed",
                }
                scan.count = scan.count + 1
            end
            ns.UpdateProgress()
        else
            -- Request inspect
            local guid = UnitGUID(unit)
            scan.current = { name = name, unit = unit, guid = guid }
            NotifyInspect(unit)
            return
        end
    end

    -- Queue empty — scan complete
    if scan.ticker then scan.ticker:Cancel() end
    scan.ticker = nil
    scan.active = false
    scan.current = nil
    ns.UpdateProgress()
    if ns.RefreshAuditUI then ns.RefreshAuditUI() end
end

local function OnInspectReady(guid)
    local scan = ns.scan
    if not scan.active or not scan.current then return end

    -- GUID check: only process if this is the player we asked about
    if guid ~= scan.current.guid then return end

    local name = scan.current.name
    local unit = scan.current.unit
    scan.current = nil

    -- Delay slightly for item data to fully populate
    C_Timer.After(INSPECT_DELAY, function()
        if UnitExists(unit) and FullName(unit) == name then
            ProcessUnitData(name, unit)
        else
            -- Unit gone or swapped
            if not ns.auditData[name] then
                ns.auditData[name] = { name = name, shortName = ShortName(name), status = "failed" }
                scan.count = scan.count + 1
                ns.UpdateProgress()
            end
        end
        ClearInspectPlayer()
    end)
end

------------------------------------------------------------
-- Scan Control
------------------------------------------------------------

function ns.StartAuditScan()
    -- Reset scan state
    local scan = ns.scan
    if scan.ticker then scan.ticker:Cancel() end
    wipe(scan.queue)
    wipe(scan.units)
    scan.current = nil
    scan.count = 0
    scan.active = true
    scan.paused = false
    wipe(ns.auditData)
    wipe(ns.auditSelected)

    -- Build roster
    local inRaid = IsInRaid()
    local count = GetNumGroupMembers()

    -- Always scan self first
    local myName = FullName("player")
    if myName then
        scan.units[myName] = "player"
        scan.queue[#scan.queue + 1] = { name = myName, unit = "player" }
    end

    for i = 1, count do
        local unit = inRaid and ("raid" .. i) or ("party" .. i)
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name = FullName(unit)
            if name and not scan.units[name] then
                scan.units[name] = unit
                scan.queue[#scan.queue + 1] = { name = name, unit = unit }
            end
        end
    end

    scan.total = #scan.queue
    ns.UpdateProgress()

    -- Show window if not already visible
    if ns.ShowAuditWindow then ns.ShowAuditWindow() end

    -- Seed rows for all pending players
    for _, entry in ipairs(scan.queue) do
        local unit = entry.unit
        if not ns.auditData[entry.name] then
            ns.auditData[entry.name] = {
                name = entry.name,
                shortName = ShortName(entry.name),
                class = UnitExists(unit) and ClassToken(unit) or nil,
                status = "pending",
            }
        end
    end
    if ns.RefreshAuditUI then ns.RefreshAuditUI() end

    -- Start the ticker
    scan.ticker = C_Timer.NewTicker(SCAN_INTERVAL, ScanNext)
    -- Process first entry immediately
    ScanNext()
end

------------------------------------------------------------
-- Combat Pause
------------------------------------------------------------
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(_, event)
    if not ns.scan.active then return end
    if event == "PLAYER_REGEN_DISABLED" then
        ns.scan.paused = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.scan.paused = false
    end
end)

------------------------------------------------------------
-- Inspect Event Handler
------------------------------------------------------------
local inspectFrame = CreateFrame("Frame")
inspectFrame:RegisterEvent("INSPECT_READY")
inspectFrame:SetScript("OnEvent", function(_, _, guid)
    OnInspectReady(guid)
end)

------------------------------------------------------------
-- UI: Main Frame
------------------------------------------------------------
local auditFrame, scrollFrame, scrollChild, headerRow
local rows = {}
local activeMode = "ench"
local activeCols = nil

local function CreateAuditFrame()
    if auditFrame then return end

    auditFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ns.auditFrame = auditFrame
    auditFrame:SetSize(600, 420)
    auditFrame:SetPoint("CENTER")
    auditFrame:SetFrameStrata("HIGH")
    auditFrame:SetMovable(true)
    auditFrame:SetClampedToScreen(true)
    auditFrame:Hide()

    auditFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    auditFrame:SetBackdropColor(0, 0, 0, 0.92)
    auditFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    -- Title bar (drag region)
    local titleBar = CreateFrame("Frame", nil, auditFrame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(24)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() auditFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() auditFrame:StopMovingOrSizing() end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 10, 0)
    title:SetText("|cff00ccffGRT|r Gear Audit")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, auditFrame, "UIPanelCloseButtonNoScripts")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetSize(20, 20)
    closeBtn:SetScript("OnClick", function() auditFrame:Hide() end)

    -- Control bar
    local controlBar = CreateFrame("Frame", nil, auditFrame)
    controlBar:SetPoint("TOPLEFT", 8, -24)
    controlBar:SetPoint("TOPRIGHT", -8, -24)
    controlBar:SetHeight(26)

    -- Scan button
    local scanBtn = CreateFrame("Button", nil, controlBar, "UIPanelButtonTemplate")
    scanBtn:SetPoint("LEFT", 0, 0)
    scanBtn:SetSize(60, 22)
    scanBtn:SetText("Scan")
    scanBtn:SetScript("OnClick", function() ns.StartAuditScan() end)

    -- Report button
    local reportBtn = CreateFrame("Button", nil, controlBar, "UIPanelButtonTemplate")
    reportBtn:SetPoint("LEFT", scanBtn, "RIGHT", 4, 0)
    reportBtn:SetSize(60, 22)
    reportBtn:SetText("Report")
    reportBtn:SetScript("OnClick", function() ns.SendAuditReport() end)

    -- Progress text
    local progressText = controlBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progressText:SetPoint("LEFT", reportBtn, "RIGHT", 8, 0)
    progressText:SetText("Idle")
    ns._progressText = progressText

    -- Mode tabs
    local modeButtons = {}
    local modes = { { key = "ench", label = "Ench" }, { key = "tier", label = "Tier" }, { key = "ilvl", label = "iLvl" } }
    for _, m in ipairs(modes) do
        local btn = CreateFrame("Button", nil, controlBar)
        btn:SetSize(42, 20)
        btn:SetNormalFontObject(GameFontHighlightSmall)
        btn:SetHighlightFontObject(GameFontNormalSmall)
        btn:SetText(m.label)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        btn._bg = bg

        btn:SetScript("OnClick", function()
            activeMode = m.key
            for _, b in ipairs(modeButtons) do
                b._bg:SetColorTexture(0.3, 0.3, 0.3, 0.5)
            end
            btn._bg:SetColorTexture(0, 0.5, 0.8, 0.6)
            ns.RefreshAuditUI()
        end)

        modeButtons[#modeButtons + 1] = btn
    end
    -- Position mode buttons right-to-left (single pass, no circular anchors)
    for i = #modeButtons, 1, -1 do
        if i == #modeButtons then
            modeButtons[i]:SetPoint("RIGHT", controlBar, "RIGHT", 0, 0)
        else
            modeButtons[i]:SetPoint("RIGHT", modeButtons[i + 1], "LEFT", -4, 0)
        end
    end
    -- Highlight default mode
    modeButtons[1]._bg:SetColorTexture(0, 0.5, 0.8, 0.6)
    ns._modeButtons = modeButtons

    -- Settings bar (compact inline cycle toggles, ench mode only)
    local settingsBar = CreateFrame("Frame", nil, auditFrame)
    settingsBar:SetPoint("TOPLEFT", 8, -50)
    settingsBar:SetPoint("TOPRIGHT", -8, -50)
    settingsBar:SetHeight(16)
    ns._settingsBar = settingsBar

    local Q1 = ns.Q1_ICON
    local Q2 = ns.Q2_ICON
    local THRESH_OPTS = {
        { label = "Any",         value = "any" },
        { label = "High " .. Q1, value = "high_q1" },
        { label = "High " .. Q2, value = "high_q2" },
    }
    local EPIC_OPTS = {
        { label = Q1 .. "+", value = 1 },
        { label = Q2,        value = 2 },
    }
    local function onSettingChange()
        ns.ReEvaluateAll()
        ns.RefreshAuditUI()
    end

    -- Enchant threshold
    local eLabel = settingsBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    eLabel:SetPoint("LEFT", 0, 0)
    eLabel:SetText("|cff888888Ench:|r")

    local eBtn = ns.MakeCycleButton(settingsBar, THRESH_OPTS,
        function() return ns.db and ns.db.auditEnchantThreshold or "high_q1" end,
        function(v) if ns.db then ns.db.auditEnchantThreshold = v end end,
        onSettingChange)
    eBtn:SetPoint("LEFT", eLabel, "RIGHT", 2, 0)

    -- Gem threshold
    local gLabel = settingsBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gLabel:SetPoint("LEFT", eBtn, "RIGHT", 10, 0)
    gLabel:SetText("|cff888888Gem:|r")

    local gBtn = ns.MakeCycleButton(settingsBar, THRESH_OPTS,
        function() return ns.db and ns.db.auditGemThreshold or "high_q1" end,
        function(v) if ns.db then ns.db.auditGemThreshold = v end end,
        onSettingChange)
    gBtn:SetPoint("LEFT", gLabel, "RIGHT", 2, 0)

    -- Epic gem threshold
    local epLabel = settingsBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epLabel:SetPoint("LEFT", gBtn, "RIGHT", 10, 0)
    epLabel:SetText("|cff888888Epic:|r")

    local epBtn = ns.MakeCycleButton(settingsBar, EPIC_OPTS,
        function() return ns.db and ns.db.auditEpicGemMin or 2 end,
        function(v) if ns.db then ns.db.auditEpicGemMin = v end end,
        onSettingChange)
    epBtn:SetPoint("LEFT", epLabel, "RIGHT", 2, 0)

    -- Header row
    headerRow = CreateFrame("Frame", nil, auditFrame)
    headerRow:SetPoint("TOPLEFT", 8, -68)
    headerRow:SetPoint("TOPRIGHT", -26, -68)
    headerRow:SetHeight(ROW_HEIGHT)

    -- Header separator line
    local sep = auditFrame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -1)
    sep:SetPoint("TOPRIGHT", headerRow, "BOTTOMRIGHT", 0, -1)
    sep:SetHeight(1)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.8)

    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", nil, auditFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -68 - ROW_HEIGHT - 2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 540)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    -- Size the scroll child width after layout
    auditFrame:SetScript("OnShow", function()
        scrollChild:SetWidth(scrollFrame:GetWidth())
    end)
end

------------------------------------------------------------
-- UI: Row Management
------------------------------------------------------------
local MAX_CELLS = 12

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", 0, 0)

    -- Alternating background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetColorTexture(0.15, 0.15, 0.15, 0.5)
    else
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
    end

    -- Selection checkbox
    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetSize(CB_WIDTH, CB_WIDTH)
    cb:SetPoint("LEFT", 2, 0)
    cb:SetScript("OnClick", function(self)
        if row._playerName then
            ns.auditSelected[row._playerName] = self:GetChecked() or nil
        end
    end)
    row.selectCB = cb

    -- Name cell
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    nameText:SetWidth(NAME_WIDTH - CB_WIDTH - 2)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- iLvl cell
    local ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ilvlText:SetPoint("LEFT", nameText, "RIGHT", 2, 0)
    ilvlText:SetWidth(ILVL_WIDTH)
    ilvlText:SetJustifyH("RIGHT")
    row.ilvlText = ilvlText

    -- Value cells (positioned dynamically per mode)
    row.cells = {}
    for i = 1, MAX_CELLS do
        local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cell:SetJustifyH("CENTER")
        cell:Hide()
        row.cells[i] = cell
    end

    -- Tooltip hover zones (invisible buttons overlaying cells for enchant tooltips)
    row.hovers = {}
    for i = 1, MAX_CELLS do
        local hf = CreateFrame("Button", nil, row)
        hf:SetFrameLevel(row:GetFrameLevel() + 10)
        hf:SetHeight(ROW_HEIGHT)
        hf:SetWidth(COL_WIDTH)
        hf:EnableMouse(true)
        hf:Hide()
        hf:SetScript("OnEnter", function(self)
            if self.tipLines then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT") -- luacheck: ignore 113
                local first = self.tipLines[1]
                if type(first) == "table" then
                    -- Gem format: { {name, stats}, {name, stats}, ... }
                    GameTooltip:SetText("Gems", 1, 1, 1) -- luacheck: ignore 113
                    for _, gem in ipairs(self.tipLines) do
                        GameTooltip:AddLine(gem[1], 0, 1, 0) -- luacheck: ignore 113
                        if gem[2] and gem[2] ~= "" then
                            GameTooltip:AddLine("  " .. gem[2], 1, 1, 1) -- luacheck: ignore 113
                        end
                    end
                else
                    -- Enchant format: { name, effect, ... }
                    GameTooltip:SetText(first or "", 0, 1, 0) -- luacheck: ignore 113
                    for j = 2, #self.tipLines do
                        GameTooltip:AddLine(self.tipLines[j], 1, 1, 1, true) -- luacheck: ignore 113
                    end
                end
                GameTooltip:Show() -- luacheck: ignore 113
            elseif self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT") -- luacheck: ignore 113
                GameTooltip:SetHyperlink(self.link) -- luacheck: ignore 113
                GameTooltip:Show() -- luacheck: ignore 113
            end
        end)
        hf:SetScript("OnLeave", function()
            GameTooltip:Hide() -- luacheck: ignore 113
        end)
        row.hovers[i] = hf
    end

    -- Icon buttons (for iLvl mode item icons)
    row.icons = {}
    for i = 1, NUM_ICONS do
        local btn = CreateFrame("Button", nil, row)
        btn:SetSize(ICON_SIZE, ICON_SIZE)
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.icon = tex
        -- iLvl overlay in bottom-right corner
        local ilvlOverlay = btn:CreateFontString(nil, "OVERLAY")
        ilvlOverlay:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
        ilvlOverlay:SetPoint("BOTTOMRIGHT", 2, -2)
        ilvlOverlay:SetJustifyH("RIGHT")
        ilvlOverlay:SetText("")
        btn.ilvlText = ilvlOverlay
        btn:SetScript("OnEnter", function(self)
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT") -- luacheck: ignore 113
                GameTooltip:SetHyperlink(self.link) -- luacheck: ignore 113
                GameTooltip:Show() -- luacheck: ignore 113
            end
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide() -- luacheck: ignore 113
        end)
        btn:Hide()
        row.icons[i] = btn
    end

    row:Hide()
    return row
end

local function GetRow(index)
    if not rows[index] then
        rows[index] = CreateRow(index)
    end
    return rows[index]
end

------------------------------------------------------------
-- UI: Header Rendering
------------------------------------------------------------
local headerCells = {}

local function RenderHeaders(cols)
    -- Clear old headers
    for _, h in ipairs(headerCells) do h:Hide() end

    -- Name header
    if not headerCells.name then
        headerCells.name = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        headerCells.name:SetPoint("LEFT", 4, 0)
        headerCells.name:SetWidth(NAME_WIDTH)
        headerCells.name:SetJustifyH("LEFT")
    end
    headerCells.name:SetText("Name")
    headerCells.name:Show()

    -- iLvl header
    if not headerCells.ilvl then
        headerCells.ilvl = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        headerCells.ilvl:SetPoint("LEFT", headerCells.name, "RIGHT", 2, 0)
        headerCells.ilvl:SetWidth(ILVL_WIDTH)
        headerCells.ilvl:SetJustifyH("RIGHT")
    end
    headerCells.ilvl:SetText("Eqp")
    headerCells.ilvl:Show()

    -- Dynamic columns
    local xOffset = NAME_WIDTH + ILVL_WIDTH + 6
    for i, col in ipairs(cols) do
        if not headerCells[i] then
            headerCells[i] = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        end
        local h = headerCells[i]
        h:ClearAllPoints()
        h:SetPoint("LEFT", headerRow, "LEFT", xOffset, 0)
        h:SetWidth(col.width)
        h:SetJustifyH("CENTER")
        h:SetText(col.label)
        h:Show()
        xOffset = xOffset + col.width
    end

    -- Hide extras
    for i = #cols + 1, #headerCells do
        if headerCells[i] then headerCells[i]:Hide() end
    end
end

------------------------------------------------------------
-- UI: Cell Rendering Per Mode
------------------------------------------------------------
local CLASS_COLORS = RAID_CLASS_COLORS -- luacheck: ignore 113

-- Track letter → color (WoW quality colors)
local TRACK_COLORS = {
    M = "ffff8000", -- orange: mythic
    H = "ffa335ee", -- purple: hero
    C = "ff0070dd", -- blue: champion
    V = "ff1eff00", -- green: veteran
    A = "ffffffff", -- white: adventurer
}

-- Color an ilvl value. Uses track if available, otherwise ilvl breakpoints as fallback.
local function ColorIlvl(ilvl, track)
    if ilvl <= 0 then return "ff666666" end
    if track and TRACK_COLORS[track] then return TRACK_COLORS[track] end
    -- Fallback: rough ilvl-based estimate
    if ilvl >= 287 then return "ffff8000"
    elseif ilvl >= 280 then return "ffa335ee"
    elseif ilvl >= 265 then return "ff0070dd"
    elseif ilvl >= 251 then return "ff1eff00"
    else return "ffffffff"
    end
end

local function RenderEnchCell(data, col)
    if not data.enchants then return "...", nil end
    local slotID = col.slotID
    if not slotID then
        -- Gems summary column
        local g = data.gems
        if not g or g.sockets == 0 then return "-", "ff666666" end
        local color = g.passing >= g.sockets and "ff00ff00" or "ffff4444"
        local rankStr = ""
        local rank = data.bestGemRank or 0
        if rank > 0 then
            local icon = rank == 1 and ns.Q1_ICON or ns.Q2_ICON
            rankStr = " " .. icon
        end
        return g.passing .. "/" .. g.sockets .. rankStr, color
    end
    local result = data.enchants[slotID]
    if result == "pass" then
        return CHECK, nil
    elseif result == "missing" then
        return CROSS, nil                              -- red X: nothing enchanted
    elseif result == "low_level" then
        return "L", "ffff4444"                         -- red L: old expansion enchant
    elseif result == "low_quality" then
        local q = data.enchantDetails and data.enchantDetails[slotID]
        local icon = q == 1 and ns.Q1_ICON or ns.Q2_ICON
        return icon, nil                               -- quality icon: right level, low quality
    elseif result == "unknown" then
        return QUESTION, nil                           -- yellow ?: unrecognized enchant
    elseif result == "skip" or result == "empty" then
        return "-", "ff666666"
    else
        return "...", "ff666666"
    end
end

local function RenderTierCell(data, col)
    if not col.slotID then
        -- Tier count column
        local count = data.tierCount or 0
        local color
        if count >= 4 then color = "ff00ff00"
        elseif count >= 2 then color = "ffffff00"
        else color = "ffff4444"
        end
        return tostring(count), color
    end
    -- Per-slot tier ilvl with track letter from tooltip
    local slotID = col.slotID
    if data.tierSlots and data.tierSlots[slotID] then
        local ilvl = data.itemIlvl and data.itemIlvl[slotID] or 0
        local track = data.itemTracks and data.itemTracks[slotID]
        if ilvl > 0 then
            local color = ColorIlvl(ilvl, track)
            local text = track and (track .. " " .. ilvl) or tostring(ilvl)
            return text, color
        end
        return CHECK, nil
    end
    return "-", "ff666666"
end

-- iLvl mode uses icons, not text — this is a no-op fallback
local function RenderIlvlCell()
    return "", nil
end

local RENDER_FNS = {
    ench = RenderEnchCell,
    tier = RenderTierCell,
    ilvl = RenderIlvlCell,
}

------------------------------------------------------------
-- UI: Row Rendering
------------------------------------------------------------

local function RenderRow(row, data, cols, renderFn)
    if not data then row:Hide(); return end

    -- Checkbox state
    row._playerName = data.name
    row.selectCB:SetChecked(ns.auditSelected[data.name] or false)

    -- Name (class-colored)
    local displayName = data.shortName or data.name or "?"
    if data.class and CLASS_COLORS[data.class] then
        local cc = CLASS_COLORS[data.class]
        row.nameText:SetText(string.format("|cff%02x%02x%02x%s|r",
            cc.r * 255, cc.g * 255, cc.b * 255, displayName))
    else
        row.nameText:SetText(displayName)
    end

    -- iLvl
    if data.status == "scanned" and data.avgIlvl then
        local color = ColorIlvl(data.avgIlvl)
        row.ilvlText:SetText(string.format("|c%s%.2f|r", color, data.avgIlvl))
    elseif data.status == "failed" then
        row.ilvlText:SetText("|cff666666---|r")
    else
        row.ilvlText:SetText("|cff666666...|r")
    end

    -- Dynamic columns
    local xOffset = NAME_WIDTH + ILVL_WIDTH + 6
    local iconIdx = 1
    for i, col in ipairs(cols) do
        if col.isIcon then
            -- Icon column (iLvl mode)
            local iconBtn = row.icons[iconIdx]
            row.cells[i]:Hide()
            if row.hovers[i] then row.hovers[i]:Hide() end
            if iconBtn then
                if data.status == "scanned" and data.itemLinks then
                    local link = data.itemLinks[col.slotID]
                    if link then
                        local _, _, _, _, iconTex = C_Item.GetItemInfoInstant(link)
                        iconBtn.icon:SetTexture(iconTex)
                        iconBtn.icon:SetDesaturated(false)
                        iconBtn.link = link
                        local slotIlvl = data.itemIlvl and data.itemIlvl[col.slotID] or 0
                        local slotTrack = data.itemTracks and data.itemTracks[col.slotID]
                        if slotIlvl > 0 then
                            local c = ColorIlvl(slotIlvl, slotTrack)
                            iconBtn.ilvlText:SetText("|c" .. c .. slotIlvl .. "|r")
                        else
                            iconBtn.ilvlText:SetText("")
                        end
                    else
                        iconBtn.icon:SetTexture(134400) -- INV_Misc_QuestionMark
                        iconBtn.icon:SetDesaturated(true)
                        iconBtn.link = nil
                        iconBtn.ilvlText:SetText("")
                    end
                    iconBtn:ClearAllPoints()
                    iconBtn:SetPoint("CENTER", row, "LEFT", xOffset + col.width / 2, 0)
                    iconBtn:Show()
                elseif data.status == "failed" then
                    iconBtn.icon:SetTexture(134400)
                    iconBtn.icon:SetDesaturated(true)
                    iconBtn.link = nil
                    iconBtn.ilvlText:SetText("")
                    iconBtn:ClearAllPoints()
                    iconBtn:SetPoint("CENTER", row, "LEFT", xOffset + col.width / 2, 0)
                    iconBtn:Show()
                else
                    iconBtn:Hide()
                end
                iconIdx = iconIdx + 1
            end
        else
            -- Text column
            local cell = row.cells[i]
            if data.status == "scanned" then
                local text, clr = renderFn(data, col)
                if clr then
                    cell:SetText("|c" .. clr .. text .. "|r")
                else
                    cell:SetText(text)
                end
            elseif data.status == "failed" then
                cell:SetText("|cff666666---|r")
            else
                cell:SetText("|cff666666...|r")
            end
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", row, "LEFT", xOffset, 0)
            cell:SetWidth(col.width)
            cell:Show()

            -- Tooltip hover zone
            local hf = row.hovers[i]
            hf.link = nil
            hf.tipLines = nil
            if activeMode == "ench" and data.status == "scanned" and col.slotID and data.rawEnchantIDs then
                -- Ench mode: show enchant name + effect
                local rawID = data.rawEnchantIDs[col.slotID]
                if rawID and rawID > 0 then
                    local info = ns.ENCHANT_NAMES and ns.ENCHANT_NAMES[rawID]
                    if info then
                        local encoded = ns.ENCHANT_DATA[rawID]
                        local qIcon = ""
                        if encoded then
                            local q = encoded >= 10 and (encoded - 10) or encoded
                            qIcon = (q == 2 and ns.Q2_ICON or ns.Q1_ICON) .. " "
                        end
                        hf.tipLines = { qIcon .. info[1], info[2] }
                    else
                        hf.tipLines = { "Enchant ID: " .. rawID }
                    end
                end
            elseif activeMode == "ench" and data.status == "scanned" and not col.slotID and data.rawGemIDs then
                -- Gems column: show gem name + stats from tooltip
                local lines = {}
                for _, gemID in ipairs(data.rawGemIDs) do
                    local name = C_Item.GetItemInfo(gemID) -- luacheck: ignore 113
                    local rank = ns.GetGemRank(gemID)
                    local qIcon = rank == 2 and ns.Q2_ICON or (rank == 1 and ns.Q1_ICON or "")
                    local statText = ""
                    local tipData = C_TooltipInfo.GetItemByID(gemID)
                    if tipData and tipData.lines then
                        for _, tl in ipairs(tipData.lines) do
                            local c = tl.leftColor
                            if c and c.g and c.g > 0.9 and c.r < 0.15 and c.b < 0.15 then
                                statText = tl.leftText or ""
                                break
                            end
                        end
                    end
                    lines[#lines + 1] = { qIcon .. " " .. (name or ("Gem " .. gemID)), statText }
                end
                if #lines > 0 then hf.tipLines = lines end
            elseif activeMode ~= "ench" and data.status == "scanned" and col.slotID and data.itemLinks then
                -- Tier/iLvl modes: show the actual item tooltip
                local link = data.itemLinks[col.slotID]
                if link then hf.link = link end
            end
            hf:ClearAllPoints()
            hf:SetPoint("LEFT", row, "LEFT", xOffset, 0)
            hf:SetWidth(col.width)
            hf:SetHeight(row:GetHeight())
            hf:Show()
        end
        xOffset = xOffset + col.width
    end

    -- Hide unused cells, icons, and hovers
    for i = #cols + 1, MAX_CELLS do
        row.cells[i]:Hide()
        if row.hovers[i] then row.hovers[i]:Hide() end
    end
    for i = iconIdx, NUM_ICONS do
        if row.icons[i] then row.icons[i]:Hide() end
    end

    row:Show()
end

------------------------------------------------------------
-- UI: Refresh (full rebuild)
------------------------------------------------------------

local function SortedEntries()
    local entries = {}
    for _, data in pairs(ns.auditData) do
        entries[#entries + 1] = data
    end
    table.sort(entries, function(a, b)
        -- Scanned first, then failed, then pending
        local aOrder = a.status == "scanned" and 0 or (a.status == "failed" and 1 or 2)
        local bOrder = b.status == "scanned" and 0 or (b.status == "failed" and 1 or 2)
        if aOrder ~= bOrder then return aOrder < bOrder end
        -- Then by fail score (worst offenders first)
        local aFail = a.failScore or 0
        local bFail = b.failScore or 0
        if aFail ~= bFail then return aFail > bFail end
        -- Then by class
        local aClass = a.class or "ZZZZ"
        local bClass = b.class or "ZZZZ"
        if aClass ~= bClass then return aClass < bClass end
        -- Then by name
        return (a.shortName or a.name or "") < (b.shortName or b.name or "")
    end)
    return entries
end

function ns.RefreshAuditUI()
    if not auditFrame or not auditFrame:IsShown() then return end

    -- Show settings bar only in ench mode, adjust layout
    local showSettings = activeMode == "ench"
    if ns._settingsBar then
        ns._settingsBar:SetShown(showSettings)
    end
    local headerY = showSettings and -68 or -52
    if headerRow then
        headerRow:ClearAllPoints()
        headerRow:SetPoint("TOPLEFT", 8, headerY)
        headerRow:SetPoint("TOPRIGHT", -26, headerY)
    end
    if scrollFrame then
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", 8, headerY - ROW_HEIGHT - 2)
        scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)
    end

    activeCols = MODE_COLUMNS[activeMode]()
    RenderHeaders(activeCols)

    local renderFn = RENDER_FNS[activeMode]
    local entries = SortedEntries()
    local rowH = MODE_ROW_HEIGHT[activeMode] or ROW_HEIGHT

    -- Compute needed frame width
    local contentWidth = NAME_WIDTH + ILVL_WIDTH + 6
    for _, col in ipairs(activeCols) do contentWidth = contentWidth + col.width end
    contentWidth = contentWidth + FRAME_PADDING * 2 + 22 -- padding + scrollbar
    auditFrame:SetWidth(math.max(contentWidth, 300))
    scrollChild:SetWidth(scrollFrame:GetWidth())

    for i, data in ipairs(entries) do
        if i > MAX_ROWS then break end
        local row = GetRow(i)
        -- Reposition row for current mode's row height
        row:SetHeight(rowH)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
        row:SetPoint("RIGHT", 0, 0)
        RenderRow(row, data, activeCols, renderFn)
    end

    -- Hide excess rows
    for i = #entries + 1, #rows do
        rows[i]:Hide()
    end

    -- Update scroll child height
    local visibleRows = math.min(#entries, MAX_ROWS)
    scrollChild:SetHeight(visibleRows * rowH)
end

-- Lightweight single-row update (during scanning)
function ns.UpdateAuditRow(name)
    if not auditFrame or not auditFrame:IsShown() then return end
    -- For simplicity during scan, just do a full refresh
    -- The sort order may change as players complete
    ns.RefreshAuditUI()
end

------------------------------------------------------------
-- UI: Progress Text
------------------------------------------------------------

function ns.UpdateProgress()
    if not ns._progressText then return end
    local scan = ns.scan
    if not scan.active then
        if scan.total > 0 then
            ns._progressText:SetText(string.format("Complete (%d/%d)", scan.count, scan.total))
        else
            ns._progressText:SetText("Idle")
        end
    else
        local status = scan.paused and "Paused" or "Scanning"
        ns._progressText:SetText(string.format("%s... %d/%d", status, scan.count, scan.total))
    end
end

------------------------------------------------------------
-- Report: build issue text and send to chat + whisper
------------------------------------------------------------

-- Plain text quality labels for chat messages (no atlas markup)
local function QText(q)
    return q == 2 and "Q2" or "Q1"
end

local function BuildIssuesForPlayer(data)
    if data.status ~= "scanned" then return nil end
    local issues = {}
    for _, slotID in ipairs(ns.ENCHANTABLE_SLOTS) do
        local result = data.enchants and data.enchants[slotID]
        local sn = ns.SLOT_NAMES[slotID] or ("Slot " .. slotID)
        if result == "missing" then
            issues[#issues + 1] = "Missing " .. sn
        elseif result == "low_level" then
            issues[#issues + 1] = sn .. " old enchant"
        elseif result == "low_quality" then
            local q = data.enchantDetails and data.enchantDetails[slotID] or 1
            issues[#issues + 1] = sn .. " " .. QText(q)
        elseif result == "unknown" then
            issues[#issues + 1] = sn .. " unrecognized"
        end
    end
    local g = data.gems
    if g and g.sockets > 0 then
        local empty = g.sockets - g.filled
        if empty > 0 then issues[#issues + 1] = empty .. " empty gem socket(s)" end
        local bad = g.filled - g.passing
        if bad > 0 then issues[#issues + 1] = bad .. " gem(s) below threshold" end
    end
    if #issues == 0 then return nil end
    return issues
end

function ns.SendAuditReport()
    local selected = {}
    for name in pairs(ns.auditSelected) do
        local data = ns.auditData[name]
        if data then
            local issues = BuildIssuesForPlayer(data)
            if issues then
                selected[#selected + 1] = { data = data, issues = issues }
            end
        end
    end

    if #selected == 0 then
        print("|cff00ccffGRT:|r No selected players with issues to report.")
        return
    end

    -- Determine chat channel
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)

    -- Send group summary
    if channel then
        SendChatMessage("[GRT] Gear audit - enhancement issues:", channel)
        for _, entry in ipairs(selected) do
            local shortName = entry.data.shortName or entry.data.name
            local line = shortName .. ": " .. table.concat(entry.issues, ", ")
            if #line > 250 then line = line:sub(1, 247) .. "..." end
            SendChatMessage(line, channel)
        end
    end

    -- Whisper each player with their issues
    local delay = 0
    for _, entry in ipairs(selected) do
        local whisperName = entry.data.name
        local issueText = table.concat(entry.issues, ", ")
        C_Timer.After(delay, function()
            local msg = "[GRT] Gear check: " .. issueText
            if #msg > 250 then msg = msg:sub(1, 247) .. "..." end
            SendChatMessage(msg, "WHISPER", nil, whisperName)
        end)
        delay = delay + 0.3
    end

    print(string.format("|cff00ccffGRT:|r Reported %d player(s).", #selected))
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------

function ns.ShowAuditWindow()
    CreateAuditFrame()
    auditFrame:Show()
    if activeCols then ns.RefreshAuditUI() end
end

function ns.ToggleAuditWindow()
    CreateAuditFrame()
    if auditFrame:IsShown() then
        auditFrame:Hide()
    else
        ns.ShowAuditWindow()
        -- Auto-scan if no data
        if not next(ns.auditData) then
            ns.StartAuditScan()
        end
    end
end

------------------------------------------------------------
-- Data version check on login
------------------------------------------------------------
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    ns.CheckAuditDataVersion()
end)
