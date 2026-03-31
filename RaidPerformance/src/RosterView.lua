local _, ns = ...

-- Column layout: Name(160) | Spec(90) | ilvl(45) | Median(60) | Best(50) | Trend(50) | Consistency(70) | Bosses(50)
local COLUMNS = {
    { key = "name",        label = "Name",        x = 4,   w = 155, justify = "LEFT" },
    { key = "spec",        label = "Spec",        x = 160, w = 85,  justify = "LEFT" },
    { key = "ilvl",        label = "ilvl",        x = 250, w = 45,  justify = "RIGHT" },
    { key = "medianParse", label = "Median",      x = 300, w = 55,  justify = "RIGHT" },
    { key = "bestParse",   label = "Best",        x = 360, w = 50,  justify = "RIGHT" },
    { key = "trend",       label = "Trend",       x = 415, w = 50,  justify = "CENTER" },
    { key = "consistency", label = "Consistency",  x = 470, w = 70,  justify = "CENTER" },
    { key = "bosses",      label = "Bosses",      x = 545, w = 50,  justify = "RIGHT" },
}

local function BuildSortedPlayerList()
    local players = {}
    if not ns.data or not ns.data.players then return players end

    for key, pdata in pairs(ns.data.players) do
        local bossCount = 0
        for _ in pairs(pdata.bosses or {}) do
            bossCount = bossCount + 1
        end
        table.insert(players, {
            key = key,
            name = key:match("^(.+)-") or key,
            realm = key:match("-(.+)$") or "",
            class = pdata.class,
            spec = pdata.spec,
            ilvl = pdata.ilvl,
            medianParse = pdata.overall.medianParse,
            bestParse = 0, -- computed below
            trend = pdata.overall.trend,
            consistency = pdata.overall.consistency,
            bossCount = bossCount,
        })
        -- Compute best parse across all bosses
        local best = 0
        for _, boss in pairs(pdata.bosses or {}) do
            if boss.bestParse > best then
                best = boss.bestParse
            end
        end
        players[#players].bestParse = best
    end

    local sortCol = ns.GetSortColumn()
    local _, asc = ns.GetSortColumn()
    table.sort(players, function(a, b)
        local va, vb
        if sortCol == "name" then
            va, vb = a.name:lower(), b.name:lower()
        elseif sortCol == "bosses" then
            va, vb = a.bossCount, b.bossCount
        else
            va, vb = a[sortCol] or 0, b[sortCol] or 0
        end
        if asc then
            return va < vb
        else
            return va > vb
        end
    end)

    return players
end

local function RenderHeader(scrollChild)
    local headerRow = ns.GetRow(scrollChild, 1)
    headerRow.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)

    for _, col in ipairs(COLUMNS) do
        local sortCol = ns.GetSortColumn()
        local label = col.label
        if sortCol == col.key then
            local _, asc = ns.GetSortColumn()
            label = label .. (asc and " ^" or " v")
        end
        local fs = ns.SetRowColumn(headerRow, col.key, label, col.x, col.w, col.justify)
        fs:SetFontObject(GameFontNormalSmall)
    end

    -- Make header columns clickable for sorting
    if not headerRow.clickFrame then
        local click = CreateFrame("Button", nil, headerRow)
        click:SetAllPoints()
        click:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            local cursorX = GetCursorPosition()
            local scale = headerRow:GetEffectiveScale()
            local frameLeft = headerRow:GetLeft()
            local relX = cursorX / scale - frameLeft

            for _, col in ipairs(COLUMNS) do
                if relX >= col.x and relX <= col.x + col.w then
                    ns.SetSortColumn(col.key)
                    local d = ns.EnsureDashboard()
                    ns.RenderRosterView(d)
                    break
                end
            end
        end)
        headerRow.clickFrame = click
    end
end

function ns.RenderRosterView(dashboard)
    local scrollChild = dashboard.scrollChild

    local players = BuildSortedPlayerList()
    ns.SetSortedPlayers(players)

    -- Header row
    RenderHeader(scrollChild)

    -- Player rows
    for i, p in ipairs(players) do
        local rowIdx = i + 1 -- offset by header
        local row = ns.GetRow(scrollChild, rowIdx)

        -- Name (class-colored)
        local nameColor = ns.GetClassColorHex(p.class)
        ns.SetRowColumn(row, "name", nameColor .. p.name .. "|r", COLUMNS[1].x, COLUMNS[1].w, COLUMNS[1].justify)

        -- Spec
        ns.SetRowColumn(row, "spec", p.spec, COLUMNS[2].x, COLUMNS[2].w, COLUMNS[2].justify)

        -- ilvl
        ns.SetRowColumn(row, "ilvl", tostring(p.ilvl), COLUMNS[3].x, COLUMNS[3].w, COLUMNS[3].justify)

        -- Median parse (color-coded)
        local parseColor = ns.GetParseColorHex(p.medianParse)
        ns.SetRowColumn(row, "medianParse", parseColor .. string.format("%.0f", p.medianParse) .. "|r",
            COLUMNS[4].x, COLUMNS[4].w, COLUMNS[4].justify)

        -- Best parse (color-coded)
        local bestColor = ns.GetParseColorHex(p.bestParse)
        ns.SetRowColumn(row, "bestParse", bestColor .. string.format("%.0f", p.bestParse) .. "|r",
            COLUMNS[5].x, COLUMNS[5].w, COLUMNS[5].justify)

        -- Trend
        local trendText = ns.GetTrendText(p.trend)
        local trendVal = string.format("%+.0f", p.trend)
        ns.SetRowColumn(row, "trend", trendText .. " " .. trendVal,
            COLUMNS[6].x, COLUMNS[6].w, COLUMNS[6].justify)

        -- Consistency
        ns.SetRowColumn(row, "consistency", ns.GetConsistencyText(p.consistency),
            COLUMNS[7].x, COLUMNS[7].w, COLUMNS[7].justify)

        -- Boss count
        ns.SetRowColumn(row, "bosses", tostring(p.bossCount),
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

    -- Hide unused rows
    ns.HideRowsFrom(scrollChild, #players + 2)

    -- Set scroll child height
    scrollChild:SetHeight((#players + 1) * ns.ROW_HEIGHT)
end

function ns.ShowRosterView()
    local d = ns.EnsureDashboard()
    ns.SwitchView("roster")
    d:Show()
end
