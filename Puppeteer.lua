Puppeteer = {}
PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
_G.PuppeteerLib = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0")

VERSION = GetAddOnMetadata("Puppeteer", "version")

TestUI = false

Banzai = AceLibrary("Banzai-1.0")
HealComm = AceLibrary("HealComm-1.0")
GuidRoster = nil -- Will be nil if SuperWoW isn't present

local compost = AceLibrary("Compost-2.0")
local util = PTUtil
local colorize = util.Colorize
local GetKeyModifier = util.GetKeyModifier
local GetClass = util.GetClass
local GetPowerType = util.GetPowerType
local UseItem = util.UseItem
local GetItemCount = util.GetItemCount

PartyUnits = util.PartyUnits
PetUnits = util.PetUnits
TargetUnits = util.TargetUnits
RaidUnits = util.RaidUnits
RaidPetUnits = util.RaidPetUnits
AllUnits = util.AllUnits
AllUnitsSet = util.AllUnitsSet
AllCustomUnits = util.CustomUnits
AllCustomUnitsSet = util.CustomUnitsSet

local ptBarsPath = util.GetAssetsPath().."textures\\bars\\"
BarStyles = {
    ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Blizzard Smooth"] = ptBarsPath.."Blizzard-Smooth",
    ["Blizzard Raid"] = ptBarsPath.."Blizzard-Raid",
    ["Blizzard Raid Sideless"] = ptBarsPath.."Blizzard-Raid-Sideless",
    ["Puppeteer"] = ptBarsPath.."Puppeteer",
    ["Puppeteer Borderless"] = ptBarsPath.."Puppeteer-Borderless",
    ["Puppeteer Shineless"] = ptBarsPath.."Puppeteer-Shineless",
    ["Puppeteer Shineless Borderless"] = ptBarsPath.."Puppeteer-Shineless-Borderless"
}

CurrentlyHeldButton = nil

-- An unmapped array of all unit frames
AllUnitFrames = {}
-- A map of units to an array of unit frames associated with the unit
PTUnitFrames = {}

-- Key: Unit frame group name | Value: The group
UnitFrameGroups = {}

CustomUnitGUIDMap = PTUnitProxy and PTUnitProxy.CustomUnitGUIDMap or {}
GUIDCustomUnitMap = PTUnitProxy and PTUnitProxy.GUIDCustomUnitMap or {}


CurrentlyInRaid = false

Mouseover = nil

-- Returns the array of unit frames of the unit
function GetUnitFrames(unit)
    return PTUnitFrames[unit]
end

-- A temporary dummy function while the addon initializes. See below for the real iterator.
function UnitFrames(unit)
    return function() end
end

local function OpenUnitFramesIterator()
    -- UnitFrames function definition.
    -- Returns an iterator for the unit frames of the unit.
    -- These iterators have a serious problem in that they do not support concurrent iteration.
    if util.IsSuperWowPresent() then
        local EMPTY_UIS = {}
        local PTUnitFrames = PTUnitFrames
        local GuidUnitMap = PTGuidRoster.GuidUnitMap
        local iterTable = {} -- The table reused for iteration over GUID units
        local uis
        local i = 0
        local len = 0
        local iterFunc = function()
            i = i + 1
            if i <= len then
                return uis[i]
            end
        end
        function UnitFrames(unit)
            if i < len then
                print("Collision: "..i.."/"..len)
            end
            if GuidUnitMap[unit] then -- If a GUID is provided, ALL UIs associated with that GUID will be iterated
                uis = iterTable
                for i = 1, table.getn(uis) do
                    uis[i] = nil
                end
                table.setn(uis, 0)
                for _, unit in pairs(GuidUnitMap[unit]) do
                    for _, frame in ipairs(PTUnitFrames[unit] or EMPTY_UIS) do
                        table.insert(uis, frame)
                    end
                end
            else
                uis = PTUnitFrames[unit] or EMPTY_UIS
            end
            len = table.getn(uis)
            i = 0
            return iterFunc
        end
    else -- Optimized version for vanilla
        local PTUnitFrames = PTUnitFrames
        local uis
        local i = 0
        local len = 0
        local iterFunc = function()
            i = i + 1
            if i <= len then
                return uis[i]
            end
        end
        function UnitFrames(unit)
            i = 0
            uis = PTUnitFrames[unit]
            len = table.getn(uis)
            return iterFunc
        end
    end
end

function Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function UpdateUnitFrameGroups()
    for _, group in pairs(UnitFrameGroups) do
        group:UpdateUIPositions()
    end
end

function UpdateAllIncomingHealing()
    if PTHealPredict then
        for _, ui in ipairs(AllUnitFrames) do
            if PTOptions.UseHealPredictions then
                local _, guid = UnitExists(ui:GetUnit())
                ui:SetIncomingHealing(PTHealPredict.GetIncomingHealing(guid))
            else
                ui:SetIncomingHealing(0)
            end
        end
    else
        for _, ui in ipairs(AllUnitFrames) do
            if PTOptions.UseHealPredictions then
                ui:UpdateIncomingHealing()
            else
                ui:SetIncomingHealing(0)
            end
        end
    end
end

function UpdateAllOutlines()
    for _, ui in ipairs(AllUnitFrames) do
        ui:UpdateOutline()
    end
end

function CreateUnitFrameGroup(groupName, environment, units, petGroup, profile, sortByRole)
    if UnitFrameGroups[groupName] then
        error("[Puppeteer] Tried to create a unit frame group using existing name! \""..groupName.."\"")
        return
    end
    local uiGroup = PTUnitFrameGroup:New(groupName, environment, units, petGroup, profile, sortByRole)
    for _, unit in ipairs(units) do
        local ui = PTUnitFrame:New(unit, AllCustomUnitsSet[unit] ~= nil)
        if not PTUnitFrames[unit] then
            PTUnitFrames[unit] = {}
        end
        table.insert(PTUnitFrames[unit], ui)
        table.insert(AllUnitFrames, ui)
        uiGroup:AddUI(ui, true)
        if unit ~= "target" then
            ui:Hide()
        end
    end
    UnitFrameGroups[groupName] = uiGroup
    uiGroup:UpdateUIPositions()
    return uiGroup
end

local function initUnitFrames()
    local getSelectedProfile = PuppeteerSettings.GetSelectedProfile
    CreateUnitFrameGroup("Party", "party", PartyUnits, false, getSelectedProfile("Party"))
    CreateUnitFrameGroup("Pets", "party", PetUnits, true, getSelectedProfile("Pets"))
    CreateUnitFrameGroup("Raid", "raid", RaidUnits, false, getSelectedProfile("Raid"))
    CreateUnitFrameGroup("Raid Pets", "raid", RaidPetUnits, true, getSelectedProfile("Raid Pets"))
    CreateUnitFrameGroup("Target", "all", TargetUnits, false, getSelectedProfile("Target"), false)
    if util.IsSuperWowPresent() then
        CreateUnitFrameGroup("Focus", "all", PTUnitProxy.CustomUnitsMap["focus"], false, getSelectedProfile("Focus"), false)
        CreateUnitFrameGroup("Enemy", "all", PTUnitProxy.CustomUnitsMap["enemy"], false, getSelectedProfile("Enemy"), false)
    end

    local baseCondition = UnitFrameGroups["Target"].ShowCondition
    UnitFrameGroups["Target"].ShowCondition = function(self)
        local friendly = not UnitCanAttack("player", "target")
        return (PTOptions.AlwaysShowTargetFrame or (UnitExists("target") and 
            (friendly and PTOptions.ShowTargets.Friendly) or (not friendly and PTOptions.ShowTargets.Hostile))) 
            and baseCondition(self)
    end

    OpenUnitFramesIterator()
end

function OnAddonLoaded()
    PuppeteerSettings.SetDefaults()

    if PTBindings == nil then
        GenerateDefaultBindings()
    end

    InitOverrideBindingsMapping()
    InitBindingDisplayCache()

    if util.HasModVersion("Nampower", util.Nampower_v3_0) then
        SetCVar("NP_EnableAuraCastEvents", 1)
        SetCVar("NP_EnableSpellHealEvents", 1)
    end

    if util.IsSuperWowPresent() then
        -- In case other addons override unit functions, we want to make sure we're using their functions
        PTUnitProxy.CreateUnitProxies()

        -- Do it again after all addons have loaded
        local frame = CreateFrame("Frame")
        local reapply = GetTime() + 0.1
        frame:SetScript("OnUpdate", function()
            if GetTime() > reapply then
                PTUnitProxy.CreateUnitProxies()
                frame:SetScript("OnUpdate", nil)
            end
        end)
    end

    if not _G.PTRoleCache then
        _G.PTRoleCache = {}
    end
    if not _G.PTRoleCache[GetRealmName()] then
        _G.PTRoleCache[GetRealmName()] = {}
    end
    AssignedRoles = _G.PTRoleCache[GetRealmName()]
    PruneAssignedRoles()

    if util.IsSuperWowPresent() then
        PTUnit.UpdateGuidCaches()

        local customUnitUpdater = CreateFrame("Frame", "PTCustomUnitUpdater")
        local nextUpdate = GetTime() + 0.25
        -- Older versions of SuperWoW had an issue where units that aren't part of normal units wouldn't receive events,
        -- so updates are done manually
        local needsManualUpdates = util.SuperWoWFeatureLevel < util.SuperWoW_v1_4
        local existing = {}
        local nextCleanup = GetTime() + 10
        customUnitUpdater:SetScript("OnUpdate", function()
            if GetTime() > nextUpdate then
                nextUpdate = GetTime() + 0.25

                for guid, units in pairs(GUIDCustomUnitMap) do
                    local exists = UnitExists(guid) == 1
                    local needsUpdate = false
                    if (existing[guid] ~= nil) ~= exists then
                        existing[guid] = exists or nil
                        needsUpdate = true
                    end

                    if needsManualUpdates or needsUpdate then
                        PTUnit.Get(guid):UpdateAuras()
                        for _, unit in ipairs(units) do
                            for ui in UnitFrames(unit) do
                                ui:UpdateAll()
                                ui:UpdateIncomingHealing()
                            end
                        end
                    end
                end

                if GetTime() > nextCleanup then
                    nextCleanup = GetTime() + 10
                    for guid in pairs(existing) do
                        if not GUIDCustomUnitMap[guid] then
                            existing[guid] = nil
                        end
                    end
                end
            end
        end)
    else
        PTUnit.CreateCaches()
    end
    PuppeteerSettings.UpdateTrackedDebuffTypes()
    PTProfileManager.InitializeDefaultProfiles()

    do
        if PTOptions.Scripts.OnLoad then
            local scriptString = "local GetProfile = PTProfileManager.GetProfile "..
                "local CreateProfile = PTProfileManager.CreateProfile "..PTOptions.Scripts.OnLoad
            local script, err = loadstring(scriptString)
            if script then
                local ok, result = pcall(script)
                if not ok then
                    DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 1, 0.4, 0.4)..colorize("ERROR: ", 1, 0.2, 0.2)
                        ..colorize("The Load Script produced an error! If this causes Puppeteer to fail to load, "..
                            "you will need to manually edit the script in your game files.", 1, 0.4, 0.4))
                    DEFAULT_CHAT_FRAME:AddMessage(colorize("OnLoad Script Error: "..tostring(result), 1, 0, 0))
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 1, 0.4, 0.4)..colorize("ERROR: ", 1, 0.2, 0.2)
                    ..colorize("The Load Script failed to load: "..err, 1, 0.4, 0.4))
            end
        end
    end
    PTSettingsGui.Init()
    if PTHealPredict then
        PTHealPredict.OnLoad()

        PTHealPredict.HookUpdates(function(guid, incomingHealing, incomingDirectHealing)
            if not PTOptions.UseHealPredictions then
                return
            end
            local units = GuidRoster.GetUnits(guid)
            if not units then
                return
            end
            for _, unit in ipairs(units) do
                for ui in UnitFrames(unit) do
                    ui:SetIncomingHealing(incomingHealing, incomingDirectHealing)
                end
            end
        end)
    else
        local roster = AceLibrary("RosterLib-2.0")
        PuppeteerLib:RegisterEvent("HealComm_Healupdate", function(name)
            if not PTOptions.UseHealPredictions then
                return
            end
            local unit = roster:GetUnitIDFromName(name)
            if unit then
                for ui in UnitFrames(unit) do
                    ui:UpdateIncomingHealing()
                end
            end
            if UnitName("target") == name then
                for ui in UnitFrames("target") do
                    ui:UpdateIncomingHealing()
                end
            end
        end)
        PuppeteerLib:RegisterEvent("HealComm_Ressupdate", function(name)
            local unit = roster:GetUnitIDFromName(name)
            if unit then
                for ui in UnitFrames(unit) do
                    ui:UpdateHealth()
                end
            end
            if UnitName("target") == name then
                for ui in UnitFrames("target") do
                    ui:UpdateHealth()
                end
            end
        end)
    end

    InitRoleDropdown()
    
    SetLFTAutoRoleEnabled(PTOptions.LFTAutoRole)

    SetOutOfRangeArrowEnabled(PTOptions.OutOfRangeArrow)

    if util.IsSuperWowPresent() then
        SetEnemyTrackingEnabled(PuppeteerSettings.IsExperimentEnabled("Enemy"))
    end

    TestUI = PTOptions.TestUI

    if TestUI then
        DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] UI Testing is enabled. Use /pt testui to disable.", 1, 0.6, 0.6))
    end

    initUnitFrames()
    StartUnitTracker()

    PuppeteerLib:RegisterEvent("Banzai_UnitGainedAggro", function(unit)
        if PTGuidRoster then
            unit = PTGuidRoster.GetUnitGuid(unit)
        end
        for ui in UnitFrames(unit) do
            ui:UpdateOutline()
        end
    end)
	PuppeteerLib:RegisterEvent("Banzai_UnitLostAggro", function(unit)
        if PTGuidRoster then
            unit = PTGuidRoster.GetUnitGuid(unit)
        end
        for ui in UnitFrames(unit) do
            ui:UpdateOutline()
        end
    end)

    if PTOnLoadInfoDisabled == nil then
        PTOnLoadInfoDisabled = false
    end

    do
        local INFO_SEND_TIME = GetTime() + 0.5
        local infoFrame = CreateFrame("Frame")
        infoFrame:SetScript("OnUpdate", function()
            if GetTime() < INFO_SEND_TIME then
                return
            end
            infoFrame:SetScript("OnUpdate", nil)
            if PTGlobalOptions.ShowLoadMessage then
                DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] Use ", 0.5, 1, 0.5)..colorize("/pt help", 0, 1, 0)
                    ..colorize(" to see commands.", 0.5, 1, 0.5))
            end
    
            if not util.IsSuperWowPresent() and util.IsNampowerPresent() then
                DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 1, 0.4, 0.4)..colorize("WARNING: ", 1, 0.2, 0.2)
                    ..colorize("You are using Nampower without SuperWoW, which will cause heal predictions to be wildly inaccurate "..
                    "for you and your raid members! It is highly recommended to install SuperWoW.", 1, 0.4, 0.4))
            end

            if util.IsSuperWowPresent() and not HealComm:IsEventRegistered("UNIT_CASTEVENT") then
                DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 1, 0.4, 0.4)..colorize("WARNING: ", 1, 0.2, 0.2)
                    ..colorize("You have another addon that uses a HealComm version that is incompatible with SuperWoW! "..
                    "This will cause wildly inaccurate heal predictions to be shown to your raid members. It is "..
                    "recommended to either unload the offending addon or copy Puppeteer's HealComm "..
                    "into the other addon.", 1, 0.4, 0.4))
            end
        end)
    end

    do
        if PTOptions.Scripts.OnPostLoad then
            local scriptString = "local GetProfile = PTProfileManager.GetProfile "..
                "local CreateProfile = PTProfileManager.CreateProfile "..PTOptions.Scripts.OnPostLoad
            local script, err = loadstring(scriptString)
            if script then
                local ok, result = pcall(script)
                if not ok then
                    DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 1, 0.4, 0.4)..colorize("ERROR: ", 1, 0.2, 0.2)
                        ..colorize("The Postload Script produced an error! If this causes Puppeteer to fail to operate, "..
                            "you may need to manually edit the script in your game files.", 1, 0.4, 0.4))
                    DEFAULT_CHAT_FRAME:AddMessage(colorize("OnPostLoad Script Error: "..tostring(result), 1, 0, 0))
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 1, 0.4, 0.4)..colorize("ERROR: ", 1, 0.2, 0.2)
                    ..colorize("The Postload Script failed to load: "..err, 1, 0.4, 0.4))
            end
        end
    end
end

function PromptHealersMateImport()
    if IsAddOnLoaded("HealersMate") and HealersMate and PTOptions["ImportedFromHM"] == nil then
        local dialog = PTGuiLib.Get("simple_dialog", UIParent)
            :SetWidth(350)
            :SetPoint("CENTER")
            :SetTitle("Puppeteer HealersMate Import")
            :SetText("Puppeteer has detected HealersMate. Would you like to import your character's data from HealersMate? "..
                "This will overwrite your settings in Puppeteer!")
            :SetMovable(true)
        dialog:GetHandle():SetFrameStrata("HIGH")
        dialog:SetDisposeHandler(function(self)
            self:GetHandle():SetFrameStrata("MEDIUM")
        end)

        dialog:AddButton("Import & Disable HM", function()
            DisableAddOn("HealersMate")
            ImportHealersMateSettings()
        end)
        dialog:AddButton("Import & Don't Disable HM", function()
            ImportHealersMateSettings()
        end)
        dialog:AddButton("Don't Import & Disable HM", function()
            PTOptions["ImportedFromHM"] = false
            DisableAddOn("HealersMate")
            ReloadUI()
            dialog:Dispose()
        end)
        dialog:AddButton("Don't Import & Don't Disable HM", function()
            PTOptions["ImportedFromHM"] = false
            dialog:Dispose()
        end)
        dialog:AddButton("Ask Me Later", function()
            dialog:Dispose()
        end)
    end
end

function ImportHealersMateSettings()
    if _G.HMOptions then
        _G.PTOptions = util.CloneTable(_G.HMOptions, true)
        _G.PTOptions["ImportedFromHM"] = true
    end
    if _G.HMSpells then
        local loadout = ConvertSpellsToBindings(_G.HMSpells)
        GetBindingLoadouts()["Imported"] = loadout
        PTBindings.SelectedLoadout = "Imported"
    end

    if _G.PTGlobalOptions["ImportedFromHM"] == nil then
        -- Import global fields if HealersMate has a larger heal cache
        if _G.PTHealCache and (util.GetTableSize(_G.PTHealCache) < util.GetTableSize(_G.HMHealCache)) then
            _G.PTHealCache = _G.HMHealCache
            _G.PTPlayerHealCache = _G.HMPlayerHealCache
            _G.PTRoleCache = _G.HMRoleCache
        end
        _G.PTGlobalOptions["ImportedFromHM"] = true
    end

    ReloadUI()
end

-- Converts legacy HealersMate spells to a Puppeteer loadout
function ConvertSpellsToBindings(spells)
    local specialToActionMap = {
        ["TARGET"] = "Target",
        ["ASSIST"] = "Assist",
        ["FOLLOW"] = "Follow",
        ["CONTEXT"] = "Menu",
        ["ROLE"] = "Role",
        ["SET ROLE"] = "Role",
        ["ROLE: TANK"] = "Role: Tank",
        ["ROLE: HEALER"] = "Role: Healer",
        ["ROLE: DAMAGE"] = "Role: Damage",
        ["ROLE: NONE"] = "Role: None",
        ["FOCUS"] = "Focus",
        ["PROMOTE FOCUS"] = "Promote Focus"
    }
    local loadout = CreateEmptyBindingsLoadout()
    for target, modifiers in pairs(spells) do
        for modifier, buttons in pairs(modifiers) do
            loadout.Bindings[target][modifier] = {}
            for button, spell in pairs(buttons) do
                local binding
                if util.StartsWith(spell, "Item: ") then
                    binding = {
                        Type = "ITEM",
                        Data = string.sub(spell, string.len("Item: ") + 1)
                    }
                elseif util.StartsWith(spell, "Macro: ") then
                    binding = {
                        Type = "MACRO",
                        Data = string.sub(spell, string.len("Macro: ") + 1)
                    }
                elseif specialToActionMap[string.upper(spell)] then
                    binding = {
                        Type = "ACTION",
                        Data = specialToActionMap[string.upper(spell)]
                    }
                else
                    binding = {
                        Type = "SPELL",
                        Data = spell
                    }
                end

                loadout.Bindings[target][modifier][button] = binding
            end
        end
    end
    PruneLoadout(loadout)
    return loadout
end

function CheckPartyFramesEnabled()
    local shouldBeDisabled = (CurrentlyInRaid and PTOptions.DisablePartyFrames.InRaid) or 
        (not CurrentlyInRaid and PTOptions.DisablePartyFrames.InParty)
    SetPartyFramesEnabled(not shouldBeDisabled)
end

function SetPartyFramesEnabled(enabled)
    if enabled then
        for i = 1, MAX_PARTY_MEMBERS do
            local frame = getglobal("PartyMemberFrame"..i)
            if frame and frame.PTRealShow then
                frame.Show = frame.PTRealShow
                frame.PTRealShow = nil

                if UnitExists("party"..i) then
                    frame:Show()
                end
                local prevThis = _G.this
                _G.this = frame
                PartyMemberFrame_OnLoad()
                _G.this = prevThis
            end
        end
    else
        for i = 1, MAX_PARTY_MEMBERS do
            local frame = getglobal("PartyMemberFrame"..i)
            if frame and not frame.PTRealShow then
                frame:UnregisterAllEvents()
                frame.PTRealShow = frame.Show
                frame.Show = function() end
                frame:Hide()
            end
        end
    end
end

function ToggleFocusUnit(unit)
    if PTUnitProxy.IsUnitUnitType(unit, "focus") then
        if not PTUnitProxy.CustomUnitsSetMap["focus"][unit] then
            return -- Do not toggle focus if user is clicking on a UI that isn't the focus UI
        end
        UnfocusUnit(unit)
    else
        FocusUnit(unit)
    end
end

function FocusUnit(unit)
    local guid = PTGuidRoster.ResolveUnitGuid(unit)
    if not guid or PTUnitProxy.IsGuidUnitType(guid, "focus") then
        return
    end

    PTUnitProxy.SetGuidUnitType(guid, "focus")
    PlaySound("GAMETARGETHOSTILEUNIT")
end

function UnfocusUnit(unit)
    local guid = PTGuidRoster.ResolveUnitGuid(unit)
    if not guid then
        return
    end
    local focusUnit = PTUnitProxy.GetCurrentUnitOfType(guid, "focus")
    if not focusUnit then
        return
    end
    PTUnitProxy.SetCustomUnitGuid(focusUnit, nil)
    PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
end

function PromoteFocus(unit)
    local guid = PTGuidRoster.ResolveUnitGuid(unit)
    if not guid then
        return
    end
    PTUnitProxy.PromoteGuidUnitType(guid, "focus")
end

function CycleFocus(onlyAttackable)
    PTUnitProxy.CycleUnitType("focus", onlyAttackable)
end

local emptySpell = {}
function UnitFrame_OnClick(button, unit, unitFrame)
    local binding = GetBindingFor(unit, GetKeyModifier(), button)
    if not UnitExists(unit) then
        if binding and binding.Type == "ACTION" then
            RunBinding(binding, unit, unitFrame)
        end
        return
    end
    if not binding then
        RunBinding_Spell(emptySpell, unit)
        return
    end

    RunBinding(binding, unit, unitFrame)
end

local CheckGroupThrottler = CreateFrame("Frame", "PTCheckGroupThrottler")
local MAX_GROUP_UPDATE_TOKENS = 2
local GROUP_UPDATE_RECOVERY = 0.2
local groupUpdateTokens = 2
local nextGroupUpdateToken = 0
local groupUpdateWaiting = false
local CheckGroupThrottler_OnUpdate = function()
    if nextGroupUpdateToken <= GetTime() then
        groupUpdateTokens = groupUpdateTokens + 1
        nextGroupUpdateToken = GetTime() + GROUP_UPDATE_RECOVERY
        if groupUpdateWaiting then
            groupUpdateWaiting = false
            print("Delayed Group Update")
            CheckGroupThrottled()
        end
        if groupUpdateTokens == MAX_GROUP_UPDATE_TOKENS then
            CheckGroupThrottler:SetScript("OnUpdate", nil)
        end
    end
end
function UseGroupUpdateToken()
    if groupUpdateTokens > 0 then
        groupUpdateTokens = groupUpdateTokens - 1
        if CheckGroupThrottler:GetScript("OnUpdate") == nil then
            nextGroupUpdateToken = GetTime() + GROUP_UPDATE_RECOVERY
            CheckGroupThrottler:SetScript("OnUpdate", CheckGroupThrottler_OnUpdate)
        end
        return true
    end
    groupUpdateWaiting = true
    return false
end

-- Same as CheckGroup, but may delay and consolidate checks if there's been many calls
function CheckGroupThrottled()
    if UseGroupUpdateToken() then
        CheckGroup()
        print("Group Update "..groupUpdateTokens)
    else
        print("GROUP UPDATE THROTTLED")
    end
end

-- Reevaluates what UI frames should be shown and updates the roster if using SuperWoW
function CheckGroup()
    --StartTiming("CheckGroup")
    if GetNumRaidMembers() > 0 then
        if not CurrentlyInRaid then
            CurrentlyInRaid = true
            SetPartyFramesEnabled(not PTOptions.DisablePartyFrames.InRaid)
        end
    else
        if CurrentlyInRaid then
            CurrentlyInRaid = false
            SetPartyFramesEnabled(not PTOptions.DisablePartyFrames.InParty)
        end
    end
    local superwow = util.IsSuperWowPresent()
    if superwow then
        GuidRoster.ResetRoster()
        GuidRoster.PopulateRoster()
        PTUnit.UpdateGuidCaches()
    end
    for _, unit in ipairs(util.AllRealUnits) do
        local exists, guid = UnitExists(unit)
        if unit ~= "target" then
            if exists then
                for ui in UnitFrames(unit) do
                    ui:Show()
                end
            else
                for ui in UnitFrames(unit) do
                    ui:Hide()
                end
            end
        end
    end
    for _, group in pairs(UnitFrameGroups) do
        group:EvaluateShown()
    end
    if not superwow then -- If SuperWoW isn't present, the units may have shifted and thus require a full scan
        PTUnit.UpdateAllUnits()
    end
    for _, ui in ipairs(AllUnitFrames) do
        if ui:IsShown() then
            ui:UpdateRange()
            ui:UpdateSight()
            ui:UpdateAuras()
            ui:UpdateIncomingHealing()
            ui:UpdateOutline()
        end
    end
    if superwow then
        PTHealPredict.SetRelevantGUIDs(GuidRoster.GetTrackedGuids())
    end
    RunTrackingScan()
    --EndTiming("CheckGroup")
end

function CheckTarget()
    local exists, guid = UnitExists("target")
    if exists then
        local friendly = not UnitCanAttack("player", "target")
        if (friendly and PTOptions.ShowTargets.Friendly) or (not friendly and PTOptions.ShowTargets.Hostile) then
            for ui in UnitFrames("target") do
                ui.lastHealthPercent = (ui:GetCurrentHealth() / ui:GetMaxHealth()) * 100
                ui:UpdateRange()
                ui:UpdateSight()
                ui:UpdateRole()
                ui:UpdateIncomingHealing()
            end
        end
    else
        for ui in UnitFrames("target") do
            ui.lastHealthPercent = (ui:GetCurrentHealth() / ui:GetMaxHealth()) * 100
            ui:UpdateAll()
            ui:UpdateRole()
            ui:UpdateIncomingHealing()
        end
    end
    UnitFrameGroups["Target"]:EvaluateShown()
end

function IsRelevantUnit(unit)
    return AllUnitsSet[unit] ~= nil or GUIDCustomUnitMap[unit]
end

function Info(msg)
    DEFAULT_CHAT_FRAME:AddMessage(colorize("[Puppeteer] ", 0.5, 1, 0.5)..colorize(msg, 1, 1, 0.4))
end

function print(msg)
    if not PTOptions or not PTOptions["Debug"] then
        return
    end
    local window
    local i = 1
    while not window do
        local name = GetChatWindowInfo(i)
        if not name then
            break
        end
        if name == "Debug" then
            window = getglobal("ChatFrame"..i)
            break
        end
        i = i + 1
    end
    if window then
        window:AddMessage(tostring(msg))
    end
end

function StartTiming(name)
    if not pfDebug_StartTiming then
        return
    end
    pfDebug_StartTiming(name)
end

function EndTiming(name)
    if not pfDebug_EndTiming then
        return
    end
    pfDebug_EndTiming(name)
end

function PrintStack()
    print(debugstack(2))
end