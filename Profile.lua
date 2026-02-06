-- DEPRECATION NOTICE
-- UI Profiles as they currently stand will be retired in a future update for a more modular system

PTUIProfile = {}
PTUIProfile.__index = PTUIProfile
local util = PTUtil

local positionedMethods = {
    GetWidth = function(self, ui)
        return (self.Width ~= "Anchor" and self.Width or self:GetAnchorComponent(ui):GetWidth()) + (self.Width2 or 0)
    end,
    GetHeight = function(self, ui)
        return (self.Height ~= "Anchor" and self.Height or self:GetAnchorComponent(ui):GetHeight()) + (self.Height2 or 0)
    end,
    GetOffsetX = function(self)
        if self.AlignmentH == "LEFT" then
            return self.PaddingH + self.OffsetX
        elseif self.AlignmentH == "RIGHT" then
            return -self.PaddingH + self.OffsetX
        end
        return self.OffsetX
    end,
    GetOffsetY = function(self)
        if self.AlignmentV == "TOP" then
            return -self.PaddingV + self.OffsetY
        elseif self.AlignmentV == "BOTTOM" then
            return self.PaddingV + self.OffsetY
        end
        return self.OffsetY
    end,
    GetAlpha = function(self)
        return self.Opacity / 100
    end,
    GetAnchorComponent = function(self, ui)
        local anchorName = self.Anchor
        if anchorName == "Health Bar" then
            return ui.healthBar
        elseif anchorName == "Power Bar" then
            return ui.powerBar
        elseif anchorName == "Button" then
            return ui.button
        elseif anchorName == "Container" then
            return ui.container
        end
    end
}
local textMethods = util.CloneTable(positionedMethods)
textMethods.GetMaxWidth = function(self)
    return self.MaxWidth or 1000
end
local objectMethods = {
    Sized = positionedMethods,
    Text = textMethods
}

local function InjectObjectMethods(t)
    if t.ObjectType then
        for k, f in pairs(objectMethods[t.ObjectType]) do
            t[k] = f
        end
        return
    end
    for k, v in pairs(t) do
        if type(v) == "table" then
            InjectObjectMethods(v)
        end
    end
end

function PTUIProfile:New(base, diff)
    local obj = setmetatable(util.CloneTable(base or PTProfileManager.GetDefaultProfile(), true), self)
    if diff then
        util.ApplyTableDiffs(obj, diff)
    end
    InjectObjectMethods(obj)
    return obj
end

function PTUIProfile:Deserialize(serialized)
    local diff = loadstring(serialized)()
    return PTUIProfile:New(PTProfileManager.GetDefaultProfile(), diff)
end

function PTUIProfile:Serialize(base)
    return "return "..PTUtil.SerializeTable(self, nil, base)
end

function PTUIProfile:GetHeight()
    local totalHeight = self.HealthBarHeight + self.PowerBarHeight + self.PaddingTop + self.PaddingBottom
    return totalHeight
end