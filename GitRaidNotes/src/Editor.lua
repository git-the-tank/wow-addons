local _, ns = ...

------------------------------------------------------------
-- Editor Popup
-- MultiLine EditBox for modifying note content
------------------------------------------------------------
local editorFrame, editBox, saveBtn, resetBtn, cancelBtn, titleLabel

local EDITOR_WIDTH = 420
local EDITOR_HEIGHT = 380

local function CreateEditor()
    if editorFrame then return end

    editorFrame = CreateFrame("Frame", "GitRaidNotesEditor", UIParent, "BackdropTemplate")
    editorFrame:SetSize(EDITOR_WIDTH, EDITOR_HEIGHT)
    editorFrame:SetPoint("CENTER")
    editorFrame:SetFrameStrata("DIALOG")
    editorFrame:SetMovable(true)
    editorFrame:SetClampedToScreen(true)
    editorFrame:EnableMouse(true)
    editorFrame:Hide()

    editorFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    editorFrame:SetBackdropColor(0, 0, 0, 0.95)
    editorFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Title bar (drag)
    local titleBar = CreateFrame("Frame", nil, editorFrame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(24)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() editorFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() editorFrame:StopMovingOrSizing() end)

    titleLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("LEFT", 10, 0)
    titleLabel:SetText("|cff00ccffGRN|r Edit")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, editorFrame, "UIPanelCloseButtonNoScripts")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetSize(18, 18)
    closeBtn:SetScript("OnClick", function() editorFrame:Hide() end)

    -- Scroll frame for the edit box
    local scrollFrame = CreateFrame("ScrollFrame", "GitRaidNotesEditorScroll", editorFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -28)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 40)

    -- EditBox
    editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth() or (EDITOR_WIDTH - 40))
    editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)

    -- Update edit box width when scrollframe resizes
    scrollFrame:SetScript("OnSizeChanged", function(_, w)
        editBox:SetWidth(w)
    end)

    -- Button bar
    local btnBar = CreateFrame("Frame", nil, editorFrame)
    btnBar:SetPoint("BOTTOMLEFT", 8, 8)
    btnBar:SetPoint("BOTTOMRIGHT", -8, 8)
    btnBar:SetHeight(26)

    -- Save button
    saveBtn = CreateFrame("Button", nil, btnBar, "UIPanelButtonTemplate")
    saveBtn:SetSize(70, 22)
    saveBtn:SetPoint("LEFT", 0, 0)
    saveBtn:SetText("Save")

    -- Reset button
    resetBtn = CreateFrame("Button", nil, btnBar, "UIPanelButtonTemplate")
    resetBtn:SetSize(70, 22)
    resetBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
    resetBtn:SetText("Reset")

    -- Cancel button
    cancelBtn = CreateFrame("Button", nil, btnBar, "UIPanelButtonTemplate")
    cancelBtn:SetSize(70, 22)
    cancelBtn:SetPoint("RIGHT", 0, 0)
    cancelBtn:SetText("Cancel")

    cancelBtn:SetScript("OnClick", function()
        editorFrame:Hide()
    end)
end

------------------------------------------------------------
-- Public: Open Editor
------------------------------------------------------------
function ns.OpenEditor()
    if not ns.db or not ns.BOSSES then return end
    CreateEditor()

    local boss = ns.BOSSES[ns.db.currentBoss]
    if not boss then return end

    local tabKey = ns.db.currentTab
    local diff = ns.currentDifficulty or ns.db.manualDifficulty or "heroic"

    -- Title
    titleLabel:SetText("|cff00ccffGRN|r Edit: " .. boss.short .. " / " .. string.upper(tabKey))

    -- Load current content
    local content = ns.GetNoteContent(boss.key, tabKey, diff)
    editBox:SetText(content)
    editBox:SetCursorPosition(0)

    -- Save handler
    saveBtn:SetScript("OnClick", function()
        local text = editBox:GetText()
        if not ns.db.notes[boss.key] then
            ns.db.notes[boss.key] = {}
        end
        ns.db.notes[boss.key][tabKey] = text
        editorFrame:Hide()
        ns.RefreshContent()
        print("|cff00ccffGRN:|r Saved " .. boss.short .. " / " .. string.upper(tabKey))
    end)

    -- Reset handler
    resetBtn:SetScript("OnClick", function()
        if ns.db.notes[boss.key] then
            ns.db.notes[boss.key][tabKey] = nil
        end
        -- Reload default content into edit box
        local defaultContent = ns.GetNoteContent(boss.key, tabKey, diff)
        editBox:SetText(defaultContent)
        editBox:SetCursorPosition(0)
        ns.RefreshContent()
        print("|cff00ccffGRN:|r Reset " .. boss.short .. " / " .. string.upper(tabKey) .. " to default")
    end)

    editorFrame:Show()
    editBox:SetFocus()
end
