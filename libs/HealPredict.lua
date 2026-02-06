-- Predicts healing based on previously seen healing.
-- This library currently is not independent and relies on some Puppeteer code.

if not PTUtil.IsSuperWowPresent() then
    return
end

PTHealPredict = {}
PTUtil.SetEnvironment(PTHealPredict)
local _G = getfenv(0)

local compost = AceLibrary("Compost-2.0")

RelevantGUIDs = {} -- A set of GUIDs to listen to

IncomingHeals = {} -- Key: Receiver | Value: List of incoming casts
IncomingHots = {} -- Key: Receiver | Value: {HoT Name: {"caster", "id", "heal"}}
Casts = {} -- Key: Caster | Value: {"targets", "spellID", "startTime"}
LastCastedSpells = {}

-- A cache of expected heal values for spells. These values are saved.
-- Key: Spell ID | Value: Typical heal value for the spell ID
HealCache = {}

-- Since every healer heals for different values based on talents and gear,
-- everyone's heal values are cached
-- Key: Name | Value: Array: {Spell ID: Heal value}
PlayerHealCache = {}

ResurrectionTargets = {} -- Key: Receiver | Value: {Caster: {"startTime", "castTime"}}

-- An array of functions that listen to changes to incoming healing
Listeners = {}

local print
local colorize = PTUtil.Colorize

local PRAYER_OF_HEALING_IDS = PTUtil.ToSet({596, 996, 10960, 10961, 25316})
local ResurrectionSpells = PTUtil.ToSet({
    "Resurrection", "Revive Champion", "Redemption", "Ancestral Spirit", "Rebirth"
})
PTLocale.Keys(ResurrectionSpells)

local TRACKED_HOTS = PTUtil.ToSet({
    "Rejuvenation", "Regrowth", -- Druid
    "Renew", -- Priest
    "Mend Pet", -- Hunter
    "First Aid" -- Generic
})
PTLocale.Keys(TRACKED_HOTS)

function OnLoad()
    print = Puppeteer.print
    if not PTHealCache then
        setglobal("PTHealCache", {})
    end
    HealCache = PTHealCache

    local hardcodedHots = {
        -- Bandages
        [746] = 11, -- Linen
        [1159] = 19, -- Heavy Linen
        [3267] = 23, -- Wool
        [3268] = 43, -- Heavy Wool
        [7926] = 50, -- Silk
        [7927] = 80, -- Heavy Silk
        [10838] = 100, -- Mageweave
        [10839] = 138, -- Heavy Mageweave
        [18608] = 170, -- Runecloth
        [18610] = 250, -- Heavy Runecloth
        -- Mend Pet
        [136] = 20,
        [3111] = 38,
        [3661] = 68,
        [3662] = 103,
        [13542] = 142,
        [13543] = 189,
        [13544] = 245
    }
    for k, v in pairs(hardcodedHots) do
        HealCache[k.."-HoT"] = v
    end

    if not PTPlayerHealCache then
        setglobal("PTPlayerHealCache", {})
    end
    if not PTPlayerHealCache[GetRealmName()] then
        PTPlayerHealCache[GetRealmName()] = {}
    end
    PlayerHealCache = PTPlayerHealCache[GetRealmName()]
end

-- Get the expected heal of a player's spell
function GetExpectedHeal(playerName, spellID)
    local playerCache = PlayerHealCache[playerName]
    if not playerCache or not playerCache[spellID] then
        return GetGenericExpectedHeal(spellID)
    end
    return playerCache[spellID]
end

function GetGenericExpectedHeal(spellID)
    return HealCache[spellID] or 0
end

-- Returns all incoming healing and incoming direct healing
function GetIncomingHealing(guid)
    local healing = 0
    local casts = IncomingHeals[guid]
    if casts then
        for _, cast in pairs(casts) do
            healing = healing + cast["heal"]
        end
    end
    local directHealing = healing
    local hots = IncomingHots[guid]
    if hots then
        for _, hot in pairs(hots) do
            healing = healing + hot["heal"]
        end
    end
    return healing, directHealing
end

-- Returns non-HoT incoming healing
function GetIncomingDirectHealing(guid)
    local healing = 0
    local casts = IncomingHeals[guid]
    if casts then
        for _, cast in pairs(casts) do
            healing = healing + cast["heal"]
        end
    end
    return healing
end

-- To mimick HealComm, but this currently only accepts GUIDs
function getHeal(guid)
    return GetIncomingHealing(guid)
end

function IsBeingResurrected(guid)
    return ResurrectionTargets[guid] ~= nil
end

function GetResurrectionCount(guid)
    local resses = ResurrectionTargets[guid]
    if not resses then
        return 0
    end
    local count = 0
    for _ in pairs(resses) do
        count = count + 1
    end
    return count
end

-- Used for Prayer of Healing to add incoming healing to multiple players
function AddIncomingMultiCast(targets, caster, spellID, healAmount, castTime)
    Casts[caster] = compost:AcquireHash(
        "targets", targets,
        "spellID", spellID,
        "startTime", GetTime()
    )
    for _, target in ipairs(targets) do
        AddIncomingCast(target, caster, spellID, healAmount, castTime, true)
    end
end

local castIcons = {}
function RemoveAllCastIcons()
    for caster, icons in pairs(castIcons) do
        for _, icon in ipairs(castIcons[caster]) do
            icon:End(false)
        end
        compost:Recycle(icons)
        castIcons[caster] = nil
    end
end

function AddIncomingCast(target, caster, spellID, healAmount, castTime, multi)
    if not multi then
        Casts[caster] = compost:AcquireHash(
            "targets", compost:Acquire(target),
            "spellID", spellID,
            "startTime", GetTime()
        )
    end
    local targetTable = IncomingHeals[target]
    if not targetTable then
        targetTable = {}
        IncomingHeals[target] = targetTable
    end
    targetTable[caster] = compost:AcquireHash(
        "spellID", spellID,
        "heal", healAmount,
        "castTime", castTime,
        "startTime", GetTime()
    )

    UpdateTarget(target)


    if PuppeteerSettings.IsExperimentEnabled("CastIcons") then
        local spellName, _, tex = SpellInfo(spellID)
        local targetFrame
        for f in Puppeteer.UnitFrames(target) do
            if f.owningGroup:GetContainer():IsShown() then
                targetFrame = f
                break
            end
        end
        if not targetFrame then
            return
        end
        local icon = PTGuiLib.Get("puppeteer_cast_icon")
        icon:Start(spellName, tex, castTime / 1000, caster, healAmount, targetFrame)
        if not castIcons[caster] then
            castIcons[caster] = compost:GetTable()
        end
        table.insert(castIcons[caster], icon)
    end
end

function RemoveIncomingCast(caster, successful)
    local cast = Casts[caster]
    if cast then
        for _, target in ipairs(cast["targets"]) do
            local incomingHeals = IncomingHeals[target]
            compost:Reclaim(incomingHeals[caster])
            incomingHeals[caster] = nil
            UpdateTarget(target)
        end
        compost:Reclaim(cast["targets"])
        compost:Reclaim(cast)
        Casts[caster] = nil

        if castIcons[caster] then
            for _, icon in ipairs(castIcons[caster]) do
                icon:End(successful)
            end
            compost:Reclaim(castIcons[caster])
            castIcons[caster] = nil
        end
    end
end

function GetCurrentCast(caster)
    local cast = Casts[caster]
    if cast then
        return IncomingHeals[cast["targets"][1]][caster]
    end
end

function AddHot(target, caster, spellID, spellName, healAmount)
    local hot = compost:AcquireHash(
        "caster", caster,
        "id", spellID,
        "heal", healAmount,
        "startTime", GetTime()
    )
    local targetTable = IncomingHots[target]
    if not targetTable then
        targetTable = {}
        IncomingHots[target] = targetTable
    end
    targetTable[spellName] = hot

    UpdateTarget(target)
end

function UpdateTarget(target)
    for _, listener in ipairs(Listeners) do
        listener(target, GetIncomingHealing(target))
    end
end

local function trimDecimal(number, places)
    local factor = 10 ^ places
    return math.floor(number * factor) / factor
end

local GENERIC_CHANGE_FACTOR = 0.05
local PLAYER_CHANGE_FACTOR = 0.25
function UpdateCache(heal, name)
    name = name or UnitName("player")
    local lastCastedSpell = LastCastedSpells[name]
    LastCastedSpells[name] = nil

    if not lastCastedSpell then
        return
    end

    local spellID = lastCastedSpell["spellID"]

    if not PRAYER_OF_HEALING_IDS[spellID] then
        if lastCastedSpell["target"] == "" then
            --print(colorize("Don't have a target of spell cast for "..name.."'s "..spellID, 1, 0, 0))
            return
        end
        local cache = PTUnit.Get(lastCastedSpell["target"])
        if not cache or cache == PTUnit then
            --print(colorize("Could not find "..name.."'s unit while updating cache!", 1, 0, 0))
            return
        end
        if cache.HasHealingModifier then
            --print(colorize("Not updating cache for "..name.."'s "..spellID.." because of healing modifier", 0.5, 0.5, 0.5))
            return
        end
    end

    -- Update the generic cache
    if not HealCache[spellID] then
        HealCache[spellID] = heal
    else
        local prevHeal = HealCache[spellID]
        local adjustedHeal = trimDecimal(prevHeal + ((heal - prevHeal) * GENERIC_CHANGE_FACTOR), 2)
        HealCache[spellID] = adjustedHeal
        print(colorize("Generic "..spellID..": "..prevHeal.." -> "..adjustedHeal, 0, 0.8, 0.8))
    end

    if not PlayerHealCache[name] then
        PlayerHealCache[name] = {}
    end
    -- Update the player-specific cache
    local playerCache = PlayerHealCache[name]
    if not playerCache[spellID] then
        playerCache[spellID] = heal
        print(colorize("Created cache for "..name.."'s "..spellID, 1, 0.5, 1))
    end
    local prevHeal = playerCache[spellID]
    local adjustedHeal = trimDecimal(prevHeal + ((heal - prevHeal) * PLAYER_CHANGE_FACTOR), 2)
    playerCache[spellID] = adjustedHeal
    playerCache["lastSeen"] = time()

    compost:Reclaim(lastCastedSpell)
    print(colorize(name.."'s "..spellID..": "..prevHeal.." -> "..adjustedHeal, 0, 0.8, 0.2))
end

function UpdateCacheHot(spellName, heal, targetGuid, targetName, casterGuid, casterName)
    if not IncomingHots[targetGuid] then
        return
    end
    local hots = IncomingHots[targetGuid]
    if not hots[spellName] then
        return
    end
    heal = tonumber(heal) or 0
    local hot = hots[spellName]
    if hot["heal"] ~= heal then
        local prevHeal = hot["heal"]
        hot["heal"] = heal
        UpdateTarget(targetGuid)
        if not PlayerHealCache[casterName] then
            PlayerHealCache[casterName] = {}
        end
        local spellID = hot["id"]

        local cache = PTUnit.Get(targetGuid)
        if not cache or cache == PTUnit then
            print(colorize("Could not find "..targetName.."'s unit while updating cache!", 1, 0, 0))
            return
        end
        if cache.HasHealingModifier then
            print(colorize("Not updating cache for "..casterName.."'s "..spellID.." because of healing modifier", 0.5, 0.5, 0.5))
            return
        end
        -- Update the player-specific cache
        local playerCache = PlayerHealCache[casterName]
        spellID = spellID.."-HoT"
        if not playerCache[spellID] then
            playerCache[spellID] = heal
            print(colorize("Created cache for "..casterName.."'s "..spellID.." ("..spellName..")", 1, 0.5, 1))
        end
        PlayerHealCache[casterName][spellID] = heal
        print(colorize(casterName.."'s "..spellID.." ("..spellName..")"..": "..prevHeal.." -> "..heal, 0, 0.8, 0.2))
    end
end

function RemoveHoT(spellName, targetGuid)
    if not IncomingHots[targetGuid] then
        return
    end
    if not IncomingHots[targetGuid][spellName] then
        return
    end
    local hot = IncomingHots[targetGuid][spellName]
    -- A hack needed because overwritten HoTs cause the previous HoT to be removed,
    -- which happens after the UNIT_CASTEVENT
    if hot["startTime"] + 0.5 > GetTime() and not hot["swiftmend"] then
        return
    end
    compost:Reclaim(hot)
    IncomingHots[targetGuid][spellName] = nil
    UpdateTarget(targetGuid)
end

local roster = AceLibrary("RosterLib-2.0")
local function getGuidFromLogName(name)
    local petName, owner = PTUtil.cmatch(name, "%s (%s)")
    local unit
    if owner then -- A pet is being healed
        local ownerUnit = roster:GetUnitIDFromName(owner)
        if not ownerUnit then
            return
        end
        unit = roster:GetPetFromOwner(ownerUnit)
    else
        unit = roster:GetUnitIDFromName(name)
    end
    if not unit then
        -- Check custom units
        for _, guid in pairs(PTUnitProxy.CustomUnitGUIDMap) do
            if UnitName(guid) == name then
                return guid
            end
        end
    end
    if unit then
        local _, guid = UnitExists(unit)
        return guid
    end
end

local function getSelfGuid()
    local _, guid = UnitExists("player")
    return guid
end

local autoShotName = PTLocale.Translate("Auto Shot")

local eventFrame = CreateFrame("Frame", "PTHealPredictCasts")
eventFrame:RegisterEvent("UNIT_CASTEVENT")
eventFrame:SetScript("OnEvent", function()
    local caster, target, event, spellID, duration = arg1, arg2, arg3, arg4, arg5

    if not RelevantGUIDs[caster] then
        return
    end

    if not UnitIsPlayer(caster) then
        return
    end

    local spellName = SpellInfo(spellID)

    if ResurrectionSpells[spellName] then
        if event == "START" then
            if target then
                if not ResurrectionTargets[target] then
                    ResurrectionTargets[target] = compost:GetTable()
                end
                local resses = ResurrectionTargets[target]
                resses[caster] = compost:AcquireHash("startTime", GetTime(), "castTime", duration)
            end
        elseif event == "CAST" or event == "FAIL" then
            local cast = Casts[caster]
            if cast then
                local target = cast["targets"][1]
                local resses = ResurrectionTargets[target]
                if resses and resses[caster] then
                    compost:Reclaim(resses[caster])
                    resses[caster] = nil
                    
                    if not next(resses) then
                        compost:Reclaim(resses)
                        ResurrectionTargets[target] = nil
                    end
                end
            end
        end
        UpdateTarget(target)
    end

    if event == "CAST" or event == "CHANNEL" then
        -- Swiftmend could cause Rejuvenation or Regrowth to end very quickly, 
        -- so there needs to be a flag to allow the removal of the HoT
        if spellName == "Swiftmend" then
            if IncomingHots[target] then
                local hots = IncomingHots[target]
                if hots["Rejuvenation"] then
                    hots["Rejuvenation"]["swiftmend"] = true
                end
                if hots["Regrowth"] then
                    hots["Regrowth"]["swiftmend"] = true
                end
            end
        end

        if TRACKED_HOTS[spellName] then
            if spellName == "Mend Pet" then -- Mend pet doesn't "target" the pet, so we have to acquire the pet
                local units = PTGuidRoster.GetUnits(caster)
                if not units then
                    return
                end
                local casterUnit = units[1]
                if not casterUnit then
                    return
                end
                local petUnit = roster:GetPetFromOwner(casterUnit)
                if not petUnit then
                    return
                end
                local _, guid = UnitExists(petUnit)
                target = guid
            end
            AddHot(target, caster, spellID, spellName, GetExpectedHeal(UnitName(caster), spellID.."-HoT"))
        end
    end

    -- Check started cast spell ID to prevent instant mid-cast spells from removing incoming healing
    local currentCast = GetCurrentCast(caster)
    if event == "CAST" and currentCast and currentCast["spellID"] == spellID then
        RemoveIncomingCast(caster, true)
        LastCastedSpells[UnitName(caster)] = compost:AcquireHash("unit", caster, "target", target, "spellID", spellID)
        return
    end

    if event == "START" or event == "FAIL" then
        if spellName ~= autoShotName then -- Don't remove the cast when Auto Shot fails
            RemoveIncomingCast(caster, event == "START")
        end
    end

    if event == "START" then
        if target and target ~= "" and UnitCanAssist(caster, target) and duration > 0 then
            local casterName = UnitName(caster)
            local expectedHeal = GetExpectedHeal(casterName, spellID)
            AddIncomingCast(target, caster, spellID, expectedHeal, duration)
        elseif PRAYER_OF_HEALING_IDS[spellID] then
            local inRange = PTUtil.GetSurroundingPartyMembers(caster)
            local casterName = UnitName(caster)
            local expectedHeal = GetExpectedHeal(casterName, spellID)
            AddIncomingMultiCast(inRange, caster, spellID, expectedHeal, duration)
        end
    end
end)
-- Because the prediction code is not currently bullet-proof to infinite incoming heals, we're checking once a while for old casts
local GARBAGE_CHECK_INTERVAL = 10
local nextGarbageCheck = GetTime() + GARBAGE_CHECK_INTERVAL
eventFrame:SetScript("OnUpdate", function()
    if GetTime() > nextGarbageCheck then
        local time = GetTime()
        nextGarbageCheck = time + GARBAGE_CHECK_INTERVAL

        for receiver, casts in pairs(IncomingHeals) do
            for caster, cast in pairs(casts) do
                if cast["startTime"] + 15 < time then
                    print(colorize("Removed "..caster.."'s heal on "..receiver.." for taking too long", 1, 0, 0))
                    compost:Reclaim(cast)
                    casts[caster] = nil
                    UpdateTarget(receiver)
                end
            end
        end

        for receiver, hots in pairs(IncomingHots) do
            for name, hot in pairs(hots) do
                if hot["startTime"] + 25 < time then
                    print(colorize("Removed "..hot["caster"].."'s "..name.." (HoT) on "..
                        receiver.." for taking too long", 1, 0, 0))
                    compost:Reclaim(hot)
                    hots[name] = nil
                    UpdateTarget(receiver)
                end
            end
        end

        for target, resses in pairs(ResurrectionTargets) do
            for caster, res in pairs(resses) do
                if res["startTime"] + 20 < time then
                    print(colorize("Removed "..caster.."'s resurrection on "..
                        target.." for taking too long", 1, 0, 0))
                    compost:Reclaim(res)
                    resses[caster] = nil
                    ResurrectionTargets[target] = nil
                    UpdateTarget(target)
                end
            end
            if not ResurrectionTargets[target] then -- Must've been removed
                compost:Reclaim(resses)
            end
        end
    end
end)

local cmatch = PTUtil.cmatch

local combatLogFrame = CreateFrame("Frame", "PTHealPredictCombatLog")
combatLogFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
combatLogFrame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
combatLogFrame:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF") -- Needed to see casts coming from other players to yourself
combatLogFrame:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF")
combatLogFrame:RegisterEvent("CHAT_MSG_SPELL_PET_BUFF")
combatLogFrame:SetScript("OnEvent", function()
    if string.find(arg1, "critically") then
        return
    end

    if string.find(arg1, "Bonus Healing") then
        return
    end

    local spell, targetName, heal = cmatch(arg1, HEALEDSELFOTHER) -- "Your %s heals %s for %d."
    if spell and targetName and heal then
        UpdateCache(tonumber(heal))
        return
    end

    local spell, heal = cmatch(arg1, HEALEDSELFSELF) -- "Your %s heals you for %d."
    if spell and heal then
        UpdateCache(tonumber(heal))
        return
    end

    local name, spell, heal = cmatch(arg1, HEALEDOTHERSELF) -- "%s's %s heals you for %d."
    if name and spell and heal then
        UpdateCache(tonumber(heal), name)
        return
    end

    local name, spell, targetName, heal = cmatch(arg1, HEALEDOTHEROTHER) -- "%s's %s heals %s for %d."
    if name and spell and targetName and heal then
        UpdateCache(tonumber(heal), name)
        return
    end
end)

local periodicCombatLogFrame = CreateFrame("Frame", "PTHealPredictPerCombatLog")
periodicCombatLogFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
periodicCombatLogFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS")
periodicCombatLogFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS")
periodicCombatLogFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS")
periodicCombatLogFrame:SetScript("OnEvent", function()
    local heal, spell = cmatch(arg1, PERIODICAURAHEALSELFSELF) -- "You gain %d health from %s."
    if heal and spell then
        local selfName = UnitName("player")
        local selfGuid = getSelfGuid()
        UpdateCacheHot(spell, heal, selfGuid, selfName, selfGuid, selfName)
        return
    end

    local name, heal, spell = cmatch(arg1, PERIODICAURAHEALSELFOTHER) -- "%s gains %d health from your %s."
    if name and heal and spell then
        local casterGuid = getSelfGuid()
        local targetGuid = getGuidFromLogName(name)
        UpdateCacheHot(spell, heal, targetGuid, name, casterGuid, UnitName(casterGuid))
        return
    end

    local heal, name, spell = cmatch(arg1, PERIODICAURAHEALOTHERSELF) -- "You gain %d health from %s's %s."
    if heal and name and spell then
        local casterGuid = getGuidFromLogName(name)
        local targetGuid = getSelfGuid()
        UpdateCacheHot(spell, heal, targetGuid, UnitName("player"), casterGuid, name)
        return
    end

    local targetName, heal, name, spell = cmatch(arg1, PERIODICAURAHEALOTHEROTHER) -- "%s gains %d health from %s's %s."
    if targetName and heal and name and spell then
        local casterGuid = getGuidFromLogName(name)
        local targetGuid = getGuidFromLogName(targetName)
        UpdateCacheHot(spell, heal, targetGuid, targetName, casterGuid, name)
        return
    end
end)

local auraCombatLogFrame = CreateFrame("Frame", "PTHealPredictAuraCombatLog")
auraCombatLogFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER")
auraCombatLogFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_PARTY")
auraCombatLogFrame:SetScript("OnEvent", function()
    local spell, name = cmatch(arg1, AURAREMOVEDOTHER) -- "%s fades from %s."
    if spell and name then
        local guid = getGuidFromLogName(name)
        if not guid then
            return
        end
        RemoveHoT(spell, guid)
        return
    end
end)

local selfAuraCombatLogFrame = CreateFrame("Frame", "PTHealPredictSelfAuraCombatLog")
selfAuraCombatLogFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
selfAuraCombatLogFrame:SetScript("OnEvent", function()
    local spell = cmatch(arg1, AURAREMOVEDSELF) -- "%s fades from you."
    if spell then
        RemoveHoT(spell, getSelfGuid())
        return
    end
end)

-- Set the GUIDs to listen to
function SetRelevantGUIDs(guidArray)
    RelevantGUIDs = PTUtil.ToSet(guidArray)
end

-- Provided listener function will receive the arguments: Updated GUID, Updated Incoming Healing
function HookUpdates(listener)
    table.insert(Listeners, listener)
end
