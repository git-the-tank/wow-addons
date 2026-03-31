local _, ns = ...

function ns.InitTooltip()
    if not ns.db or not ns.db.tooltipEnabled then return end

    -- Hook GameTooltip to add parse info when hovering raid members
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
        if tooltip ~= GameTooltip then return end
        if not ns.data or not ns.data.players then return end

        local _, unit = tooltip:GetUnit()
        if not unit then return end

        -- Only show for group members
        if not UnitInRaid(unit) and not UnitInParty(unit) then return end
        if not UnitIsPlayer(unit) then return end

        local name, realm = UnitName(unit)
        if not name then return end
        if not realm or realm == "" then
            realm = GetNormalizedRealmName()
        end

        local key = name .. "-" .. realm
        local pdata = ns.data.players[key]
        if not pdata then
            -- Try without realm for same-server players
            for k, pd in pairs(ns.data.players) do
                if k:match("^(.+)-") == name then
                    pdata = pd
                    break
                end
            end
        end

        if not pdata then return end

        local parseColor = ns.GetParseColorHex(pdata.overall.medianParse)
        local trendText = ns.GetTrendText(pdata.overall.trend)

        -- Count bosses
        local bossCount = 0
        for _ in pairs(pdata.bosses or {}) do
            bossCount = bossCount + 1
        end

        tooltip:AddLine(" ")
        tooltip:AddLine(
            string.format("RaidPerf: %s%.0f|r median  %s  %d bosses  %s",
                parseColor, pdata.overall.medianParse,
                trendText,
                bossCount,
                ns.GetConsistencyText(pdata.overall.consistency)
            ),
            1, 1, 1
        )
    end)
end
