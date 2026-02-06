-- An experimental feature that tracks enemies

local util = PTUtil

if not util.IsSuperWowPresent() then
    return
end

util.SetEnvironment(Puppeteer)

local function isUnitRelevant(unit)
    return UnitCanAttack("player", unit) and UnitHealth(unit) > 0 and UnitIsConnected(unit) and UnitExists(unit) 
        and (UnitAffectingCombat(unit) or UnitIsUnit(unit, "target") or UnitIsUnit(unit, "pettarget"))
end

local isUnitNearby = util.CanClientGetPreciseDistance(true) and
function(unit)
    return util.GetDistanceTo(unit) < 60
end
or
function() return true end

local f = CreateFrame("Frame", "PTEnemyUpdater")

f:SetScript("OnEvent", function()
    local unit = arg1
    if event == "PLAYER_TARGET_CHANGED" then
        unit = "target"
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        unit = UnitGUID("mouseover")
    end

    if UnitCanAttack("player", unit) and (UnitAffectingCombat(unit) or (unit == "target" and UnitHealth(unit) > 0)) then
        if not CustomUnitsMap["enemy"] then
            return
        end

        local guid = UnitGUID(unit)
        if IsGuidUnitType(guid, "enemy") then -- Already enemy
            return
        end

        local enemyUnits = CustomUnitsMap["enemy"]
        if not enemyUnits then
            return
        end

        if not util.IsReallyInInstance() and (not UnitAffectingCombat("player") or not isUnitNearby(unit)) 
                and (unit ~= "target" or not UnitCanAttack("player", unit)) then
            return
        end

        for _, enemyUnit in ipairs(enemyUnits) do
            if CustomUnitGUIDMap[enemyUnit] then
                if not isUnitRelevant(enemyUnit) then
                    SetCustomUnitGuid(enemyUnit, nil)
                    SetCustomUnitGuid(enemyUnit, guid)
                    return
                end
            end
        end

        SetGuidUnitType(guid, "enemy")
    end
end)

local nextUpdate = GetTime() + 0.25
local EnemyTracker_OnUpdate = function()
    if GetTime() > nextUpdate then
        nextUpdate = nextUpdate + 0.25

        local enemyUnits = CustomUnitsMap["enemy"]
        if not enemyUnits then
            return
        end
        local maxEnemies = table.getn(enemyUnits)
        local lastIndex = 0
        for i, unit in ipairs(enemyUnits) do
            if CustomUnitGUIDMap[unit] then
                if isUnitRelevant(unit) then
                    lastIndex = i
                end
            end
        end

        for i = lastIndex + 1, maxEnemies - lastIndex do
            local enemyUnit = enemyUnits[i]
            if CustomUnitGUIDMap[enemyUnit] then
                SetCustomUnitGuid(enemyUnit, nil)
            end
        end
    end
end

function SetEnemyTrackingEnabled(trackEnemies)
    if trackEnemies then
        f:RegisterEvent("UNIT_COMBAT")
        f:RegisterEvent("UNIT_FLAGS")
        f:RegisterEvent("PLAYER_TARGET_CHANGED")
        f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        f:SetScript("OnUpdate", EnemyTracker_OnUpdate)
    else
        f:UnregisterAllEvents()
        f:SetScript("OnUpdate", nil)
        for _, unit in ipairs(CustomUnitsMap["enemy"]) do
            SetCustomUnitGuid(unit, nil)
        end
    end
end

RegisterCustomUnits("enemy", 40)