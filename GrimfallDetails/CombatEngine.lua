-- ============================================================================
-- GrimfallDetails: CombatEngine.lua
-- Real-time Combat Log Parser, Segments, Archetypes & Damage Attribution
-- Compatible with WoW 3.3.5a (Wrath of the Lich King)
-- ============================================================================

GrimfallDetails = GrimfallDetails or {}
local GD = GrimfallDetails
GD.CombatEngine = {}
local CE = GD.CombatEngine
local C = GD.Constants
local RDB = GD.RuneDatabase

-- Active and Overall Combat Segments
CE.currentSegment = nil
CE.overallSegment = nil
CE.inCombat = false
CE.activeMode = C.MODE_DAMAGE
CE.activeSegmentType = C.SEGMENT_CURRENT

-- Create a fresh empty segment table
local function CreateNewSegment(title)
    return {
        title = title or "Combat",
        startTime = GetTime(),
        endTime = nil,
        totalDamage = 0,
        totalHealing = 0,
        totalDamageTaken = 0,
        totalRuneDamage = 0,
        players = {}, -- [name] = playerTable
    }
end

-- Create or fetch player record within a segment
local function GetOrCreatePlayer(segment, name, guid, classToken)
    if not segment or not name then return nil end
    local p = segment.players[name]
    if not p then
        p = {
            name = name,
            guid = guid,
            class = classToken or "HERO",
            archetype = "Adventurer",
            dominantSchool = "PHYSICAL",
            schoolDamage = {},
            damageTotal = 0,
            healingTotal = 0,
            overhealingTotal = 0,
            damageTakenTotal = 0,
            runeDamageTotal = 0,
            firstEventTime = GetTime(),
            lastEventTime = GetTime(),
            spells = {},       -- [spellKey] = spellData
            targets = {},      -- [targetName] = amount
            damageTakenFrom = {},
        }
        segment.players[name] = p
    end
    return p
end

-- Update dominant school and infer classless archetype
local function UpdatePlayerArchetype(player)
    local maxSchoolName = "PHYSICAL"
    local maxDamage = 0

    for school, amt in pairs(player.schoolDamage) do
        if amt > maxDamage then
            maxDamage = amt
            maxSchoolName = school
        end
    end

    player.dominantSchool = maxSchoolName
    if C.ARCHETYPES[maxSchoolName] then
        player.archetype = C.ARCHETYPES[maxSchoolName].title
    else
        player.archetype = "Hero"
    end
end

-- Initialize Engine
function CE:Init()
    self.currentSegment = CreateNewSegment("Current Fight")
    self.overallSegment = CreateNewSegment("Overall Data")
end

function CE:StartCombat()
    if self.inCombat then return end
    self.inCombat = true
    self.currentSegment = CreateNewSegment("Current Fight")
    self.currentSegment.startTime = GetTime()
end

function CE:EndCombat()
    if not self.inCombat then return end
    self.inCombat = false
    self.currentSegment.endTime = GetTime()

    -- Merge currentSegment into overallSegment
    self:MergeIntoOverall(self.currentSegment)
end

function CE:ResetSegment(segmentType)
    if segmentType == C.SEGMENT_CURRENT then
        self.currentSegment = CreateNewSegment("Current Fight")
    elseif segmentType == C.SEGMENT_OVERALL then
        self.overallSegment = CreateNewSegment("Overall Data")
    else
        self.currentSegment = CreateNewSegment("Current Fight")
        self.overallSegment = CreateNewSegment("Overall Data")
    end
end

-- Merge current fight into overall data
function CE:MergeIntoOverall(current)
    if not current or not self.overallSegment then return end
    local overall = self.overallSegment

    overall.totalDamage       = overall.totalDamage + current.totalDamage
    overall.totalHealing      = overall.totalHealing + current.totalHealing
    overall.totalDamageTaken  = overall.totalDamageTaken + current.totalDamageTaken
    overall.totalRuneDamage   = overall.totalRuneDamage + current.totalRuneDamage

    for name, pCurr in pairs(current.players) do
        local pOver = GetOrCreatePlayer(overall, name, pCurr.guid, pCurr.class)
        pOver.damageTotal       = pOver.damageTotal + pCurr.damageTotal
        pOver.healingTotal      = pOver.healingTotal + pCurr.healingTotal
        pOver.overhealingTotal  = pOver.overhealingTotal + pCurr.overhealingTotal
        pOver.damageTakenTotal  = pOver.damageTakenTotal + pCurr.damageTakenTotal
        pOver.runeDamageTotal   = pOver.runeDamageTotal + pCurr.runeDamageTotal

        -- Merge schools
        for s, amt in pairs(pCurr.schoolDamage) do
            pOver.schoolDamage[s] = (pOver.schoolDamage[s] or 0) + amt
        end
        UpdatePlayerArchetype(pOver)

        -- Merge spells
        for key, sCurr in pairs(pCurr.spells) do
            local sOver = pOver.spells[key]
            if not sOver then
                sOver = {
                    name = sCurr.name,
                    icon = sCurr.icon,
                    school = sCurr.school,
                    total = 0,
                    hits = 0,
                    crits = 0,
                    misses = 0,
                    maxHit = 0,
                    minHit = 999999999,
                    isRune = sCurr.isRune,
                    runeName = sCurr.runeName,
                }
                pOver.spells[key] = sOver
            end
            sOver.total  = sOver.total + sCurr.total
            sOver.hits   = sOver.hits + sCurr.hits
            sOver.crits  = sOver.crits + sCurr.crits
            sOver.misses = sOver.misses + sCurr.misses
            if sCurr.maxHit > sOver.maxHit then sOver.maxHit = sCurr.maxHit end
            if sCurr.minHit < sOver.minHit then sOver.minHit = sCurr.minHit end
        end

        -- Merge targets
        for tgt, amt in pairs(pCurr.targets) do
            pOver.targets[tgt] = (pOver.targets[tgt] or 0) + amt
        end
    end
end

-- ----------------------------------------------------------------------------
-- Combat Log Parsing
-- ----------------------------------------------------------------------------
local function IsRelevantSource(sourceFlags)
    if not sourceFlags then return false end
    -- COMBATLOG_OBJECT_AFFILIATION_MINE (0x0001) or PARTY (0x0002) or RAID (0x0004)
    local isPlayerOrGroup = bit.band(sourceFlags, 0x0007) > 0
    return isPlayerOrGroup
end

function CE:ProcessCombatEvent(...)
    local timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = ...
    if not eventType then return end

    -- Check if this event involves player or party/raid
    local isSourcePlayer = IsRelevantSource(sourceFlags)
    local isDestPlayer   = IsRelevantSource(destFlags)
    if not isSourcePlayer and not isDestPlayer then return end

    -- Auto start combat if out of combat and damage/heal occurs
    if not self.inCombat then
        self:StartCombat()
    end

    local now = GetTime()
    self.currentSegment.lastEventTime = now

    -- 1. DAMAGE DEALT
    if isSourcePlayer and (eventType == "SWING_DAMAGE" or eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "RANGE_DAMAGE") then
        local spellId, spellName, spellSchool, amount, critical
        if eventType == "SWING_DAMAGE" then
            spellId = 6603
            spellName = "Auto Attack"
            spellSchool = 1
            amount = select(9, ...)
            critical = select(15, ...)
        else
            spellId, spellName, spellSchool, amount = select(9, ...)
            critical = select(19, ...)
        end

        if amount and amount > 0 then
            local p = GetOrCreatePlayer(self.currentSegment, sourceName, sourceGUID, "HERO")
            p.lastEventTime = now
            p.damageTotal = p.damageTotal + amount
            self.currentSegment.totalDamage = self.currentSegment.totalDamage + amount

            -- Check Grimfall Rune
            local isRune, runeName = RDB:IsGrimfallRune(spellId, spellName)
            if isRune then
                p.runeDamageTotal = p.runeDamageTotal + amount
                self.currentSegment.totalRuneDamage = self.currentSegment.totalRuneDamage + amount
            end

            -- School tracking
            local schoolKey = C.SCHOOL_NAMES[spellSchool] or "Physical"
            p.schoolDamage[schoolKey] = (p.schoolDamage[schoolKey] or 0) + amount
            UpdatePlayerArchetype(p)

            -- Spell Breakdown record
            local spellKey = string.lower(spellName or "Auto Attack")
            local s = p.spells[spellKey]
            if not s then
                local _, _, icon = GetSpellInfo(spellId or 6603)
                s = {
                    name = spellName or "Auto Attack",
                    icon = icon or "Interface\\Icons\\INV_Sword_04",
                    school = schoolKey,
                    total = 0,
                    hits = 0,
                    crits = 0,
                    misses = 0,
                    maxHit = 0,
                    minHit = 999999999,
                    isRune = isRune,
                    runeName = runeName,
                }
                p.spells[spellKey] = s
            end

            s.total = s.total + amount
            s.hits = s.hits + 1
            if critical then
                s.crits = s.crits + 1
            end
            if amount > s.maxHit then s.maxHit = amount end
            if amount < s.minHit then s.minHit = amount end

            -- Target breakdown
            if destName then
                p.targets[destName] = (p.targets[destName] or 0) + amount
            end
        end

    -- 2. HEALING DONE
    elseif isSourcePlayer and (eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL") then
        local spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = select(9, ...)
        if amount and amount > 0 then
            local effectiveHeal = amount - (overhealing or 0)
            local p = GetOrCreatePlayer(self.currentSegment, sourceName, sourceGUID, "HERO")
            p.lastEventTime = now
            p.healingTotal = p.healingTotal + effectiveHeal
            p.overhealingTotal = p.overhealingTotal + (overhealing or 0)
            self.currentSegment.totalHealing = self.currentSegment.totalHealing + effectiveHeal

            local spellKey = string.lower(spellName or "Heal")
            local s = p.spells[spellKey]
            if not s then
                local _, _, icon = GetSpellInfo(spellId or 2050)
                s = {
                    name = spellName or "Heal",
                    icon = icon or "Interface\\Icons\\Spell_Holy_Renew",
                    school = "Holy",
                    total = 0,
                    hits = 0,
                    crits = 0,
                    misses = 0,
                    maxHit = 0,
                    minHit = 999999999,
                    isRune = false,
                }
                p.spells[spellKey] = s
            end
            s.total = s.total + effectiveHeal
            s.hits = s.hits + 1
            if critical then s.crits = s.crits + 1 end
            if effectiveHeal > s.maxHit then s.maxHit = effectiveHeal end
            if effectiveHeal < s.minHit then s.minHit = effectiveHeal end
        end

    -- 3. DAMAGE TAKEN
    elseif isDestPlayer and (eventType == "SWING_DAMAGE" or eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "RANGE_DAMAGE") then
        local amount
        if eventType == "SWING_DAMAGE" then
            amount = select(9, ...)
        else
            amount = select(12, ...)
        end
        if amount and amount > 0 then
            local p = GetOrCreatePlayer(self.currentSegment, destName, destGUID, "HERO")
            p.damageTakenTotal = p.damageTakenTotal + amount
            self.currentSegment.totalDamageTaken = self.currentSegment.totalDamageTaken + amount
        end
    end
end

-- ----------------------------------------------------------------------------
-- Public Query Methods for UI
-- ----------------------------------------------------------------------------
function CE:GetCombatDuration(segment)
    if not segment then return 1 end
    local endTime = segment.endTime or GetTime()
    local startTime = segment.startTime or endTime
    return math.max(1, endTime - startTime)
end

function CE:GetSortedPlayerList(segmentType, mode)
    local segment = (segmentType == C.SEGMENT_OVERALL) and self.overallSegment or self.currentSegment
    if not segment then return {} end

    local duration = self:GetCombatDuration(segment)
    local list = {}
    local maxAmount = 0
    local segmentTotal = 0

    for name, p in pairs(segment.players) do
        local amount = 0
        local rate = 0

        if mode == C.MODE_DAMAGE then
            amount = p.damageTotal
            rate = amount / duration
            segmentTotal = segment.totalDamage
        elseif mode == C.MODE_DPS then
            amount = p.damageTotal / duration
            rate = amount
            segmentTotal = segment.totalDamage / duration
        elseif mode == C.MODE_HEALING then
            amount = p.healingTotal
            rate = amount / duration
            segmentTotal = segment.totalHealing
        elseif mode == C.MODE_DAMAGE_TAKEN then
            amount = p.damageTakenTotal
            rate = amount / duration
            segmentTotal = segment.totalDamageTaken
        elseif mode == C.MODE_RUNES then
            amount = p.runeDamageTotal
            rate = amount / duration
            segmentTotal = segment.totalRuneDamage
        end

        if amount > 0 then
            if amount > maxAmount then maxAmount = amount end
            local col = C:GetPlayerColor(p.class, p.dominantSchool)
            table.insert(list, {
                name = p.name,
                class = p.class,
                archetype = p.archetype,
                dominantSchool = p.dominantSchool,
                color = col,
                amount = amount,
                rate = rate,
                runeDamage = p.runeDamageTotal,
                percent = 0, -- calculated below
                relativeBarRatio = 0,
            })
        end
    end

    -- Sort descending by amount
    table.sort(list, function(a, b) return a.amount > b.amount end)

    -- Calculate percent & bar ratio
    for rank, entry in ipairs(list) do
        entry.rank = rank
        entry.percent = (segmentTotal > 0) and (entry.amount / segmentTotal) or 0
        entry.relativeBarRatio = (maxAmount > 0) and (entry.amount / maxAmount) or 0
    end

    return list, segmentTotal, maxAmount
end

function CE:GetPlayerRecord(segmentType, playerName)
    local segment = (segmentType == C.SEGMENT_OVERALL) and self.overallSegment or self.currentSegment
    if not segment or not playerName then return nil end
    return segment.players[playerName]
end
