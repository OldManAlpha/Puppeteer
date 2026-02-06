-- Contains standalone utility functions that cause no side effects and don't require data from other files, other than the unit proxy

PTUtil = {}

function PTUtil.SetEnvironment(t, index)
    setmetatable(t, {__index = index or PTUnitProxy or getfenv(1)})
    setfenv(2, t)
end

local _G = getfenv(0)
PTUtil.SetEnvironment(PTUtil)
local getn = table.getn

Classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}
HealerClasses = {"PRIEST", "DRUID", "SHAMAN", "PALADIN"}

UnitXPSP3 = pcall(UnitXP, "inSight", "player", "player") -- WTB better way to check for UnitXP SP3
UnitXPSP3_Version = -1
if UnitXPSP3 and pcall(UnitXP, "version", "coffTimeDateStamp") then
    UnitXPSP3_Version = UnitXP("version", "coffTimeDateStamp") or -1
end
SuperWoW = SpellInfo ~= nil
SuperWoWFeatureLevel = 0
SuperWoW_v1_2 = 1
SuperWoW_v1_3 = 2
SuperWoW_v1_4 = 3
if SUPERWOW_VERSION then
    if SUPERWOW_VERSION == "1.2" then
        SuperWoWFeatureLevel = SuperWoW_v1_2
    elseif SUPERWOW_VERSION == "1.3" then
        SuperWoWFeatureLevel = SuperWoW_v1_3
    else -- Anything newer than 1.3 is considered as 1.4 feature set
        SuperWoWFeatureLevel = SuperWoW_v1_4
    end
end
Nampower = QueueSpellByName ~= nil

TurtleWow = TURTLE_WOW_VERSION ~= nil

PowerColors = {
    ["mana"] = {0.1, 0.25, 1}, --{r = 0, g = 0, b = 0.882}, Not accurate, changed color to make brighter
    ["rage"] = {1, 0, 0},
    ["focus"] = {1, 0.5, 0.25},
    ["energy"] = {1, 1, 0}
}

ClassPowerTypes = {
    ["WARRIOR"] = "rage",
    ["PALADIN"] = "mana",
    ["HUNTER"] = "mana",
    ["ROGUE"] = "energy",
    ["PRIEST"] = "mana",
    ["SHAMAN"] = "mana",
    ["MAGE"] = "mana",
    ["WARLOCK"] = "mana",
    ["DRUID"] = "mana"
}

-- The power types IDs mapped in accordance to UnitPowerType
PowerTypeMap = {
    [0] = "mana", 
    [1] = "rage", 
    [2] = "focus", 
    [3] = "energy"
}

ResurrectionSpells = {
    ["PRIEST"] = "Resurrection",
    ["PALADIN"] = "Redemption",
    ["SHAMAN"] = "Ancestral Spirit",
    ["DRUID"] = "Rebirth"
}
ResurrectionSpellsSet = {
    ["Resurrection"] = "PRIEST",
    ["Redemption"] = "PALADIN",
    ["Ancestral Spirit"] = "SHAMAN",
    ["Rebirth"] = "DRUID"
}

-- The default color Blizzard uses for text
DefaultTextColor = {1, 0.82, 0}

PartyUnits = {"player", "party1", "party2", "party3", "party4"}
PetUnits = {"pet", "partypet1", "partypet2", "partypet3", "partypet4"}
TargetUnits = {"target"}
RaidUnits = {}
for i = 1, MAX_RAID_MEMBERS do
    RaidUnits[i] = "raid"..i
end
RaidPetUnits = {}
for i = 1, MAX_RAID_MEMBERS do
    RaidPetUnits[i] = "raidpet"..i
end
CustomUnits = PTUnitProxy and PTUnitProxy.AllCustomUnits or {}
CustomUnitsSet = PTUnitProxy and PTUnitProxy.AllCustomUnitsSet or {}
FocusUnits = PTUnitProxy and PTUnitProxy.CustomUnitsMap["focus"] or {}

local unitArrays = {PartyUnits, PetUnits, RaidUnits, RaidPetUnits, TargetUnits}
AllUnits = {}
for _, unitArray in ipairs(unitArrays) do
    for _, unit in ipairs(unitArray) do
        table.insert(AllUnits, unit)
    end
end
AllRealUnits = {}
for i, unit in ipairs(AllUnits) do
    AllRealUnits[i] = unit
end
if PTUnitProxy then
    for _, unit in ipairs(CustomUnits) do
        table.insert(AllUnits, unit)
    end
    PTUnitProxy.RegisterUpdateListener(function()
        local i = 1
        for _, unit in ipairs(AllRealUnits) do
            AllUnits[i] = unit
            i = i + 1
        end
        for _, unit in ipairs(CustomUnits) do
            AllUnits[i] = unit
            i = i + 1
        end
        ClearTable(AllUnitsSet)
        for k, v in pairs(ToSet(AllUnits)) do
            AllUnitsSet[k] = v
        end
    end)
end

local assetsPath = "Interface\\AddOns\\Puppeteer\\assets\\"
function GetAssetsPath()
    return assetsPath
end

-- Returns a new table with the elements of the given array being the keys with 1 being the value of all keys, 
-- or the index if indexValue is true
function ToSet(array, indexValue, to)
    local set = to or {}
    for index, value in ipairs(array) do
        set[value] = indexValue and index or 1
    end
    return set
end

-- Returns a new table with the keys of the given set being the values of the array
function ToArray(set)
    local array = {}
    for value, _ in pairs(set) do
        table.insert(array, value)
    end
    return array
end

-- Adds the elements of otherArray to the array
function AppendArrayElements(array, otherArray)
    for _, v in ipairs(otherArray) do
        table.insert(array, v)
    end
end

function IndexOf(table, value)
    for i, v in ipairs(table) do
        if v == value then
            return i
        end
    end
    return -1
end

function KeyOf(table, value)
    for k, v in pairs(table) do
        if v == value then
            return k
        end
    end
end

function ArrayContains(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

function RemoveElement(t, value)
    table.remove(t, IndexOf(t, value))
end

function ReverseArray(t)
	for i = 1, math.floor(getn(t) / 2) do
        t[i], t[getn(t) - i + 1] = t[getn(t) - i + 1], t[i]
    end
end

function CloneTable(table, deep)
    local clone = {}
    for k, v in pairs(table) do
        if deep and type(v) == "table" then
            clone[k] = CloneTable(v, true)
        else
            clone[k] = v
        end
    end
    return clone
end

function ApplyTableDiffs(t, overrides)
    for k, v in pairs(overrides) do
        if t[k] ~= nil then
            if type(v) == "table" then
                if type(t[k]) == "table" then
                    ApplyTableDiffs(t[k], v)
                else
                    t[k] = CloneTable(v, true)
                end
            else
                t[k] = v
            end
        else
            t[k] = type(v) == "table" and CloneTable(v, true) or v
        end
    end
end

local compost = AceLibrary("Compost-2.0")

-- Recursively reclaims all tables this table contains
function CompostReclaim(t)
    for k, v in pairs(t) do
        if type(v) == "table" then
            CompostReclaim(v)
        end
    end
    compost:Reclaim(t)
end

function CloneTableCompost(t, deep)
    local clone = compost:GetTable()
    local n = 0
    for k, v in pairs(t) do
        if deep and type(v) == "table" then
            clone[k] = CloneTableCompost(v, true)
        else
            clone[k] = v
        end
        n = n + 1
    end
    table.setn(clone, n)
    return clone
end

function ClearTable(t)
    for k, v in pairs(t) do
        t[k] = nil
    end
    table.setn(t, 0)
end

function GetTableSize(t)
    local size = 0
    for _ in pairs(t) do
        size = size + 1
    end
    return size
end

function IsTableEmpty(t)
    for _ in pairs(t) do
        return false
    end
    return true
end

-- Recursion not supported
function TableEquals(t1, t2)
    -- Verify the tables have the same keys
    for k, v in pairs(t1) do
        if t2[k] == nil then
            return false
        end
    end
    for k, v in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end
    -- Verify the tables have equal values
    for k, v in pairs(t1) do
        if type(v) == "table" then
            if type(t2[k]) ~= "table" or not TableEquals(v, t2[k]) then
                return false
            end
        else
            if v ~= t2[k] then
                return false
            end
        end
    end
    return true
end

function TraverseTable(v, k1, k2, k3, k4, k5)
    local keys = compost:Acquire(k1, k2, k3, k4, k5)
    for _, k in ipairs(keys) do
        if type(v) ~= "table" then
            return nil, k
        end
        v = v[k]
    end
    compost:Reclaim(keys)
    return v
end

-- Courtesy of ChatGPT
function SplitString(str, delimiter)
    local result = {}
    local start_pos = 1
    
    while true do
        local end_pos = string.find(str, delimiter, start_pos, true)
        
        if not end_pos then
            table.insert(result, string.sub(str, start_pos))
            break
        end
        
        table.insert(result, string.sub(str, start_pos, end_pos - 1))
        start_pos = end_pos + string.len(delimiter)
    end
    
    return result
end

function StartsWith(str, starts)
    return string.sub(str, 1, string.len(starts)) == starts
end

function RoundNumber(number, decimalPlaces)
    decimalPlaces = decimalPlaces or 0
    return math.floor(number * 10^decimalPlaces + 0.5) / 10^decimalPlaces
end

-- Courtesy of ChatGPT
function InterpolateColors(colors, t)
    local r, g, b = InterpolateColorsNoTable(colors, t)
    return {r, g, b}
end

function InterpolateColorsNoTable(colors, t)
    local numColors = getn(colors)
    
    -- Ensure t is between 0 and 1
    t = math.max(0, math.min(1, t))

    -- If there are fewer than 2 colors, just return the single color
    if numColors < 2 then
        local c = colors[1]
        return c[1], c[2], c[3]
    end

    -- Determine the segment in which t falls
    local scaledT = t * (numColors - 1)  -- Scale t to cover the range of indices
    local index = math.floor(scaledT)
    local fraction = scaledT - index

    -- Handle edge cases where index is out of bounds
    if index >= numColors - 1 then
        local c = colors[numColors]
        return c[1], c[2], c[3]
    end

    local color1 = colors[index + 1]
    local color2 = colors[index + 2]

    -- Linear interpolation between color1 and color2
    local r = color1[1] + (color2[1] - color1[1]) * fraction
    local g = color1[2] + (color2[2] - color1[2]) * fraction
    local b = color1[3] + (color2[3] - color1[3]) * fraction

    return r, g, b
end

function Colorize(text, r, g, b)
    if type(r) == "table" then
        local rgb = r
        r = rgb[1]
        g = rgb[2]
        b = rgb[3]
    end
    return "|cFF" .. string.format("%02x%02x%02x", r * 255, g * 255, b * 255) .. text .. "|r"
end

function StripColors(text)
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

local coloredRoles = {
    ["Tank"] = Colorize("Tank", 0.3, 0.6, 1),
    ["Healer"] = Colorize("Healer", 0.2, 1, 0.2),
    ["Damage"] = Colorize("Damage", 1, 0.4, 0.4),
    ["No Role"] = "No Role"
}
function GetColoredRoleText(role)
    if not role then
        return coloredRoles["No Role"]
    end
    return coloredRoles[role]
end

function IsFeigning(unit)
    local cache = PTUnit.Get(unit)
    if not cache then
        local unitClass = GetClass(unit)
        if unitClass == "HUNTER" then
            local superwow = IsSuperWowPresent()
            for i = 1, 32 do
                local texture, _, id = UnitBuff(unit, i)
                if superwow then -- Use the ID if SuperWoW is present
                    if id == 5384 then -- 5384 is Feign Death
                        return true
                    end
                else -- Use the texture otherwise
                    if texture == "Interface\\Icons\\Ability_Rogue_FeignDeath" then
                        return true
                    end
                end
            end
        end
        return false
    end
    return cache:HasBuffIDOrName(5384, "Feign Death")
end

function HasAura(unit, auraType, auraTexture, auraID)
    local auraFunc = auraType == "Buff" and UnitBuff or UnitDebuff
    local checkCount = auraType == "Buff" and 32 or 16

    local superwow = IsSuperWowPresent()
    for i = 1, checkCount do
        local texture, _, id = auraFunc(unit, i)
        if superwow and auraID then
            if auraID == id then
                return true
            end
        else
            if texture == auraTexture then
                return true
            end
        end
    end
    return false
end

function GetBagSlotInfo(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then
        return
    end
    local _, _, name = string.find(link, "%[(.*)%]")
    local _, count = GetContainerItemInfo(bag, slot)
    return name, count
end

-- Returns: Bag index, Slot index
function FindBagSlot(itemName)
    local bestBag, bestSlot, lowestStackSize
    for bag = 0, NUM_BAG_FRAMES do
        for slot = 1, GetContainerNumSlots(bag) do
            local name, count = GetBagSlotInfo(bag, slot)
            if itemName == name then
                if not lowestStackSize or lowestStackSize > count then
                    bestBag = bag
                    bestSlot = slot
                    lowestStackSize = count
                end
            end
        end
    end
    return bestBag, bestSlot
end

-- Returns true if an item was found and attempted to be used
function UseItem(itemName)
    local bag, slot = FindBagSlot(itemName)
    if not bag then
        return
    end
    UseContainerItem(bag, slot)
    return true
end

function GetItemCount(itemName)
    local total = 0
    for bag = 0, NUM_BAG_FRAMES do
        for slot = 1, GetContainerNumSlots(bag) do
            local name, count = GetBagSlotInfo(bag, slot)
            if itemName == name then
                total = total + count
            end
        end
    end
    return total
end

function IsValidMacro(name)
    return GetMacroIndexByName(name) ~= 0
end

function RunMacro(name, target)
    if not IsValidMacro(name) then
        return
    end
    if target then
        _G.PT_MacroTarget = target
    end
    local _, _, body = GetMacroInfo(GetMacroIndexByName(name))
    local commands = SplitString(body, "\n")
    for i = 1, getn(commands) do
        ChatFrameEditBox:SetText(commands[i])
        ChatEdit_SendText(ChatFrameEditBox)
    end
    if target then
        _G.PT_MacroTarget = nil
    end
end

local ScanningTooltip = CreateFrame("GameTooltip", "PTScanningTooltip", nil, "GameTooltipTemplate");
ScanningTooltip:SetOwner(WorldFrame, "ANCHOR_NONE");
-- Allow tooltip SetX() methods to dynamically add new lines based on these
ScanningTooltip:AddFontStrings(
    ScanningTooltip:CreateFontString( "$parentTextLeft1", nil, "GameTooltipText" ),
    ScanningTooltip:CreateFontString( "$parentTextRight1", nil, "GameTooltipText" ) );

local spellRankString = RANK.." "
function ExtractSpellRank(spellname)
    -- Find the starting position of "Rank "
    local start_pos = string.find(spellname, spellRankString)

    -- Check if "Rank " was found
    if start_pos then
        -- Adjust start_pos to point to the first digit
        --start_pos = start_pos + 5  -- Move past "Rank "

        -- Find the ending parenthesis
        local end_pos = string.find(spellname, ")", start_pos)

        -- Extract the number substring
        if end_pos then
            local number_str = string.sub(spellname, start_pos, end_pos - 1)
            --local number = tonumber(number_str)  -- Convert to a number

            return number_str
        end
    end
    return nil
end

local resourceCostPatterns = {[MANA_COST] = "mana", [RAGE_COST] = "rage", [ENERGY_COST] = "energy", [FOCUS_COST] = "focus"}
function ExtractResourceCost(costText)
    for costPattern, resourceName in pairs(resourceCostPatterns) do
        local cost = cmatch(costText, costPattern)
        if cost then
            return tonumber(cost), resourceName
        end
    end
    return 0
end

function GetSpellID(spellname)
    local id = 1
    local matchingSpells = compost:GetTable()
    local spellRank = ExtractSpellRank(spellname)

    if spellRank ~= nil then
        spellname = string.gsub(spellname, "%b()", "")
    end

    for i = 1, GetNumSpellTabs() do
        local _, _, _, numSpells = GetSpellTabInfo(i)
        for j = 1, numSpells do
            local spellName, rank, realID = GetSpellName(id, "spell")
            if spellName == spellname then
                if rank == spellRank then -- If the rank is specified, then we can check if this is the right spell
                    return id
                else
                    table.insert(matchingSpells, id)
                end
            end
            id = id + 1
        end
    end
    local foundID = matchingSpells[getn(matchingSpells)]
    compost:Reclaim(matchingSpells)
    return foundID
end

local costCache = {}
local costTypeCache = {}
local costCacheDirty = false
function MarkSpellCostCacheDirty()
    costCacheDirty = true
end
-- Returns the numerical cost and the resource name; "unknown" if the spell is unknown; 0 if the spell is free
function GetResourceCost(spellName)
    if costCacheDirty then
        ClearTable(costCache)
        ClearTable(costTypeCache)
        costCacheDirty = false
    end
    if costCache[spellName] then
        return costCache[spellName], costTypeCache[spellName]
    end

    ScanningTooltip:SetOwner(UIParent, "ANCHOR_NONE");

    local spellID, bookType
    if GetSpellSlotTypeIdForName then -- Nampower 2.6.0 function
        spellID, bookType = GetSpellSlotTypeIdForName(spellName)
        if bookType == "unknown" then
            return "unknown"
        end
        if bookType ~= "spell" then
            return 0
        end
    else
        spellID = GetSpellID(spellName)
    end
    if not spellID then
        return "unknown"
    end

    ScanningTooltip:SetSpell(spellID, "spell")

    local leftText = _G["PTScanningTooltipTextLeft2"]

    if leftText:GetText() then
        costCache[spellName], costTypeCache[spellName] = ExtractResourceCost(leftText:GetText())
        return costCache[spellName], costTypeCache[spellName]
    end
    costCache[spellName] = 0
    return 0
end

-- Returns the aura's name and its school type
function ScanAuraInfo(unit, index, type)
    -- Make these texts blank since they don't clear otherwise
    local leftText = _G["PTScanningTooltipTextLeft1"]
    leftText:SetText("")
    local rightText = _G["PTScanningTooltipTextRight1"]
    rightText:SetText("")
    if type == "Buff" then
        ScanningTooltip:SetUnitBuff(unit, index)
    else
        ScanningTooltip:SetUnitDebuff(unit, index)
    end
    return leftText:GetText() or "", rightText:GetText() or ""
end

if SuperWoW or TurtleWow then
    local auraNameCache = {}
    local auraTypeCache = {}

    function GetAuraInfo(unit, index, type, id)
        if not id then
            if type == "Buff" then
                local _, _, i = UnitBuff(unit, index)
                id = i
            else
                local _, _, _, i = UnitDebuff(unit, index)
                id = i
            end
            if not id then -- Uh oh, Turtle lost the ID
                return ScanAuraInfo(unit, index, type)
            end
        end
        if not auraNameCache[id] then
            auraNameCache[id], auraTypeCache[id] = ScanAuraInfo(unit, index, type)
        end
        return auraNameCache[id], auraTypeCache[id]
    end

    function GetCachedAuraInfo(id)
        return auraNameCache[id], auraTypeCache[id]
    end
else
    GetAuraInfo = ScanAuraInfo
end

function GetActionSlotName(slot)
    _G["PTScanningTooltipTextLeft1"]:SetText("")
    ScanningTooltip:SetAction(slot)
    return _G["PTScanningTooltipTextLeft1"]:GetText() or ""
end

local actionCache = {}
function FindAction(name)
    if actionCache[name] then
        local data = actionCache[name]
        if GetActionTexture(data.slot) == data.texture then
            return data.slot
        end
        actionCache[name] = nil
    end
    for i = 1, 120 do
        if GetActionTexture(i) then
            local slotName = GetActionSlotName(i)
            if slotName == name then
                actionCache[name] = {
                    slot = i,
                    texture = GetActionTexture(i)
                }
                return i
            end
        end
    end
end

function IsCurrentActionByName(name)
    local slot = FindAction(name)
    if slot then
        return IsCurrentAction(slot)
    end
end

function IsAutoRepeatActionByName(name)
    local slot = FindAction(name)
    if slot then
        return IsAutoRepeatAction(slot)
    end
end

-- Casts an action if it's not already being used. Very useful for auto attack abilities. They must be somewhere on your bars.
function CastActionByName(name, target)
    if not (IsAutoRepeatActionByName(name) or IsCurrentActionByName(name)) then
        CastSpellByName(name, target)
    end
end

-- Returns an array of the units in the party number or the unit's raid group
function GetRaidPartyMembers(partyNumberOrUnit)
    if not RAID_SUBGROUP_LISTS then
        return compost:GetTable()
    end
    if type(partyNumberOrUnit) == "string" then
        partyNumberOrUnit = FindUnitRaidGroup(partyNumberOrUnit)
    end
    local members = {}
    if RAID_SUBGROUP_LISTS[partyNumberOrUnit] then
        for frameNumber, raidNumber in pairs(RAID_SUBGROUP_LISTS[partyNumberOrUnit]) do
            table.insert(members, RaidUnits[raidNumber])
        end
    end
    return members
end

-- Returns the raid unit that this unit is, or nil if the unit is not in the raid
function FindRaidUnit(unit)
    if not RAID_SUBGROUP_LISTS then
        return nil
    end
    for party = 1, 8 do
        if RAID_SUBGROUP_LISTS[party] then
            for frameNumber, raidNumber in pairs(RAID_SUBGROUP_LISTS[party]) do
                local raidUnit = RaidUnits[raidNumber]
                if UnitIsUnit(unit, raidUnit) then
                    return raidUnit
                end
            end
        end
    end
end

-- Returns the raid group number the unit is part of, or nil if the unit is not in the raid
function FindUnitRaidGroup(unit)
    for party = 1, 8 do
        if RAID_SUBGROUP_LISTS[party] then
            for frameNumber, raidNumber in pairs(RAID_SUBGROUP_LISTS[party]) do
                local raidUnit = RaidUnits[raidNumber]
                if UnitIsUnit(unit, raidUnit) then
                    return party
                end
            end
        end
    end
end

-- Requires SuperWoW
function GetSurroundingPartyMembers(player, range)
    local units
    if UnitInRaid("player") then
        units = GetRaidPartyMembers(player)
    else
        units = CloneTableCompost(PartyUnits)
        AppendArrayElements(units, PetUnits)
    end

    return GetUnitsInRange(player, units, range or 30)
end

function GetSurroundingRaidMembers(player, range, checkPets)
    local units
    if UnitInRaid("player") then
        units = CloneTableCompost(RaidUnits)
        if checkPets then
            AppendArrayElements(units, RaidPetUnits)
        end
    else
        units = CloneTableCompost(PartyUnits)
        if checkPets then
            AppendArrayElements(units, PetUnits)
        end
    end

    return GetUnitsInRange(player, units, range or 30)
end

function GetUnitsInRange(center, units, range)
    local inRange = compost:GetTable()
    for _, unit in ipairs(units) do
        local exists, guid = UnitExists(unit)
        if exists and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and 
            GetDistanceBetween(center, unit) <= (range or 30) then
            table.insert(inRange, guid)
        end
    end
    return inRange
end

-- Blizzard's UI functions seem to get called referring to a global called "this" referring to the UI object.
-- This function calls a function on the object, emulating the "this" variable.
function CallWithThis(object, func)
    local prevThis = _G.this
    _G.this = object
    func()
    _G.this = prevThis
end

local function _FixFrameLevels(parent, ...)
	local level = parent:GetFrameLevel() + 1
	for i = 1, getn(arg) do
		local child = arg[i]
        -- Children of scroll frames can block components outside if they're layered above the scroll pane
        if parent.GetScrollChild and parent:GetScrollChild() == child then
            child:SetFrameLevel(level - 1)
        else
		    child:SetFrameLevel(level)
        end
		_FixFrameLevels(child, child:GetChildren())
	end
end

function FixFrameLevels(frame)
	return _FixFrameLevels(frame, frame:GetChildren())
end

-- Modified ChatGPT function
function RotateTexture(texture, degrees, extent)
    local angleRadians = math.rad(degrees)
    local cos = math.cos(angleRadians)
    local sin = math.sin(angleRadians)

    extent = (extent or 1) / 2

    local x1, y1 = -extent,  extent -- UL
    local x2, y2 = -extent, -extent -- LL
    local x3, y3 =  extent,  extent -- UR
    local x4, y4 =  extent, -extent -- LR

    local ULx, ULy = x1 * cos - y1 * sin + 0.5, x1 * sin + y1 * cos + 0.5
    local LLx, LLy = x2 * cos - y2 * sin + 0.5, x2 * sin + y2 * cos + 0.5
    local URx, URy = x3 * cos - y3 * sin + 0.5, x3 * sin + y3 * cos + 0.5
    local LRx, LRy = x4 * cos - y4 * sin + 0.5, x4 * sin + y4 * cos + 0.5

    texture:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

local PTTaskExecutor = CreateFrame("Frame", "PTTaskExecutor")
local taskQueue = {}
local offTaskQueue = {}
local PTTaskExecutor_OnUpdate = function()
    local runningQueue = taskQueue
    taskQueue = offTaskQueue
    for _, task in ipairs(runningQueue) do
        local ok, result = pcall(task)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("Puppeteer Task Error: "..result)
        end
    end
    ClearTable(runningQueue)
    if getn(taskQueue) == 0 then
        PTTaskExecutor:SetScript("OnUpdate", nil)
    end
end
function RunLater(func)
    table.insert(taskQueue, func)
    if PTTaskExecutor:GetScript("OnUpdate") == nil then
        PTTaskExecutor:SetScript("OnUpdate", PTTaskExecutor_OnUpdate)
    end
end

-- Returns the class without the first return variable fluff
function GetClass(unit)
    local _, class = UnitClass(unit)
    return class
end

function GetClasses()
    return Classes
end

function GetRandomClass()
    return Classes[math.random(1, 9)]
end

local healerClassesSet = ToSet(HealerClasses)
function IsHealerClass(unit)
    return healerClassesSet[GetClass(unit)] == 1
end

local classColors = {
    ["DRUID"] = {1.0, 0.49, 0.04},
    ["HUNTER"] = {0.67, 0.83, 0.45},
    ["MAGE"] = {0.41, 0.8, 0.94},
    ["PALADIN"] = {0.96, 0.55, 0.73},
    ["PRIEST"] = {1.0, 1.0, 1.0},
    ["ROGUE"] = {1.0, 0.96, 0.41},
    ["SHAMAN"] = {0.14, 0.35, 1.0},
    ["WARLOCK"] = {0.58, 0.51, 0.79},
    ["WARRIOR"] = {0.78, 0.61, 0.43}
}
function GetClassColor(class, asArray)
    local color = classColors[class]
    if not color then -- Unknown class
        color = {0.7, 0.7, 0.7}
    end
    if asArray then
        return color
    end
    return color[1], color[2], color[3]
end

-- Returns an array of spells starting with the string, ordered from highest rank to lowest.
-- Limit is 20 if nil, non-ranks not included. Adds non-ranked name unless specified otherwise.
function SearchSpells(startStr, limit, noNonRank)
    startStr = string.upper(startStr)
    limit = limit or 20
    local matchingSpells = {}
    local id = 1
    for i = 1, GetNumSpellTabs() do
        local breakOut
        local tabName, _, _, numSpells = GetSpellTabInfo(i)
        if tabName == "ZMounts" or tabName == "ZzCompanions" then -- No Turtle "spell" tabs
            id = id + numSpells
        else
            for j = 1, numSpells do
                local spellName, rank, realID = GetSpellName(id, "spell")
                if not IsSpellPassive(id, "spell") then
                    local fullName = spellName
                    if rank ~= "" then
                        fullName = fullName.."("..rank..")"
                    end
                    if StartsWith(string.upper(fullName), startStr) then
                        table.insert(matchingSpells, fullName)
                        if getn(matchingSpells) >= limit then
                            breakOut = true
                            break
                        end
                    end
                end
                id = id + 1
            end
        end
        if breakOut then
            break
        end
    end

    ReverseArray(matchingSpells)
    
    if not noNonRank then
        local alreadyFound = compost:GetTable()
        local toInsert = compost:GetTable()
        for i = 1, getn(matchingSpells) do
            local rank = ExtractSpellRank(matchingSpells[i])
            -- Don't add non rank if the user is explicitly typing out the rank already
            if (string.len(matchingSpells[i]) - string.len(rank or "") - 2) < (string.len(startStr)) then
                break
            end
            if rank then
                local baseSpell = string.sub(matchingSpells[i], 1, string.len(matchingSpells[i]) - string.len(rank) - 2)
                if not alreadyFound[baseSpell] then
                    alreadyFound[baseSpell] = true
                    table.insert(toInsert, compost:Acquire(i, baseSpell))
                end
            end
        end
        local offset = 0
        for _, insertion in ipairs(toInsert) do
            table.insert(matchingSpells, insertion[1] + offset, insertion[2])
            offset = offset + 1
        end
        compost:Reclaim(alreadyFound)
        compost:Reclaim(toInsert, 1)
    end

    return matchingSpells
end

function SearchMacros(startStr, limit)
    startStr = string.upper(startStr)
    limit = limit or 20
    local matchingMacros = {}
    for i = 1, GetNumMacros() do
        local name = GetMacroInfo(i)
        if StartsWith(string.upper(name), startStr) then
            table.insert(matchingMacros, name)
            if getn(matchingMacros) >= limit then
                break
            end
        end
    end
    return matchingMacros
end

function SearchItems(startStr, limit)
    startStr = string.upper(startStr)
    limit = limit or 20
    local alreadyFound = compost:GetTable()
    local matchingItems = {}
    for bag = 0, NUM_BAG_FRAMES do
        for slot = 1, GetContainerNumSlots(bag) do
            local name = GetBagSlotInfo(bag, slot)
            if name and not alreadyFound[name] and StartsWith(string.upper(name), startStr) then
                table.insert(matchingItems, name)
                alreadyFound[name] = true
                if getn(matchingItems) >= limit then
                    break
                end
            end
        end
    end
    compost:Reclaim(alreadyFound)
    return matchingItems
end

-- Checks for feign death as well
function IsDeadFriend(unit)
    return (UnitIsDead(unit) or UnitIsCorpse(unit)) and UnitIsFriend("player", unit) and not IsFeigning(unit)
end

local keyModifiers = {"None", "Shift", "Control", "Alt", "Shift+Control", "Shift+Alt", "Control+Alt", "Shift+Control+Alt"}
function GetKeyModifiers()
    return keyModifiers
end

-- L1: Shift
-- L2: Control
-- L3: Alt
KeyModifierMap = {}
do
    -- That moment when trying to be more concise goes terribly wrong
    local keys = {{"Shift", "S", {0.4, 1, 0.4}}, {"Control", "C", {0.4, 0.4, 1}}, {"Alt", "A", {1, 0.4, 0.4}}}
    local states = {true, false}
    for _, l1State in ipairs(states) do
        local l1 = {}
        KeyModifierMap[l1State] = l1
        for _, l2State in ipairs(states) do
            local l2 = {}
            l1[l2State] = l2
            for _, l3State in ipairs(states) do
                local keyStr = ""
                local keyStrColored = ""
                local keyAbbStr = ""
                local keyAbbStrColored = ""
                for i = 1, 3 do
                    if (i == 1 and l1State) or (i == 2 and l2State) or (i == 3 and l3State) then
                        local key = keys[i]
                        if keyStr ~= "" then
                            keyStr = keyStr.."+"
                            keyStrColored = keyStrColored.."+"
                            keyAbbStr = keyAbbStr.."+"
                            keyAbbStrColored = keyAbbStrColored.."+"
                        end
                        keyStr = keyStr..key[1]
                        keyStrColored = keyStrColored..Colorize(key[1], key[3])
                        keyAbbStr = keyAbbStr..key[2]
                        keyAbbStrColored = keyAbbStrColored..Colorize(key[2], key[3])
                    end
                end

                if keyStr == "" then
                    keyStr = "None"
                    keyStrColored = "None"
                    keyAbbStr = "None"
                    keyAbbStrColored = "None"
                end

                l2[l3State] = {keyStr, keyStrColored, keyAbbStr, keyAbbStrColored}
            end
        end
    end
end
function GetKeyModifier()
    return KeyModifierMap[IsShiftKeyDown() == 1][IsControlKeyDown() == 1][IsAltKeyDown() == 1][1]
end

function GetColoredKeyModifier()
    return KeyModifierMap[IsShiftKeyDown() == 1][IsControlKeyDown() == 1][IsAltKeyDown() == 1][2]
end

function GetAbbreviatedKeyModifier()
    return KeyModifierMap[IsShiftKeyDown() == 1][IsControlKeyDown() == 1][IsAltKeyDown() == 1][3]
end

function GetColoredAbbreviatedKeyModifier()
    return KeyModifierMap[IsShiftKeyDown() == 1][IsControlKeyDown() == 1][IsAltKeyDown() == 1][4]
end

function GetKeyModifierTypeByID(id)
    return KeyModifierMap[IsShiftKeyDown() == 1][IsControlKeyDown() == 1][IsAltKeyDown() == 1][id]
end

local nameOverrides = {
    ["LeftButton"] = "Left Button",
    ["RightButton"] = "Right Button",
    ["MiddleButton"] = "Middle Button"
}
function GetButtonName(rawButton)
    return nameOverrides[rawButton] or GetBindingText(rawButton, "KEY_")
end

local buttons = {"LeftButton", "MiddleButton", "RightButton", "Button4", "Button5"}
function GetAllButtons()
    return buttons
end

local buttonsSet = ToSet(buttons, true)
function GetAllButtonsSet()
    return buttonsSet
end

local upButtons = {}
for _, button in ipairs(buttons) do
    table.insert(upButtons, button.."Up")
end
function GetUpButtons()
    return upButtons
end

local downButtons = {}
for _, button in ipairs(buttons) do
    table.insert(downButtons, button.."Down")
end
function GetDownButtons()
    return downButtons
end

function GetCenterScreenPoint(componentWidth, componentHeight)
    return "TOPLEFT", (GetScreenWidth() / 2) - (componentWidth / 2), -((GetScreenHeight() / 2) - (componentHeight / 2))
end

-- Keeps the frame at the current position, while modifying the anchor point
function ConvertAnchor(frame, anchor)
    local leftX, rightX, topY, bottomY = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local centerX, centerY = frame:GetCenter()
    local x, y
    if anchor == "TOPLEFT" then
        x, y = leftX, topY
    elseif anchor == "TOPRIGHT" then
        x, y = rightX, topY
    elseif anchor == "BOTTOMLEFT" then
        x, y = leftX, bottomY
    elseif anchor == "BOTTOMRIGHT" then
        x, y = rightX, bottomY
    elseif anchor == "TOP" then
        x, y = centerX, topY
    elseif anchor == "BOTTOM" then
        x, y = centerX, bottomY
    elseif anchor == "LEFT" then
        x, y = leftX, centerY
    elseif anchor == "RIGHT" then
        x, y = rightX, centerY
    elseif anchor == "CENTER" then
        x, y = centerX, centerY
    end
    frame:ClearAllPoints()
    frame:SetPoint(anchor, UIParent, "TOPLEFT", x, y - GetScreenHeight())
end

function GetPowerType(unit)
    return PowerTypeMap[UnitPowerType(unit)]
end

function GetPowerColor(unit)
    return PowerColors[GetPowerType(unit)]
end

-- You never really know these days
function IsReallyInInstance()
    return IsInInstance() and not InstanceWorldZones[GetRealZoneText()]
end

-- Returns distance if UnitXP SP3 or SuperWoW is present;
-- 0 if unit is offline, or unit is enemy and SuperWoW is the distance provider;
-- 9999 if unit is not visible or UnitXP SP3 is not present.
-- Might try to do hacky stuff for people without mods later on.
function GetDistanceTo(unit)
    return GetDistanceBetween("player", unit)
end

function GetDistanceBetween_SuperWow(unit1, unit2)
    if not UnitIsConnected(unit1) or not UnitIsConnected(unit2) then
        return 0
    end

    if not UnitIsVisible(unit1) or not UnitIsVisible(unit2) then
        return 9999
    end

    local x1, z1, y1 = UnitPosition(unit1)
    local x2, z2, y2 = UnitPosition(unit2)
    
    if not x1 or not x2 then
        return 0
    end
    local dx = x2 - x1
    local dz = z2 - z1
    local dy = y2 - y1
    return math.sqrt(dx*dx + dz*dz + dy*dy)
end

function GetDistanceBetween_UnitXPSP3_Legacy(unit1, unit2)
    if not UnitIsConnected(unit1) or not UnitIsConnected(unit2) then
        return 0
    end

    if not UnitIsVisible(unit1) or not UnitIsVisible(unit2) then
        return 9999
    end

    return math.max((UnitXP("distanceBetween", unit1, unit2) or (9999 + 3)) - 3, 0) -- UnitXP SP3 modded function
end

function GetDistanceBetween_UnitXPSP3(unit1, unit2)
    if not UnitIsConnected(unit1) or not UnitIsConnected(unit2) then
        return 0
    end

    if not UnitIsVisible(unit1) or not UnitIsVisible(unit2) then
        return 9999
    end

    return math.max(UnitXP("distanceBetween", unit1, unit2) or 9999, 0) -- UnitXP SP3 modded function
end

function GetDistanceBetween_Vanilla(unit1, unit2)
    if not UnitIsConnected(unit1) or not UnitIsConnected(unit2) then
        return 0
    end

    if not UnitIsVisible(unit1) or not UnitIsVisible(unit2) then
        return 9999
    end

    if unit1 == "player" then
        if CheckInteractDistance(unit2, 3) then
            return 9
        end
        if CheckInteractDistance(unit2, 4) then
            return 27
        end
    end

    return 28
end

if UnitXPSP3 then
    if UnitXPSP3_Version > -1 then -- Newer versions have more accurate distances
        GetDistanceBetween = GetDistanceBetween_UnitXPSP3
    else -- Fall back to old distance calculation
        GetDistanceBetween = GetDistanceBetween_UnitXPSP3_Legacy
    end
elseif SuperWoW then
    GetDistanceBetween = GetDistanceBetween_SuperWow
else -- sad
    GetDistanceBetween = GetDistanceBetween_Vanilla
end

-- SuperWoW cannot provide precise distance for enemies
function CanClientGetPreciseDistance(alsoEnemies)
    return UnitXPSP3 or (SuperWoW and not alsoEnemies)
end

-- Returns whether unit is in sight if UnitXP SP3 is present, otherwise always true.
IsInSight = function()
    return true
end

do -- This is done to prevent crashes from checking sight too early
    local sightEnableFrame = CreateFrame("Frame")
    sightEnableFrame:RegisterEvent("ADDON_LOADED")
    sightEnableFrame:SetScript("OnEvent", function()
        if arg1 == "Puppeteer" and UnitXPSP3 then
            IsInSight = function(unit)
                return UnitXP("inSight", "player", unit) -- UnitXP SP3 modded function
            end
            sightEnableFrame:SetScript("OnEvent", nil)
        end
    end)
end

function CanClientSightCheck()
    return UnitXPSP3
end

function CanClientGetAuraIDs()
    return SuperWoW-- or TurtleWow -- Turtle ID fetching is not reliable
end

function IsSuperWowPresent()
    return SuperWoW
end

function IsUnitXPSP3Present()
    return UnitXPSP3
end

-- Only detects Pepopo's Nampower
function IsNampowerPresent()
    return Nampower
end

function IsTurtleWow()
    return TurtleWow
end

AllUnitsSet = ToSet(AllUnits)
FocusUnitsSet = ToSet(FocusUnits)
RunLater(function()
    PTLocale.Values(ResurrectionSpells)
    PTLocale.Keys(ResurrectionSpellsSet)
end)

InstanceWorldZones = ToSet({"Winter Veil Vale"}) -- Why is this an instance??