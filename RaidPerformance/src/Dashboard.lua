local _, ns = ...

local FRAME_WIDTH = 750
local FRAME_HEIGHT = 500
local HEADER_HEIGHT = 60
local TAB_HEIGHT = 28
local ROW_HEIGHT = 22

local dashboard = nil
local currentView = "roster" -- roster, boss, player

-- Sorted player data cache
local sortedPlayers = {}
local sortColumn = "medianParse"
local sortAscending = false

local function CreateDashboard()
    local f = CreateFrame("Frame", "RaidPerformanceDashboard", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })

    -- Title bar
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("RaidPerformance")
    f.title = title

    -- Data freshness
    local freshness = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freshness:SetPoint("TOPRIGHT", -40, -20)
    freshness:SetTextColor(0.7, 0.7, 0.7)
    f.freshness = freshness

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    -- Tab buttons
    local tabY = -(HEADER_HEIGHT)
    local tabs = {}
    local tabNames = {
        { key = "roster", label = "Roster Overview" },
        { key = "boss",   label = "Boss Detail" },
        { key = "player", label = "Player Detail" },
    }

    for i, info in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, f)
        tab:SetSize(120, TAB_HEIGHT)
        if i == 1 then
            tab:SetPoint("TOPLEFT", 12, tabY)
        else
            tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 4, 0)
        end

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        tab.bg = bg

        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        text:SetText(info.label)
        tab.text = text

        tab:SetScript("OnClick", function()
            ns.SwitchView(info.key)
        end)
        tab:SetScript("OnEnter", function(self)
            if currentView ~= info.key then
                self.bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            end
        end)
        tab:SetScript("OnLeave", function(self)
            if currentView ~= info.key then
                self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            end
        end)

        tabs[i] = tab
        tabs[info.key] = tab
    end
    f.tabs = tabs

    -- Content area
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 12, tabY - TAB_HEIGHT - 4)
    content:SetPoint("BOTTOMRIGHT", -12, 12)
    f.content = content

    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 0)
    f.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(content:GetWidth() - 24)
    scrollChild:SetHeight(1) -- will be set dynamically
    scrollFrame:SetScrollChild(scrollChild)
    f.scrollChild = scrollChild

    -- Row pool
    f.rows = {}

    f:Hide()
    return f
end

local function UpdateTabHighlights()
    for _, info in ipairs({ "roster", "boss", "player" }) do
        local tab = dashboard.tabs[info]
        if tab then
            if currentView == info then
                tab.bg:SetColorTexture(0.1, 0.4, 0.6, 0.9)
            else
                tab.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            end
        end
    end
end

local function UpdateFreshness()
    if not ns.data then
        dashboard.freshness:SetText("No data")
        return
    end
    local age = time() - (ns.data.generatedAt or 0)
    local ageDays = math.floor(age / 86400)
    local text
    if ageDays == 0 then
        text = "Data from today"
    elseif ageDays == 1 then
        text = "Data from yesterday"
    else
        text = "Data from " .. ageDays .. "d ago"
    end
    if ageDays > 7 then
        text = "|cffff4444" .. text .. " (stale!)|r"
    end
    dashboard.freshness:SetText(text)
end

function ns.EnsureDashboard()
    if not dashboard then
        dashboard = CreateDashboard()
    end
    return dashboard
end

function ns.ToggleDashboard()
    local d = ns.EnsureDashboard()
    if d:IsShown() then
        d:Hide()
    else
        UpdateFreshness()
        if currentView == "roster" then
            ns.ShowRosterView()
        else
            ns.SwitchView(currentView)
        end
        d:Show()
    end
end

function ns.SwitchView(view)
    currentView = view
    local d = ns.EnsureDashboard()
    UpdateTabHighlights()
    UpdateFreshness()

    if view == "roster" then
        ns.RenderRosterView(d)
    elseif view == "boss" then
        ns.RenderBossView(d)
    elseif view == "player" then
        ns.RenderPlayerView(d)
    end
end

-- Utility: get or create a row frame
function ns.GetRow(parent, index)
    if not parent.rows then parent.rows = {} end
    if parent.rows[index] then
        parent.rows[index]:Show()
        return parent.rows[index]
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT")

    -- Alternating background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
    else
        bg:SetColorTexture(0, 0, 0, 0)
    end
    row.bg = bg

    -- Columns are created by each view as needed
    row.columns = {}
    parent.rows[index] = row
    return row
end

-- Utility: hide all rows from startIndex onwards
function ns.HideRowsFrom(parent, startIndex)
    if not parent.rows then return end
    for i = startIndex, #parent.rows do
        if parent.rows[i] then
            parent.rows[i]:Hide()
        end
    end
end

-- Utility: add or reuse a column FontString on a row
function ns.SetRowColumn(row, colIndex, text, xOffset, width, justifyH)
    if not row.columns[colIndex] then
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.columns[colIndex] = fs
    end
    local fs = row.columns[colIndex]
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", xOffset, 0)
    if width then
        fs:SetWidth(width)
    end
    fs:SetJustifyH(justifyH or "LEFT")
    fs:SetText(text)
    fs:Show()
    return fs
end

-- Expose constants for views
ns.ROW_HEIGHT = ROW_HEIGHT
ns.FRAME_WIDTH = FRAME_WIDTH

-- Sort helpers
function ns.GetSortedPlayers()
    return sortedPlayers
end

function ns.SetSortedPlayers(players)
    sortedPlayers = players
end

function ns.GetSortColumn()
    return sortColumn, sortAscending
end

function ns.SetSortColumn(col)
    if sortColumn == col then
        sortAscending = not sortAscending
    else
        sortColumn = col
        sortAscending = false
    end
end
