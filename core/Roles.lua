PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
local util = PTUtil
local colorize = util.Colorize
local GetColoredRoleText = util.GetColoredRoleText
local SplitString = util.SplitString

AssignedRoles = nil

LFTAutoRoleFrame = CreateFrame("Frame", "PT_LFTAutoRoleFrame")
function SetLFTAutoRoleEnabled(enabled)
    if not util.IsTurtleWow() then
        return
    end

    if not enabled then
        LFTAutoRoleFrame:SetScript("OnEvent", nil)
        LFTAutoRoleFrame:SetScript("OnUpdate", nil)
        LFTAutoRoleFrame:UnregisterAllEvents()
        return
    end

    if LFTAutoRoleFrame:GetScript("OnEvent") ~= nil then -- Already enabled
        return
    end
    
    local roleMap = {
        ["t"] = "Tank",
        ["h"] = "Healer",
        ["d"] = "Damage"
    }
    local offerCompleteTime = -1 -- The time the offer is completed, used to verify rolecheck info is valid
    local alreadyAssigned = {} -- The Tank & Healer names
    local scanDPSTime = -1
    local AutoRoleFrame_OnUpdate = function()
        if scanDPSTime > GetTime() then
            return
        end

        for _, unit in ipairs(PartyUnits) do
            local name = UnitName(unit)
            if name ~= "Unknown" and not util.ArrayContains(alreadyAssigned, name) then
                print("Assuming "..name.." is Damage")
                SetAssignedRole(name, "Damage")
            end
        end
        UpdateUnitFrameGroups()
        LFTAutoRoleFrame:SetScript("OnUpdate", nil)
    end
    LFTAutoRoleFrame:RegisterEvent("CHAT_MSG_ADDON")
    LFTAutoRoleFrame:SetScript("OnEvent", function()
        if arg1 == (LFT_ADDON_PREFIX or "TW_LFG") then
            -- After an offer is complete, it is immediately followed by rolecheck info for the tank and healer
            if strfind(arg2, "S2C_ROLECHECK_INFO") then
                if GetNumPartyMembers() == 4 then
                    local params = util.SplitString(arg2, ";")
                    local member = params[2]
                    params = util.SplitString(params[3], ":") -- get confirmed roles
                    if offerCompleteTime + 0.5 > GetTime() and table.getn(params) == 1 then
                        local role = roleMap[params[1]]
                        table.insert(alreadyAssigned, member)
                        SetAssignedRole(member, role) -- Tank & Healer is sent after the offer is complete
                        print("Assigning "..member.." to "..role)
                        if table.getn(alreadyAssigned) == 2 then -- Set rest as Damage after Tank & Healer is sent
                            -- Delay scanning party members because their names might not be loaded yet
                            scanDPSTime = GetTime() + 1.5
                            LFTAutoRoleFrame:SetScript("OnUpdate", AutoRoleFrame_OnUpdate)
                        end
                        UpdateUnitFrameGroups()
                    end
                end
            elseif strfind(arg2, "S2C_OFFER_COMPLETE") then
                alreadyAssigned = {}
                offerCompleteTime = GetTime()
            end
        end
    end)
end

function GetAssignedRole(name)
    if not AssignedRoles or not AssignedRoles[name] then
        return
    end
    AssignedRoles[name]["lastSeen"] = time()
    return AssignedRoles[name]["role"]
end

function GetUnitAssignedRole(unit)
    if not UnitIsPlayer(unit) then
        return
    end
    return GetAssignedRole(UnitName(unit))
end

function SetAssignedRole(name, role)
    if role == nil or role == "No Role" then
        AssignedRoles[name] = nil
        return
    end
    AssignedRoles[name] = {
        ["role"] = role,
        ["lastSeen"] = time()
    }
end

-- Returns true if role assignment failed
function SetUnitAssignedRole(unit, role)
    if not UnitIsPlayer(unit) then
        return true
    end
    SetAssignedRole(UnitName(unit), role)
end

function PruneAssignedRoles()
    local currentTime = time()
    for name, data in pairs(AssignedRoles) do
        if not data["lastSeen"] or data["lastSeen"] < currentTime - (24 * 60 * 60) then
            AssignedRoles[name] = nil
            --print("Pruned "..name.."'s role")
        end
    end
end

function SetRoleAndUpdate(name, role)
    SetAssignedRole(name, role)
    UpdateUnitFrameGroups()
end

function SetUnitRoleAndUpdate(unit, role)
    if not SetUnitAssignedRole(unit, role) then
        UpdateUnitFrameGroups()
    end
end

-- Players will be considered as the role in the index if they have the highest talent points in said index.
-- Classes not listed have only DPS specs and are not bothered to be scanned.
TalentCountRoleMap = {
    PRIEST = {
        "Healer", "Healer", "Damage"
    },
    PALADIN = {
        "Healer", "Tank", "Damage"
    },
    WARRIOR = {
        "Damage", "Damage", "Tank"
    },
    SHAMAN = {
        "Damage", "Damage", "Healer"
    },
    DRUID = { -- Spec #2(Feral) will be swapped to Tank if Thick Hide talent is found
        "Damage", "Damage", "Healer"
    }
}

local PlayerTalentData = {}
local SCAN_TIMEOUT = 4
local scanTimeoutAt
local talentScanner = CreateFrame("Frame", "PTTalentScanner")
local function TalentScanner_OnUpdate()
    if GetTime() >= scanTimeoutAt then
        talentScanner:SetScript("OnUpdate", nil)
        util.ClearTable(PlayerTalentData)
        if InspectTalentsComFrame then
            InspectTalentsComFrame:RegisterEvent("CHAT_MSG_ADDON")
        end
    end
end
talentScanner:RegisterEvent("CHAT_MSG_ADDON")
talentScanner:SetScript("OnEvent", function()
    if arg1 == "TW_CHAT_MSG_WHISPER" then
        local message = arg2
		local sender = arg4

        if not PlayerTalentData[sender] then
            return
        end

        if string.find(message, "INSTalentTabInfo;", 1, true) then
            -- This is sent right before receiving info for individual talents in the tree
            local split = SplitString(message, ';')
            local index = tonumber(split[2])
            local pointsSpent = tonumber(split[4])

            PlayerTalentData[sender].trees[index] = {points = pointsSpent, talents = {}}
        elseif string.find(message, "INSTalentInfo;", 1, true) then
            local split = SplitString(message, ';')

            local tree = tonumber(split[2])
            local tier = tonumber(split[5])
            local column = tonumber(split[6])
            local currRank = tonumber(split[7])

            local cache = PlayerTalentData[sender]
            local talents = cache.trees[tree].talents
            talents[tier.."-"..column] = currRank
        elseif string.find(message, "INSTalentEND;", 1, true) then
            local data = PlayerTalentData[sender]
            local trees = data.trees
            local mostPoints = 0
            local mostIndex = 0
            for i = 1, 3 do
                if trees[i] and trees[i].points > mostPoints then -- TODO: Error
                    mostPoints = trees[i].points
                    mostIndex = i
                end
            end
            local class = data.class
            if mostIndex > 0 then
                -- Check for Druid Thick Hide talent, set as tank if they have it
                if class == "DRUID" and mostIndex == 2 and (trees[2].talents["2-3"] or 0) > 0 then
                    SetRoleAndUpdate(sender, "Tank")
                else
                    SetRoleAndUpdate(sender, mostPoints > 0 and TalentCountRoleMap[class][mostIndex] or "Damage")
                end
            end
            PlayerTalentData[sender] = nil
            if util.IsTableEmpty(PlayerTalentData) then
                scanTimeoutAt = 0 -- Re-enable inspect comm next frame
            end
        end
    end
end)

local function requestTalents(name)
    if name == UnitName("player") then
        if InspectTalentsComFrame then
            -- Fake a message to ourself to send our own talents to ourself (lol)
            local event, arg1, arg2, arg4 = _G.event, _G.arg1, _G.arg2, _G.arg4
            _G.event, _G.arg1, _G.arg2, _G.arg4 = "CHAT_MSG_ADDON", "TW_CHAT_MSG_WHISPER", "INSShowTalents", UnitName("player")
            InspectTalentsComFrame:GetScript("OnEvent")()
            _G.event, _G.arg1, _G.arg2, _G.arg4 = event, arg1, arg2, arg4
            return
        end
    end
    SendAddonMessage("TW_CHAT_MSG_WHISPER<"..name..">", "INSShowTalents", "GUILD")
end

local function startTalentScan(name, class)
    PlayerTalentData[name] = {class = class, trees = {}}
    talentScanner:SetScript("OnUpdate", TalentScanner_OnUpdate)
    scanTimeoutAt = GetTime() + SCAN_TIMEOUT
    if InspectTalentsComFrame then -- This frame generates errors if there's unexpected talent inspections
        InspectTalentsComFrame:UnregisterEvent("CHAT_MSG_ADDON")
    end
    requestTalents(name)
end

function AutoRole(unit)
    local class = util.GetClass(unit)
    if not TalentCountRoleMap[class] then
        SetUnitRoleAndUpdate(unit, "Damage")
        return
    end
    if not UnitIsConnected(unit) then -- Can't request offline player's talents
        return
    end
    startTalentScan(UnitName(unit), class)
end

function AutoRoleByNameClass(name, class)
    if not TalentCountRoleMap[class] then
        SetRoleAndUpdate(name, "Damage")
        return
    end
    startTalentScan(name, class)
end

RoleAssignInfo = {}

RoleDropdown = PTGuiLib.Get("dropdown", UIParent)

function InitRoleDropdown()
    local initFunc = function(self)
        self.checked = (GetAssignedRole(RoleAssignInfo.Name) or "No Role") == self.role
    end

    local genRole = function(role)
        return {
            text = GetColoredRoleText(role),
            role = role,
            initFunc = initFunc,
            func = function(info)
                SetAssignedRole(RoleAssignInfo.Name, info.role)
                UpdateUnitFrameGroups()
            end
        }
    end
    local massRoleFunc = function(info)
        if not RoleAssignInfo.FrameGroup then
            return
        end
        for _, ui in pairs(RoleAssignInfo.FrameGroup.uis) do
            if (not ui:GetRole() or not info.role) and UnitIsPlayer(ui:GetUnit()) then
                SetAssignedRole(UnitName(ui:GetUnit()), info.role)
            end
        end
        UpdateUnitFrameGroups()
        RoleDropdown:SetToggleState(false)
    end
    local genMassRole = function(role)
        return {
            text = GetColoredRoleText(role),
            role = role,
            notCheckable = true,
            func = massRoleFunc
        }
    end

    local options = {
        {
            initFunc = function(self)
                self.text = colorize(RoleAssignInfo.Name.."'s Role", RoleAssignInfo.ClassColor)
            end,
            notCheckable = true,
            disabled = true,
            textHeight = 12
        }, 
        genRole("Tank"),
        genRole("Healer"),
        genRole("Damage"),
        genRole("No Role"),
        {
            notCheckable = true,
            disabled = true
        }, {
            text = "Set Unassigned As",
            tooltipTitle = "Set Unassigned As",
            tooltipText = "Mass-set the roles of unassigned players. Only applies to players contained in this UI group.",
            notCheckable = true,
            textHeight = 11,
            children = {
                genMassRole("Tank"),
                genMassRole("Healer"),
                genMassRole("Damage")
            }
        }, {
            text = "Clear Roles",
            tooltipTitle = "Clear Roles",
            tooltipText = "Clear all players' roles. Only applies to players contained in this UI group.",
            notCheckable = true,
            textHeight = 11,
            func = massRoleFunc
        }
    }
    if PuppeteerSettings.IsExperimentEnabled("AutoRole") then
        table.insert(options, 6, {
            text = colorize("Auto Detect", 1, 0.6, 0),
            func = function()
                if not RoleAssignInfo.FrameGroup then
                    return
                end
                AutoRoleByNameClass(RoleAssignInfo.Name, RoleAssignInfo.Class)
            end
        })
        local lastMassRole = 0
        table.insert(options, 9, {
            text = "Auto Detect Unassigned",
            tooltipTitle = "Auto Detect Unassigned",
            tooltipText = "Automatically detect the roles of unassigned players. Only applies to players contained in this UI group.",
            notCheckable = true,
            textHeight = 11,
            func = function()
                if not RoleAssignInfo.FrameGroup then
                    return
                end
                if lastMassRole + 6 > GetTime() then
                    Puppeteer.Info("Please wait a moment before requesting roles again")
                    return
                end
                lastMassRole = GetTime()
                for _, ui in pairs(RoleAssignInfo.FrameGroup.uis) do
                    if UnitIsPlayer(ui:GetUnit()) and not GetUnitAssignedRole(ui:GetUnit()) then
                        AutoRole(ui:GetUnit())
                    end
                end
            end
        })
    end
    RoleDropdown:SetOptions(options)
end