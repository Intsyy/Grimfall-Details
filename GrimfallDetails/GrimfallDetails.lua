-- ============================================================================
-- GrimfallDetails: GrimfallDetails.lua
-- Main Orchestrator, Slash Commands, Chat Reporting & Test Data
-- Compatible with WoW 3.3.5a (Wrath of the Lich King)
-- ============================================================================

GrimfallDetails = GrimfallDetails or {}
local GD = GrimfallDetails
local C = GD.Constants
local CE = GD.CombatEngine
local MF = GD.MainFrame
local SB = GD.SpellBreakdown

-- Main Event Frame
local eventFrame = CreateFrame("Frame", "GrimfallDetailsEventFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Out-of-combat delay timer for ending combat segments
local oocTimerFrame = CreateFrame("Frame")
local oocTime = 0
local waitingForOOC = false

oocTimerFrame:SetScript("OnUpdate", function(self, elapsed)
    if waitingForOOC then
        oocTime = oocTime + elapsed
        if oocTime >= 3.5 then
            waitingForOOC = false
            CE:EndCombat()
            MF:Refresh()
        end
    end
end)

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
        GrimfallDetailsDB = GrimfallDetailsDB or {
            x = 220,
            y = 0,
            w = 280,
            h = 220,
            locked = false,
        }

        CE:Init()
        MF:Create()
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF8000[GrimfallDetails]|r v1.0 loaded! Type |cffffd700/gd|r to toggle, or |cffffd700/gd test|r to preview party damage!")

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not CE.currentSegment then CE:Init() end
        MF:Refresh()

    elseif event == "PLAYER_REGEN_DISABLED" then
        waitingForOOC = false
        CE:StartCombat()
        MF:Refresh()

    elseif event == "PLAYER_REGEN_ENABLED" then
        oocTime = 0
        waitingForOOC = true

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        CE:ProcessCombatEvent(...)
    end
end)

-- ----------------------------------------------------------------------------
-- Chat Reporting System
-- ----------------------------------------------------------------------------
function GD:ReportTopToChat(targetChannel)
    local list, segTotal = CE:GetSortedPlayerList(CE.activeSegmentType, CE.activeMode)
    if #list == 0 then
        DEFAULT_CHAT_FRAME:AddMessage(C.ADDON_PREFIX .. "No combat data recorded to report.")
        return
    end

    local channel = targetChannel
    if not channel then
        if UnitInRaid("player") then
            channel = "RAID"
        elseif GetNumPartyMembers() > 0 then
            channel = "PARTY"
        elseif IsInGuild() then
            channel = "GUILD"
        else
            channel = "SAY"
        end
    end

    local modeName = C.MODE_NAMES[CE.activeMode] or "Damage"
    local segName = C.SEGMENT_NAMES[CE.activeSegmentType] or "Current"

    SendChatMessage(string.format("[GrimfallDetails] %s - %s (Total: %s):", modeName, segName, C:FormatNumber(segTotal)), channel)

    local maxReport = math.min(5, #list)
    for i = 1, maxReport do
        local e = list[i]
        local rateSuffix = (CE.activeMode == C.MODE_HEALING) and "HPS" or "DPS"
        local runeTag = (e.runeDamage > 0) and string.format(" [Runes: %s]", C:FormatNumber(e.runeDamage)) or ""
        local line = string.format("%d. %s: %s (%s, %s %s) [%s]%s",
            e.rank, e.name, C:FormatNumber(e.amount), C:FormatPercent(e.percent), C:FormatDPS(e.rate), rateSuffix, e.archetype, runeTag)
        SendChatMessage(line, channel)
    end
end

-- ----------------------------------------------------------------------------
-- Test Mode: Populate Realistic Mock Encounter Data
-- ----------------------------------------------------------------------------
function GD:LoadTestData()
    CE:Init()
    local seg = CE.currentSegment
    seg.startTime = GetTime() - 65
    seg.endTime = GetTime()
    local now = GetTime()

    -- 1. Cuex (Fire Artillery / Pyromancer)
    seg.players["Cuex"] = {
        name = "Cuex",
        guid = "Player-0-01",
        class = "HERO",
        archetype = "Pyromancer",
        dominantSchool = "FIRE",
        schoolDamage = { ["Fire"] = 145000 },
        damageTotal = 145000,
        healingTotal = 0,
        overhealingTotal = 0,
        damageTakenTotal = 12000,
        runeDamageTotal = 24500, -- From Twice-Burned Flesh!
        firstEventTime = seg.startTime,
        lastEventTime = now,
        spells = {
            ["fireball"] = {
                name = "Fireball",
                school = "Fire",
                icon = "Interface\\Icons\\Spell_Fire_Fireball02",
                total = 64000,
                hits = 16,
                crits = 11,
                misses = 0,
                maxHit = 4850,
                minHit = 3200,
                isRune = false,
            },
            ["pyroblast"] = {
                name = "Pyroblast",
                school = "Fire",
                icon = "Interface\\Icons\\Spell_Fire_Fireball02",
                total = 42500,
                hits = 7,
                crits = 6,
                misses = 0,
                maxHit = 7400,
                minHit = 5800,
                isRune = false,
            },
            ["immolate"] = {
                name = "Immolate",
                school = "Fire",
                icon = "Interface\\Icons\\Spell_Fire_Immolation",
                total = 24500,
                hits = 24,
                crits = 14,
                misses = 0,
                maxHit = 1450,
                minHit = 820,
                isRune = true,
                runeName = "Rune of Twice-Burned Flesh",
            },
            ["scorch"] = {
                name = "Scorch",
                school = "Fire",
                icon = "Interface\\Icons\\Spell_Fire_SoulBurn",
                total = 9200,
                hits = 8,
                crits = 5,
                misses = 0,
                maxHit = 1950,
                minHit = 1100,
                isRune = false,
            },
            ["flame shock"] = {
                name = "Flame Shock",
                school = "Fire",
                icon = "Interface\\Icons\\Spell_Fire_FlameShock",
                total = 4800,
                hits = 9,
                crits = 3,
                misses = 0,
                maxHit = 850,
                minHit = 420,
                isRune = false,
            },
        },
        targets = {
            ["Dungeon Boss"] = 128000,
            ["Add Minion"] = 17000,
        },
        damageTakenFrom = {},
    }

    -- 2. Thorvald (Warrior / Gladiator)
    seg.players["Thorvald"] = {
        name = "Thorvald",
        guid = "Player-0-02",
        class = "WARRIOR",
        archetype = "Gladiator",
        dominantSchool = "PHYSICAL",
        schoolDamage = { ["Physical"] = 108000 },
        damageTotal = 108000,
        healingTotal = 0,
        overhealingTotal = 0,
        damageTakenTotal = 15000,
        runeDamageTotal = 0,
        firstEventTime = seg.startTime,
        lastEventTime = now,
        spells = {
            ["bloodthirst"] = { name = "Bloodthirst", school = "Physical", icon = "Interface\\Icons\\Spell_Nature_BloodLust", total = 46000, hits = 14, crits = 8, misses = 0, maxHit = 4100, minHit = 2800, isRune = false },
            ["whirlwind"]   = { name = "Whirlwind",   school = "Physical", icon = "Interface\\Icons\\Ability_Whirlwind",       total = 34000, hits = 18, crits = 9, misses = 0, maxHit = 2900, minHit = 1500, isRune = false },
            ["heroic strike"]={ name = "Heroic Strike",school = "Physical", icon = "Interface\\Icons\\Ability_Rogue_Ambush",   total = 28000, hits = 10, crits = 5, misses = 0, maxHit = 3500, minHit = 2200, isRune = false },
        },
        targets = { ["Dungeon Boss"] = 92000, ["Add Minion"] = 16000 },
        damageTakenFrom = {},
    }

    -- 3. Lyra (Stormcaller / Shaman)
    seg.players["Lyra"] = {
        name = "Lyra",
        guid = "Player-0-03",
        class = "SHAMAN",
        archetype = "Stormcaller",
        dominantSchool = "NATURE",
        schoolDamage = { ["Nature"] = 92000 },
        damageTotal = 92000,
        healingTotal = 0,
        overhealingTotal = 0,
        damageTakenTotal = 8000,
        runeDamageTotal = 31000, -- From Overloaded Lightning!
        firstEventTime = seg.startTime,
        lastEventTime = now,
        spells = {
            ["lightning bolt"] = { name = "Lightning Bolt", school = "Nature", icon = "Interface\\Icons\\Spell_Nature_Lightning", total = 42000, hits = 15, crits = 7, misses = 0, maxHit = 3600, minHit = 2400, isRune = false },
            ["overloaded lightning"] = { name = "Overloaded Lightning", school = "Nature", icon = "Interface\\Icons\\Spell_Nature_Lightning", total = 31000, hits = 12, crits = 6, misses = 0, maxHit = 3600, minHit = 2400, isRune = true, runeName = "Rune of Overloaded Lightning" },
            ["lava burst"]     = { name = "Lava Burst",     school = "Fire",   icon = "Interface\\Icons\\Spell_Shaman_LavaBurst",  total = 19000, hits = 4, crits = 4, misses = 0, maxHit = 5200, minHit = 4600, isRune = false },
        },
        targets = { ["Dungeon Boss"] = 92000 },
        damageTakenFrom = {},
    }

    -- 4. Aaron (Paladin / Crusader Tank)
    seg.players["Aaron"] = {
        name = "Aaron",
        guid = "Player-0-04",
        class = "PALADIN",
        archetype = "Crusader",
        dominantSchool = "HOLY",
        schoolDamage = { ["Holy"] = 38000, ["Physical"] = 12000 },
        damageTotal = 50000,
        healingTotal = 12000,
        overhealingTotal = 8000,
        damageTakenTotal = 95000,
        runeDamageTotal = 0,
        firstEventTime = seg.startTime,
        lastEventTime = now,
        spells = {
            ["shield of righteousness"] = { name = "Shield of Righteousness", school = "Holy", icon = "Interface\\Icons\\Ability_Paladin_ShieldofVengeance", total = 26000, hits = 9, crits = 3, misses = 0, maxHit = 3200, minHit = 2200, isRune = false },
            ["consecration"]            = { name = "Consecration",            school = "Holy", icon = "Interface\\Icons\\Spell_Holy_InnerFire",          total = 14000, hits = 18, crits = 6, misses = 0, maxHit = 950, minHit = 650, isRune = false },
            ["auto attack"]             = { name = "Auto Attack",             school = "Physical", icon = "Interface\\Icons\\INV_Sword_04",             total = 10000, hits = 12, crits = 2, misses = 0, maxHit = 1100, minHit = 700, isRune = false },
        },
        targets = { ["Dungeon Boss"] = 42000, ["Add Minion"] = 8000 },
        damageTakenFrom = {},
    }

    -- 5. Selena (Priest / Restorer Healer)
    seg.players["Selena"] = {
        name = "Selena",
        guid = "Player-0-05",
        class = "PRIEST",
        archetype = "Restorer",
        dominantSchool = "HOLY",
        schoolDamage = { ["Holy"] = 4000 },
        damageTotal = 4000,
        healingTotal = 138000,
        overhealingTotal = 42000,
        damageTakenTotal = 5000,
        runeDamageTotal = 0,
        firstEventTime = seg.startTime,
        lastEventTime = now,
        spells = {
            ["flash heal"]         = { name = "Flash Heal",         school = "Holy", icon = "Interface\\Icons\\Spell_Holy_FlashHeal",      total = 68000, hits = 22, crits = 9, misses = 0, maxHit = 4200, minHit = 2600, isRune = false },
            ["circle of healing"]  = { name = "Circle of Healing",  school = "Holy", icon = "Interface\\Icons\\Spell_Holy_CircleOfRenewal",total = 44000, hits = 35, crits = 12, misses = 0, maxHit = 1600, minHit = 950, isRune = false },
            ["prayer of mending"]  = { name = "Prayer of Mending",  school = "Holy", icon = "Interface\\Icons\\Spell_Holy_PrayerOfMendingtga",total = 26000, hits = 14, crits = 5, misses = 0, maxHit = 2400, minHit = 1800, isRune = false },
        },
        targets = { ["Aaron"] = 88000, ["Thorvald"] = 28000, ["Cuex"] = 12000, ["Lyra"] = 10000 },
        damageTakenFrom = {},
    }

    seg.totalDamage = 145000 + 108000 + 92000 + 50000 + 4000
    seg.totalHealing = 138000 + 12000
    seg.totalDamageTaken = 12000 + 15000 + 8000 + 95000 + 5000
    seg.totalRuneDamage = 24500 + 31000

    MF:Refresh()
    DEFAULT_CHAT_FRAME:AddMessage(C.ADDON_PREFIX .. "Loaded mock party combat encounter! Left-Click on any bar (e.g. Cuex) to inspect the Spell & Rune Breakdown.")
end

-- ----------------------------------------------------------------------------
-- Slash Commands
-- ----------------------------------------------------------------------------
SLASH_GRIMFALLDETAILS1 = "/gd"
SLASH_GRIMFALLDETAILS2 = "/details"
SLASH_GRIMFALLDETAILS3 = "/gmeter"

SlashCmdList["GRIMFALLDETAILS"] = function(msg)
    local cmd = string.lower(string.match(msg or "", "^(%a+)") or "")

    if cmd == "test" then
        GD:LoadTestData()
    elseif cmd == "reset" then
        CE:ResetSegment(C.SEGMENT_CURRENT)
        CE:ResetSegment(C.SEGMENT_OVERALL)
        MF:Refresh()
        DEFAULT_CHAT_FRAME:AddMessage(C.ADDON_PREFIX .. "All combat data reset!")
    elseif cmd == "report" then
        local chan = string.match(msg or "", "^%a+%s*(%a+)")
        GD:ReportTopToChat(chan and string.upper(chan) or nil)
    elseif cmd == "show" then
        MF:Create():Show()
        MF:Refresh()
    elseif cmd == "hide" then
        if mainFrame then mainFrame:Hide() end
    else
        MF:Toggle()
    end
end
