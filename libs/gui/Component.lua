PTGuiComponent = {}
PTUtil.SetEnvironment(PTGuiComponent)
local _G = getfenv(0)
PTGuiComponent.__index = PTGuiComponent

-- A static flag to verify if this is a gui component
PTGuiComponent.IsPuppeteerGui = true

PTGuiComponent.TypeName = "BASE_COMPONENT"

-- The primary frame associated with the set of components
PTGuiComponent.Primary = nil
-- The raw frame associated with the component
PTGuiComponent.Frame = nil
-- All gui component instances associated with the component, including itself(named "Frame")
PTGuiComponent.Components = {}

-- Permanent frames cannot be recycled
PTGuiComponent.Permanent = false

PTGuiComponent.FrameCount = 0

function PTGuiComponent:Extend(typeName)
    local obj = {}
    setmetatable(obj, self)
    obj.TypeName = typeName
    obj.super = self
    obj.__index = obj
    return obj
end

-- Called when a component is acquired
function PTGuiComponent:OnAcquire()
    self:Show()
end

-- Responsible for cleaning up a component, putting it in a default state
function PTGuiComponent:OnDispose()
    self:Hide()
    self:ClearAllPoints()
    self:SetSize(0, 0)
    self:SetParent(nil)
    if self.HasScript and self:HasScript("OnClick") then
        self:OnClick(nil)
    end

    if self.DisposeHandler then
        self:DisposeHandler()
        self.DisposeHandler = nil
    end
end

function PTGuiComponent:Dispose()
    if not self:IsPermanent() then -- Permanent components aren't recycled, but can try to hide themselves
        PTGuiLib.Recycle(self)
    end

    self:OnDispose()
end

-- Set a special handler that is called when this component is being disposed.
-- Should be used for cleaning up things components don't normally clean up.
function PTGuiComponent:SetDisposeHandler(handler)
    self.DisposeHandler = handler
    return self
end

function PTGuiComponent:SetPermanent()
    self.Permanent = true
    return self
end

function PTGuiComponent:IsPermanent()
    return self.Permanent
end

function PTGuiComponent:Type()
    return self.TypeName
end

function PTGuiComponent:GenerateName()
    self.FrameCount = self.FrameCount + 1
    return "PTGui_"..self:Type()..self.FrameCount
end

function PTGuiComponent:SetHandle(frame)
    self.Frame = frame
    self:AddComponent("Frame", self)
    frame.GuiInstance = self
    self:SetPrimary()
    return self
end

function PTGuiComponent:GetHandle()
    return self.Frame
end

function PTGuiComponent:IsInstance()
    return self.Frame ~= nil
end

function PTGuiComponent:IsPrimary()
    return self.Primary == self.Frame
end

function PTGuiComponent:GetPrimary()
    return self.Primary
end

-- Sets this component as the primary for all associated components
function PTGuiComponent:SetPrimary()
    for _, component in pairs(self.Components) do
        component.Primary = self
    end
end

function PTGuiComponent:Import(returnSelf, ...)
    self:ImportComponent(nil, returnSelf, arg)
end

function PTGuiComponent:ImportComponent(frameName, returnSelf, ...)
    frameName = frameName or "Frame"
    for _, import in ipairs(arg) do
        if type(import) == "table" then
            for _, import in ipairs(import) do
                self:DoImport(frameName, returnSelf, import)
            end
        else
            self:DoImport(frameName, returnSelf, import)
        end
    end
end

-- Instance imports are faster and static imports consume less memory.
-- Instance importing must be done after the component is added.
function PTGuiComponent:DoImport(frameName, returnSelf, import)
    if self:IsInstance() then -- Prefer an instance import
        local frame = self:GetComponent(frameName):GetHandle()
        local func = frame[import]
        if returnSelf then
            self[import] = function(self, a1, a2, a3, a4, a5)
                func(frame, a1, a2, a3, a4, a5)
                return self
            end
        else
            self[import] = function(self, a1, a2, a3, a4, a5)
                return func(frame, a1, a2, a3, a4, a5)
            end
        end
    elseif frameName == "Frame" then -- Optimized static import for the handle
        if returnSelf then
            self[import] = function(self, a1, a2, a3, a4, a5)
                local frame = self.Frame
                frame[import](frame, a1, a2, a3, a4, a5)
                return self
            end
        else
            self[import] = function(self, a1, a2, a3, a4, a5)
                local frame = self.Frame
                return frame[import](frame, a1, a2, a3, a4, a5)
            end
        end
    else -- Static import for other components
        if returnSelf then
            self[import] = function(self, a1, a2, a3, a4, a5)
                local frame = self.Components[frameName]:GetHandle()
                frame[import](frame, a1, a2, a3, a4, a5)
                return self
            end
        else
            self[import] = function(self, a1, a2, a3, a4, a5)
                local frame = self.Components[frameName]:GetHandle()
                return frame[import](frame, a1, a2, a3, a4, a5)
            end
        end
    end
end

function PTGuiComponent:GetContainer()
    return self.Frame
end

function PTGuiComponent:GetAnchor()
    return self.Frame
end

function PTGuiComponent:AddComponent(name, component)
    if self.Components == PTGuiComponent.Components then
        self.Components = {}
    end
    self.Components[name] = component
end

function PTGuiComponent:GetComponent(name)
    return self.Components[name]
end

function PTGuiComponent:GetComponents()
    return self.Components
end

function PTGuiComponent:SetParent(obj)
    if obj and obj.IsPuppeteerGui then
        obj = obj:GetContainer()
    end
    self:GetHandle():SetParent(obj)
    PTUtil.FixFrameLevels(self:GetHandle())
    return self
end

function PTGuiComponent:SetSize(width, height)
    self:SetWidth(width)
    self:SetHeight(height)
    return self
end

function PTGuiComponent:SetScript(scriptName, script, noSelf)
    self:GetHandle():SetScript(scriptName, script and (noSelf and script or function() script(self) end) or nil)
    return self
end

function PTGuiComponent:OnClick(script, noSelf)
    return self:SetScript("OnClick", script, noSelf)
end

function PTGuiComponent:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset)
    if type(relativeFrame) == "table" and relativeFrame.IsPuppeteerGui then
        relativeFrame = relativeFrame:GetAnchor()
    end
    self:GetHandle():SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset)
    return self
end

PTGuiComponent.BACKGROUND_TOOLTIP = 1
PTGuiComponent.BACKGROUND_DIALOG = 2
function PTGuiComponent:SetSimpleBackground(type, diff)
    type = type or PTGuiComponent.BACKGROUND_TOOLTIP
    local background
    if type == PTGuiComponent.BACKGROUND_TOOLTIP then
        background = {
            frameBackdrop = {
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeSize = 11,
                tile = true
            },
            frameBackdropColor = {0.09, 0.09, 0.19},
            frameBorderColor = nil,
            borderBackdrop = {
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 11,
                tileSize = 11,
                tile = true
            },
            borderBackdropColor = nil,
            borderBorderColor = {0.8, 0.8, 0.8},
            borderPadding = 2
        }
    elseif type == PTGuiComponent.BACKGROUND_DIALOG then
        background = {
            frameBackdrop = {
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeSize = 32,
                tile = true,
                tileSize = 32
            },
            borderBackdrop = {
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", 
                edgeSize = 32,
                tile = true,
                tileSize = 32
            },
            borderPadding = 11
        }
    end
    if diff then
        for k, v in pairs(diff) do
            background[k] = v
        end
    end
    return self:SetBackground(background)
end

function PTGuiComponent:SetBackground(params)
    local frame = self:GetHandle()

    frame:SetBackdrop(nil)
    frame:SetBackdropColor()
    frame:SetBackdropBorderColor()
    if frame.guiBorder then
        frame.guiBorder:Hide()
        frame.guiBorder:SetBackdrop(nil)
        frame.guiBorder:SetBackdropColor()
        frame.guiBorder:SetBackdropBorderColor()
    end

    if not params then
        return self
    end

    if params.frameBackdrop then
        frame:SetBackdrop(params.frameBackdrop)
        if params.frameBackdropColor then
            frame:SetBackdropColor(unpack(params.frameBackdropColor))
        end
        if params.frameBorderColor then
            frame:SetBackdropColor(unpack(params.frameBorderColor))
        end
    end

    if params.borderBackdrop then
        local border = frame.guiBorder or CreateFrame("Frame", nil, frame)
        frame.guiBorder = border
        frame.guiBorder:Show()
        local padding = params.borderPadding or 0
        border:SetPoint("TOPLEFT", frame, "TOPLEFT", -padding, padding)
        border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", padding, -padding)
        border:SetBackdrop(params.borderBackdrop)
        border:SetFrameLevel(frame:GetFrameLevel())
        if params.borderBackdropColor then
            border:SetBackdropColor(unpack(params.borderBackdropColor))
        end
        if params.borderBorderColor then
            border:SetBackdropBorderColor(unpack(params.borderBorderColor))
        end
    end
    return self
end

-- TODO: Handle cleanup of tooltips for disposed components
local infoTooltip = CreateFrame("GameTooltip", "PTGuiInfoTooltip", UIParent, "GameTooltipTemplate")

local singleTextArray = {}
local function ShowTooltip(attachTo, texts)
    infoTooltip:SetOwner(attachTo, "ANCHOR_RIGHT")
    infoTooltip:SetPoint("RIGHT", attachTo, "LEFT", 0, 0)

    if type(texts) == "string" then
        singleTextArray[1] = texts
        texts = singleTextArray
    end

    for i, text in ipairs(texts) do
        infoTooltip:AddLine(text)
        _G["PTGuiInfoTooltipTextLeft"..i]:SetFont("Fonts\\FRIZQT__.TTF", i == 1 and 14 or 12, "OUTLINE")
    end
    
    infoTooltip:Show()
end

function PTGuiComponent:ApplyTooltip(...)
    self:ApplyTooltipToAll(arg)
end

function PTGuiComponent:ApplyTooltipTo(component, texts)
    local primary = component:GetPrimary():GetHandle()
    local frame = component:GetHandle()
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function()
        ShowTooltip(primary, texts)
    end)
    frame:SetScript("OnLeave", function()
        infoTooltip:Hide()
    end)
end

function PTGuiComponent:ApplyTooltipToAll(texts)
    local primary = self:GetPrimary():GetHandle()
    local onEnter = function()
        ShowTooltip(primary, texts)
    end
    local onLeave = function()
        infoTooltip:Hide()
    end
    for _, component in pairs(self:GetComponents()) do
        local frame = component:GetHandle()
        if frame.EnableMouse and frame.HasScript and frame:HasScript("OnEnter") then
            frame:EnableMouse(true)
            frame:SetScript("OnEnter", onEnter)
            frame:SetScript("OnLeave", onLeave)
        end
    end
end


PTGuiComponent:Import(true, "ClearAllPoints", "SetAllPoints", "SetWidth", "SetHeight", "Show", "Hide")
PTGuiComponent:Import(false, "GetWidth", "GetHeight", "GetName", "HasScript", "GetScript", "GetParent")