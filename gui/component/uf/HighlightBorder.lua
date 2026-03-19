PTHighlightBorder = PTGuiComponent:Extend("puppeteer_highlight_border")
local compost = AceLibrary("Compost-2.0")
local util = PTUtil
local dashes = {}

function PTHighlightBorder:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    obj.BorderWidth = 4
    obj.Dashes = {}
    return obj
end

function PTHighlightBorder:OnAcquire()
    self.super.OnAcquire(self)
    self.State = 0
    self.Speed = 1.5
    self.Interval = 20
    self.Length = 10
    self.Thickness = 2
end

function PTHighlightBorder:OnDispose()
    self.super.OnDispose(self)
    self:DisposeDashes()
    self:SetScript("OnUpdate", nil)
end

function PTHighlightBorder:AcquireDash()
    local dash
    if table.getn(dashes) > 0 then
        dash = table.remove(dashes, table.getn(dashes))
    else
        dash = CreateFrame("Frame")
        local tex = dash:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(1, 1, 0)
    end
    dash:SetParent(self:GetHandle())
    dash:Show()
    table.insert(self.Dashes, dash)
    return dash
end

function PTHighlightBorder:DisposeDashes()
    for _, dash in ipairs(self.Dashes) do
        dash:ClearAllPoints()
        dash:Hide()
        table.insert(dashes, dash)
    end
    util.ClearTable(self.Dashes)
end

local lines = {
    {anchor = "BOTTOMLEFT", heightwise = true, reversed = true},
    {anchor = "TOPLEFT", heightwise = false, reversed = false},
    {anchor = "TOPRIGHT", heightwise = true, reversed = false},
    {anchor = "BOTTOMRIGHT", heightwise = false, reversed = true}
}

function PTHighlightBorder:Draw()
    self:DisposeDashes()

    self.State = self.State + self.Speed
    if self.State >= self.Interval then
        self.State = self.State - self.Interval
    end

    local width = self:GetWidth()
    local height = self:GetHeight()

    local state = self.State
    local length = self.Length
    local interval = self.Interval
    local thickness = self.Thickness

    for _, line in ipairs(lines) do
        local anchor = line.anchor
        local heightwise = line.heightwise
        local reversed = line.reversed
        local point = 0
        local sideLength = heightwise and height or width
        while point < sideLength do
            if point == 0 and state ~= 0 then
                point = point + state
                if point > (interval - length) then
                    local dash = self:AcquireDash()
                    local dashLength = length - (interval - state)
                    dash:SetWidth(heightwise and thickness or dashLength)
                    dash:SetHeight(heightwise and dashLength or thickness)
                    dash:SetPoint(anchor, self:GetHandle(), anchor, 0, 0)
                end
            else
                local dash = self:AcquireDash()
                local dashLength = length
                if point + length > sideLength then
                    dashLength = sideLength - point
                end
                dash:SetWidth(heightwise and thickness or dashLength)
                dash:SetHeight(heightwise and dashLength or thickness)
                dash:SetPoint(anchor, self:GetHandle(), anchor, 
                    (heightwise and 0 or point) * (reversed and -1 or 1), 
                    (heightwise and point or 0) * (reversed and 1 or -1))
                point = point + interval
            end
        end
    end
end

function PTHighlightBorder:SetBorderParent(borderParent)
    self.BorderParent = borderParent
    self:SetParent(borderParent)
    self:GetHandle():SetAllPoints(borderParent)
    local nextUpdate = 0
    self:SetScript("OnUpdate", function(self)
        if nextUpdate < GetTime() then
            nextUpdate = GetTime() + 0.033
            self:Draw()
        end
    end)
end

function PTHighlightBorder:AttachToUnitFrame(unitFrame)
    self:SetBorderParent(unitFrame.overlayContainer)
end

PTGuiLib.RegisterComponent(PTHighlightBorder)