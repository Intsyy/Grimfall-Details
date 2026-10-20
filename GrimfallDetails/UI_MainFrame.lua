-- ============================================================================
-- GrimfallDetails: UI_MainFrame.lua
-- Sleek Modern Damage Meter Window (Details! Style for Grimfall WoW)
-- Compatible with WoW 3.3.5a (Wrath of the Lich King)
-- ============================================================================

GrimfallDetails = GrimfallDetails or {}
local GD = GrimfallDetails
GD.MainFrame = {}
local MF = GD.MainFrame
local C = GD.Constants
local CE = GD.CombatEngine

local ROW_HEIGHT = 20
local ROW_SPACING = 2
local MAX_ROWS = 12

local mainFrame = nil
local rowPool = {}
local updateTimer = 0

-- ----------------------------------------------------------------------------
-- Create Main Details Window
-- ----------------------------------------------------------------------------
function MF:Create()
    if mainFrame then return mainFrame end

    -- Main Container Window
    mainFrame = CreateFrame("Frame", "GrimfallDetailsMainFrame", UIParent)
    mainFrame:SetSize(280, 220)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    mainFrame:SetMinResize(200, 120)
    mainFrame:SetMaxResize(500, 500)
    mainFrame:EnableMouse(true)

    -- Window Backdrop
    mainFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    mainFrame:SetBackdropColor(0.05, 0.05, 0.07, 0.90)
    mainFrame:SetBackdropBorderColor(0.20, 0.20, 0.25, 0.80)

    -- ------------------------------------------------------------------------
    -- Title / Header Bar
    -- ------------------------------------------------------------------------
    local header = CreateFrame("Frame", nil, mainFrame)
    header:SetHeight(24)
    header:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 2, -2)
    header:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, -2)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() mainFrame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
        MF:SavePosition()
    end)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints(header)
    headerBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    headerBg:SetVertexColor(0.10, 0.10, 0.14, 0.95)

    -- Logo / Title Text
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", header, "LEFT", 6, 0)
    title:SetText("|cffFF8000Grimfall|rDetails")

    -- Segment Selector Button (Current / Overall)
    local segBtn = CreateFrame("Button", nil, header)
    segBtn:SetSize(75, 18)
    segBtn:SetPoint("LEFT", title, "RIGHT", 8, 0)
    local segBtnText = segBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    segBtnText:SetPoint("CENTER", segBtn, "CENTER", 0, 0)
    segBtnText:SetText("|cff00ff96Current|r")
    segBtn:SetScript("OnClick", function()
        if CE.activeSegmentType == C.SEGMENT_CURRENT then
            CE.activeSegmentType = C.SEGMENT_OVERALL
            segBtnText:SetText("|cffffcc00Overall|r")
        else
            CE.activeSegmentType = C.SEGMENT_CURRENT
            segBtnText:SetText("|cff00ff96Current|r")
        end
        MF:Refresh()
    end)

    -- Mode Selector Button (Damage / DPS / Healing / Runes)
    local modeBtn = CreateFrame("Button", nil, header)
    modeBtn:SetSize(80, 18)
    modeBtn:SetPoint("LEFT", segBtn, "RIGHT", 4, 0)
    local modeBtnText = modeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modeBtnText:SetPoint("CENTER", modeBtn, "CENTER", 0, 0)
    modeBtnText:SetText("Damage")
    modeBtn:SetScript("OnClick", function()
        CE.activeMode = CE.activeMode + 1
        if CE.activeMode > C.MODE_RUNES then CE.activeMode = 1 end
        modeBtnText:SetText(C.MODE_NAMES[CE.activeMode] or "Damage")
        MF:Refresh()
    end)

    -- Reset Button [X]
    local resetBtn = CreateFrame("Button", nil, header)
    resetBtn:SetSize(18, 18)
    resetBtn:SetPoint("RIGHT", header, "RIGHT", -22, 0)
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
    resetText:SetText("|cffff4444R|r")
    resetBtn:SetScript("OnClick", function()
        CE:ResetSegment(CE.activeSegmentType)
        MF:Refresh()
        DEFAULT_CHAT_FRAME:AddMessage(C.ADDON_PREFIX .. "Data reset for " .. C.SEGMENT_NAMES[CE.activeSegmentType] .. "!")
    end)
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Reset Data (" .. C.SEGMENT_NAMES[CE.activeSegmentType] .. ")")
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Share / Report Button [>]
    local shareBtn = CreateFrame("Button", nil, header)
    shareBtn:SetSize(18, 18)
    shareBtn:SetPoint("RIGHT", resetBtn, "LEFT", -4, 0)
    local shareText = shareBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    shareText:SetPoint("CENTER", shareBtn, "CENTER", 0, 0)
    shareText:SetText("|cff00ccffS|r")
    shareBtn:SetScript("OnClick", function()
        GD:ReportTopToChat()
    end)
    shareBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Report to Party / Raid")
        GameTooltip:Show()
    end)
    shareBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Close Button [X]
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeText:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeText:SetText("|cff888888x|r")
    closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

    -- ------------------------------------------------------------------------
    -- Footer Bar
    -- ------------------------------------------------------------------------
    local footer = CreateFrame("Frame", nil, mainFrame)
    footer:SetHeight(18)
    footer:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 4, 3)
    footer:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -16, 3)

    local footerText = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerText:SetPoint("LEFT", footer, "LEFT", 2, 0)
    footerText:SetText("Time: 00:00  |  Total: 0")
    mainFrame.footerText = footerText

    -- Resize Grip
    local resizeGrip = CreateFrame("Button", nil, mainFrame)
    resizeGrip:SetSize(14, 14)
    resizeGrip:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -2, 2)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function() mainFrame:StartSizing("BOTTOMRIGHT") end)
    resizeGrip:SetScript("OnMouseUp", function()
        mainFrame:StopMovingOrSizing()
        MF:SavePosition()
        MF:Refresh()
    end)

    -- ------------------------------------------------------------------------
    -- Bar Rows Container
    -- ------------------------------------------------------------------------
    local barContainer = CreateFrame("Frame", nil, mainFrame)
    barContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 2, -3)
    barContainer:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 14, 2)
    mainFrame.barContainer = barContainer

    -- Create Initial Row Pool
    for i = 1, MAX_ROWS do
        rowPool[i] = MF:CreateRow(barContainer, i)
    end

    -- Smooth Update Driver (updates every 0.3s)
    mainFrame:SetScript("OnUpdate", function(self, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer >= 0.30 then
            updateTimer = 0
            MF:Refresh()
        end
    end)

    MF:RestorePosition()
    return mainFrame
end

-- ----------------------------------------------------------------------------
-- Create Individual Row Bar
-- ----------------------------------------------------------------------------
function MF:CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * (ROW_HEIGHT + ROW_SPACING)))
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((index - 1) * (ROW_HEIGHT + ROW_SPACING)))
    row:EnableMouse(true)
    row:Hide()

    -- Status Bar Background (Dark track)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.08, 0.08, 0.10, 0.6)
    row.bg = bg

    -- Status Bar Fill (Foreground colored bar)
    local bar = row:CreateTexture(nil, "BORDER")
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    bar:SetWidth(10)
    bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.bar = bar

    -- Spec/Archetype Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 3, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    -- Left Text: Rank + Name + Archetype
    local leftText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    leftText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    leftText:SetJustifyH("LEFT")
    row.leftText = leftText

    -- Right Text: Total (Percent, Rate)
    local rightText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rightText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    rightText:SetJustifyH("RIGHT")
    row.rightText = rightText

    -- Row Click: Inspect Spell Breakdown
    row:SetScript("OnClick", function(self)
        if self.playerName then
            GD.SpellBreakdown:InspectPlayer(self.playerName, CE.activeSegmentType)
        end
    end)

    -- Row Hover: Tooltip Preview
    row:SetScript("OnEnter", function(self)
        if not self.playerName then return end
        local p = CE:GetPlayerRecord(CE.activeSegmentType, self.playerName)
        if not p then return end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(p.name .. "  |cff888888(" .. p.archetype .. ")|r", 1, 0.8, 0)
        GameTooltip:AddLine("Dominant School: " .. p.dominantSchool, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")

        -- Top 3 Spells
        local sortedSpells = {}
        for _, s in pairs(p.spells) do table.insert(sortedSpells, s) end
        table.sort(sortedSpells, function(a, b) return a.total > b.total end)

        GameTooltip:AddLine("Top Abilities:")
        for i = 1, math.min(3, #sortedSpells) do
            local s = sortedSpells[i]
            local tag = s.isRune and " |cffffd700[Rune]|r" or ""
            GameTooltip:AddDoubleLine("  " .. s.name .. tag, C:FormatNumber(s.total) .. " (" .. C:FormatPercent(p.damageTotal > 0 and (s.total/p.damageTotal) or 0) .. ")", 1, 1, 1, 0.7, 0.7, 0.7)
        end

        if p.runeDamageTotal > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Grimfall Rune Damage:", C:FormatNumber(p.runeDamageTotal) .. " (" .. C:FormatPercent(p.damageTotal > 0 and (p.runeDamageTotal/p.damageTotal) or 0) .. ")", 1, 0.82, 0, 1, 0.82, 0)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff96<Left-Click to open Spell Breakdown>|r", 0, 1, 0)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

-- ----------------------------------------------------------------------------
-- Refresh Data & Display
-- ----------------------------------------------------------------------------
function MF:Refresh()
    if not mainFrame or not mainFrame:IsShown() then return end

    local list, segTotal, maxAmount = CE:GetSortedPlayerList(CE.activeSegmentType, CE.activeMode)
    local containerHeight = mainFrame.barContainer:GetHeight() or 180
    local visibleRows = math.min(MAX_ROWS, math.floor(containerHeight / (ROW_HEIGHT + ROW_SPACING)))
    local fullWidth = mainFrame.barContainer:GetWidth() or 260

    -- Hide all rows initially
    for i = 1, MAX_ROWS do
        rowPool[i]:Hide()
    end

    -- Populate rows
    for rank = 1, math.min(visibleRows, #list) do
        local entry = list[rank]
        local row = rowPool[rank]
        row.playerName = entry.name

        -- Color & Texture
        local col = entry.color or { r = 1, g = 0.5, b = 0 }
        row.bar:SetVertexColor(col.r or 1, col.g or 0.5, col.b or 0, 0.85)

        -- Relative Bar Width
        local barWidth = math.max(12, fullWidth * entry.relativeBarRatio)
        row.bar:SetWidth(barWidth)

        -- Icon
        local archIcon = C.ARCHETYPES[entry.dominantSchool] and C.ARCHETYPES[entry.dominantSchool].icon or "Interface\\Icons\\INV_Sword_04"
        row.icon:SetTexture(archIcon)

        -- Left Text: Rank + Name + [Archetype]
        row.leftText:SetText(string.format("%d. |cff%s%s|r |cff777777[%s]|r", rank, col.hex or "ffffff", entry.name, entry.archetype))

        -- Right Text: Total + (Percent, Rate)
        local rateSuffix = (CE.activeMode == C.MODE_HEALING) and " HPS" or " DPS"
        row.rightText:SetText(string.format("%s (%s, %s%s)", C:FormatNumber(entry.amount), C:FormatPercent(entry.percent), C:FormatDPS(entry.rate), rateSuffix))

        row:Show()
    end

    -- Update Footer
    local segment = (CE.activeSegmentType == C.SEGMENT_OVERALL) and CE.overallSegment or CE.currentSegment
    local duration = CE:GetCombatDuration(segment)
    mainFrame.footerText:SetText(string.format("Time: %s  |  Total: %s", C:FormatTime(duration), C:FormatNumber(segTotal)))
end

-- Save / Restore Window Coordinates
function MF:SavePosition()
    if not GrimfallDetailsDB or not mainFrame then return end
    local point, _, _, x, y = mainFrame:GetPoint()
    GrimfallDetailsDB.x = x
    GrimfallDetailsDB.y = y
    GrimfallDetailsDB.w = mainFrame:GetWidth()
    GrimfallDetailsDB.h = mainFrame:GetHeight()
end

function MF:RestorePosition()
    if not GrimfallDetailsDB or not mainFrame then return end
    if GrimfallDetailsDB.x and GrimfallDetailsDB.y then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", GrimfallDetailsDB.x, GrimfallDetailsDB.y)
    end
    if GrimfallDetailsDB.w and GrimfallDetailsDB.h then
        mainFrame:SetSize(GrimfallDetailsDB.w, GrimfallDetailsDB.h)
    end
end

function MF:Toggle()
    if not mainFrame then self:Create() end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        self:Refresh()
    end
end
