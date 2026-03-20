PTArrow = PTGuiComponent:Extend("puppeteer_arrow")
local util = PTUtil
local interpolateColors = util.InterpolateColorsNoTable

function PTArrow:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    local arrow = frame:CreateTexture("PTUnitFrameArrow", "MEDIUM")
    arrow:SetTexture(util.GetAssetsPath().."textures\\arrow")
    arrow:SetAllPoints()
    obj.arrow = arrow
    return obj
end

function PTArrow:OnAcquire()
    self.super.OnAcquire(self)
    self.colors = nil
    self.direction = nil
end

function PTArrow:SetColor(r, g, b)
    self.arrow:SetVertexColor(r, g, b)
end

function PTArrow:SetGradientColors(colors)
    self.colors = colors
end

function PTArrow:GetDirection()
    return self.direction
end

function PTArrow:SetDirection(dir)
    self.direction = dir
    local arrow = self.arrow
    local cell = util.modulo(math.floor(dir / (math.pi*2) * 108 + 0.5), 108)
    local column = util.modulo(cell, 9)
    local row = math.floor(cell / 9)
    local xstart = (column * 56) / 512
    local ystart = (row * 42) / 512
    local xend = ((column + 1) * 56) / 512
    local yend = ((row + 1) * 42) / 512
    arrow:SetTexCoord(xstart,xend,ystart,yend)
    if self.colors then
        local perc = math.abs(((math.pi - math.abs(dir)) / math.pi))
        self:SetColor(interpolateColors(self.colors, perc))
    end
end

PTGuiLib.RegisterComponent(PTArrow)