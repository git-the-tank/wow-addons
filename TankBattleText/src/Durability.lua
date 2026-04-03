local _, ns = ...

local DUR_GREEN  = { 0.15, 0.75, 0.15 }
local DUR_YELLOW = { 1.0,  0.85, 0.0  }
local DUR_RED    = { 0.85, 0.15, 0.15 }
local DUR_PURPLE = { 0.55, 0.10, 0.85 }

-- Equipment slots that can have durability
local DUR_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }

local DEFAULTS = {
    showDurability     = true,
    durabilitySize     = 40,
    durabilityFontSize = 12,
}
ns.DURABILITY_DEFAULTS = DEFAULTS

local durFrame = CreateFrame("Frame", "TankBattleTextDurabilityFrame", UIParent)
durFrame:SetSize(DEFAULTS.durabilitySize, DEFAULTS.durabilitySize)
durFrame:SetPoint("CENTER", UIParent, "CENTER", 200, -100)

local bg = durFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(DUR_GREEN[1], DUR_GREEN[2], DUR_GREEN[3], 1)

local label = durFrame:CreateFontString(nil, "OVERLAY")
label:SetAllPoints()
label:SetJustifyH("CENTER")
label:SetJustifyV("MIDDLE")
label:SetFont(GameFontNormal:GetFont(), DEFAULTS.durabilityFontSize, "OUTLINE")
label:SetTextColor(1, 1, 1)
label:SetText("--")

local function GetLowestDurability()
    local lowest = nil
    for _, slot in ipairs(DUR_SLOTS) do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local pct = cur / max * 100
            if lowest == nil or pct < lowest then
                lowest = pct
            end
        end
    end
    return lowest
end

local function DurabilityColor(pct)
    if pct <= 0 then return DUR_PURPLE
    elseif pct < 25 then return DUR_RED
    elseif pct < 50 then return DUR_YELLOW
    else return DUR_GREEN
    end
end

function ns.UpdateDurability()
    if not ns.enabled then return end
    if not ns.db or ns.db.showDurability == false then
        durFrame:Hide()
        return
    end

    local pct = GetLowestDurability()
    if pct == nil then
        bg:SetColorTexture(DUR_GREEN[1], DUR_GREEN[2], DUR_GREEN[3], 1)
        label:SetText("--")
    else
        local c = DurabilityColor(pct)
        bg:SetColorTexture(c[1], c[2], c[3], 1)
        label:SetText(format("%d%%", math.floor(pct + 0.5)))
    end
    durFrame:Show()
end

function ns.ApplyDurabilityFont(path, size, outline)
    local face = ns.db and ns.db.durabilityFontFace
    local sz   = ns.db and ns.db.durabilityFontSize
    if face then path = ns.FindFontPath(face) end
    if sz   then size = sz end
    if outline == "NONE" then outline = "" end
    label:SetFont(path, size, outline)
end

function ns.ApplyDurabilitySize(size)
    durFrame:SetSize(size, size)
end

function ns.ShowDurabilityPreview()
    if not ns.db or ns.db.showDurability == false then
        durFrame:Hide()
        return
    end
    ns.ApplyDurabilitySize(ns.db.durabilitySize or DEFAULTS.durabilitySize)
    bg:SetColorTexture(DUR_YELLOW[1], DUR_YELLOW[2], DUR_YELLOW[3], 1)
    label:SetText("47%")
    durFrame:Show()
end

function ns.HideDurabilityPreview()
    ns.UpdateDurability()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
eventFrame:SetScript("OnEvent", function()
    ns.UpdateDurability()
end)
