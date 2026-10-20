-- ============================================================================
-- GrimfallDetails: RuneDatabase.lua
-- Detection & Attribution of Grimfall Custom Runes & Mystic Enchantments
-- Compatible with WoW 3.3.5a (Wrath of the Lich King)
-- ============================================================================

GrimfallDetails = GrimfallDetails or {}
local GD = GrimfallDetails
GD.RuneDatabase = {}
local RDB = GD.RuneDatabase

-- Table of Key Grimfall Damage & Healing Runes
RDB.KNOWN_RUNES = {
    [2595] = { name = "Rune of Twice-Burned Flesh",       desc = "Fireball applies Immolate" },
    [2644] = { name = "Rune of Overloaded Lightning",      desc = "Duplicate Lightning Bolt & Chain Lightning" },
    [5295] = { name = "Rune of the Frozen Tempest",        desc = "Frozen Tempest Froststorm eruption" },
    [2631] = { name = "Rune of Encircling Frost",          desc = "Ring of Frost on Frost Nova" },
    [2648] = { name = "Rune of the Awakened Rune Weapon",  desc = "Dancing Rune Weapon echoes all spells" },
    [2593] = { name = "Rune of the Thunderous Gale",       desc = "Thunder Clap unleashes Thunderous Gale" },
    [2592] = { name = "Rune of the Icy Winds of Northrend",desc = "Howling Blast descends Northrend Blizzard" },
    [2594] = { name = "Rune of Deepening Frost",           desc = "Icy Touch builds Permafrost stacks" },
    [2627] = { name = "Rune of the Falling Stars",         desc = "Starsurge and Shooting Stars" },
    [2622] = { name = "Rune of the Vortex of Imbued Blades",desc = "Bladestorm afflicts magical DoTs" },
    [5344] = { name = "Rune of the Blades of Sun and Moon",desc = "Astral Strike spellstorm strikes" },
    [5269] = { name = "Rune of the Firebrand",             desc = "Flamewrought Wound & Searing Brand" },
    [5273] = { name = "Rune of the Devout Flames",         desc = "Devout Flame Holy Fire eruption" },
    [5439] = { name = "Rune of the Burning Dragonhawk",    desc = "Dragonhawk's Fury Fire damage" },
    [2624] = { name = "Rune of Elemental Unleashing",      desc = "Unleash Elements weapon invocations" },
    [2587] = { name = "Rune of Atonement",                 desc = "Single target damage heals nearby allies" },
    [2588] = { name = "Rune of Haunting Reverberations",   desc = "Reverberating Haunt DoT refresher" },
    [2613] = { name = "Rune of the Shocking Rush of the Inferno", desc = "Inferno Rush casting speed overload" },
    [2616] = { name = "Rune of the Sanguine Blight",       desc = "Blood Boil erupts on Shadow DoTs" },
}

-- Custom Spell Name Keywords Triggered by Runes
RDB.RUNE_SPELL_NAMES = {
    ["frozen tempest"]       = "Rune of the Frozen Tempest",
    ["gathering tempest"]    = "Rune of the Frozen Tempest",
    ["thunderous gale"]      = "Rune of the Thunderous Gale",
    ["permafrost"]           = "Rune of Deepening Frost",
    ["ring of frost"]        = "Rune of Encircling Frost",
    ["flamewrought wound"]   = "Rune of the Firebrand",
    ["searing brand"]        = "Rune of the Firebrand",
    ["astral strike"]        = "Rune of the Blades of Sun and Moon",
    ["dragonhawk's fury"]    = "Rune of the Burning Dragonhawk",
    ["overloaded lightning"] = "Rune of Overloaded Lightning",
    ["atonement"]            = "Rune of Atonement",
    ["devout flame"]         = "Rune of the Devout Flames",
}

-- Check if a given spell event originated from a Grimfall Rune
function RDB:IsGrimfallRune(spellId, spellName)
    if spellId and self.KNOWN_RUNES[spellId] then
        return true, self.KNOWN_RUNES[spellId].name
    end
    if spellName then
        local clean = string.lower(spellName)
        if self.RUNE_SPELL_NAMES[clean] then
            return true, self.RUNE_SPELL_NAMES[clean]
        end
    end
    return false, nil
end
