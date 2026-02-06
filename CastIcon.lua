-- Proof-of-concept spaghetti code for showing incoming spell casts

PTCastIcon = PTGuiComponent:Extend("puppeteer_cast_icon")
local compost = AceLibrary("Compost-2.0")

function PTCastIcon:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    local icon = frame:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(frame)
    local border = CreateFrame("Frame", nil, frame)
    border:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -0.5, 0.5)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0.5, -0.5)
    local progressOverlay = frame:CreateTexture(nil, "ARTWORK")
    progressOverlay:SetTexture(0, 0, 0, 0.5)
    local progressEdge = frame:CreateTexture(nil, "ARTWORK")
    progressEdge:SetTexture(1, 1, 0.4, 0.75)
    progressEdge:SetPoint("BOTTOMLEFT", progressOverlay, 0, -0.5)
    progressEdge:SetPoint("BOTTOMRIGHT", progressOverlay, 0, -0.5)
    progressEdge:SetHeight(1)
    local castOrder = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    castOrder:SetTextColor(1, 1, 1)
    castOrder:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    castOrder:SetShadowOffset(0, 0)
    castOrder:ClearAllPoints()
    castOrder:SetPoint("CENTER", frame)
    local overhealIndicator = border:CreateTexture(nil, "OVERLAY")
    overhealIndicator:SetPoint("TOPLEFT", frame, "TOPLEFT")
    overhealIndicator:SetWidth(4)
    overhealIndicator:SetHeight(4)
    obj.icon = icon
    obj.border = border
    obj.castOrder = castOrder
    obj.overhealIndicator = overhealIndicator
    obj.progressOverlay = progressOverlay
    obj.progressEdge = progressEdge
    return obj
end

function PTCastIcon:OnAcquire()
    self.super.OnAcquire(self)
end

function PTCastIcon:OnDispose()
    self.super.OnDispose(self)
    self.icon:SetVertexColor(1, 1, 1)
    self.progressOverlay:Show()
    self.progressEdge:Show()
    self.castOrder:Show()
    self.overhealIndicator:Show()
    self:GetHandle():SetAlpha(1)
    self:SetScript("OnUpdate", nil)
    local index = PTUtil.KeyOf(self.castIcons, self)
    if index ~= nil then
        self.castIcons[index] = nil
    end
end

function PTCastIcon:GetPosition(index)
    local isEven = index / 2 == math.floor(index / 2)
    return (math.floor(index / 2) * 15 * (isEven and 1 or -1)), 0
end

function PTCastIcon:GetProgress()
    return math.min((GetTime() - self.startTime) / self.time, 1)
end

function PTCastIcon:GetOvertime()
    return GetTime() - self.endTime
end

local importantCasts = {
    "Soulstone Resurrection",
    "Proclaim Champion",
    "Revive Champion"
}
importantCasts = PTUtil.ToSet(importantCasts)
PTLocale.Keys(importantCasts)

local T = PTLocale.Translate
function PTCastIcon:Start(spellName, spellTexture, time, unit, healAmount, unitFrame)
    local class = PTUtil.GetClass(unit)
    self:SetScript("OnUpdate", function()
        Puppeteer.StartTiming("CastIcon")
        self:Update()
        Puppeteer.EndTiming("CastIcon")
    end, false)
    self.icon:SetTexture(spellTexture)
    self.border:SetBackdropBorderColor(PTUtil.GetClassColor(class))
    self.startTime = GetTime()
    self.endTime = self.startTime + time
    self.time = time
    self.class = class
    self.unit = unit
    self.healAmount = healAmount
    self.unitFrame = unitFrame
    self.state = "CASTING"
    local isCasterSelf = PTUnitProxy.UnitIsUnit("player", unit)
    local isSelfHealer = Puppeteer.GetUnitAssignedRole("player") == "Healer"
    local shouldBeCenter = isCasterSelf and isSelfHealer
    local canBeCenter = isCasterSelf or not isSelfHealer
    self:SetParent(unitFrame.overlayContainer)
    local group = unitFrame.owningGroup
    local totalHealth = 0
    local totalUnits = 0
    for _, unit in ipairs(group.units) do
        if PTUnitProxy.UnitExists(unit) then
            totalHealth = totalHealth + PTUnitProxy.UnitHealthMax(unit)
            totalUnits = totalUnits + 1
        end
    end
    local avgHealth = totalHealth / totalUnits
    local healPower = healAmount / avgHealth
    Puppeteer.print("Heal Power: "..healPower)
    local startSize = 9
    local maxSize = 15
    local healPowerSizeMult = 9.2
    local size = math.max(math.min(startSize + (healPower * healPowerSizeMult), maxSize), startSize)
    if PTUtil.ResurrectionSpellsSet[spellName] or importantCasts[spellName] then
        size = 14
        self.overhealIndicator:Hide()
    end
    Puppeteer.print("Size: "..size)
    self:SetSize(size, size)
    local order = self.castOrder
    if isCasterSelf then
        order:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
        order:SetTextColor(1, 1, 0)
    else
        order:SetFont("Fonts\\FRIZQT__.TTF", size - 1, "OUTLINE")
        order:SetTextColor(0.9, 0.9, 0.9)
    end
    if not unitFrame.castIcons then
        unitFrame.castIcons = {}
    end
    self.castIcons = unitFrame.castIcons
    -- Remove our own icon in case it's fading still
    if shouldBeCenter and unitFrame.castIcons[1] and PTUnitProxy.UnitIsUnit("player", unitFrame.castIcons[1].unit) then
        unitFrame.castIcons[1]:Dispose()
    end
    for i = (canBeCenter and 1 or 2), 40 do
        if not unitFrame.castIcons[i] then
            unitFrame.castIcons[i] = self
            self.point = {"CENTER", unitFrame.overlayContainer, "CENTER", self:GetPosition(i)}
            self:SetPoint(unpack(self.point))
            break
        end
    end
end

local endColors = {
    [true] = {0.6, 1, 0.6},
    [false] = {1, 0.6, 0.6}
}
function PTCastIcon:End(successful)
    self.state = "FADING"
    self.startTime = GetTime()
    self.time = successful and 0.2 or 0.4
    self.endTime = self.startTime + self.endTime
    self.icon:SetVertexColor(unpack(endColors[successful]))
    self.progressOverlay:Hide()
    if successful then
        self.progressEdge:Hide()
    end
    self.overhealIndicator:Hide()
    self.successful = successful
    self.castOrder:Hide()
end

local iconSorter = function(a, b)
    return (a.endTime + (a.state == "CASTING" and 0 or 1000)) < (b.endTime + (b.state == "CASTING" and 0 or 1000))
end
local effectiveHealColors = {
    {1, 0, 0},
    {1, 1, 0},
    {0, 1, 0}
}
function PTCastIcon:Update()
    if self.state == "CASTING" then
        local overlay = self.progressOverlay
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", self:GetHandle(), "TOPLEFT")
        overlay:SetPoint("BOTTOMRIGHT", self:GetHandle(), "BOTTOMRIGHT", 0, self:GetHandle():GetHeight() * self:GetProgress())

        local castOrder = self.castOrder
        local icons = self.castIcons
        local rankedCasts = compost:GetTable()
        for _, icon in pairs(icons) do
            table.insert(rankedCasts, icon)
        end
        table.sort(rankedCasts, iconSorter)
        local castRank = PTUtil.IndexOf(rankedCasts, self)
        local missingHealth = self.unitFrame:GetMaxHealth() - self.unitFrame:GetCurrentHealth()
        for i, icon in ipairs(rankedCasts) do
            local healAmount = icon.healAmount
            if i == castRank then
                local effectiveHealProportion = missingHealth / healAmount
                local r, g, b = PTUtil.InterpolateColorsNoTable(effectiveHealColors, effectiveHealProportion)
                self.overhealIndicator:SetTexture(r, g, b)
                break
            end
            missingHealth = missingHealth - healAmount
        end
        compost:Reclaim(rankedCasts)
        castOrder:SetText(tostring(castRank))
    elseif self.state == "FADING" then
        local progress = self:GetProgress()
        if progress >= 1 then
            self:Dispose()
            return
        end
        self:GetHandle():SetAlpha(1 - self:GetProgress())
        if not self.successful then
            self:ClearAllPoints()
            local p = self.point
            self:SetPoint(p[1], p[2], p[3], p[4] + (-math.sin(4 * math.pi * progress) * 1.5), p[5])
        end
    end
end

PTGuiLib.RegisterComponent(PTCastIcon)