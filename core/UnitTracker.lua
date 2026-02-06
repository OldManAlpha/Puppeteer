PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)

UnitTrackerFrame = CreateFrame("Frame", "PTUnitTrackerFrame", UIParent)

local util = PTUtil
local GetTime = GetTime
local compost = AceLibrary("Compost-2.0")

local TRACKING_EVAL_INTERVAL = 1.25
local RANGE_MIN_DIST = 20
local RANGE_MAX_DIST = 60
local SIGHT_MAX_DIST = 80
local DISTANCE_UPDATE_INTERVAL = 0.1
local SIGHT_UPDATE_INTERVAL = 0.1

local AllUnits = util.AllUnits

local distanceTrackedUnits = {}
local sightTrackedUnits = {}
local preciseDistance = util.CanClientGetPreciseDistance()
local sightTrackingEnabled = util.CanClientSightCheck()
local nextEval = GetTime() + 0.5
local nextRangeUpdate = GetTime() + 0.6
local nextSightUpdate = GetTime() + 0.6
if not preciseDistance then
    nextRangeUpdate = nextRangeUpdate + 99999999 -- Effectively disable updates
end
if not sightTrackingEnabled then
    nextSightUpdate = nextSightUpdate + 99999999
end

function LoadTrackingOptions()
    local opts = PTOptions.Tracking
    TRACKING_EVAL_INTERVAL = opts.EvaluateInterval
    RANGE_MIN_DIST = opts.MinDistanceTracking
    RANGE_MAX_DIST = opts.MaxDistanceTracking
    SIGHT_MAX_DIST = opts.MaxSightTracking
    DISTANCE_UPDATE_INTERVAL = opts.DistanceUpdateInterval
    SIGHT_UPDATE_INTERVAL = opts.SightUpdateInterval
end

function RunTrackingScan()
    local UnitFrames = UnitFrames
    local time = GetTime()
    if time > nextEval then
        --StartTiming("TrackingEval")
        nextEval = time + TRACKING_EVAL_INTERVAL


        compost:Erase(distanceTrackedUnits)
        local prevSightTrackedUnits = sightTrackedUnits
        sightTrackedUnits = compost:GetTable()
        if PTGuidRoster then
            for guid, cache in pairs(PTUnit.GetAllUnits()) do
                EvaluateTracking(guid)
            end
        else
            for _, unit in ipairs(AllUnits) do
                EvaluateTracking(unit)
            end
        end

        for _, unit in ipairs(prevSightTrackedUnits) do
            for ui in UnitFrames(unit) do
                ui:UpdateSight()
            end
        end
        compost:Reclaim(prevSightTrackedUnits)
        --EndTiming("TrackingEval")
    end

    if time > nextRangeUpdate then
        nextRangeUpdate = time + DISTANCE_UPDATE_INTERVAL
        for _, unit in ipairs(distanceTrackedUnits) do
            local cache = PTUnit.Get(unit)
            if cache and cache:UpdateDistance() then
                for ui in UnitFrames(unit) do
                    ui:UpdateRange()
                end
            end
        end
    end

    if time > nextSightUpdate then
        nextSightUpdate = time + SIGHT_UPDATE_INTERVAL
        for _, unit in ipairs(sightTrackedUnits) do
            local cache = PTUnit.Get(unit)
            --StartTiming("SightScan")
            if cache and cache:UpdateSight() then
                for ui in UnitFrames(unit) do
                    ui:UpdateSight()
                end
            end
            --EndTiming("SightScan")
        end
    end
end

function EvaluateTracking(unit, update)
    local UnitFrames = UnitFrames
    local cache = PTUnit.Get(unit)
    local distanceChanged = cache:UpdateDistance()
    local sightChanged = cache:UpdateSight()
    local new = cache:CheckNew()
    local dist = cache:GetDistance()
    if distanceChanged or sightChanged or new then
        for ui in UnitFrames(unit) do
            if distanceChanged or new then
                ui:UpdateRange()
            end
            if sightChanged or new then
                ui:UpdateSight()
            end
        end
    end
    if cache:UpdatePVP() then
        for ui in UnitFrames(unit) do
            ui:UpdatePVP()
        end
    end
    local isTarget = UnitIsUnit(unit, "target")
    if PTGuidRoster then
        unit = PTGuidRoster.ResolveUnitGuid(unit)
    end
    -- Only closely track units that are close to the range threshold
    if isTarget or (dist <= RANGE_MAX_DIST and dist >= RANGE_MIN_DIST) then
        if not update or not util.ArrayContains(distanceTrackedUnits, unit) then
            table.insert(distanceTrackedUnits, unit)
        end
    end
    if sightTrackingEnabled and (isTarget or (dist > 0 and dist < SIGHT_MAX_DIST)) then
        if not update or not util.ArrayContains(sightTrackedUnits, unit) then
            table.insert(sightTrackedUnits, unit)
        end
    end
end

function StartUnitTracker()
    LoadTrackingOptions()
    UnitTrackerFrame:SetScript("OnUpdate", RunTrackingScan)
end