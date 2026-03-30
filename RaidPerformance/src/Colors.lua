local _, ns = ...

-- WCL parse percentile color brackets
-- gray < 25, green < 50, blue < 75, purple < 95, orange < 99, pink >= 99
ns.PARSE_COLORS = {
    { threshold = 0,  r = 0.62, g = 0.62, b = 0.62 }, -- gray
    { threshold = 25, r = 0.12, g = 1.00, b = 0.00 }, -- green
    { threshold = 50, r = 0.00, g = 0.44, b = 1.00 }, -- blue
    { threshold = 75, r = 0.64, g = 0.21, b = 0.93 }, -- purple
    { threshold = 95, r = 1.00, g = 0.50, b = 0.00 }, -- orange
    { threshold = 99, r = 0.89, g = 0.56, b = 0.76 }, -- pink
}

function ns.GetParseColor(percentile)
    local color = ns.PARSE_COLORS[1]
    for _, c in ipairs(ns.PARSE_COLORS) do
        if percentile >= c.threshold then
            color = c
        end
    end
    return color.r, color.g, color.b
end

function ns.GetParseColorHex(percentile)
    local r, g, b = ns.GetParseColor(percentile)
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- Trend indicator text
function ns.GetTrendText(trend)
    if trend > 3 then
        return "|cff00ff00+|r"  -- green up
    elseif trend < -3 then
        return "|cffff0000-|r"  -- red down
    else
        return "|cffffff00=|r"  -- yellow stable
    end
end

-- Class colors from RAID_CLASS_COLORS
function ns.GetClassColor(class)
    local color = RAID_CLASS_COLORS[class]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

function ns.GetClassColorHex(class)
    local r, g, b = ns.GetClassColor(class)
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- Format large numbers (e.g. 450000 -> "450k")
function ns.FormatDPS(dps)
    if dps >= 1000000 then
        return string.format("%.1fM", dps / 1000000)
    elseif dps >= 1000 then
        return string.format("%.0fk", dps / 1000)
    else
        return tostring(dps)
    end
end

-- Format consistency (std dev) as a descriptor
function ns.GetConsistencyText(stddev)
    if stddev <= 5 then
        return "|cff00ff00steady|r"
    elseif stddev <= 12 then
        return "|cffffff00variable|r"
    else
        return "|cffff4444volatile|r"
    end
end
