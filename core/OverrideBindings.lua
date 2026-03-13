-- Handles mouse wheel and key bindings

PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
local util = PTUtil

_G.BINDING_HEADER_PUPPETEER = "Puppeteer (Don't Touch These)"
local bindingsNames = {}
local MAX_BINDINGS = 24
for i = 1, MAX_BINDINGS do
    bindingsNames[i] = "PUPPETEERBINDING"..i
    _G["BINDING_NAME_"..bindingsNames[i]] = "Dynamic Binding "..i
end
local bindingsNamesSet = util.ToSet(bindingsNames)

local BindingPrefixes = {
    "",
    "SHIFT-",
    "CTRL-",
    "ALT-",
    "ALT-CTRL-SHIFT-",
    "ALT-CTRL-",
    "ALT-SHIFT-",
    "CTRL-SHIFT-"
}

StoredBindings = {} -- Key: Baked keybind key(like "ALT-SHIFT-R") | Value: The stored value of the binding
IndexButtonMap = {} -- Key: Index corresponding to the binding | Value: Button name
KeybindIndexMap = {} -- Key: Baked keybind key | Value: Index corresponding to the binding

function InitOverrideBindingsMapping()
    util.ClearTable(IndexButtonMap)
    util.ClearTable(KeybindIndexMap)
    local index = 1
    for _, button in ipairs(PTOptions.Buttons) do
        if not util.GetAllButtonsSet()[button] then
            for _, prefix in ipairs(BindingPrefixes) do
                KeybindIndexMap[prefix..button] = index
            end
            IndexButtonMap[index] = button
            index = index + 1
        end
    end

    for _, bindingName in ipairs(bindingsNames) do
        local k1, k2, k3, k4, k5, k6, k7, k8 = GetBindingKey(bindingName)
        for _, key in ipairs({k1, k2, k3, k4, k5, k6, k7, k8}) do
            if key then
                SetBinding(key, nil)
            end
        end
    end
end


-- Stuff to stop expensive UPDATE_BINDINGS events as much as possible

local noOp = function() end
local updateBindingsFunctions = {}
local updateBindingsFrames = {}
local holdingFunctionsHostage = false
function AddUpdateBindingsFunction(funcName)
    table.insert(updateBindingsFunctions, {
        funcName = funcName
    })
end
function AddUpdateBindingsFrame(frame)
    frame = type(frame) ~= "string" and frame or _G[frame]
    if frame then
        table.insert(updateBindingsFrames, {
            frame = frame
        })
    end
end
-- Alternative method
function HookUpdateBindingsFrame(frameName)
    local frame = _G[frameName]
    local realScript = frame:GetScript("OnEvent")
    frame:SetScript("OnEvent", function()
        if holdingFunctionsHostage then
            return
        end
        realScript()
    end)
end
AddUpdateBindingsFunction("ActionButton_OnEvent")
AddUpdateBindingsFunction("BonusActionButton_OnEvent")
AddUpdateBindingsFunction("PetActionButton_OnEvent")
AddUpdateBindingsFunction("CharacterMicroButton_OnEvent")
AddUpdateBindingsFunction("TalentMicroButton_OnEvent")
AddUpdateBindingsFrame("MainMenuMicroButton")
AddUpdateBindingsFrame("QuestLogMicroButton")
AddUpdateBindingsFrame("SocialsMicroButton")
AddUpdateBindingsFrame("WorldMapMicroButton")
util.RunLater(function()
    AddUpdateBindingsFrame("pfActionBar") -- pfUI
    AddUpdateBindingsFrame("DFRL_HotkeyBinding") -- Dragonflight Reloaded
    if DRAGONFLIGHT then -- DF3
        AddUpdateBindingsFrame((function() DRAGONFLIGHT() return DF.setups.actionbars.eventFrame end)())
    end
end)

local function StopUpdateBindingsUpdates()
    if holdingFunctionsHostage then
        return
    end
    holdingFunctionsHostage = true
    for _, entry in ipairs(updateBindingsFunctions) do
        entry.func = _G[entry.funcName]
        _G[entry.funcName] = noOp
    end
    for _, entry in ipairs(updateBindingsFrames) do
        entry.func = entry.frame:GetScript("OnEvent")
        entry.frame:SetScript("OnEvent", nil)
    end
end

local function StartUpdateBindingsUpdates()
    if not holdingFunctionsHostage then
        return
    end
    for _, entry in ipairs(updateBindingsFunctions) do
        _G[entry.funcName] = entry.func
    end
    for _, entry in ipairs(updateBindingsFrames) do
        entry.frame:SetScript("OnEvent", entry.func)
    end
    holdingFunctionsHostage = false
end

-- End of UPDATE_BINDINGS mitigation

function ApplyOverrideBindings()
    RemoveOverrideBindings()
    StopUpdateBindingsUpdates()
    for fullButton, index in pairs(KeybindIndexMap) do
        local binding = GetBindingAction(fullButton)
        
        if binding == "" then -- Lazy set the binding to our binding and don't touch until setting up again
            SetBinding(fullButton, bindingsNames[index])
        elseif not bindingsNamesSet[binding] then -- If it's not our binding, it must be stored and replaced
            StoredBindings[fullButton] = binding
            SetBinding(fullButton, bindingsNames[index])
        end
    end
    StartUpdateBindingsUpdates()
end

function RemoveOverrideBindings()
    if util.IsTableEmpty(StoredBindings) then
        return
    end
    StopUpdateBindingsUpdates()
    for button, binding in pairs(StoredBindings) do
        SetBinding(button, binding)
    end
    StartUpdateBindingsUpdates()
    util.ClearTable(StoredBindings)
end

function HandleKeyPress(index)
    if not Mouseover then
        return
    end
    local button = IndexButtonMap[index]
    if keystate == "down" then
        CurrentlyHeldButton = button
        MouseoverFrame.pressed = true
        MouseoverFrame:AdjustHealthPosition()
        if button == "MOUSEWHEELUP" or button == "MOUSEWHEELDOWN" then
            FakeMouseWheelHold(button)
        end
        ReapplySpellsTooltip()
        if PTOptions.CastWhenKey == "Key Down" then
            UnitFrame_OnClick(button, Mouseover, MouseoverFrame)
        end
    else
        if button ~= "MOUSEWHEELUP" and button ~= "MOUSEWHEELDOWN" then
            CurrentlyHeldButton = nil
            MouseoverFrame.pressed = false
            MouseoverFrame:AdjustHealthPosition()
            ReapplySpellsTooltip()
        end
        if PTOptions.CastWhenKey == "Key Up" then
            UnitFrame_OnClick(button, Mouseover, MouseoverFrame)
        end
    end
end

MouseWheelHeldFaker = CreateFrame("Frame", "PTMouseWheelHeldFaker")

local unholdAt
local unholdButton
local MouseWheelHeldFaker_OnUpdate = function()
    if GetTime() >= unholdAt then
        MouseWheelHeldFaker:SetScript("OnUpdate", nil)
        if CurrentlyHeldButton == unholdButton then
            CurrentlyHeldButton = nil
            if MouseoverFrame then
                MouseoverFrame.pressed = false
                MouseoverFrame:AdjustHealthPosition()
            end
            ReapplySpellsTooltip()
        end
    end
end
function FakeMouseWheelHold(button)
    unholdAt = GetTime() + 0.08
    unholdButton = button
    MouseWheelHeldFaker:SetScript("OnUpdate", MouseWheelHeldFaker_OnUpdate)
end