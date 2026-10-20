-- ============================================================================
-- GrimfallDetails: UI_SpellBreakdown.lua
-- Detailed Player Inspect Window (Spell Breakdown, Crits, Hits & Grimfall Runes)
-- Compatible with WoW 3.3.5a (Wrath of the Lich King)
-- ============================================================================

GrimfallDetails = GrimfallDetails or {}
local GD = GrimfallDetails
GD.SpellBreakdown = {}
local SB = GD.SpellBreakdown
local C = GD.Constants
local CE = GD.CombatEngine

local inspectFrame = nil
local spellRows = {}
local targetRows = {}
local currentTab = "SPELLS" -- "SPELLS" or "TARGETS"
local inspectedPlayer = nil
local inspectedSegment = nil

local MAX_INSPECT_ROWS = 14
local ROW_H = 20

function SB:Create()
    if inspectFrame then return inspectFrame end

    inspectFrame = CreateFrame("Frame", "GrimfallDetailsInspectFrame", UIParent)
    inspectFrame:SetSize(460, 360)
    inspectFrame:SetPoint("CENTER", UIParent, "CENTER", -100, 0)
    inspectFrame:SetFrameStrata("HIGH")
    inspectFrame:SetClampedToScreen(true)
    inspectFrame:SetMovable(true)
    inspectFrame:EnableMouse(true)
    inspectFrame:Hide()

    -- Window Backdrop
    inspectFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    inspectFrame:SetBackdropColor(0.04, 0.05, 0.07, 0.95)
    inspectFrame:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.9)

    -- Header / Title Bar
    local header = CreateFrame("Frame", nil, inspectFrame)
    header:SetHeight(28)
    header:SetPoint("TOPLEFT", inspectFrame, "TOPLEFT", 3, -3)
    header:SetPoint("TOPRIGHT", inspectFrame, "TOPRIGHT", -3, -3)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() inspectFrame:StartMoving() end)
    header:SetScript("OnDragStop", function() inspectFrame:StopMovingOrSizing() end)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints(header)
    headerBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    headerBg:SetVertexColor(0.12, 0.12, 0.16, 0.95)

    -- Player Name & Archetype Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    title:SetText("Player Details")
    inspectFrame.title = title

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeText:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeText:SetText("|cffff4444X|r")
    closeBtn:SetScript("OnClick", function() inspectFrame:Hide() end)

    -- ------------------------------------------------------------------------
    -- Stats Summary Banner
    -- ------------------------------------------------------------------------
    local banner = CreateFrame("Frame", nil, inspectFrame)
    banner:SetHeight(38)
    banner:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    banner:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)

    local bannerBg = banner:CreateTexture(nil, "BACKGROUND")
    bannerBg:SetAllPoints(banner)
    bannerBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bannerBg:SetVertexColor(0.08, 0.08, 0.10, 0.8)

    local statLeft = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statLeft:SetPoint("TOPLEFT", banner, "TOPLEFT", 8, -4)
    statLeft:SetText("Total Damage: 0  |  DPS: 0")
    inspectFrame.statLeft = statLeft

    local statRight = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statRight:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 8, 4)
    statRight:SetText("Combat Time: 00:00  |  Crits: 0%")
    inspectFrame.statRight = statRight

    -- Grimfall Rune Contribution Badge
    local runeBadge = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    runeBadge:SetPoint("RIGHT", banner, "RIGHT", -8, 0)
    runeBadge:SetJustifyH("RIGHT")
    runeBadge:SetText("|cffffd700Grimfall Runes: 0 (0%)|r")
    inspectFrame.runeBadge = runeBadge

    -- ------------------------------------------------------------------------
    -- Tab Buttons: [Spells]  [Targets]
    -- ------------------------------------------------------------------------
    local tabSpells = CreateFrame("Button", nil, inspectFrame)
    tabSpells:SetSize(80, 20)
    tabSpells:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 4, -4)
    local tabSpellsText = tabSpells:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabSpellsText:SetPoint("CENTER", tabSpells, "CENTER", 0, 0)
    tabSpellsText:SetText("|cffffd700Spells|r")
    tabSpells:SetScript("OnClick", function()
        currentTab = "SPELLS"
        tabSpellsText:SetText("|cffffd700Spells|r")
        inspectFrame.tabTargetsText:SetText("|cff888888Targets|r")
        SB:Refresh()
    end)
    inspectFrame.tabSpellsText = tabSpellsText

    local tabTargets = CreateFrame("Button", nil, inspectFrame)
    tabTargets:SetSize(80, 20)
    tabTargets:SetPoint("LEFT", tabSpells, "RIGHT", 4, 0)
    local tabTargetsText = tabTargets:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabTargetsText:SetPoint("CENTER", tabTargets, "CENTER", 0, 0)
    tabTargetsText:SetText("|cff888888Targets|r")
    tabTargets:SetScript("OnClick", function()
        currentTab = "TARGETS"
        tabSpellsText:SetText("|cff888888Spells|r")
        tabTargetsText:SetText("|cffffd700Targets|r")
        SB:Refresh()
    end)
    inspectFrame.tabTargetsText = tabTargetsText

    -- ------------------------------------------------------------------------
    -- Table Rows Container
    -- ------------------------------------------------------------------------
    local rowsContainer = CreateFrame("Frame", nil, inspectFrame)
    rowsContainer:SetPoint("TOPLEFT", tabSpells, "BOTTOMLEFT", 0, -4)
    rowsContainer:SetPoint("BOTTOMRIGHT", inspectFrame, "BOTTOMRIGHT", -4, 6)
    inspectFrame.rowsContainer = rowsContainer

    -- Create Spell Rows
    for i = 1, MAX_INSPECT_ROWS do
        spellRows[i] = SB:CreateSpellRow(rowsContainer, i)
    end

    return inspectFrame
end

function SB:CreateSpellRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * (ROW_H + 2)))
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((index - 1) * (ROW_H + 2)))
    row:Hide()

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.06, 0.06, 0.08, 0.5)

    -- Status Fill Bar
    local bar = row:CreateTexture(nil, "BORDER")
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    bar:SetWidth(10)
    bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetVertexColor(0.8, 0.4, 0.1, 0.6)
    row.bar = bar

    -- Spell Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 3, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    -- Spell Name & Rune Tag
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    -- Stats Right: Hits, Crits %, Max, Total
    local statsText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    statsText:SetJustifyH("RIGHT")
    row.statsText = statsText

    return row
end

-- ----------------------------------------------------------------------------
-- Inspect Player API
-- ----------------------------------------------------------------------------
function SB:InspectPlayer(playerName, segmentType)
    if not inspectFrame then self:Create() end
    inspectedPlayer = playerName
    inspectedSegment = segmentType or C.SEGMENT_CURRENT
    inspectFrame:Show()
    self:Refresh()
end

function SB:Refresh()
    if not inspectFrame or not inspectFrame:IsShown() or not inspectedPlayer then return end

    local p = CE:GetPlayerRecord(inspectedSegment, inspectedPlayer)
    if not p then
        inspectFrame.title:SetText(inspectedPlayer .. " (No Data)")
        return
    end

    -- Header Info
    local col = C:GetPlayerColor(p.class, p.dominantSchool)
    inspectFrame.title:SetText(string.format("|cff%s%s|r  |cff888888[%s]|r", col.hex or "ffffff", p.name, p.archetype))

    local segment = (inspectedSegment == C.SEGMENT_OVERALL) and CE.overallSegment or CE.currentSegment
    local duration = CE:GetCombatDuration(segment)
    local dps = p.damageTotal / duration

    -- Total crits count
    local totalHits = 0
    local totalCrits = 0
    for _, s in pairs(p.spells) do
        totalHits = totalHits + s.hits
        totalCrits = totalCrits + s.crits
    end
    local overallCritPct = (totalHits > 0) and (totalCrits / totalHits) or 0

    inspectFrame.statLeft:SetText(string.format("Total Damage: |cffffffff%s|r  |  DPS: |cffffffff%s|r", C:FormatNumber(p.damageTotal), C:FormatDPS(dps)))
    inspectFrame.statRight:SetText(string.format("Combat Time: %s  |  Crits: %.1f%% (%d/%d)", C:FormatTime(duration), overallCritPct * 100, totalCrits, totalHits))

    -- Rune Contribution
    if p.runeDamageTotal > 0 then
        local runePct = (p.damageTotal > 0) and (p.runeDamageTotal / p.damageTotal) or 0
        inspectFrame.runeBadge:SetText(string.format("|cffffd700Grimfall Runes: %s (%s)|r", C:FormatNumber(p.runeDamageTotal), C:FormatPercent(runePct)))
    else
        inspectFrame.runeBadge:SetText("|cff666666Grimfall Runes: None|r")
    end

    -- Clear Rows
    for i = 1, MAX_INSPECT_ROWS do
        spellRows[i]:Hide()
    end

    local fullWidth = inspectFrame.rowsContainer:GetWidth() or 440

    if currentTab == "SPELLS" then
        -- Sort Spells by Total Damage
        local list = {}
        local maxSpellDmg = 0
        for _, s in pairs(p.spells) do
            table.insert(list, s)
            if s.total > maxSpellDmg then maxSpellDmg = s.total end
        end
        table.sort(list, function(a, b) return a.total > b.total end)

        for i = 1, math.min(MAX_INSPECT_ROWS, #list) do
            local s = list[i]
            local row = spellRows[i]

            row.icon:SetTexture(s.icon or "Interface\\Icons\\INV_Sword_04")
            row.icon:Show()

            local runeTag = s.isRune and " |cffffd700[RUNE]|r" or ""
            row.nameText:SetText(s.name .. runeTag)

            -- Fill bar ratio
            local ratio = (maxSpellDmg > 0) and (s.total / maxSpellDmg) or 0
            row.bar:SetWidth(math.max(8, fullWidth * ratio))

            -- Stats string: Total (% of total) - Hits, Crits%, Max
            local pct = (p.damageTotal > 0) and (s.total / p.damageTotal) or 0
            local critPct = (s.hits > 0) and (s.crits / s.hits) or 0
            row.statsText:SetText(string.format("%s (%s)  |  %d hits, %.0f%% crit  |  Max: %s",
                C:FormatNumber(s.total), C:FormatPercent(pct), s.hits, critPct * 100, C:FormatNumber(s.maxHit)))

            row:Show()
        end

    elseif currentTab == "TARGETS" then
        -- Sort Targets by Damage
        local list = {}
        local maxTgtDmg = 0
        for tgtName, amt in pairs(p.targets) do
            table.insert(list, { name = tgtName, total = amt })
            if amt > maxTgtDmg then maxTgtDmg = amt end
        end
        table.sort(list, function(a, b) return a.total > b.total end)

        for i = 1, math.min(MAX_INSPECT_ROWS, #list) do
            local t = list[i]
            local row = spellRows[i]

            row.icon:Hide()
            row.nameText:SetText(t.name)

            local ratio = (maxTgtDmg > 0) and (t.total / maxTgtDmg) or 0
            row.bar:SetWidth(math.max(8, fullWidth * ratio))

            local pct = (p.damageTotal > 0) and (t.total / p.damageTotal) or 0
            row.statsText:SetText(string.format("%s (%s)", C:FormatNumber(t.total), C:FormatPercent(pct)))

            row:Show()
        end
    end
end
