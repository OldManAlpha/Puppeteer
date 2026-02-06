-- Proxy unit functions that resolve custom units to their GUIDs before doing what they do.
-- One might say you'd be insane to do this just to have custom units, and you'd be correct.

-- SuperWoW check, can't rely on PTUtil because it depends on this file
if SpellInfo == nil then
    return
end

PTUnitProxy = {}
local _G = getfenv(0)
setmetatable(PTUnitProxy, {__index = getfenv(1)})
setfenv(1, PTUnitProxy)

local compost = AceLibrary("Compost-2.0")

-- Unit data

CustomUnitTypes = {} -- Array of custom unit types(ex: "focus")
CustomUnitTypesSet = {} -- Set of custom unit types

CustomUnitsTypeMap = {} -- Key: Custom unit(ex: "focus5") | Value: Unit type(ex: "focus")

CustomUnitsMap = {} -- Key: Type(ex: "focus") | Value: Array of all units
CustomUnitsSetMap = {} -- Key: Type(ex: "focus") | Value: Set of all units

AllCustomUnits = {} -- Array of all custom units
AllCustomUnitsSet = {} -- Set of all custom units

-- End of unit data


GUIDCustomUnitMap = {} -- Key: GUID | Value: Array of custom units
--UnitTypeGUIDUnitMap = {} -- Key: Unit type | Value: {Key: GUID | Value: Custom unit of type}
CustomUnitGUIDMap = {} -- Key: Custom unit | Value: GUID

DEFAULT_CUSTOM_UNITS = {["focus"] = 40}

UpdateListeners = {}

function RegisterCustomUnits(unitName, maxUnits)
    table.insert(CustomUnitTypes, unitName)
    CustomUnitTypesSet[unitName] = 1
    local units = {}
    local unitsSet = {}
    for i = 1, maxUnits do
        local unit = unitName..i
        units[i] = unit
        unitsSet[unit] = 1
        CustomUnitsTypeMap[unit] = unitName
        table.insert(AllCustomUnits, unit)
        AllCustomUnitsSet[unit] = 1
    end
    CustomUnitsMap[unitName] = units
    CustomUnitsSetMap[unitName] = unitsSet
    
    for _, listener in ipairs(UpdateListeners) do
        listener()
    end
end

for unitName, maxUnits in pairs(DEFAULT_CUSTOM_UNITS) do
    RegisterCustomUnits(unitName, maxUnits)
end

-- Listen for new custom unit registries
function RegisterUpdateListener(listener)
    table.insert(UpdateListeners, listener)
end

function UnregisterUpdateListener(listener)
    PTUtil.RemoveElement(UpdateListeners, listener)
end

ImportedEnvironments = {}
UnitFunctions = {}


function UpdateUnitTypeFrames(unitType)
    local groups = compost:GetTable()
    for _, unit in ipairs(CustomUnitsMap[unitType]) do
        local guid = CustomUnitGUIDMap[unit]
        for ui in Puppeteer.UnitFrames(unit) do
            if guid then
                ui:Show()
                ui.guidUnit = guid
                ui:UpdateAll()
                ui:UpdateIncomingHealing()
            else
                ui:Hide()
                ui.guidUnit = nil
            end
            groups[ui.owningGroup] = 1
        end
    end

    for group, _ in pairs(groups) do
        group:EvaluateShown()
    end
    compost:Reclaim(groups)
end

function UpdateUnitFrames(unit)
    local groups = compost:GetTable()
    local guid = CustomUnitGUIDMap[unit]
    for ui in Puppeteer.UnitFrames(unit) do
        if guid then
            ui:Show()
            ui.guidUnit = guid
            ui:UpdateAll()
        else
            ui:Hide()
            ui.guidUnit = nil
        end
        groups[ui.owningGroup] = 1
    end

    for group, _ in pairs(groups) do
        group:EvaluateShown()
    end
    compost:Reclaim(groups)
end

function GetCurrentUnitOfType(guid, unitType)
    local unitArray = GUIDCustomUnitMap[guid]
    if not unitArray then
        return
    end
    for _, unit in ipairs(unitArray) do
        if CustomUnitsTypeMap[unit] == unitType then
            return unit
        end
    end
end

-- Sets the GUID of the custom unit. If the GUID already has a unit of the type, this will do nothing.
-- If the GUID is nil, the unit will be freed. Returns true if state was changed.
function SetCustomUnitGuid(unit, guid, skipUpdate)
    if guid then
        local unitType = CustomUnitsTypeMap[unit]
        local currentUnit = GetCurrentUnitOfType(guid, unitType)
        if currentUnit then
            return
        end
        CustomUnitGUIDMap[unit] = guid
        local unitArray = GUIDCustomUnitMap[guid]
        if not unitArray then
            unitArray = compost:GetTable()
            GUIDCustomUnitMap[guid] = unitArray
        end
        table.insert(unitArray, unit)
        PTGuidRoster.SetUnitGuid(unit, guid)
        PTUnit.UpdateGuidCaches()
        if not skipUpdate then
            UpdateUnitFrames(unit)
        end
        return true
    else
        local guid = CustomUnitGUIDMap[unit]
        if guid then
            CustomUnitGUIDMap[unit] = nil
            local unitArray = GUIDCustomUnitMap[guid]
            if table.getn(unitArray) == 1 then
                compost:Reclaim(unitArray)
                GUIDCustomUnitMap[guid] = nil
            else
                PTUtil.RemoveElement(unitArray, unit)
            end
            PTGuidRoster.SetUnitGuid(unit, nil)
            PTUnit.UpdateGuidCaches()
            if not skipUpdate then
                UpdateUnitFrames(unit)
            end
            return true
        end
    end
end

function ClearGuidUnitType(guid, unitType)
    for _, unit in ipairs(CustomUnitsMap[unitType]) do
        if CustomUnitGUIDMap[unit] then
            SetCustomUnitGuid(unit, nil)
            return unit
        end
    end
end

-- Finds a free unit of the unit type to assign for the GUID. Returns the unit if successful, otherwise nil.
function SetGuidUnitType(guid, unitType, skipUpdate)
    if GetCurrentUnitOfType(guid, unitType) then
        return
    end
    local selectedUnit
    for _, unit in ipairs(CustomUnitsMap[unitType]) do
        if not CustomUnitGUIDMap[unit] then
            selectedUnit = unit
            break
        end
    end

    if not selectedUnit then
        return
    end

    SetCustomUnitGuid(selectedUnit, guid, skipUpdate)
    return selectedUnit
end

-- Promotes a GUID from a lower unit number of the type to the first unit number. For example, if the GUID
-- is "focus5", it would be moved to "focus1" and all units in between would be shifted down and/or compressed.
-- TODO: Probably should just handle promotion in unit frame sorting rather than actually changing their IDs.
function PromoteGuidUnitType(guid, unitType)
    local unit = GetCurrentUnitOfType(guid, unitType)
    if not unit then
        return
    end
    local units = CustomUnitsMap[unitType]
    local index = PTUtil.IndexOf(units, unit)

    SetCustomUnitGuid(unit, nil)
    -- Remove all units before this unit
    local reacquire = compost:GetTable()
    for i = 1, index do
        local moveUnit = units[i]
        if CustomUnitGUIDMap[moveUnit] then
            local moveGuid = CustomUnitGUIDMap[moveUnit]
            SetCustomUnitGuid(moveUnit, nil, true)
            table.insert(reacquire, moveGuid)
        end
    end
    -- Set the promotion first so they get the first spot
    SetGuidUnitType(guid, unitType, true)
    -- Reacquire the removed units
    for _, reacquireGuid in ipairs(reacquire) do
        SetGuidUnitType(reacquireGuid, unitType, true)
    end
    compost:Reclaim(reacquire)
    UpdateUnitTypeFrames(unitType)
end

function IsGuidCustomUnit(guid, unit)
    local unitArray = GUIDCustomUnitMap[guid]
    for _, customUnit in ipairs(unitArray) do
        if customUnit == unit then
            return true
        end
    end
    return false
end

function IsUnitUnitType(unit, unitType)
    local guid = PTGuidRoster.ResolveUnitGuid(unit)
    return IsGuidUnitType(guid, unitType)
end

function IsGuidUnitType(guid, unitType)
    local unitArray = GUIDCustomUnitMap[guid]
    if not unitArray then
        return false
    end
    for _, customUnit in ipairs(unitArray) do
        if CustomUnitsTypeMap[customUnit] == unitType then
            return true
        end
    end
    return false
end

-- Returns a normal unit associated with the custom unit or GUID, or nil if there is none
function ResolveCustomUnit(customUnit)
    local guid = CustomUnitGUIDMap[customUnit] or customUnit
    local units = PTGuidRoster.GetUnits(guid)
    if units and table.getn(units) > 1 then
        for _, rosterUnit in ipairs(units) do
            if not AllCustomUnitsSet[rosterUnit] then
                return rosterUnit
            end
        end
    end
end

function CycleUnitType(unitType, onlyAttackable)
    local targetGuid = PTGuidRoster.GetUnitGuid("target")
    local typeTarget = GetCurrentUnitOfType(targetGuid, unitType)
    local typeUnits = CustomUnitsMap[unitType]
    if not typeTarget then -- Not targeting this unit type
        for _, typeUnit in ipairs(typeUnits) do
            if UnitExists(typeUnit) then
                TargetUnit(typeUnit)
                return
            end
        end
        return
    end
    local maxUnits = table.getn(typeUnits)
    local targetIndex = PTUtil.IndexOf(typeUnits, typeTarget)
    local i = targetIndex
    for e = 1, maxUnits - 1 do
        i = i + 1
        if i > maxUnits then
            i = i - maxUnits
        end
        local guid = CustomUnitGUIDMap[typeUnits[i]]
        if guid and UnitExists(guid) and (not onlyAttackable or UnitCanAttack("player", guid)) then
            TargetUnit(guid)
            break
        end
    end
end

function ImportFunctions(env)
    for name, func in pairs(UnitFunctions) do
        env[name] = func
    end
    table.insert(ImportedEnvironments, env)
end

function UpdateImports()
    for _, env in ipairs(ImportedEnvironments) do
        for name, func in pairs(UnitFunctions) do
            env[name] = func
        end
    end
end

function UnitProxy(name, func, defaultValue)
    local proxy = function(unit)
        if AllCustomUnitsSet[unit] then
            unit = CustomUnitGUIDMap[unit]
            if not unit then
                return defaultValue
            end
        end
        if not unit then
            return
        end
        return func(unit)
    end
    PTUnitProxy[name] = proxy
    UnitFunctions[name] = proxy
end

function DoubleUnitProxy(name, func, defaultValue)
    local proxy = function(unit1, unit2)
        if AllCustomUnitsSet[unit1] then
            unit1 = CustomUnitGUIDMap[unit1]
            if not unit1 then
                return defaultValue
            end
        end
        if AllCustomUnitsSet[unit2] then
            unit2 = CustomUnitGUIDMap[unit2]
            if not unit2 then
                return defaultValue
            end
        end
        return func(unit1, unit2)
    end
    PTUnitProxy[name] = proxy
    UnitFunctions[name] = proxy
end

function AuraProxy(name, func, defaultValue)
    local proxy = function(unit, index)
        if AllCustomUnitsSet[unit] then
            unit = CustomUnitGUIDMap[unit]
            if not unit then
                return defaultValue
            end
        end
        return func(unit, index)
    end
    PTUnitProxy[name] = proxy
    UnitFunctions[name] = proxy
end

function CustomProxy(name, constructor)
    local proxy = constructor()
    PTUnitProxy[name] = proxy
    UnitFunctions[name] = proxy
end

function CustomFunction(name, func)
    PTUnitProxy[name] = func
    UnitFunctions[name] = func
end

function CreateUnitProxies()
    AuraProxy("UnitBuff", _G.UnitBuff, nil)
    AuraProxy("UnitDebuff", _G.UnitDebuff, nil)
    UnitProxy("UnitExists", _G.UnitExists, false)
    UnitProxy("UnitHealth", _G.UnitHealth, 0)
    UnitProxy("UnitHealthMax", _G.UnitHealthMax, 0)
    UnitProxy("UnitMana", _G.UnitMana, 0)
    UnitProxy("UnitManaMax", _G.UnitManaMax, 0)
    UnitProxy("UnitIsPlayer", _G.UnitIsPlayer, false)
    UnitProxy("UnitIsConnected", _G.UnitIsConnected, false)
    UnitProxy("UnitIsDead", _G.UnitIsDead, false)
    UnitProxy("UnitIsGhost", _G.UnitIsGhost, false)
    UnitProxy("UnitIsDeadOrGhost", _G.UnitIsDeadOrGhost, false)
    UnitProxy("UnitIsCorpse", _G.UnitIsCorpse, false)
    UnitProxy("UnitClass", _G.UnitClass, "")
    UnitProxy("UnitName", _G.UnitName, "Unknown")
    UnitProxy("UnitPowerType", _G.UnitPowerType, 0)
    UnitProxy("UnitIsVisible", _G.UnitIsVisible, false)
    UnitProxy("UnitIsCharmed", _G.UnitIsCharmed, false)
    UnitProxy("TargetUnit", _G.TargetUnit, nil)
    UnitProxy("FollowUnit", _G.FollowUnit, nil)
    UnitProxy("AssistUnit", _G.AssistUnit, nil)
    UnitProxy("UnitAffectingCombat", _G.UnitAffectingCombat, false)
    UnitProxy("UnitIsPVP", _G.UnitIsPVP, false)
    UnitProxy("UnitFactionGroup", _G.UnitFactionGroup, nil)
    DoubleUnitProxy("UnitIsFriend", _G.UnitIsFriend, false)
    DoubleUnitProxy("UnitIsEnemy", _G.UnitIsEnemy, false)
    DoubleUnitProxy("UnitIsUnit", _G.UnitIsUnit, false)
    DoubleUnitProxy("UnitCanAttack", _G.UnitCanAttack, false)
    DoubleUnitProxy("CheckInteractDistance", _G.CheckInteractDistance, false)
    CustomProxy("CastSpellByName", function()
        return function(spell, unit)
            if AllCustomUnitsSet[unit] then
                unit = CustomUnitGUIDMap[unit]
                if not unit then
                    return
                end
            end
            return _G.CastSpellByName(spell, unit)
        end
    end)
    -- UnitXP SP3 compatibility
    CustomProxy("UnitXP", function()
        local UnitXP = _G.UnitXP
        return function(a1, a2, a3, a4, a5)
            if a1 then
                a1 = AllCustomUnitsSet[a1] and CustomUnitGUIDMap[a1] or a1
                if not a1 then return 0 end
            end
            if a2 then
                a2 = AllCustomUnitsSet[a2] and CustomUnitGUIDMap[a2] or a2
                if not a2 then return 0 end
            end
            if a3 then
                a3 = AllCustomUnitsSet[a3] and CustomUnitGUIDMap[a3] or a3
                if not a3 then return 0 end
            end
            if a4 then
                a4 = AllCustomUnitsSet[a4] and CustomUnitGUIDMap[a4] or a4
                if not a4 then return 0 end
            end
            if a5 then
                a5 = AllCustomUnitsSet[a5] and CustomUnitGUIDMap[a5] or a5
                if not a5 then return 0 end
            end
            return UnitXP(a1, a2, a3, a4, a5)
        end
    end)
    CustomProxy("UnitGUID", function()
        return function(unit)
            local _, guid = UnitExists(unit)
            return guid
        end
    end)

    UpdateImports()
end

CreateUnitProxies()