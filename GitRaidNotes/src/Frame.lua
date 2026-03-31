local _, ns = ...

------------------------------------------------------------
-- Constants
------------------------------------------------------------
local HEADER_HEIGHT = 24
local TAB_HEIGHT = 20
local CONTENT_PADDING = 8
local LINE_SPACING = 3
local MAX_LINES = 50
local MAX_CONTENT_HEIGHT = 380
local MIN_WIDTH = 250
local MAX_WIDTH = 600
local MIN_HEIGHT = 120

-- Keyword -> color mapping (matched against first word of each line)
local KEYWORD_COLORS = {
    SWAP = { 1.0, 0.53, 0.0 },     -- orange
    POS  = { 0.0, 0.8, 1.0 },      -- cyan
    DEF  = { 1.0, 0.27, 0.27 },    -- red
    ADDS = { 0.27, 1.0, 0.27 },    -- green
    MOVE = { 1.0, 1.0, 0.0 },      -- yellow
    CALL = { 1.0, 1.0, 1.0 },      -- white
    HERO = { 1.0, 1.0, 0.0 },      -- yellow
}
-- Special prefix match
local MYTHIC_COLOR = { 0.8, 0.27, 1.0 }
local CONTINUATION_COLOR = { 0.6, 0.6, 0.6 }

local DIFF_COLORS = {
    normal  = { 0.27, 1.0, 0.27 },
    heroic  = { 0.8, 0.27, 1.0 },
    mythic  = { 1.0, 0.53, 0.0 },
}

local DIFF_LABELS = {
    normal  = "N",
    heroic  = "H",
    mythic  = "M",
}

local TAB_KEYS = { "tank", "calls", "notes" }
local TAB_LABELS = { tank = "TANK", calls = "CALLS", notes = "NOTES" }

------------------------------------------------------------
-- Locals
------------------------------------------------------------
local frame, headerBar, bossLabel, diffBadge
local tabButtons = {}
local linePool = {}
local scrollFrame, scrollChild

------------------------------------------------------------
-- Line Color Resolution
------------------------------------------------------------
local function GetLineColor(text)
    -- Mythic-only lines
    if text:match("^%[M%]") then return MYTHIC_COLOR end
    -- Keyword match: first word
    local firstWord = text:match("^(%S+)")
    if firstWord and KEYWORD_COLORS[firstWord] then
        return KEYWORD_COLORS[firstWord]
    end
    -- Continuation / unmarked
    return CONTINUATION_COLOR
end

------------------------------------------------------------
-- Navigation
------------------------------------------------------------
function ns.NextBoss()
    if not ns.db or not ns.BOSSES then return end
    ns.db.currentBoss = (ns.db.currentBoss % #ns.BOSSES) + 1
    ns.RefreshContent()
end

function ns.PrevBoss()
    if not ns.db or not ns.BOSSES then return end
    ns.db.currentBoss = ns.db.currentBoss - 1
    if ns.db.currentBoss < 1 then ns.db.currentBoss = #ns.BOSSES end
    ns.RefreshContent()
end

local function SetTab(tabKey)
    if not ns.db then return end
    ns.db.currentTab = tabKey
    for _, key in ipairs(TAB_KEYS) do
        local btn = tabButtons[key]
        if btn then
            if key == tabKey then
                btn.bg:SetColorTexture(0, 0.5, 0.8, 0.6)
            else
                btn.bg:SetColorTexture(0.3, 0.3, 0.3, 0.5)
            end
        end
    end
    ns.RefreshContent()
end

------------------------------------------------------------
-- Content Rendering
------------------------------------------------------------
local function EnsureLines(count)
    local fontSize = ns.db and ns.db.fontSize or ns.CONFIG.fontSize
    local fontPath = "Fonts\\FRIZQT__.TTF"

    for i = #linePool + 1, count do
        local fs = scrollChild:CreateFontString(nil, "OVERLAY")
        fs:SetFont(fontPath, fontSize, "")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetWidth(scrollChild:GetWidth() - 4)
        fs:Hide()
        linePool[i] = fs
    end
end

local function RenderContent(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end

    EnsureLines(math.max(#lines, MAX_LINES))

    local fontSize = ns.db and ns.db.fontSize or ns.CONFIG.fontSize
    local lineHeight = fontSize + LINE_SPACING
    local contentWidth = scrollChild:GetWidth() - 4
    local totalHeight = 0

    for i, fs in ipairs(linePool) do
        if i <= #lines then
            local line = lines[i]
            fs:SetWidth(contentWidth)
            if line == "" then
                fs:SetText(" ")
                fs:SetTextColor(0.6, 0.6, 0.6)
            else
                fs:SetText(line)
                local color = GetLineColor(line)
                fs:SetTextColor(color[1], color[2], color[3])
            end
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", 2, -totalHeight)
            -- Measure actual height for wrapped lines
            local h = math.max(fs:GetStringHeight(), lineHeight)
            totalHeight = totalHeight + h
            fs:Show()
        else
            fs:Hide()
        end
    end

    scrollChild:SetHeight(math.max(totalHeight + CONTENT_PADDING, 1))
end

function ns.RefreshContent()
    if not frame or not ns.db or not ns.BOSSES then return end

    local bossIdx = ns.db.currentBoss
    local boss = ns.BOSSES[bossIdx]
    if not boss then return end

    -- Update header
    bossLabel:SetText(boss.short)

    -- Difficulty badge
    local diff = ns.currentDifficulty or ns.db.manualDifficulty or "heroic"
    local diffColor = DIFF_COLORS[diff] or DIFF_COLORS.heroic
    local diffLabel = DIFF_LABELS[diff] or "H"
    diffBadge:SetText(diffLabel)
    diffBadge:SetTextColor(diffColor[1], diffColor[2], diffColor[3])

    -- Tab highlight
    for _, key in ipairs(TAB_KEYS) do
        local btn = tabButtons[key]
        if btn then
            if key == ns.db.currentTab then
                btn.bg:SetColorTexture(0, 0.5, 0.8, 0.6)
            else
                btn.bg:SetColorTexture(0.3, 0.3, 0.3, 0.5)
            end
        end
    end

    -- Render note content
    local text = ns.GetNoteContent(boss.key, ns.db.currentTab, diff)
    RenderContent(text)

    -- Update line widths for new frame width
    local contentWidth = frame:GetWidth() - CONTENT_PADDING * 2 - 18
    scrollChild:SetWidth(contentWidth)
    for _, fs in ipairs(linePool) do
        fs:SetWidth(contentWidth - 4)
    end
end

------------------------------------------------------------
-- Lock / Click-Through
------------------------------------------------------------
function ns.ApplyLock()
    if not frame or not ns.db then return end
    if ns.db.locked then
        frame:EnableMouse(false)
    else
        frame:EnableMouse(true)
    end
end

------------------------------------------------------------
-- Frame Construction
------------------------------------------------------------
local function CreateMainFrame()
    if frame then return end

    local width = ns.db and ns.db.frameWidth or ns.CONFIG.frameWidth
    local alpha = ns.db and ns.db.frameAlpha or ns.CONFIG.frameAlpha

    frame = CreateFrame("Frame", "GitRaidNotesFrame", UIParent, "BackdropTemplate")
    ns.frame = frame
    frame:SetSize(width, 200) -- height adjusts to content
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, 600)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, alpha)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    --------------------------------------------------------
    -- Header Bar (drag region)
    --------------------------------------------------------
    headerBar = CreateFrame("Frame", nil, frame)
    headerBar:SetPoint("TOPLEFT", 0, 0)
    headerBar:SetPoint("TOPRIGHT", 0, 0)
    headerBar:SetHeight(HEADER_HEIGHT)
    headerBar:EnableMouse(true)
    headerBar:RegisterForDrag("LeftButton")
    headerBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    headerBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if ns.db then
            local point, _, _, x, y = frame:GetPoint()
            ns.db.pos = { point = point, x = x, y = y }
        end
    end)

    -- Prev button
    local prevBtn = CreateFrame("Button", nil, headerBar)
    prevBtn:SetSize(20, HEADER_HEIGHT)
    prevBtn:SetPoint("LEFT", 4, 0)
    local prevText = prevBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    prevText:SetPoint("CENTER")
    prevText:SetText("<")
    prevBtn:SetScript("OnClick", function() ns.PrevBoss() end)

    -- Next button
    local nextBtn = CreateFrame("Button", nil, headerBar)
    nextBtn:SetSize(20, HEADER_HEIGHT)
    nextBtn:SetPoint("RIGHT", -60, 0)
    local nextText = nextBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nextText:SetPoint("CENTER")
    nextText:SetText(">")
    nextBtn:SetScript("OnClick", function() ns.NextBoss() end)

    -- Boss name
    bossLabel = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossLabel:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
    bossLabel:SetPoint("RIGHT", nextBtn, "LEFT", -4, 0)
    bossLabel:SetJustifyH("LEFT")
    bossLabel:SetText("Boss")

    -- Difficulty badge (clickable to cycle when outside instance)
    local diffFrame = CreateFrame("Button", nil, headerBar)
    diffFrame:SetSize(20, HEADER_HEIGHT)
    diffFrame:SetPoint("RIGHT", nextBtn, "LEFT", -4, 0)
    diffBadge = diffFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    diffBadge:SetPoint("CENTER")
    diffBadge:SetText("H")
    diffFrame:SetScript("OnClick", function()
        if not ns.currentDifficulty and ns.db then
            local order = { "normal", "heroic", "mythic" }
            local cur = ns.db.manualDifficulty or "heroic"
            for i, d in ipairs(order) do
                if d == cur then
                    ns.db.manualDifficulty = order[(i % #order) + 1]
                    break
                end
            end
            ns.RefreshContent()
        end
    end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, headerBar, "UIPanelCloseButtonNoScripts")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeBtn:SetSize(18, 18)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Edit button
    local editBtn = CreateFrame("Button", nil, headerBar)
    editBtn:SetSize(20, 18)
    editBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    local editText = editBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editText:SetPoint("CENTER")
    editText:SetText("E")
    editBtn:SetScript("OnClick", function()
        if ns.OpenEditor then ns.OpenEditor() end
    end)

    --------------------------------------------------------
    -- Tab Bar
    --------------------------------------------------------
    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", 4, -HEADER_HEIGHT)
    tabBar:SetPoint("TOPRIGHT", -4, -HEADER_HEIGHT)
    tabBar:SetHeight(TAB_HEIGHT)

    local tabAnchor = tabBar
    for i, key in ipairs(TAB_KEYS) do
        local btn = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        btn:SetHeight(TAB_HEIGHT - 2)

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER", 0, 0)
        label:SetText(TAB_LABELS[key])
        btn._label = label

        local textWidth = label:GetStringWidth() + 16
        btn:SetWidth(textWidth)

        if i == 1 then
            btn:SetPoint("LEFT", tabBar, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", tabAnchor, "RIGHT", 2, 0)
        end
        tabAnchor = btn

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        btn.bg = bg

        btn:SetScript("OnClick", function() SetTab(key) end)
        tabButtons[key] = btn
    end

    --------------------------------------------------------
    -- Content Area (ScrollFrame)
    --------------------------------------------------------
    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", CONTENT_PADDING, -(HEADER_HEIGHT + TAB_HEIGHT + 4))
    scrollFrame:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING - 18, CONTENT_PADDING + 12)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or (width - CONTENT_PADDING * 2 - 18))
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    --------------------------------------------------------
    -- Resize grip (bottom-right corner)
    --------------------------------------------------------
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeGrip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if ns.db then
            ns.db.frameWidth = math.floor(frame:GetWidth() + 0.5)
        end
        -- Reflow content for new width
        local cw = frame:GetWidth() - CONTENT_PADDING * 2 - 18
        scrollChild:SetWidth(cw)
        for _, fs in ipairs(linePool) do
            fs:SetWidth(cw - 4)
        end
        ns.RefreshContent()
    end)

    -- Adjust scroll child width on resize
    frame:SetScript("OnSizeChanged", function(_, w)
        local cw = w - CONTENT_PADDING * 2 - 18
        scrollChild:SetWidth(cw)
        for _, fs in ipairs(linePool) do
            fs:SetWidth(cw - 4)
        end
    end)

    --------------------------------------------------------
    -- Auto-size height based on content
    --------------------------------------------------------
    scrollChild:SetScript("OnSizeChanged", function(_, _, h)
        -- Only auto-size if not actively resizing
        if frame._userResizing then return end
        local targetH = HEADER_HEIGHT + TAB_HEIGHT + 4 + math.min(h, MAX_CONTENT_HEIGHT) + CONTENT_PADDING + 16
        targetH = math.max(targetH, MIN_HEIGHT)
        frame:SetHeight(targetH)

        local scrollBar = scrollFrame.ScrollBar
        if scrollBar then
            if h > MAX_CONTENT_HEIGHT then
                scrollBar:Show()
            else
                scrollBar:Hide()
                scrollFrame:SetVerticalScroll(0)
            end
        end
    end)

    --------------------------------------------------------
    -- Position Restore
    --------------------------------------------------------
    local pos = ns.db and ns.db.pos
    if pos and pos.point then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER")
    end

    --------------------------------------------------------
    -- LibEditMode
    --------------------------------------------------------
    local LibEditMode = LibStub("LibEditMode")
    local defaultPos = { point = "CENTER", x = 0, y = 0 }

    LibEditMode:AddFrame(frame, function(_, _, point, x, y)
        if ns.db then
            ns.db.pos = { point = point, x = x, y = y }
        end
    end, defaultPos, "GRN: Raid Notes")

    LibEditMode:AddFrameSettings(frame, {
        {
            name = "Font Size",
            kind = LibEditMode.SettingType.Slider,
            default = ns.CONFIG.fontSize,
            get = function()
                return ns.db and ns.db.fontSize or ns.CONFIG.fontSize
            end,
            set = function(_, val)
                if ns.db then
                    ns.db.fontSize = val
                    local fontPath = "Fonts\\FRIZQT__.TTF"
                    for _, fs in ipairs(linePool) do
                        fs:SetFont(fontPath, val, "")
                    end
                    ns.RefreshContent()
                end
            end,
            minValue = 8,
            maxValue = 18,
            valueStep = 1,
        },
    })

    LibEditMode:RegisterCallback("enter", function()
        frame:Show()
    end)

    --------------------------------------------------------
    -- Apply lock state & render
    --------------------------------------------------------
    ns.ApplyLock()
    ns.RefreshContent()
    frame:Show()
end

------------------------------------------------------------
-- Public: ensure frame exists
------------------------------------------------------------
function ns.CreateFrame()
    CreateMainFrame()
end
