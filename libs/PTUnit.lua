-- Caches important information about units and makes the data easily readable at any time.
-- If using SuperWoW, the cache map will have GUIDs as the key instead of unit IDs.

PTUnit = {}
PTUtil.SetEnvironment(PTUnit)
local _G = getfenv(0)

local util = PTUtil
local GetAuraInfo = util.GetAuraInfo
local AllUnits = util.AllUnits
local AllRealUnits = util.AllRealUnits
local AllUnitsSet = util.AllUnitsSet
local superwow = util.IsSuperWowPresent()
local canGetAuraIDs = util.CanClientGetAuraIDs()

local compost = AceLibrary("Compost-2.0")

-- Non-instance variable
-- Key: Unit ID(Unmodded) or GUID(SuperWoW) | Value: PTUnit Instance
PTUnit.Cached = {}

PTUnit.Unit = nil

PTUnit.AurasPopulated = false
-- Buff/debuff entry contents: {"name", "stacks", "texture", "index", "type", "id"(SuperWoW only)}
PTUnit.Buffs = {} -- Array of all buffs
PTUnit.BuffsMap = {} -- Key: Name | Value: Array of buffs with key's name
PTUnit.BuffsIDSet = {} -- Set of currently applied buff IDs
PTUnit.Debuffs = {} -- Array of all debuffs
PTUnit.DebuffsMap = {} -- Key: Name | Value: Array of debuffs with key's name
PTUnit.DebuffsIDSet = {} -- Set of currently applied debuff IDs
PTUnit.TypedDebuffs = {} -- Key: Type | Value: Array of debuffs that are the type
PTUnit.AfflictedDebuffTypes = {} -- Set of the afflicted debuff types
PTUnit.TrackedDebuffTypes = {} -- Set of debuff types that exclude frivilous debuffs

PTUnit.HasHealingModifier = false
PTUnit.HasImportantDebuff = false

-- Only used with SuperWoW, managed in AuraTracker.lua
PTUnit.AuraTimes = {} -- Key: Aura Name | Value: {"startTime", "duration"}
PTUnit.AuraTimesByName = {}

PTUnit.DisplayPVP = false -- This is not the real PVP status of the unit, this is affected by other conditions

PTUnit.Distance = 0
PTUnit.InSight = true
PTUnit.IsNew = false

-- Non-GUID function
function CreateCaches()
    if superwow then
        Puppeteer.print("Tried to create non-SuperWoW caches while using SuperWoW!")
        return
    end
    for _, unit in ipairs(AllUnits) do
        PTUnit:New(unit)
    end
end

function UpdateGuidCaches()
    local cached = PTUnit.Cached
    local prevCached = PTUtil.CloneTableCompost(cached)
    for _, unit in ipairs(AllRealUnits) do
        local exists, guid = UnitExists(unit)
        if exists then
            if not cached[guid] then
                PTUnit:New(guid)
                Puppeteer.EvaluateTracking(unit, true)
            end
            prevCached[guid] = nil
        end
    end
    for guid, units in pairs(PTUnitProxy.GUIDCustomUnitMap) do
        if not cached[guid] then
            PTUnit:New(guid)
            for _, unit in ipairs(units) do
                Puppeteer.EvaluateTracking(unit, true)
            end
        end
        prevCached[guid] = nil
    end
    for garbageGuid, cache in pairs(prevCached) do
        cache:Dispose()
        compost:Reclaim(cache)
        cached[garbageGuid] = nil
    end
    compost:Reclaim(prevCached)
end

-- Likely never needed to be called when using GUIDs
function UpdateAllUnits()
    for _, cache in pairs(PTUnit.Cached) do
        cache:UpdateAll()
    end
end

-- Get the PTUnit by unit ID. If using SuperWoW, GUID or unit ID is accepted.
function Get(unit)
    if superwow and AllUnitsSet[unit] then
        return PTUnit.Cached[PTGuidRoster.GetUnitGuid(unit)] or PTUnit
    end
    return PTUnit.Cached[unit] or PTUnit
end

function GetAllUnits()
    return PTUnit.Cached
end

function PTUnit:New(unit)
    local obj = compost:AcquireHash("Unit", unit)
    setmetatable(obj, self)
    self.__index = self
    PTUnit.Cached[unit] = obj
    obj:AllocateAuras()
    obj.AurasPopulated = true -- To force aura fields to generate
    obj.IsNew = true
    obj.IsSelf = UnitIsUnit(unit, "player")
    if superwow then
        obj.AuraTimes = compost:GetTable()
        obj.AuraTimesByName = compost:GetTable()
    end
    obj:UpdateAll()
    return obj
end

function PTUnit:Dispose()
    compost:Reclaim(self.Buffs, 1)
    compost:Reclaim(self.BuffsMap, 1)
    compost:Reclaim(self.BuffsIDSet)
    compost:Reclaim(self.Debuffs, 1)
    compost:Reclaim(self.DebuffsMap, 1)
    compost:Reclaim(self.DebuffsIDSet)
    compost:Reclaim(self.TypedDebuffs, 1)
    compost:Reclaim(self.AfflictedDebuffTypes)
    compost:Reclaim(self.TrackedDebuffTypes)
    util.CompostReclaim(self.AuraTimes)
    compost:Reclaim(self.AuraTimesByName)
end

function PTUnit:UpdateAll()
    self:UpdateAuras()
    self:UpdatePVP()
    self:UpdateDistance()
    self:UpdateSight()
end

-- Returns true if this unit is new, clearing its new status.
function PTUnit:CheckNew()
    if self.IsNew then
        self.IsNew = false
        return true
    end
end

function PTUnit:UpdatePVP()
    if not self.Unit then
        return
    end
    local shouldDisplay = UnitIsPVP(self.Unit) and (not util.IsReallyInInstance() or not UnitIsVisible(self.Unit))
    if self.DisplayPVP ~= (shouldDisplay == 1 or shouldDisplay == true) then
        self.DisplayPVP = shouldDisplay
        return true
    end
    return false
end

function PTUnit:ShouldDisplayPVP()
    return self.DisplayPVP
end

-- Returns true if the distance changed
function PTUnit:UpdateDistance()
    if not self.Unit then
        return
    end
    local prevDist = self.Distance
    self.Distance = self.IsSelf and 0 or util.GetDistanceTo(self.Unit)

    return self.Distance ~= prevDist
end

function PTUnit:GetDistance()
    return self.Distance
end

-- Returns true if the sight state has changed
function PTUnit:UpdateSight()
    if not self.Unit then
        return
    end
    local wasInSight = self.InSight
    self.InSight = self.IsSelf or util.IsInSight(self.Unit)

    return self.InSight ~= wasInSight
end

function PTUnit:IsInSight()
    return self.InSight
end

function PTUnit:IsBeingResurrected()
    if not self.Unit then
        return false
    end
    if PTHealPredict then
        return PTHealPredict.IsBeingResurrected(self.Unit)
    end
    return Puppeteer.HealComm:UnitisResurrecting(UnitName(self.Unit))
end

function PTUnit:GetResurrectionCasts()
    if not self.Unit then
        return 0
    end
    if PTHealPredict then
        return PTHealPredict.GetResurrectionCount(self.Unit)
    end
    return Puppeteer.HealComm:UnitisResurrecting(UnitName(self.Unit)) and 1 or 0
end

function PTUnit:AllocateAuras()
    self.Buffs = compost:GetTable()
    self.BuffsMap = compost:GetTable()
    self.BuffsIDSet = compost:GetTable()
    self.Debuffs = compost:GetTable()
    self.DebuffsMap = compost:GetTable()
    self.DebuffsIDSet = compost:GetTable()
    self.TypedDebuffs = compost:GetTable()
    self.AfflictedDebuffTypes = compost:GetTable()
    self.TrackedDebuffTypes = compost:GetTable()
end

function PTUnit:ClearAuras()
    if not self.AurasPopulated or self == PTUnit then
        return
    end
    compost:Reclaim(self.Buffs, 1)
    compost:Reclaim(self.BuffsMap, 1)
    compost:Erase(self.BuffsIDSet)
    compost:Reclaim(self.Debuffs, 1)
    compost:Reclaim(self.DebuffsMap, 1)
    compost:Erase(self.DebuffsIDSet)
    compost:Reclaim(self.TypedDebuffs, 1)
    compost:Erase(self.AfflictedDebuffTypes)
    compost:Erase(self.TrackedDebuffTypes)
    self.Buffs = compost:GetTable()
    self.BuffsMap = compost:GetTable()
    self.Debuffs = compost:GetTable()
    self.DebuffsMap = compost:GetTable()
    self.TypedDebuffs = compost:GetTable()
    self.HasHealingModifier = false
    self.AurasPopulated = false
    self.HasImportantDebuff = false
end

local claimedAuras = {}
function PTUnit:UpdateAuras()
    local unit = self.Unit

    if not unit then
        return
    end

    Puppeteer.StartTiming("PTUnitAuraUpdate")

    self:ClearAuras()

    if not UnitExists(unit) then
        Puppeteer.EndTiming("PTUnitAuraUpdate")
        return
    end

    local buffs = self.Buffs
    local buffsMap = self.BuffsMap
    local buffsIDSet = self.BuffsIDSet
    local time = GetTime()
    for index = 1, 32 do
        local texture, stacks, id = UnitBuff(unit, index)
        if not texture then
            break
        end
        local name, type = GetAuraInfo(unit, index, "Buff", id)
        if PuppeteerSettings.TrackedHealingBuffs[name] then
            self.HasHealingModifier = true
        end
        local auraTime = nil
        if id and self.AuraTimes[id] then
            local auraTimes = self.AuraTimes[id]
            local highestDuration = -100
            for owner, aura in pairs(auraTimes) do
                local timeLeft = aura.endTime - time
                if not claimedAuras[aura] and timeLeft > highestDuration then
                    auraTime = aura
                    highestDuration = timeLeft
                end
            end
            if auraTime then
                claimedAuras[auraTime] = 1
            end
        end
        local buff = compost:AcquireHash("name", name, "index", index, "texture", texture, "stacks", stacks, "type", type, "id", id, "time", auraTime)
        if not buffsMap[name] then
            buffsMap[name] = compost:GetTable()
        end
        if id ~= nil then
            buffsIDSet[id] = true
        end
        table.insert(buffsMap[name], buff)
        table.insert(buffs, buff)
    end

    local afflictedDebuffTypes = self.AfflictedDebuffTypes
    local trackedDebuffTypes = self.TrackedDebuffTypes
    local debuffs = self.Debuffs
    local debuffsMap = self.DebuffsMap
    local debuffsIDSet = self.DebuffsIDSet
    local typedDebuffs = self.TypedDebuffs -- Dispellable debuffs
    for index = 1, 16 do
        local texture, stacks, type, id = UnitDebuff(unit, index)
        if not texture then
            break
        end
        type = type or ""
        local name = GetAuraInfo(unit, index, "Debuff", id)
        if PuppeteerSettings.TrackedHealingDebuffs[name] then
            self.HasHealingModifier = true
        end
        if PuppeteerSettings.ImportantDebuffs[name] then
            self.HasImportantDebuff = true
        end
        local auraTime = nil
        if id and self.AuraTimes[id] then
            local auraTimes = self.AuraTimes[id]
            local highestDuration = -100
            for owner, aura in pairs(auraTimes) do
                local timeLeft = aura.endTime - time
                if not claimedAuras[aura] and timeLeft > highestDuration then
                    auraTime = aura
                    highestDuration = timeLeft
                end
            end
            if auraTime then
                claimedAuras[auraTime] = 1
            end
        end
        local debuff = compost:AcquireHash("name", name, "index", index, "texture", texture, "stacks", stacks, "type", type, "id", id, "time", auraTime)
        if not debuffsMap[name] then
            debuffsMap[name] = compost:GetTable()
        end
        if id ~= nil then
            debuffsIDSet[id] = true
        end
        table.insert(debuffsMap[name], debuff)
        if type ~= "" then
            afflictedDebuffTypes[type] = 1
            if not PuppeteerSettings.IgnoredDispellableDebuffs[name] then
                trackedDebuffTypes[type] = 1
            end
            if not typedDebuffs[type] then
                typedDebuffs[type] = compost:GetTable()
            end
            table.insert(typedDebuffs[type], debuff)
        end
        table.insert(debuffs, debuff)
    end
    self.AurasPopulated = true
    util.ClearTable(claimedAuras)
    Puppeteer.EndTiming("PTUnitAuraUpdate")
end

function PTUnit:HasBuff(name)
    return self.BuffsMap[name] ~= nil
end

-- SuperWoW/Turtle WoW only
function PTUnit:HasBuffID(id)
    return self.BuffsIDSet[id] ~= nil
end

-- Looks for ID if SuperWoW/Turtle WoW is present, otherwise searches by name
function PTUnit:HasBuffIDOrName(id, name)
    if canGetAuraIDs then
        return self:HasBuffID(id)
    end
    return self:HasBuff(name)
end

function PTUnit:HasDebuff(name)
    return self.DebuffsMap[name] ~= nil
end

-- SuperWoW/Turtle WoW only
function PTUnit:HasDebuffID(id)
    return self.DebuffsIDSet[id] ~= nil
end

-- Looks for ID if SuperWoW/Turtle WoW is present, otherwise searches by name
function PTUnit:HasDebuffIDOrName(id, name)
    if canGetAuraIDs then
        return self:HasDebuffID(id)
    end
    return self:HasDebuff(name)
end

function PTUnit:HasDebuffType(type)
    return self.AfflictedDebuffTypes[type]
end

function PTUnit:HasTrackedDebuffType(type)
    return self.TrackedDebuffTypes[type]
end

-- Returns the first buff with the provided name
function PTUnit:GetBuff(name)
    if not self:HasBuff(name) then
        return
    end
    return self.BuffsMap[name][1]
end

-- Returns the table of all buffs with the provided name
function PTUnit:GetBuffs(name)
    return self.BuffsMap[name]
end

function PTUnit:GetDebuff(name)
    if not self:HasDebuff(name) then
        return
    end
    return self.DebuffsMap[name][1]
end

function PTUnit:GetDebuffs(name)
    return self.DebuffsMap[name]
end

function PTUnit:ApplyTimedAura(spellName, spellID, owner, duration, isNampower)
    if not self.AuraTimes[spellID] then
        self.AuraTimes[spellID] = compost:GetTable()
    end
    if not self.AuraTimesByName[spellName] then
        self.AuraTimesByName[spellName] = compost:GetTable()
    end
    duration = duration or 0
    local time = GetTime()
    local entry = compost:AcquireHash(
        "startTime", time,
        "endTime", time + duration,
        "duration", duration,
        "owner", owner,
        "ownerName", UnitName(owner),
        "nampower", isNampower ~= nil and isNampower ~= false
    )
    if self.AuraTimes[spellID][owner] then
        compost:Reclaim(self.AuraTimes[spellID][owner])
    end
    self.AuraTimes[spellID][owner] = entry
    self.AuraTimesByName[spellName] = entry

    self:UpdateAuras()
    for ui in Puppeteer.UnitFrames(self.Unit) do
        ui:UpdateAuras()
    end
end

function PTUnit:GetAuraTimeRemaining(name)
    if not superwow then
        return
    end
    local auraTime = self.AuraTimesByName[name]
    if not auraTime then
        return
    end
    return auraTime.startTime - GetTime() + auraTime.duration
end