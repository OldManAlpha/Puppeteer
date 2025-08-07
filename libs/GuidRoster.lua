-- A utility to map guids to units

if not PTUtil.IsSuperWowPresent() then
    return
end

PTGuidRoster = {}
PTUtil.SetEnvironment(PTGuidRoster)
local _G = getfenv(0)

local compost = AceLibrary("Compost-2.0")

local util = PTUtil

GuidUnitMap = {}
GuidFrameMap = {}

function ResetRoster()
    local roster = GuidUnitMap
    for k, v in pairs(roster) do
        compost:Reclaim(v)
        roster[k] = nil
    end
end

function PopulateRoster()
    for _, unit in ipairs(util.AllUnits) do
        local exists, guid = UnitExists(unit)
        if exists then
            AddUnit(guid, unit)
        end
    end
end

function AddUnit(guid, unit)
    if not GuidUnitMap[guid] then
        GuidUnitMap[guid] = compost:GetTable()
    end
    table.insert(GuidUnitMap[guid], unit)
end

function SetUnitGuid(unit, guid)
    for guidInMap, units in pairs(GuidUnitMap) do
        if util.ArrayContains(units, unit) then
            util.RemoveElement(units, unit)
            if table.getn(units) == 0 then
                compost:Reclaim(units)
                GuidUnitMap[guidInMap] = nil
            end
            break
        end
    end

    if not guid then
        return
    end

    if not GuidUnitMap[guid] then
        GuidUnitMap[guid] = compost:GetTable()
    end
    table.insert(GuidUnitMap[guid], unit)
end

function GetUnitGuid(unit)
    local _, guid = UnitExists(unit)
    return guid
end

-- Resolves the GUID of the real unit, custom unit, or returns the unit itself if it's already a GUID.
-- If the unit is "target" and there's no target, this returns nil.
function ResolveUnitGuid(unit)
    local guid = GetUnitGuid(unit) or PTUnitProxy.CustomUnitGUIDMap[unit] or unit
    if guid ~= "target" then
        return guid
    end
end

-- Returns an array of all the units the guid is, or nil if none
function GetUnits(guid)
    return GuidUnitMap[guid]
end

function HasUnits(guid)
    return GuidUnitMap[guid] ~= nil
end

-- Returns an array of units this unit is
function GetAllUnits(unit)
    return GetUnits(GetUnitGuid(unit))
end

-- Returns an array of all guids that have units
function GetTrackedGuids()
    return util.ToArray(GuidUnitMap)
end