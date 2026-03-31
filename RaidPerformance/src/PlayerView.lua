local _, ns = ...

local selectedPlayer = nil

-- Column layout for player view (per-boss rows)
local COLUMNS = {
    { key = "boss",       label = "Boss",       x = 4,   w = 180, justify = "LEFT" },
    { key = "medianParse",label = "Median",     x = 190, w = 55,  justify = "RIGHT" },
    { key = "bestParse",  label = "Best",       x = 250, w = 50,  justify = "RIGHT" },
    { key = "medianDPS",  label = "Med DPS",    x = 305, w = 65,  justify = "RIGHT" },
    { key = "bestDPS",    label = "Best DPS",   x = 375, w = 65,  justify = "RIGHT" },
    { key = "trend",      label = "Trend",      x = 445, w = 50,  justify = "CENTER" },
    { key = "vsAvg",      label = "vs Avg",     x = 500, w = 50,  justify = "RIGHT" },
    { key = "kills",      label = "Kills",      x = 555, w = 40,  justify = "RIGHT" },
}

local function RenderPlayerHeader(scrollChild, playerKey, pdata)
    -- Player info header (row 1)
    local infoRow = ns.GetRow(scrollChild, 1)
    infoRow.bg:SetColorTexture(0.1, 0.15, 0.2, 0.6)
    infoRow:SetHeight(28)

    local nameColor = ns.GetClassColorHex(pdata.class)
    local name = playerKey:match("^(.+)-") or playerKey
    local parseColor = ns.GetParseColorHex(pdata.overall.medianParse)

    local headerText = string.format(
        "%s%s|r  %s  ilvl %d  |  Overall: %s%.0f|r median  %s  %s",
        nameColor, name,
        pdata.spec,
        pdata.ilvl,
        parseColor, pdata.overall.medianParse,
        ns.GetTrendText(pdata.overall.trend),
        ns.GetConsistencyText(pdata.overall.consistency)
    )
    ns.SetRowColumn(infoRow, "info", headerText, 4, 700, "LEFT")

    -- Column headers (row 2)
    local headerRow = ns.GetRow(scrollChild, 2)
    headerRow.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)
    for _, col in ipairs(COLUMNS) do
        local fs = ns.SetRowColumn(headerRow, col.key, col.label, col.x, col.w, col.justify)
        fs:SetFontObject(GameFontNormalSmall)
    end
end

local function BuildPlayerBossList(pdata)
    local bosses = {}
    if not pdata or not pdata.bosses then return bosses end

    local raidAvg = ns.data and ns.data.raidAverages or {}

    for bossName, boss in pairs(pdata.bosses) do
        local avg = raidAvg[bossName]
        local vsAvg = avg and (boss.medianParse - avg.medianParse) or 0

        table.insert(bosses, {
            name = bossName,
            medianParse = boss.medianParse,
            bestParse = boss.bestParse,
            medianDPS = boss.medianDPS,
            bestDPS = boss.bestDPS,
            trend = boss.trend,
            consistency = boss.consistency,
            kills = boss.kills,
            vsAvg = vsAvg,
            recentParses = boss.recentParses,
        })
    end

    -- Sort by median parse descending
    table.sort(bosses, function(a, b)
        return a.medianParse > b.medianParse
    end)

    return bosses
end

local function RenderRecentParses(scrollChild, startRow, recentParses)
    if not recentParses or #recentParses == 0 then return startRow end

    -- Sub-header
    local subHeader = ns.GetRow(scrollChild, startRow)
    subHeader.bg:SetColorTexture(0.08, 0.08, 0.15, 0.4)
    ns.SetRowColumn(subHeader, "info", "    |cff888888Recent: ", 4, 700, "LEFT")

    -- Build recent parses as inline text
    local parts = {}
    for i, rp in ipairs(recentParses) do
        if i > 5 then break end -- show last 5
        local color = ns.GetParseColorHex(rp.parse)
        table.insert(parts, color .. string.format("%.0f", rp.parse) .. "|r")
    end

    ns.SetRowColumn(subHeader, "info",
        "    |cff888888Recent:|r " .. table.concat(parts, "  "),
        4, 700, "LEFT")

    return startRow + 1
end

function ns.RenderPlayerView(dashboard)
    local scrollChild = dashboard.scrollChild

    if not selectedPlayer or not ns.data or not ns.data.players then
        ns.HideRowsFrom(scrollChild, 1)
        scrollChild:SetHeight(1)
        return
    end

    local pdata = ns.data.players[selectedPlayer]
    if not pdata then
        -- Try fuzzy match
        local lower = selectedPlayer:lower()
        for key, pd in pairs(ns.data.players) do
            if key:lower():find(lower, 1, true) then
                selectedPlayer = key
                pdata = pd
                break
            end
        end
    end

    if not pdata then
        ns.HideRowsFrom(scrollChild, 1)
        local row = ns.GetRow(scrollChild, 1)
        ns.SetRowColumn(row, "info", "Player not found: " .. selectedPlayer, 4, 700, "LEFT")
        scrollChild:SetHeight(ns.ROW_HEIGHT)
        return
    end

    -- Header rows
    RenderPlayerHeader(scrollChild, selectedPlayer, pdata)

    -- Boss rows
    local bosses = BuildPlayerBossList(pdata)
    local nextRow = 3

    for _, boss in ipairs(bosses) do
        local row = ns.GetRow(scrollChild, nextRow)

        ns.SetRowColumn(row, "boss", boss.name, COLUMNS[1].x, COLUMNS[1].w, COLUMNS[1].justify)

        local parseColor = ns.GetParseColorHex(boss.medianParse)
        ns.SetRowColumn(row, "medianParse", parseColor .. string.format("%.0f", boss.medianParse) .. "|r",
            COLUMNS[2].x, COLUMNS[2].w, COLUMNS[2].justify)

        local bestColor = ns.GetParseColorHex(boss.bestParse)
        ns.SetRowColumn(row, "bestParse", bestColor .. string.format("%.0f", boss.bestParse) .. "|r",
            COLUMNS[3].x, COLUMNS[3].w, COLUMNS[3].justify)

        ns.SetRowColumn(row, "medianDPS", ns.FormatDPS(boss.medianDPS),
            COLUMNS[4].x, COLUMNS[4].w, COLUMNS[4].justify)

        ns.SetRowColumn(row, "bestDPS", ns.FormatDPS(boss.bestDPS),
            COLUMNS[5].x, COLUMNS[5].w, COLUMNS[5].justify)

        local trendText = ns.GetTrendText(boss.trend)
        ns.SetRowColumn(row, "trend", trendText .. " " .. string.format("%+.0f", boss.trend),
            COLUMNS[6].x, COLUMNS[6].w, COLUMNS[6].justify)

        local vsColor
        if boss.vsAvg >= 5 then
            vsColor = "|cff00ff00"
        elseif boss.vsAvg <= -5 then
            vsColor = "|cffff4444"
        else
            vsColor = "|cffffff00"
        end
        ns.SetRowColumn(row, "vsAvg", vsColor .. string.format("%+.0f", boss.vsAvg) .. "|r",
            COLUMNS[7].x, COLUMNS[7].w, COLUMNS[7].justify)

        ns.SetRowColumn(row, "kills", tostring(boss.kills),
            COLUMNS[8].x, COLUMNS[8].w, COLUMNS[8].justify)

        nextRow = nextRow + 1

        -- Recent parses inline
        nextRow = RenderRecentParses(scrollChild, nextRow, boss.recentParses)
    end

    ns.HideRowsFrom(scrollChild, nextRow)
    scrollChild:SetHeight((nextRow - 1) * ns.ROW_HEIGHT)
end

function ns.ShowPlayerView(playerKey)
    if playerKey and playerKey ~= "" then
        selectedPlayer = playerKey
    end

    local d = ns.EnsureDashboard()
    ns.SwitchView("player")
    d:Show()
end
