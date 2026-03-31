local _, ns = ...

local selectedBoss = nil
local bossList = {}

-- Column layout for boss view
local COLUMNS = {
    { key = "name",       label = "Name",      x = 4,   w = 155, justify = "LEFT" },
    { key = "spec",       label = "Spec",       x = 160, w = 85,  justify = "LEFT" },
    { key = "medianParse",label = "Median",     x = 250, w = 55,  justify = "RIGHT" },
    { key = "bestParse",  label = "Best",       x = 310, w = 50,  justify = "RIGHT" },
    { key = "medianDPS",  label = "Med DPS",    x = 365, w = 65,  justify = "RIGHT" },
    { key = "trend",      label = "Trend",      x = 435, w = 50,  justify = "CENTER" },
    { key = "vsAvg",      label = "vs Avg",     x = 490, w = 50,  justify = "RIGHT" },
    { key = "kills",      label = "Kills",      x = 545, w = 40,  justify = "RIGHT" },
}

local function GetBossList()
    local names = {}
    if not ns.data or not ns.data.players then return names end
    local seen = {}
    for _, pdata in pairs(ns.data.players) do
        for bossName in pairs(pdata.bosses or {}) do
            if not seen[bossName] then
                seen[bossName] = true
                table.insert(names, bossName)
            end
        end
    end
    table.sort(names)
    return names
end

local function BuildBossPlayerList(bossName)
    local players = {}
    if not ns.data or not ns.data.players then return players end

    local raidAvg = ns.data.raidAverages and ns.data.raidAverages[bossName]
    local avgParse = raidAvg and raidAvg.medianParse or 0

    for key, pdata in pairs(ns.data.players) do
        local boss = pdata.bosses and pdata.bosses[bossName]
        if boss then
            table.insert(players, {
                key = key,
                name = key:match("^(.+)-") or key,
                class = pdata.class,
                spec = pdata.spec,
                medianParse = boss.medianParse,
                bestParse = boss.bestParse,
                medianDPS = boss.medianDPS,
                trend = boss.trend,
                consistency = boss.consistency,
                kills = boss.kills,
                vsAvg = boss.medianParse - avgParse,
            })
        end
    end

    -- Sort by median parse descending
    table.sort(players, function(a, b)
        return a.medianParse > b.medianParse
    end)

    return players
end

local bossDropdown = nil

local function CreateBossSelector(parent)
    if bossDropdown then
        bossDropdown:SetParent(parent)
        bossDropdown:ClearAllPoints()
        bossDropdown:SetPoint("TOPLEFT", 0, 0)
        bossDropdown:Show()
        return bossDropdown
    end

    local dd = CreateFrame("Frame", "RaidPerfBossDropdown", parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", -12, 4)

    UIDropDownMenu_SetWidth(dd, 220)
    UIDropDownMenu_SetText(dd, selectedBoss or "Select a boss...")

    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, bossName in ipairs(bossList) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = bossName
            info.checked = (bossName == selectedBoss)
            info.func = function()
                selectedBoss = bossName
                UIDropDownMenu_SetText(dd, bossName)
                local d = ns.EnsureDashboard()
                ns.RenderBossView(d)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    bossDropdown = dd
    return dd
end

local function RenderBossHeader(scrollChild)
    local headerRow = ns.GetRow(scrollChild, 1)
    headerRow.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)

    for _, col in ipairs(COLUMNS) do
        local fs = ns.SetRowColumn(headerRow, col.key, col.label, col.x, col.w, col.justify)
        fs:SetFontObject(GameFontNormalSmall)
    end
end

local function RenderRaidAverage(scrollChild, rowIdx, bossName)
    local raidAvg = ns.data and ns.data.raidAverages and ns.data.raidAverages[bossName]
    if not raidAvg then return rowIdx end

    local row = ns.GetRow(scrollChild, rowIdx)
    row.bg:SetColorTexture(0.15, 0.2, 0.15, 0.4)

    ns.SetRowColumn(row, "name", "|cff888888Raid Average|r", COLUMNS[1].x, COLUMNS[1].w, COLUMNS[1].justify)
    ns.SetRowColumn(row, "spec", "", COLUMNS[2].x, COLUMNS[2].w, COLUMNS[2].justify)

    local parseColor = ns.GetParseColorHex(raidAvg.medianParse)
    ns.SetRowColumn(row, "medianParse", parseColor .. string.format("%.0f", raidAvg.medianParse) .. "|r",
        COLUMNS[3].x, COLUMNS[3].w, COLUMNS[3].justify)
    ns.SetRowColumn(row, "bestParse", "", COLUMNS[4].x, COLUMNS[4].w, COLUMNS[4].justify)
    ns.SetRowColumn(row, "medianDPS", ns.FormatDPS(raidAvg.medianDPS),
        COLUMNS[5].x, COLUMNS[5].w, COLUMNS[5].justify)
    ns.SetRowColumn(row, "trend", "", COLUMNS[6].x, COLUMNS[6].w, COLUMNS[6].justify)
    ns.SetRowColumn(row, "vsAvg", "", COLUMNS[7].x, COLUMNS[7].w, COLUMNS[7].justify)
    ns.SetRowColumn(row, "kills", "", COLUMNS[8].x, COLUMNS[8].w, COLUMNS[8].justify)

    return rowIdx + 1
end

function ns.RenderBossView(dashboard)
    local scrollChild = dashboard.scrollChild
    local content = dashboard.content

    bossList = GetBossList()

    -- Boss selector dropdown
    CreateBossSelector(content)

    if not selectedBoss and #bossList > 0 then
        selectedBoss = bossList[1]
        UIDropDownMenu_SetText(bossDropdown, selectedBoss)
    end

    if not selectedBoss then
        ns.HideRowsFrom(scrollChild, 1)
        scrollChild:SetHeight(1)
        return
    end

    -- Offset rows below the dropdown
    -- Header
    RenderBossHeader(scrollChild)

    -- Raid average row
    local nextRow = RenderRaidAverage(scrollChild, 2, selectedBoss)

    -- Player rows
    local players = BuildBossPlayerList(selectedBoss)
    for i, p in ipairs(players) do
        local rowIdx = nextRow + i - 1
        local row = ns.GetRow(scrollChild, rowIdx)

        local nameColor = ns.GetClassColorHex(p.class)
        ns.SetRowColumn(row, "name", nameColor .. p.name .. "|r", COLUMNS[1].x, COLUMNS[1].w, COLUMNS[1].justify)
        ns.SetRowColumn(row, "spec", p.spec, COLUMNS[2].x, COLUMNS[2].w, COLUMNS[2].justify)

        local parseColor = ns.GetParseColorHex(p.medianParse)
        ns.SetRowColumn(row, "medianParse", parseColor .. string.format("%.0f", p.medianParse) .. "|r",
            COLUMNS[3].x, COLUMNS[3].w, COLUMNS[3].justify)

        local bestColor = ns.GetParseColorHex(p.bestParse)
        ns.SetRowColumn(row, "bestParse", bestColor .. string.format("%.0f", p.bestParse) .. "|r",
            COLUMNS[4].x, COLUMNS[4].w, COLUMNS[4].justify)

        ns.SetRowColumn(row, "medianDPS", ns.FormatDPS(p.medianDPS),
            COLUMNS[5].x, COLUMNS[5].w, COLUMNS[5].justify)

        local trendText = ns.GetTrendText(p.trend)
        ns.SetRowColumn(row, "trend", trendText .. " " .. string.format("%+.0f", p.trend),
            COLUMNS[6].x, COLUMNS[6].w, COLUMNS[6].justify)

        -- vs avg
        local vsColor
        if p.vsAvg >= 5 then
            vsColor = "|cff00ff00"
        elseif p.vsAvg <= -5 then
            vsColor = "|cffff4444"
        else
            vsColor = "|cffffff00"
        end
        ns.SetRowColumn(row, "vsAvg", vsColor .. string.format("%+.0f", p.vsAvg) .. "|r",
            COLUMNS[7].x, COLUMNS[7].w, COLUMNS[7].justify)

        ns.SetRowColumn(row, "kills", tostring(p.kills),
            COLUMNS[8].x, COLUMNS[8].w, COLUMNS[8].justify)

        -- Click to open player detail
        if not row.clickFrame then
            local click = CreateFrame("Button", nil, row)
            click:SetAllPoints()
            click:SetScript("OnClick", function()
                ns.ShowPlayerView(row.playerKey)
            end)
            click:SetScript("OnEnter", function()
                row.bg:SetColorTexture(0.2, 0.3, 0.4, 0.4)
            end)
            click:SetScript("OnLeave", function()
                local idx = row.rowIndex or 1
                if idx % 2 == 0 then
                    row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
                else
                    row.bg:SetColorTexture(0, 0, 0, 0)
                end
            end)
            row.clickFrame = click
        end
        row.playerKey = p.key
        row.rowIndex = rowIdx
    end

    ns.HideRowsFrom(scrollChild, nextRow + #players)
    scrollChild:SetHeight((nextRow + #players - 1) * ns.ROW_HEIGHT)
end

function ns.ShowBossView(bossName)
    if bossName and bossName ~= "" then
        -- Fuzzy match boss name
        local names = GetBossList()
        local lower = bossName:lower()
        for _, name in ipairs(names) do
            if name:lower():find(lower, 1, true) then
                selectedBoss = name
                break
            end
        end
    end

    local d = ns.EnsureDashboard()
    ns.SwitchView("boss")
    d:Show()
end
