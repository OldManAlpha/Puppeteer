-- Detects casts and records the aura times in PTUnit

if not PTUtil.IsSuperWowPresent() then
    return
end

local turtle = PTUtil.IsTurtleWow()
-- Value is duration
local trackedCastedAuras = {
    -- Druid
    ["Rejuvenation"] = 12,
    ["Regrowth"] = turtle and 20 or 21,
    ["Mark of the Wild"] = 30 * 60,
    ["Gift of the Wild"] = 60 * 60,
    ["Thorns"] = 10 * 60,
    ["Abolish Poison"] = 8,
    ["Innervate"] = 20,
    ["Barkskin"] = 15,
    ["Barkskin (Feral)"] = 12,
    -- Druid: Offensive
    ["Moonfire"] = 18,
    ["Insect Swarm"] = 18,
    ["Faerie Fire"] = 40,
    ["Faerie Fire (Feral)"] = 40,
    -- Priest
    ["Power Word: Fortitude"] = 30 * 60,
    ["Divine Spirit"] = 30 * 60,
    ["Shadow Protection"] = 10 * 60,
    ["Prayer of Fortitude"] = 60 * 60,
    ["Prayer of Spirit"] = 60 * 60,
    ["Prayer of Shadow Protection"] = 20 * 60,
    ["Renew"] = 15,
    ["Power Word: Shield"] = 30,
    ["Weakened Soul"] = 15,
    ["Fade"] = 10,
    ["Fear Ward"] = 10 * 60,
    ["Champion's Grace"] = 30 * 60,
    ["Empower Champion"] = 10 * 60,
    ["Champion's Bond"] = 10 * 60,
    ["Spirit of Redemption"] = 10,
    ["Abolish Disease"] = 20,
    ["Inner Fire"] = 10 * 60,
    -- Priest: Offensive
    ["Shadow Word: Pain"] = 18,
    ["Holy Fire"] = 10,
    ["Mind Control"] = 60,
    -- Paladin
    ["Blessing of Protection"] = 10,
    ["Hand of Protection"] = 10,
    ["Divine Protection"] = 8,
    ["Divine Shield"] = 12,
    ["Holy Shield"] = 10,
    ["Bulwark of the Righteous"] = 12,
    ["Forbearance"] = 60,
    ["Blessing of Sacrifice"] = 30,
    ["Hand of Sacrifice"] = 30,
    ["Divine Intervention"] = 3 * 60,
    ["Blessing of Wisdom"] = (turtle and 10 or 5) * 60,
    ["Blessing of Might"] = (turtle and 10 or 5) * 60,
    ["Blessing of Salvation"] = (turtle and 10 or 5) * 60,
    ["Blessing of Sanctuary"] = (turtle and 10 or 5) * 60,
    ["Blessing of Kings"] = (turtle and 10 or 5) * 60,
    ["Blessing of Light"] = (turtle and 10 or 5) * 60,
    ["Greater Blessing of Wisdom"] = (turtle and 30 or 15) * 60,
    ["Greater Blessing of Might"] = (turtle and 30 or 15) * 60,
    ["Greater Blessing of Salvation"] = (turtle and 30 or 15) * 60,
    ["Greater Blessing of Sanctuary"] = (turtle and 30 or 15) * 60,
    ["Greater Blessing of Kings"] = (turtle and 30 or 15) * 60,
    ["Greater Blessing of Light"] = (turtle and 30 or 15) * 60,
    -- Shaman
    ["Water Walking"] = 10 * 60,
    -- Mage
    ["Arcane Intellect"] = 30 * 60,
    ["Arcane Brilliance"] = 60 * 60,
    ["Frost Armor"] = 30 * 60,
    ["Ice Armor"] = 30 * 60,
    ["Mage Armor"] = 30 * 60,
    ["Ice Barrier"] = 60,
    ["Mana Shield"] = 60,
    ["Fire Ward"] = 30,
    ["Frost Ward"] = 30,
    ["Ice Block"] = 10,
    ["Arcane Power"] = 20,
    -- Mage: Offensive
    ["Polymorph"] = 50,
    -- Warlock
    ["Soulstone Resurrection"] = 30 * 60,
    ["Unending Breath"] = 10 * 60,
    ["Demon Skin"] = 30 * 60,
    ["Demon Armor"] = 30 * 60,
    ["Fire Shield"] = 3 * 60,
    -- Warlock: Offsensive
    ["Corruption"] = 18,
    ["Immolate"] = 15,
    ["Curse of Agony"] = 24,
    ["Curse of Tongues"] = 30,
    ["Curse of Recklessness"] = 2 * 60,
    -- Rogue
    ["Evasion"] = 15,
    -- Hunter
    ["Feign Death"] = 6 * 60,
    ["Deterrence"] = 10,
    ["Rapid Fire"] = 15,
    -- Hunter: Offensive
    ["Hunter's Mark"] = 2 * 60,
    ["Serpent Sting"] = 15,
    ["Scorpid Sting"] = 20,
    ["Viper Sting"] = 8,
    -- Warrior
    ["Battle Shout"] = 2 * 60,
    ["Shield Wall"] = 10, -- 12 with talent
    ["Last Stand"] = 20,
    ["Death Wish"] = 30,
    -- Warrior: Offensive
    ["Rend"] = 21,
    ["Mortal Strike"] = 10,
    -- Racial
    ["Quel'dorei Meditation"] = 5,
    ["Grace of the Sunwell"] = 15,
    ["Blood Fury"] = 25,
    -- Generic
    ["First Aid"] = 8,
    ["Recently Bandaged"] = 60,
    ["Rapid Healing"] = 15,
    -- Emerald Sanctum
    ["Call of Nightmare"] = 10,
    ["Dreamstate"] = 10,
    -- Naxxramas
    ["Veil of Darkness"] = 7,
    -- Misc
    ["Curse of the Deadwood"] = 2 * 60
}
PTLocale.Keys(trackedCastedAuras)
PuppeteerSettings.TrackedCastedAuras = trackedCastedAuras

-- Auras to start the timer for even though they weren't directly casted
local additionalAuras = {
    ["Divine Protection"] = {{"Forbearance", 25771}},
    ["Divine Shield"] = {{"Forbearance", 25771}},
    ["Blessing of Protection"] = {{"Forbearance", 25771}},
    ["Hand of Protection"] = {{"Forbearance", 25771}},
    ["First Aid"] = {{"Recently Bandaged", 11196}},
    ["Power Word: Shield"] = {{"Weakened Soul", 6788}}
}
PTLocale.Keys(additionalAuras)
for _, array in pairs(additionalAuras) do
    for _, entry in ipairs(array) do
        entry[1] = PTLocale.T(entry[1])
    end
end

-- Value is range
local aoeAuras = {
    ["Prayer of Fortitude"] = 100, 
    ["Prayer of Spirit"] = 100, 
    ["Prayer of Shadow Protection"] = 100, 
    ["Arcane Brilliance"] = 100, 
    ["Gift of the Wild"] = 100, 
    ["Battle Shout"] = 20
}
PTLocale.Keys(aoeAuras)

-- Paladins always get their own special stuff..
-- Their buffs are aoe but apply to the whole raid for a specific class
local aoeClassAuras = PTUtil.ToSet({
    "Greater Blessing of Wisdom", "Greater Blessing of Might", "Greater Blessing of Salvation", 
    "Greater Blessing of Sanctuary", "Greater Blessing of Kings", "Greater Blessing of Light"
})
PTLocale.Keys(aoeClassAuras)

local function applyTimedAura(spellName, id, owner, units, duration)
    for _, unit in ipairs(units) do
        if PTUnit.Get(unit) then
            PTUnit.Get(unit):ApplyTimedAura(spellName, id, owner, duration or trackedCastedAuras[spellName], duration ~= nil)
        end
    end
end

local castEventFrame = CreateFrame("Frame", "PTAuraTrackingCasts")
castEventFrame:RegisterEvent("UNIT_CASTEVENT")
castEventFrame:SetScript("OnEvent", function()
    local caster, target, event, spellID, duration = arg1, arg2, arg3, arg4, arg5

    if event == "CAST" or event == "CHANNEL" then
        local spellName = SpellInfo(spellID)
        if trackedCastedAuras[spellName] then
            if target == "" then
                target = caster
            end
            local units = PTGuidRoster.GetUnits(target)
            if not units then
                return
            end
            if aoeAuras[spellName] then
                local targets = PTUtil.GetSurroundingPartyMembers(target, aoeAuras[spellName])
                for _, unit in ipairs(targets) do
                    local units = PTGuidRoster.GetAllUnits(unit)
                    applyTimedAura(spellName, spellID, caster, units)
                end
            elseif aoeClassAuras[spellName] then
                local class = PTUtil.GetClass(target)
                local targets = PTUtil.GetSurroundingRaidMembers(target, 100)
                for _, unit in ipairs(targets) do
                    if PTUtil.GetClass(unit) == class then
                        local units = PTGuidRoster.GetAllUnits(unit)
                        applyTimedAura(spellName, spellID, caster, units)
                    end
                end
            else
                applyTimedAura(spellName, spellID, caster, units)
            end

            if additionalAuras[spellName] then
                for _, aura in ipairs(additionalAuras[spellName]) do
                    applyTimedAura(aura[1], aura[2], caster, units)
                end
            end
        end
    end
end)

if not PTUtil.HasModVersion("Nampower", PTUtil.Nampower_v3_0) then
    return
end

local nampowerAuraFrame = CreateFrame("Frame", "PTNampowerAuras")
nampowerAuraFrame:RegisterEvent("AURA_CAST_ON_SELF")
nampowerAuraFrame:RegisterEvent("AURA_CAST_ON_OTHER")
nampowerAuraFrame:SetScript("OnEvent", function()
    local spellID, caster, target, _, _, _, _, duration = arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8
    if not caster or not target then
        return
    end
    if duration <= 0 then
        return
    end
    applyTimedAura(GetSpellRecField(spellID, "name"), spellID, caster, {target}, duration / 1000)
end)

local inspirationTracker = CreateFrame("Frame", "PTInspirationTracker")
inspirationTracker:RegisterEvent("SPELL_HEAL_BY_SELF")
inspirationTracker:RegisterEvent("SPELL_HEAL_BY_OTHER")
local inspirationProcSpells = PTUtil.ToSet({"Heal", "Greater Heal", "Flash Heal", "Prayer of Healing"})
inspirationTracker:SetScript("OnEvent", function()
    local target, caster, spellID, amount, crit, periodic = arg1, arg2, arg3, arg4, arg5, arg6

    local spellName = GetSpellRecField(spellID, "name")

    if crit == 1 and inspirationProcSpells[spellName] then
        if PTUnit.Get(target) then
            PTUnit.Get(target):ApplyTimedAura(spellName, 15359, caster, 15, true)
        end
    end
end)