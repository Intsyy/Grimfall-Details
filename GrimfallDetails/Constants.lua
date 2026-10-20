-- ============================================================================
-- GrimfallDetails: Constants.lua
-- Configuration, Number Formatting, Archetypes & Color Palettes
-- Compatible with WoW 3.3.5a (Wrath of the Lich King)
-- ============================================================================

GrimfallDetails = GrimfallDetails or {}
local GD = GrimfallDetails
GD.Constants = {}
local C = GD.Constants

C.ADDON_NAME = "GrimfallDetails"
C.ADDON_VERSION = "1.0.0"
C.ADDON_PREFIX = "|cffFF8000[GrimfallDetails]|r "

-- Display Modes
C.MODE_DAMAGE       = 1
C.MODE_DPS          = 2
C.MODE_HEALING      = 3
C.MODE_DAMAGE_TAKEN = 4
C.MODE_RUNES        = 5

C.MODE_NAMES = {
    [C.MODE_DAMAGE]       = "Damage Done",
    [C.MODE_DPS]          = "DPS",
    [C.MODE_HEALING]      = "Healing Done",
    [C.MODE_DAMAGE_TAKEN] = "Damage Taken",
    [C.MODE_RUNES]        = "Rune Damage",
}

-- Segments
C.SEGMENT_CURRENT = 1
C.SEGMENT_OVERALL = 2

C.SEGMENT_NAMES = {
    [C.SEGMENT_CURRENT] = "Current Fight",
    [C.SEGMENT_OVERALL] = "Overall Data",
}

-- Standard WoW Class Colors
C.CLASS_COLORS = {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43, hex = "C79C6E" },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73, hex = "F58CBA" },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45, hex = "ABD473" },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41, hex = "FFF569" },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00, hex = "FFFFFF" },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23, hex = "C41F3B" },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87, hex = "0070DE" },
    ["MAGE"]        = { r = 0.41, g = 0.80, b = 0.94, hex = "69CCF0" },
    ["WARLOCK"]     = { r = 0.58, g = 0.51, b = 0.79, hex = "9482C9" },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04, hex = "FF7D0A" },
    ["HERO"]        = { r = 1.00, g = 0.50, b = 0.00, hex = "FF8000" },
}

-- Grimfall Classless Archetypes (Inferred dynamically from dominant spell school)
C.ARCHETYPES = {
    ["FIRE"]     = { title = "Pyromancer",    r = 1.00, g = 0.38, b = 0.05, hex = "FF610D", icon = "Interface\\Icons\\Spell_Fire_Fireball02" },
    ["FROST"]    = { title = "Cryomancer",    r = 0.25, g = 0.65, b = 1.00, hex = "40A6FF", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
    ["ARCANE"]   = { title = "Arcanist",      r = 0.85, g = 0.40, b = 1.00, hex = "D966FF", icon = "Interface\\Icons\\Spell_Nature_WispSplode" },
    ["NATURE"]   = { title = "Stormcaller",   r = 0.18, g = 0.85, b = 0.45, hex = "2ED973", icon = "Interface\\Icons\\Spell_Nature_Lightning" },
    ["SHADOW"]   = { title = "Voidbinder",    r = 0.60, g = 0.35, b = 0.95, hex = "9959F2", icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt" },
    ["HOLY"]     = { title = "Crusader",      r = 0.98, g = 0.82, b = 0.25, hex = "FAC740", icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
    ["PHYSICAL"] = { title = "Gladiator",     r = 0.78, g = 0.61, b = 0.43, hex = "C79C6E", icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance" },
    ["HYBRID"]   = { title = "Battlemage",    r = 1.00, g = 0.75, b = 0.20, hex = "FFC033", icon = "Interface\\Icons\\INV_Sword_04" },
    ["HEALER"]   = { title = "Restorer",      r = 0.15, g = 0.90, b = 0.65, hex = "26E6A6", icon = "Interface\\Icons\\Spell_Holy_Renew" },
}

-- Spell School Bitmasks to String
C.SCHOOL_NAMES = {
    [1]  = "Physical",
    [2]  = "Holy",
    [4]  = "Fire",
    [8]  = "Nature",
    [16] = "Frost",
    [32] = "Shadow",
    [64] = "Arcane",
}

-- ----------------------------------------------------------------------------
-- Utility Formatter Functions
-- ----------------------------------------------------------------------------
function C:FormatNumber(num)
    if not num or num <= 0 then return "0" end
    if num >= 1000000 then
        return string.format("%.2fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fk", num / 1000)
    else
        return string.format("%d", math.floor(num))
    end
end

function C:FormatDPS(dps)
    if not dps or dps <= 0 then return "0" end
    if dps >= 10000 then
        return string.format("%.1fk", dps / 1000)
    elseif dps >= 1000 then
        local thousands = math.floor(dps / 1000)
        local remainder = math.floor(dps % 1000)
        return string.format("%d,%03d", thousands, remainder)
    else
        return string.format("%d", math.floor(dps))
    end
end

function C:FormatPercent(ratio)
    if not ratio or ratio <= 0 then return "0.0%" end
    return string.format("%.1f%%", ratio * 100)
end

function C:FormatTime(seconds)
    if not seconds or seconds <= 0 then return "00:00" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

-- Get Color for a player by class or archetype
function C:GetPlayerColor(classToken, dominantSchool)
    if classToken and C.CLASS_COLORS[classToken] and classToken ~= "HERO" then
        return C.CLASS_COLORS[classToken]
    end
    if dominantSchool and C.ARCHETYPES[dominantSchool] then
        return C.ARCHETYPES[dominantSchool]
    end
    return C.CLASS_COLORS["HERO"]
end
