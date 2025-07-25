PTUnitFrame = {}
PTUtil.SetEnvironment(PTUnitFrame)
PTUnitFrame.__index = PTUnitFrame
local _G = getfenv(0)
local PT = Puppeteer
local util = PTUtil
local compost = AceLibrary("Compost-2.0")

PTUnitFrame.owningGroup = nil

PTUnitFrame.unit = nil
PTUnitFrame.isCustomUnit = false
PTUnitFrame.guidUnit = nil -- Used for custom units

PTUnitFrame.rootContainer = nil -- Contains the main container and the overlay
PTUnitFrame.overlayContainer = nil -- Contains elements that should not be affected by opacity
PTUnitFrame.container = nil -- Most elements are contained in this
PTUnitFrame.nameText = nil
PTUnitFrame.healthBar = nil
PTUnitFrame.incomingHealthBar = nil
PTUnitFrame.incomingDirectHealthBar = nil
PTUnitFrame.healthText = nil
PTUnitFrame.missingHealthText = nil
PTUnitFrame.incomingHealText = nil
PTUnitFrame.powerBar = nil
PTUnitFrame.powerText = nil
PTUnitFrame.roleIcon = nil
PTUnitFrame.button = nil
PTUnitFrame.auraPanel = nil
PTUnitFrame.scrollingDamageFrame = nil -- Unimplemented
PTUnitFrame.scrollingHealFrame = nil -- Unimplemented
PTUnitFrame.auraIconPool = {} -- map: {"frame", "icon", "stackText"}
PTUnitFrame.auraIcons = {} -- map: {"frame", "icon", "stackText"}

PTUnitFrame.targetOutline = nil

PTUnitFrame.targeted = false

PTUnitFrame.flashTexture = nil -- {"frame", "texture"}
PTUnitFrame.flashTime = 0
PTUnitFrame.lastHealthPercent = 0

PTUnitFrame.incomingHealing = 0
PTUnitFrame.incomingDirectHealing = 0

PTUnitFrame.hovered = false
PTUnitFrame.pressed = false

PTUnitFrame.distanceText = nil
PTUnitFrame.lineOfSightIcon = nil -- map: {"frame", "icon"}

PTUnitFrame.inRange = true
PTUnitFrame.distance = 0
PTUnitFrame.inSight = true

PTUnitFrame.fakeStats = {} -- Used for displaying a fake party/raid

function PTUnitFrame:New(unit, isCustomUnit)
    local obj = setmetatable({unit = unit, isCustomUnit = isCustomUnit, auraIconPool = {}, 
        auraIcons = {}, fakeStats = PTUnitFrame.GenerateFakeStats()}, self)
    return obj
end

local fakeNames = {"Leeroyjenkins", "Realsigred", "Appledog", "Exdraclespy", "Dieghostt", "Olascoli", "Yaijin", 
    "Geroya", "Artemyz", "Nomeon", "Orinnberry", "Hoppetosse", "Deathell", "Jackbob", "Luscita", "Healpiggies", 
    "Pamara", "Merauder", "Onetwofree", "Biggly", "Drexx", "Grassguzzler", "Thebackup", "Steaktank", "Fshoo", 
    "Bovinebill", "Rawtee", "Aylin", "Sneeziesnorf", "Dreak", "Jordin", "Evilkillers", "Xathas", "Linkado", 
    "Smiteknight", "Rollnmbqs", "Viniss", "Rinnegon", "Elfdefense", "Foxtau", "Tombdeath", "Myhawk", "Numnumcat", 
    "Laudead", "Esatto", "Boffin", "Tikomo", "Huddletree", "Butterboy", "Bolgrand", "Ginius", "Exulthiuss", 
    "Xplol", "Wheeliebear", "Pimenton", "Meditating", "Qyroth", "Lazhar", "Rookon", "Eiris", "Padren", 
    "Erazergus", "Scarlatina", "Holdrim", "Soulbane", "Debilitated", "Doorooid", "Palefire", "Tellarna", 
    "Breathofwing", "Chillaf", "Hulena", "Hyperiann", "Bluebeam", "Daevana", "Adriena", "Aeywynn", "Bluaa", 
    "Chadd", "Leutry", "Mouzer", "Qiner"}
function PTUnitFrame.GenerateFakeStats()

    local name = fakeNames[math.random(table.getn(fakeNames))]

    local class = util.GetRandomClass()

    local currentHealth
    local maxHealth = math.random(100, 5000)
    if math.random(10) > 3 then
        currentHealth = math.random(1, maxHealth)
    elseif math.random(8) == 1 then
        currentHealth = 0
    else
        currentHealth = maxHealth
    end

    local maxPower = math.random(100, 5000)
    if util.ClassPowerTypes[class] ~= "mana" then
        maxPower = 100
    end
    local currentPower = math.random(1, maxPower)

    local debuffType
    local trackedDebuffCount = table.getn(PuppeteerSettings.TrackedDebuffTypes)
    if trackedDebuffCount > 0 then
        if math.random(1, 10) == 1 then
            debuffType = PuppeteerSettings.TrackedDebuffTypes[math.random(trackedDebuffCount)]
        end
    end

    local raidMark
    if math.random(10) == 1 then
        raidMark = math.random(8)
    end

    local online = not (math.random(12) == 1)

    local fakeStats = {
        name = name,
        class = class, 
        currentHealth = currentHealth, 
        maxHealth = maxHealth,
        currentPower = currentPower,
        maxPower = maxPower,
        debuffType = debuffType,
        raidMark = raidMark,
        online = online}
    return fakeStats
end

function PTUnitFrame:GetUnit()
    return self.unit
end

function PTUnitFrame:GetResolvedUnit()
    return not self.isCustomUnit and self.unit or self.guidUnit
end

function PTUnitFrame:GetRootContainer()
    return self.rootContainer
end

function PTUnitFrame:GetContainer()
    return self.container
end

function PTUnitFrame:Show()
    self.container:Show()
    self.rootContainer:Show()
    self:UpdateAll()
end

function PTUnitFrame:Hide()
    if not self:IsFake() then
        self.container:Hide()
        self.rootContainer:Hide()
    end
end

function PTUnitFrame:IsShown()
    return self.rootContainer:IsShown()
end

function PTUnitFrame:SetOwningGroup(group)
    self.owningGroup = group
    self:Initialize()
    self:GetRootContainer():SetParent(group:GetContainer())
end

function PTUnitFrame:RegisterClicks()
    local buttons = PTOptions.CastWhen == "Mouse Up" and util.GetUpButtons() or util.GetDownButtons()
    self.button:RegisterForClicks(unpack(buttons))
    for _, aura in ipairs(self.auraIcons) do
        aura.frame:RegisterForClicks(unpack(buttons))
    end
    for _, aura in ipairs(self.auraIconPool) do
        aura.frame:RegisterForClicks(unpack(buttons))
    end
end

function PTUnitFrame:UpdateAll()
    self:UpdateAuras()
    self:UpdateHealth()
    self:UpdatePower()
    self:UpdateRange()
    self:UpdateSight()
    self:EvaluateTarget()
    self:UpdateOutline()
    self:UpdateRaidMark()
end

function PTUnitFrame:GetShowDistanceThreshold()
    local threshold = self:GetProfile().ShowDistanceThreshold
    return self:IsEnemy() and threshold.Hostile or threshold.Friendly
end

function PTUnitFrame:GetOutOfRangeThreshold()
    local threshold = self:GetProfile().OutOfRangeThreshold
    return self:IsEnemy() and threshold.Hostile or threshold.Friendly
end

function PTUnitFrame:UpdateRange()
    local wasInRange = self.inRange
    self.distance = self:GetCache():GetDistance()
    self.inRange = math.ceil(self.distance) < self:GetOutOfRangeThreshold()
    if wasInRange ~= self.inRange then
        self:UpdateOpacity()
    end

    self:UpdateRangeText()
end

function PTUnitFrame:UpdateSight()
    self.inSight = self:GetCache():IsInSight()
    local frame = self.lineOfSightIcon.frame
    if frame:IsShown() ~= self.inSight then
        local dist = math.ceil(self.distance)
        if not self.inSight and (dist < 80 or UnitIsUnit(self.unit, "target")) then
            frame:Show()
        else
            frame:Hide()
        end
    end
end

local preciseDistance = util.CanClientGetPreciseDistance()
function PTUnitFrame:UpdateRangeText()
    local dist = math.ceil(self.distance)
    local distanceText = self.distanceText
    local text = ""
    if dist >= (preciseDistance and self:GetShowDistanceThreshold() or 28) and dist < 9999 then
        local r, g, b
        if dist > 80 then
            r, g, b = 0.75, 0.75, 0.75
        elseif dist >= self:GetOutOfRangeThreshold() then
            r, g, b = 1, 0.3, 0.3
        else
            r, g, b = 1, 0.6, 0
        end

        if preciseDistance then
            text = text..util.Colorize(dist.." yd", r, g, b)
        else
            if dist < 28 then
                text = text..util.Colorize("<"..dist.." yd", r, g, b)
            else
                text = text..util.Colorize("28+ yd", r, g, b)
            end
        end
    end
    distanceText:SetText(text)
end

function PTUnitFrame:UpdateOpacity()
    local profile = self:GetProfile()
    
    local alpha = 1
    if not self.inRange then
        alpha = alpha * (profile.OutOfRangeOpacity / 100)
    end
    if profile.AlertPercent < math.ceil((self:GetCurrentHealth() / self:GetMaxHealth()) * 100) and 
            table.getn(self:GetAfflictedDebuffTypes()) == 0 then
        alpha = alpha * (profile.NotAlertedOpacity / 100)
    end
    self.container:SetAlpha(alpha)
end

-- Evaluate if the unit of this frame is the target and update the target outline if the state has changed
function PTUnitFrame:EvaluateTarget()
    if self.unit == "target" then -- "target" frames should not show a border since it's obvious they're the target
        return
    end
    local wasTargeted = self.targeted
    self.targeted = UnitIsUnit(self.unit, "target")
    if self.targeted ~= wasTargeted then
        self:UpdateOutline()
    end
end

function PTUnitFrame:UpdateOutline()
    local aggro = self:HasAggro()
    local targeted = self.targeted

    local r, g, b
    if aggro and targeted then
        r, g, b  = 1, 0.6, 0.5
    elseif aggro then
        r, g, b = 1, 0, 0
    elseif targeted then
        r, g, b = 1, 1, 0.85
    end

    self:SetOutlineColor(r, g, b)
end

function PTUnitFrame:SetOutlineColor(r, g, b)
    if r then
        self.targetOutline:Show()
        self.targetOutline:SetBackdropBorderColor(r, g, b, 0.75)
    else
        self.targetOutline:Hide()
    end
end

function PTUnitFrame:UpdateRaidMark()
    local unit = self:GetResolvedUnit()
    local fake = self:IsFake()
    if not unit and not fake then
        self.raidMarkIcon.frame:Hide()
        return
    end

    if unit == "target" and not UnitExists("target") then
        self.raidMarkIcon.frame:Hide()
        return
    end

    local markIndex
    if fake then
        markIndex = self.fakeStats.raidMark
    else
        markIndex = GetRaidTargetIndex(unit)
    end
    if not markIndex then
        self.raidMarkIcon.frame:Hide()
        return
    end
    SetRaidTargetIconTexture(self.raidMarkIcon.icon, markIndex)
    self.raidMarkIcon.frame:Show()
end

function PTUnitFrame:Flash()
    local FLASH_TIME = 0.15
    local START_OPACITY = self:GetProfile().FlashOpacity / 100

    self.flashTime = FLASH_TIME
    local frame = self.flashTexture.frame
    frame:Show()
    frame:SetAlpha(START_OPACITY)

    frame.flashTime = FLASH_TIME
    frame.startOpacity = START_OPACITY

    if not frame:GetScript("OnUpdate") then
        frame:SetScript("OnUpdate", PTUnitFrame.Flash_OnUpdate)
    end
end

function PTUnitFrame.Flash_OnUpdate()
    local frame = this
    local self = frame.unitFrame
    local FLASH_TIME = frame.flashTime
    local START_OPACITY = frame.startOpacity
    self.flashTime = self.flashTime - arg1
    frame:SetAlpha(START_OPACITY - (((FLASH_TIME - self.flashTime) / FLASH_TIME) * START_OPACITY))

    if self.flashTime <= 0 then
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
    end
end

-- If direct healing is nil, it will be assumed that all the incoming healing is direct healing
function PTUnitFrame:SetIncomingHealing(incomingHealing, incomingDirectHealing)
    self.incomingHealing = incomingHealing
    self.incomingDirectHealing = incomingDirectHealing or incomingHealing
    self:UpdateHealth()
end

function PTUnitFrame:UpdateIncomingHealing()
    if PTHealPredict then
        local _, guid = UnitExists(self:GetUnit())
        self:SetIncomingHealing(PTHealPredict.GetIncomingHealing(guid))
    else
        local name = UnitName(self:GetUnit())
        self:SetIncomingHealing(Puppeteer.HealComm:getHeal(name))
    end
end

function PTUnitFrame:GetCurrentHealth()
    if self:IsFake() then
        if not self.fakeStats.online then
            return 0
        end
        return self.fakeStats.currentHealth
    end
    return UnitHealth(self.unit)
end

function PTUnitFrame:GetMaxHealth()
    if self:IsFake() then
        return self.fakeStats.maxHealth
    end
    return UnitHealthMax(self.unit)
end

function PTUnitFrame:GetCurrentPower()
    if self:IsFake() then
        return self.fakeStats.currentPower
    end
    return UnitMana(self.unit)
end

function PTUnitFrame:GetMaxPower()
    if self:IsFake() then
        return self.fakeStats.maxPower
    end
    return UnitManaMax(self.unit)
end

function PTUnitFrame:ShouldShowMissingHealth()
    local profile = self:GetProfile()
    local currentHealth = self:GetCurrentHealth()
    if currentHealth == 0 then
        return false
    end
    local missingHealth = self:GetMaxHealth() - currentHealth
    return (missingHealth > 0 or profile.AlwaysShowMissingHealth) and profile.MissingHealthDisplay ~= "Hidden" 
                and (profile.ShowEnemyMissingHealth or not self:IsEnemy()) 
                and not UnitIsGhost(self.unit) and (UnitIsConnected(self.unit) or self:IsFake())
end

-- Used for custom colors in profiles.
-- Valid Colors:
-- "Class" - Uses the unit's class color
-- "Default" - Does not color the text
-- Array RGB - Colors the text as the RGB values
function PTUnitFrame:ColorizeText(inputText, color)
    if color == "Class" then
        local r, g, b = util.GetClassColor(self:GetClass())
        return util.Colorize(inputText, r, g, b)
    elseif type(color) == "table" then
        return util.Colorize(inputText, color)
    end
    return inputText
end

function PTUnitFrame:UpdateHealth()
    local fake = self:IsFake()
    if not UnitExists(self.unit) and not fake then
        if self.isCustomUnit or self.unit == "target" then
            self.healthText:SetText(util.Colorize(self.unit ~= "target" and "Too Far" or "", 0.7, 0.7, 0.7))
            self.missingHealthText:SetText("")
            self:SetHealthBarValue(0)
            self.powerBar:SetValue(0)
            self:UpdateOpacity()
            self:AdjustHealthPosition()
        end
        if self.unit == "target" then
            self.nameText:SetText("")
        end
        return
    end
    local profile = self:GetProfile()
    local unit = self.unit

    local fakeOnline = self.fakeStats.online
    
    local currentHealth = self:GetCurrentHealth()
    local maxHealth = self:GetMaxHealth()
    
    local unitName = self:GetName()

    self:UpdateOpacity() -- May be changed further down

    if not UnitIsConnected(unit) and (not fake or not fakeOnline) then
        self.nameText:SetText(self:ColorizeText(unitName, profile.NameText.Color))
        self.healthText:SetText(util.Colorize("Offline", 0.7, 0.7, 0.7))
        self.missingHealthText:SetText("")
        self:SetHealthBarValue(0)
        self.powerBar:SetValue(0)
        self:UpdateOpacity()
        self:AdjustHealthPosition()
        return
    end

    local enemy = self:IsEnemy()

    -- Set Name and its colors
    local nameText
    if self:IsPlayer() or fake then
        local r, g, b
        if profile.ShowDebuffColorsOn == "Name" and not enemy then
            r, g, b = self:GetDebuffColor()
        end
        if r then
            nameText = util.Colorize(unitName, r, g, b)
        else
            nameText = self:ColorizeText(unitName, profile.NameText.Color)
        end
    else -- Unit is not a player
        if enemy then
            nameText = util.Colorize(unitName, 1, 0.3, 0.3)
        else -- Unit is not an enemy
            local r, g, b
            if profile.ShowDebuffColorsOn == "Name" then
                r, g, b = self:GetDebuffColor()
            end
            if r then
                nameText = util.Colorize(unitName, r, g, b)
            else
                nameText = unitName
            end
        end
    end
    self.nameText:SetText(nameText)

    local healthText = self.healthText
    local missingHealthText = self.missingHealthText

    -- Set Health Status
    if currentHealth <= 0 then -- Unit Dead
        local cache = self:GetCache()
        local text
        if cache:IsBeingResurrected() then
            if cache:GetResurrectionCasts() > 1 then
                text = util.Colorize("DEAD", 0.8, 1, 0.8)
            else
                text = util.Colorize("DEAD", 0.3, 1, 0.3)
            end
        else
            text = util.Colorize("DEAD", 1, 0.3, 0.3)
        end

        -- Check for Feign Death so the healer doesn't get alarmed
        local feign = self:GetCache():HasBuffIDOrName(5384, "Feign Death")
        if feign then
            text = "Feign"
        end

        healthText:SetText(text)
        missingHealthText:SetText("")
        self:SetHealthBarValue(0)
        self.powerBar:SetValue(0)
        if self.lastHealthPercent > 0 and not self:IsEnemy() then
            if not feign then
                self:Flash()
            end
            self.lastHealthPercent = 0
        end
    elseif UnitIsGhost(unit) then
        healthText:SetText(util.Colorize("Ghost", 1, 0.3, 0.3))
        missingHealthText:SetText("")
        self:SetHealthBarValue(0)
        self.powerBar:SetValue(0)
    else -- Unit Not Dead
        local text = ""
        local missingText = ""
        if profile.HealthDisplay == "Health/Max Health" then
            text = currentHealth.."/"..maxHealth
        elseif profile.HealthDisplay == "Health" then
            text = currentHealth
        elseif profile.HealthDisplay == "% Health" then
            text = math.floor((currentHealth / maxHealth) * 100).."%"
        end
        
        if profile.ShowDebuffColorsOn == "Health" then
            local r, g, b = self:GetDebuffColor()
            if r then
                text = util.Colorize(text, r, g, b)
            end
        end
        if self.hovered then
            text = util.Colorize(text, 1, 1, 1)
        end

        local missingHealth = math.floor(maxHealth - currentHealth)

        if self:ShouldShowMissingHealth() then
            local missingHealthStr
            if profile.MissingHealthDisplay == "-Health" then
                missingHealthStr = "-"..missingHealth
            elseif profile.MissingHealthDisplay == "-% Health" then
                missingHealthStr = "-"..math.ceil((missingHealth / maxHealth) * 100).."%"
            end

            if profile.MissingHealthInline then
                if text ~= "" then
                    text = text..self:ColorizeText(" ("..missingHealthStr..")", profile.HealthTexts.Missing.Color)
                end
            else
                missingText = self:ColorizeText(missingHealthStr, profile.HealthTexts.Missing.Color)
            end
        end

        healthText:SetText(text)
        missingHealthText:SetText(missingText)

        self:SetHealthBarValue(currentHealth / maxHealth)

        local healthPercent = (currentHealth / maxHealth) * 100
        if healthPercent < self.lastHealthPercent - profile.FlashThreshold and not self:IsEnemy() then
            self:Flash()
        end
        self.lastHealthPercent = healthPercent

        if self:GetCache():HasBuffIDOrName(27827, "Spirit of Redemption") then
            healthText:SetText(util.Colorize("Spirit", 1, 0.3, 0.3))
        end
    end

    self:UpdateOpacity()
    self:AdjustHealthPosition()
end

local greenToRedColors = {{1, 0, 0}, {1, 0.3, 0}, {1, 1, 0}, {0.6, 0.92, 0}, {0, 0.8, 0}}
function PTUnitFrame:SetHealthBarValue(value)
    local unit = self.unit
    local healthBar = self.healthBar
    local incomingHealthBar = self.incomingHealthBar
    local incomingDirectHealthBar = self.incomingDirectHealthBar
    local incomingHealText = self.incomingHealText
    local incomingHealing = self.incomingHealing
    local incomingDirectHealing = self.incomingDirectHealing
    local profile = self:GetProfile()
    local enemy = self:IsEnemy()

    healthBar:SetValue(value)

    local healthIncMaxRatio = 0
    local healthIncDirectMaxRatio = 0

    if incomingHealing > 0 then
        healthIncMaxRatio = value + (incomingHealing / self:GetMaxHealth())
        healthIncDirectMaxRatio = value + (incomingDirectHealing / self:GetMaxHealth())
        incomingHealthBar:SetValue(healthIncMaxRatio)
        incomingDirectHealthBar:SetValue(healthIncDirectMaxRatio)
        if profile.IncomingHealDisplay == "Overheal" then
            if healthIncMaxRatio > 1 then
                incomingHealText:SetText("+"..math.ceil(self:GetCurrentHealth() + incomingHealing - self:GetMaxHealth()))
                local rgb = incomingDirectHealing > 0 and profile.IncomingHealText.Color or 
                    profile.IncomingHealText.IndirectColor
                if incomingDirectHealing > 0 then
                    incomingHealText:SetTextColor(rgb[1], rgb[2], rgb[3])
                else
                    incomingHealText:SetTextColor(rgb[1], rgb[2], rgb[3])
                end
            else
                incomingHealText:SetText("")
            end
        elseif profile.IncomingHealDisplay == "Heal" then
            incomingHealText:SetText("+"..self.incomingHealing)
            local rgb = incomingDirectHealing > 0 and profile.IncomingHealText.Color or 
                    profile.IncomingHealText.IndirectColor
            if incomingDirectHealing > 0 then
                incomingHealText:SetTextColor(rgb[1], rgb[2], rgb[3])
            else
                incomingHealText:SetTextColor(rgb[1], rgb[2], rgb[3])
            end
        else
            incomingHealText:SetText("")
        end
    else -- No incoming healing
        incomingHealthBar:SetValue(0)
        incomingDirectHealthBar:SetValue(0)
        incomingHealText:SetText("")
    end
    incomingHealthBar:SetAlpha(0.35)
    incomingDirectHealthBar:SetAlpha(0.4)

    local r, g, b
    
    if profile.ShowDebuffColorsOn == "Health Bar" then
        r, g, b = self:GetDebuffColor()
    end

    if UnitIsCharmed(unit) and enemy then
        r, g, b = 0.25, 0.25, 0.25
    end
    
    if r == nil then -- If there's no debuff color, proceed to normal colors
        local hbc = enemy and profile.EnemyHealthBarColor or profile.HealthBarColor
        if hbc == "Class" then
            local class = util.GetClass(unit)
            if class == nil then
                class = self.fakeStats.class
            end
            r, g, b = util.GetClassColor(class)
        elseif hbc == "Green" then
            r, g, b = 0, 0.8, 0
        elseif hbc == "Green To Red" then
            r, g, b = util.InterpolateColorsNoTable(greenToRedColors, value)
        end

        if healthIncMaxRatio > 1 then
            local brightenFactor = math.min(((healthIncMaxRatio - 1) / 4) + 1, 1.25)
            r = math.min(r * brightenFactor, 1)
            g = math.min(g * brightenFactor, 1)
            b = math.min(b * brightenFactor, 1)
        end
    end
    healthBar:SetStatusBarColor(r, g, b)
    incomingHealthBar:SetStatusBarColor(0, 0.8, 0)
    incomingDirectHealthBar:SetStatusBarColor(0, 0.8, 0)

    local feign = self:GetCache():HasBuffIDOrName(5384, "Feign Death")
    local bg = healthBar.background
    if value == 0 and not feign then
        bg:SetTexture(0.5, 0.5, 0.5, 0.5)
    elseif value < 0.3 and not enemy and not feign then
        bg:SetTexture(1, 0.4, 0.4, 0.25)
    else
        bg:SetTexture(0.5, 0.5, 0.5, 0.25)
    end
end

-- Returns the r, g, b of the current dispellable debuff color, or nil if none
function PTUnitFrame:GetDebuffColor()
    local enemy = self:IsEnemy()
    if not enemy then -- Do not display debuff colors for enemies
        for _, trackedDebuffType in ipairs(PuppeteerSettings.TrackedDebuffTypes) do
            if self:GetAfflictedDebuffTypes()[trackedDebuffType] then
                local debuffTypeColor = PuppeteerSettings.DebuffTypeColors[trackedDebuffType]
                return debuffTypeColor[1], debuffTypeColor[2], debuffTypeColor[3]
            end
        end
    end

    local fake = self:IsFake()
    if fake and self.fakeStats.debuffType then
        local debuffTypeColor = PuppeteerSettings.DebuffTypeColors[self.fakeStats.debuffType]
        return debuffTypeColor[1], debuffTypeColor[2], debuffTypeColor[3]
    end
end

function PTUnitFrame:UpdatePower()
    local profile = self:GetProfile()
    local unit = self.unit
    local powerBar = self.powerBar
    local fake = self:IsFake()
    local class = fake and self.fakeStats.class or util.GetClass(unit)
    local currentPower = self:GetCurrentPower()
    local maxPower = self:GetMaxPower()

    if not UnitExists(self.unit) and not fake then
        powerBar:SetValue(0)
        self.powerText:SetText("")
        return
    end
    
    local powerColor = fake and util.PowerColors[util.ClassPowerTypes[class or "WARRIOR"]] or util.GetPowerColor(unit)

    powerBar:SetValue(currentPower / maxPower)
    powerBar:SetStatusBarColor(powerColor[1], powerColor[2], powerColor[3])
    local text = ""
    if profile.PowerDisplay == "Power" then
        text = currentPower
    elseif profile.PowerDisplay == "Power/Max Power" then
        text = currentPower.."/"..maxPower
    elseif profile.PowerDisplay == "% Power" then
        if maxPower == 0 then
            maxPower = 1
        end
        text = math.floor((currentPower / maxPower) * 100).."%"
    end
    self.powerText:SetText(text)
end

local AURA_DURATION_TEXT_FLASH_THRESHOLD = 5
local AURA_DURATION_TEXT_LOW_THRESHOLD = 30
-- A map of all seconds below the flash threshold to an array of colors to interpolate
local durationTextFlashColorsRange
if util.IsSuperWowPresent() then
    local flashColorsReset = {{1, 1, 0.75}, {1, 0.7, 0.55}, {1, 0.6, 0.6}}
    local flashColors = {{1, 1, 0.25}, {1, 0.6, 0.35}, {1, 0.4, 0.4}}

    local textFlashColors = {}
    for i = 0, AURA_DURATION_TEXT_FLASH_THRESHOLD + 1 do
        textFlashColors[i] = {}
        textFlashColors[i][1] = util.InterpolateColors(flashColors, 
            (AURA_DURATION_TEXT_FLASH_THRESHOLD - i) / AURA_DURATION_TEXT_FLASH_THRESHOLD)
        textFlashColors[i][2] = util.InterpolateColors(flashColorsReset, 
        (AURA_DURATION_TEXT_FLASH_THRESHOLD - i) / AURA_DURATION_TEXT_FLASH_THRESHOLD)
    end
    durationTextFlashColorsRange = {}
    for seconds, colors in pairs(textFlashColors) do
        durationTextFlashColorsRange[seconds] = {colors[2], colors[1]}
    end
end
function PTUnitFrame:AllocateAura()
    local frame = CreateFrame("Button", nil, self.auraPanel, "UIPanelButtonTemplate")
    frame.unitFrame = self
    frame:SetNormalTexture(nil)
    frame:SetHighlightTexture(nil)
    frame:SetPushedTexture(nil)
    local buttons = PTOptions.CastWhen == "Mouse Up" and util.GetUpButtons() or util.GetDownButtons()
    frame:RegisterForClicks(unpack(buttons))
    frame:EnableMouse(true)

    frame:SetScript("OnEnter", PTUnitFrame.Aura_OnEnter)
    frame:SetScript("OnLeave", PTUnitFrame.Aura_OnLeave)
    frame:SetScript("OnClick", PTUnitFrame.Aura_OnClick)
    frame:SetScript("OnMouseUp", PTUnitFrame.Aura_OnMouseUp)
    frame:SetScript("OnMouseDown", PTUnitFrame.Aura_OnMouseDown)
    
    local icon = frame:CreateTexture(nil, "OVERLAY")
    local stackText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stackText:SetTextColor(1, 1, 1)

    -- Duration display, only used when SuperWoW is present
    if util.IsSuperWowPresent() then
        local duration = CreateFrame("Model", nil, frame, "CooldownFrameTemplate")
        duration.noCooldownCount = true
        duration:SetAlpha(0.8)
        local durationOverlayFrame = CreateFrame("Frame", nil, frame)
        durationOverlayFrame:SetFrameLevel(durationOverlayFrame:GetFrameLevel() + 1)
        local durationText = durationOverlayFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        durationText:SetPoint("BOTTOMLEFT", durationOverlayFrame, "BOTTOMLEFT", 0, 0)
        durationText.SetSeconds = function(self, seconds)
            self.seconds = seconds
            if seconds == nil then
                self:SetText("")
                return
            end
            self:SetText(seconds <= 60 and seconds or math.ceil(seconds / 60).."m")
            self:SetFont("Fonts\\FRIZQT__.TTF", math.ceil(frame:GetHeight() * 
                (seconds < 540 and (seconds < 10 and 0.6 or 0.45) or 0.35)), "OUTLINE")
        end
        duration.UpdateText = function()
            local seconds = duration.seconds
            local secondsPrecise = duration.secondsPrecise
            durationText:SetSeconds(seconds)
            if seconds <= AURA_DURATION_TEXT_FLASH_THRESHOLD then
                durationText:SetTextColor(
                    util.InterpolateColorsNoTable(durationTextFlashColorsRange[seconds], 
                    secondsPrecise - seconds))
            elseif seconds <= AURA_DURATION_TEXT_LOW_THRESHOLD then
                durationText:SetTextColor(1, 1, 0.25)
            else
                durationText:SetTextColor(1, 1, 1)
            end
            duration:SetScript("OnUpdate", nil)
        end
        duration:SetScript("OnUpdateModel", function()
            if this.stopping == 0 then
                this:SetAlpha(0.8)
                local time = GetTime()
                local progress = (time - this.start) / this.duration
                if progress < 1.0 then
                    this:SetSequenceTime(0, 1000 - (progress * 1000))
                    local secondsPrecise = this.start - time + this.duration
                    local seconds = math.floor(secondsPrecise)
                    if seconds <= (this.displayAt and this.displayAt or AURA_DURATION_TEXT_FLASH_THRESHOLD) then
                        if durationText.seconds ~= seconds or seconds <= AURA_DURATION_TEXT_FLASH_THRESHOLD then
                            -- You don't want to know why it's gotta be done like this..
                            -- (If you're insane and you do, it's because otherwise the text will disappear for one frame otherwise)
                            duration.seconds = seconds
                            duration.secondsPrecise = secondsPrecise
                            duration:SetScript("OnUpdate", duration.UpdateText)
                        end
                    elseif durationText.seconds ~= nil then
                        durationText:SetSeconds(nil)
                    end
                    return
                end
                durationText:SetSeconds(nil)
                this:SetSequenceTime(0, 0)
            end
        end)
        return {["frame"] = frame, ["icon"] = icon, ["stackText"] = stackText, ["overlay"] = durationOverlayFrame, 
            ["durationText"] = durationText, ["duration"] = duration, ["durationEnabled"] = true}
    end
    return {["frame"] = frame, ["icon"] = icon, ["stackText"] = stackText}
end

-- Get an icon from the available pool. Automatically inserts into the used pool.
function PTUnitFrame:GetUnusedAura()
    local aura
    if table.getn(self.auraIconPool) > 0 then
        aura = table.remove(self.auraIconPool, table.getn(self.auraIconPool))
    else
        aura = self:AllocateAura()
    end
    aura.frame:SetAlpha(aura.frame:GetParent():GetAlpha())
    table.insert(self.auraIcons, aura)
    return aura
end

function PTUnitFrame:ReleaseAuras()
    if table.getn(self.auraIcons) == 0 then
        return
    end
    -- Release all icons back to the icon pool
    for _, aura in ipairs(self.auraIcons) do
        local frame = aura.frame
        frame:Hide()
        frame:ClearAllPoints()

        local icon = aura.icon
        icon:ClearAllPoints()

        local stackText = aura.stackText
        stackText:ClearAllPoints()
        stackText:SetText("")

        if aura.durationEnabled then
            aura.durationText:SetSeconds(nil)
            CooldownFrame_SetTimer(aura.duration, 0, 0, 0)
        end

        table.insert(self.auraIconPool, aura)
    end
    self.auraIcons = compost:Erase(self.auraIcons)
end

do
    local trackedBuffs = PuppeteerSettings.TrackedBuffs
    function PTUnitFrame.BuffSorter(a, b)
        return trackedBuffs[a.name] < trackedBuffs[b.name]
    end
end

do
    local trackedDebuffs = PuppeteerSettings.TrackedDebuffs
    function PTUnitFrame.DebuffSorter(a, b)
        return trackedDebuffs[a.name] < trackedDebuffs[b.name]
    end
end

function PTUnitFrame:UpdateAuras()
    local profile = self:GetProfile()
    local unit = self.unit
    local enemy = self:IsEnemy()

    self:ReleaseAuras()

    local cache = self:GetCache()
    
    local trackedBuffs = PuppeteerSettings.TrackedBuffs

    local buffs = compost:GetTable() -- Buffs that are tracked because of matching name
    for name, array in pairs(cache.BuffsMap) do
        if trackedBuffs[name] or enemy then
            util.AppendArrayElements(buffs, array)
        end
    end

    if not enemy then
        table.sort(buffs, self.BuffSorter)
    end
    

    local trackedDebuffs = PuppeteerSettings.TrackedDebuffs
    local trackedDebuffTypes = PuppeteerSettings.TrackedDebuffTypesSet

    local debuffs = compost:GetTable() -- Debuffs that are tracked because of matching name, later combined with typed debuffs
    local typedDebuffs = compost:GetTable() -- Debuffs that are tracked because it's a tracked type (like "Magic" or "Disease")
    for name, array in pairs(cache.DebuffsMap) do
        if trackedDebuffs[name] or enemy then
            util.AppendArrayElements(debuffs, array)
        else
            -- Check if debuff is a tracked type
            for _, debuff in ipairs(array) do
                if trackedDebuffTypes[debuff.type] then
                    table.insert(typedDebuffs, debuff)
                end
            end
        end
    end

    if not enemy then
        table.sort(debuffs, self.DebuffSorter)
        util.AppendArrayElements(debuffs, typedDebuffs)
    end

    local auraTrackerProps = profile.AuraTracker
    local width = auraTrackerProps.Width == "Anchor" and auraTrackerProps:GetAnchorComponent(self):GetWidth() or auraTrackerProps.Width
    local auraSize = auraTrackerProps.Height
    local origSize = auraSize
    local spacing = profile.TrackedAurasSpacing
    local origSpacing = spacing
    local auraCount = table.getn(buffs) + table.getn(debuffs)

    -- If there's not enough space, shrink until all auras fit
    while ((auraSize * auraCount) + (spacing * (auraCount - 1)) > width) and auraSize >= 1 do
        auraSize = auraSize - 1
        spacing = (auraSize / origSize) * origSpacing
    end

    local xOffset = 0
    local yOffset = profile.TrackedAurasAlignment == "TOP" and 0 or origSize - auraSize
    for _, buff in ipairs(buffs) do
        local aura = self:GetUnusedAura()
        self:CreateAura(aura, buff.name, buff.index, buff.texture, buff.stacks, xOffset, -yOffset, "Buff", auraSize)
        xOffset = xOffset + auraSize + spacing
    end
    xOffset = 0
    for _, debuff in ipairs(debuffs) do
        local aura = self:GetUnusedAura()
        self:CreateAura(aura, debuff.name, debuff.index, debuff.texture, debuff.stacks, xOffset, -yOffset, "Debuff", auraSize)
        xOffset = xOffset - auraSize - spacing
    end
    compost:Reclaim(buffs)
    compost:Reclaim(debuffs)
    compost:Reclaim(typedDebuffs)

    -- Prevent lingering tooltips when the icon is removed or is changed to a different aura
    if not PT.GameTooltip.OwningFrame or not PT.GameTooltip.OwningFrame:IsShown() or 
            PT.GameTooltip.IconTexture ~= PT.GameTooltip.OwningIcon:GetTexture() then
        PT.GameTooltip:Hide()
    end
end


function PTUnitFrame.Aura_OnEnter()
    local self = this.unitFrame
    local aura = this.aura
    local index = this.auraIndex
    local type = this.auraType

    local tooltip = PT.GameTooltip
    local cache = self:GetCache()
    tooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    tooltip.OwningFrame = this
    tooltip.OwningIcon = aura.icon
    local unit = self:GetResolvedUnit()
    if type == "Buff" then
        tooltip.IconTexture = cache.Buffs[index].texture
        tooltip:SetUnitBuff(unit, index)
    else
        tooltip.IconTexture = cache.Debuffs[index].texture
        tooltip:SetUnitDebuff(unit, index)
    end
    local auraTime = cache.AuraTimes[(type == "Buff" and cache.Buffs[index] or cache.Debuffs[index]).name]
    if auraTime then
        local seconds = math.floor(auraTime.startTime - GetTime() + auraTime.duration)
        if seconds < 60 then
            tooltip:AddLine(seconds.." second"..(seconds ~= 1 and "s" or "").." remaining")
        else
            tooltip:AddLine(math.ceil(seconds / 60).." minutes remaining")
        end
    end
    tooltip:Show()

    if MouseIsOver(self.button) then
        self.button:GetScript("OnEnter")()
    end
end

function PTUnitFrame.Aura_OnLeave()
    PT.GameTooltip:Hide()
    PT.GameTooltip.OwningFrame = nil
    PT.GameTooltip.OwningIcon = nil
    PT.GameTooltip.IconTexture = nil
    -- Don't check mouse position for leaving, because it could cause the tooltip to stay if the icon is on the edge
    this.unitFrame.button:GetScript("OnLeave")()
end

do
    local wrapButtonScript = function(scriptName)
        return function()
            local self = this.unitFrame
            if MouseIsOver(self.button) then
                self.button:GetScript(scriptName)()
            end
        end
    end

    PTUnitFrame.Aura_OnClick = wrapButtonScript("OnClick")

    PTUnitFrame.Aura_OnMouseUp = wrapButtonScript("OnMouseUp")

    PTUnitFrame.Aura_OnMouseDown = wrapButtonScript("OnMouseDown")
end

function PTUnitFrame:CreateAura(aura, name, index, texturePath, stacks, xOffset, yOffset, type, size)
    local frame = aura.frame
    frame:SetWidth(size)
    frame:SetHeight(size)
    frame:SetPoint(type == "Buff" and "TOPLEFT" or "TOPRIGHT", xOffset, yOffset)
    frame:Show()
    frame.unitFrame = self
    frame.aura = aura
    frame.auraIndex = index
    frame.auraType = type

    local icon = aura.icon
    icon:SetAllPoints(frame)
    icon:SetTexture(texturePath)
    --icon:SetVertexColor(1, 0, 0)

    if aura.durationEnabled then
        local overlay = aura.overlay
        overlay:SetAllPoints()

        local duration = aura.duration
        duration:SetAllPoints()
        duration:SetScale(size * 0.0275)
    end
    
    if stacks > 1 then
        local stackText = aura.stackText
        stackText:SetPoint("CENTER", frame, "CENTER", 0, 0)
        stackText:SetFont("Fonts\\FRIZQT__.TTF", math.ceil(size * (stacks < 10 and 0.75 or 0.6)))
        stackText:SetText(stacks)
    end

    if aura.durationEnabled then
        local cache = self:GetCache()
        if cache.AuraTimes[name] then
            local debuffTime = cache.AuraTimes[name]
            local start = debuffTime["startTime"]
            local duration = debuffTime["duration"]
            local durationUI = aura.duration

            CooldownFrame_SetTimer(durationUI, start, duration, 1)

            if duration < 60 then
                durationUI.displayAt = PTOptions.ShowAuraTimesAt.Short
            elseif duration <= 60 * 2 then
                durationUI.displayAt = PTOptions.ShowAuraTimesAt.Medium
            else
                durationUI.displayAt = PTOptions.ShowAuraTimesAt.Long
            end

            -- To prevent having a frame where the duration is not updated
            aura.durationText:SetSeconds(nil)
            util.CallWithThis(durationUI, durationUI:GetScript("OnUpdateModel"))
        end
    end
end

function PTUnitFrame:Initialize()
    local unit = self.unit

    local profile = self:GetProfile()

    -- Container Elements

    local rootContainer = CreateFrame("Frame", unit.."HealRootContainer", UIParent)
    self.rootContainer = rootContainer
    rootContainer:SetPoint("CENTER", 0, 0)

    local container = CreateFrame("Frame", unit.."HealContainer", rootContainer) --type, name, parent
    self.container = container
    container:SetAllPoints(rootContainer)

    local overlayContainer = CreateFrame("Frame", unit.."HealOverlayContainer", rootContainer)
    self.overlayContainer = overlayContainer
    overlayContainer:SetFrameLevel(container:GetFrameLevel() + 5)
    overlayContainer:SetAllPoints(rootContainer)

    -- Distance Text

    local distanceText = overlayContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.distanceText = distanceText
    distanceText:SetAlpha(profile.RangeText:GetAlpha())

    local losFrame = CreateFrame("Frame", nil, container)
    losFrame:SetFrameLevel(container:GetFrameLevel() + 3)
    local losIcon = losFrame:CreateTexture(nil, "OVERLAY")
    self.lineOfSightIcon = {frame = losFrame, icon = losIcon}
    losIcon:SetTexture("Interface\\Icons\\Spell_nature_sleep")
    losIcon:SetAlpha(profile.LineOfSightIcon:GetAlpha())
    losFrame:Hide()

    -- Role Icon

    local roleFrame = CreateFrame("Frame", nil, container)
    roleFrame:SetFrameLevel(container:GetFrameLevel() + 3)
    local roleIcon = roleFrame:CreateTexture(nil, "OVERLAY")
    self.roleIcon = {frame = roleFrame, icon = roleIcon}
    roleIcon:SetAlpha(profile.RoleIcon:GetAlpha())
    roleFrame:Hide()

    -- Raid Mark Icon

    local raidMarkFrame = CreateFrame("Frame", nil, container)
    raidMarkFrame:SetFrameLevel(container:GetFrameLevel() + 3)
    local raidMarkIcon = raidMarkFrame:CreateTexture(nil, "OVERLAY")
    self.raidMarkIcon = {frame = raidMarkFrame, icon = raidMarkIcon}
    raidMarkIcon:SetAlpha(profile.RaidMarkIcon:GetAlpha())
    raidMarkIcon:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
    raidMarkFrame:Hide()

    -- Health Bar Element

    local healthBar = CreateFrame("StatusBar", unit.."HealthBar", container)
    self.healthBar = healthBar
    healthBar:SetStatusBarTexture(PT.BarStyles[profile.HealthBarStyle])
    healthBar:SetMinMaxValues(0, 1)

    local incomingHealthBar = CreateFrame("StatusBar", unit.."IncomingHealthBar", container)
    self.incomingHealthBar = incomingHealthBar
    incomingHealthBar:SetStatusBarTexture(PT.BarStyles[profile.HealthBarStyle])
    incomingHealthBar:SetMinMaxValues(0, 1)
    incomingHealthBar:SetFrameLevel(healthBar:GetFrameLevel() - 1)

    local incomingDirectHealthBar = CreateFrame("StatusBar", unit.."IncomingDirectHealthBar", container)
    self.incomingDirectHealthBar = incomingDirectHealthBar
    incomingDirectHealthBar:SetStatusBarTexture(PT.BarStyles[profile.HealthBarStyle])
    incomingDirectHealthBar:SetMinMaxValues(0, 1)
    incomingDirectHealthBar:SetFrameLevel(healthBar:GetFrameLevel() - 1)

    -- Name Element

    local name = healthBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.nameText = name
    name:SetAlpha(profile.NameText:GetAlpha())

    -- Create a background texture for the status bar
    local bg = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBar.background = bg
    bg:SetAllPoints(true)
    bg:SetTexture(0.5, 0.5, 0.5, 0.25) -- set color to light gray with high transparency

    -- Incoming Text
    local incomingHealText = overlayContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.incomingHealText = incomingHealText

    -- Missing Health Text

    local missingHealthText = healthBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.missingHealthText = missingHealthText
    missingHealthText:SetAlpha(profile.HealthTexts.Missing:GetAlpha())

    -- Power Bar Element

    local powerBar = CreateFrame("StatusBar", unit.."PowerStatusBar", container)
    self.powerBar = powerBar
    powerBar:SetStatusBarTexture(PT.BarStyles[profile.PowerBarStyle])
    powerBar:SetMinMaxValues(0, 1)
    powerBar:SetValue(1)
    powerBar:SetStatusBarColor(0, 0, 1)
    powerBar:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"}) -- set a light gray background
    local powerText = powerBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.powerText = powerText
    powerText:SetAlpha(profile.PowerText:GetAlpha())

    -- Button Element

    local button = CreateFrame("Button", unit.."Button", healthBar, "UIPanelButtonTemplate")
    self.button = button
    local healthText = button:GetFontString()
    self.healthText = healthText
    healthText:ClearAllPoints()


    healthText = healthBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.healthText = healthText

    self:RegisterClicks()
    button:SetScript("OnClick", function()
        if self:IsFake() then
            return
        end
        local buttonType = arg1
        PT.UnitFrame_OnClick(buttonType, unit, self)
    end)
    button:SetScript("OnMouseDown", function()
        local buttonType = arg1
        PT.CurrentlyHeldButton = buttonType--PuppeteerSettings.CustomButtonNames[buttonType] or PT.ReadableButtonMap[buttonType]
        PT.ReapplySpellsTooltip()
        self.pressed = true
        self:AdjustHealthPosition()
    end)
    button:SetScript("OnMouseUp", function()
        PT.CurrentlyHeldButton = nil
        PT.ReapplySpellsTooltip()
        self.pressed = false
        self:AdjustHealthPosition()
    end)
    button:SetScript("OnEnter", function()
        local attachTooltipTo
        if PTOptions.SpellsTooltip.AttachTo == "Frame" then
            attachTooltipTo = self.rootContainer
        elseif PTOptions.SpellsTooltip.AttachTo == "Group" then
            attachTooltipTo = self.owningGroup:GetContainer()
        elseif PTOptions.SpellsTooltip.AttachTo == "Screen" then
            attachTooltipTo = UIParent
        else
            attachTooltipTo = self.button
        end
        PT.ApplySpellsTooltip(attachTooltipTo, unit, self.button)
        self.hovered = true
        self:UpdateHealth()
        if PTOptions.SetMouseover and util.IsSuperWowPresent() then
            SetMouseoverUnit(self:GetResolvedUnit())
        end
        PT.Mouseover = self:GetResolvedUnit()
        PT.MouseoverFrame = self
        PT.ApplyOverrideBindings()
    end)
    button:SetScript("OnLeave", function()
        PT.HideSpellsTooltip()
        self.hovered = false
        self:UpdateHealth()
        if PTOptions.SetMouseover and util.IsSuperWowPresent() then
            SetMouseoverUnit(nil)
        end
        PT.Mouseover = nil
        PT.MouseoverFrame = nil
        PT.RemoveOverrideBindings()
    end)
    button:EnableMouse(true)

    button:SetNormalTexture(nil)
    button:SetHighlightTexture(nil)
    button:SetPushedTexture(nil)

    -- Buff Panel Element

    local buffPanel = CreateFrame("Frame", unit.."BuffPanel", container)
    self.auraPanel = buffPanel
    buffPanel:SetFrameLevel(container:GetFrameLevel() + 2)

    local targetOutline = CreateFrame("Frame", "$parentTargetOutline", rootContainer)
    self.targetOutline = targetOutline
    targetOutline:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = profile.TargetOutline.Thickness})
    targetOutline:SetFrameLevel(container:GetFrameLevel() + 10)
    targetOutline:Hide()

    local flashFrame = CreateFrame("Frame", "$parentFlash", container)
    flashFrame:SetFrameLevel(container:GetFrameLevel() + 9)
    flashFrame.unitFrame = self
    local flashTexture = flashFrame:CreateTexture(nil, "OVERLAY")
    self.flashTexture = {frame = flashFrame, texture = flashTexture}
    flashTexture:SetTexture(1, 1, 1)
    flashFrame:Hide()

    --[[
    local scrollingDamageFrame = CreateFrame("Frame", unit.."ScrollingDamageFrame", container)
    self.scrollingDamageFrame = scrollingDamageFrame
    scrollingDamageFrame:SetWidth(100) -- width
    scrollingDamageFrame:SetHeight(20) -- height
    scrollingDamageFrame:SetPoint("CENTER", 0, 0) -- Adjust the initial position as needed
    scrollingDamageFrame.text = scrollingDamageFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scrollingDamageFrame.text:SetPoint("CENTER", 0, 0)
    scrollingDamageFrame:Hide() -- Hide the frame initially
    scrollingDamageFrame:SetFrameLevel(100) -- Set the frame level to a high value to ensure it's on top

    local scrollingHealFrame = CreateFrame("Frame", unit.."ScrollingHealFrame", container)
    self.scrollingHealFrame = scrollingHealFrame
    scrollingHealFrame:SetWidth(100) -- width
    scrollingHealFrame:SetHeight(20) -- height
    scrollingHealFrame:SetPoint("CENTER", 0, 0) -- Adjust the initial position as needed
    scrollingHealFrame.text = scrollingHealFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scrollingHealFrame.text:SetPoint("CENTER", 0, 0)
    scrollingHealFrame:Hide() -- Hide the frame initially
    scrollingHealFrame:SetFrameLevel(100) -- Set the frame level to a high value to ensure it's on top
    ]]

    self:SetHealthBarValue(0)
    self:SizeElements()
end

function PTUnitFrame:SizeElements()
    local profile = self:GetProfile()
    local width = profile.Width
    local healthBarHeight = profile.HealthBarHeight
    local powerBarHeight = profile.PowerBarHeight

    local rootContainer = self.rootContainer
    rootContainer:SetWidth(width)

    local overlayContainer = self.overlayContainer
    overlayContainer:SetWidth(width)

    local container = self.container
    container:SetWidth(width)

    local healthBar = self.healthBar
    healthBar:SetWidth(width)
    healthBar:SetHeight(healthBarHeight)
    healthBar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -profile.PaddingTop)

    local incomingHealthBar = self.incomingHealthBar
    incomingHealthBar:SetWidth(width)
    incomingHealthBar:SetHeight(healthBarHeight)
    incomingHealthBar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -profile.PaddingTop)

    local directIncomingHealthBar = self.incomingDirectHealthBar
    directIncomingHealthBar:SetWidth(width)
    directIncomingHealthBar:SetHeight(healthBarHeight)
    directIncomingHealthBar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -profile.PaddingTop)

    local powerBar = self.powerBar
    powerBar:SetWidth(width)
    powerBar:SetHeight(powerBarHeight)
    powerBar:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, 0)

    local button = self.button
    button:SetWidth(healthBar:GetWidth())
    button:SetHeight(healthBar:GetHeight() + powerBar:GetHeight())
    button:SetPoint("TOP", 0, 0)

    local name = self.nameText
    self:UpdateComponent(name, profile.NameText)

    self:AdjustHealthPosition()

    local powerText = self.powerText
    self:UpdateComponent(powerText, profile.PowerText)

    local incomingHealText = self.incomingHealText
    self:UpdateComponent(incomingHealText, profile.IncomingHealText)

    local distanceText = self.distanceText
    self:UpdateComponent(distanceText, profile.RangeText)

    local losFrame = self.lineOfSightIcon.frame
    self:UpdateComponent(self.lineOfSightIcon.frame, profile.LineOfSightIcon)

    local losIcon = self.lineOfSightIcon.icon
    losIcon:SetAllPoints(losFrame)

    local roleFrame = self.roleIcon.frame
    self:UpdateComponent(roleFrame, profile.RoleIcon)

    local roleIcon = self.roleIcon.icon
    roleIcon:SetAllPoints(roleFrame)

    local raidMarkFrame = self.raidMarkIcon.frame
    self:UpdateComponent(raidMarkFrame, profile.RaidMarkIcon)

    local raidMarkIcon = self.raidMarkIcon.icon
    raidMarkIcon:SetAllPoints(raidMarkFrame)

    local auraPanel = self.auraPanel
    self:UpdateComponent(auraPanel, profile.AuraTracker)

    self:UpdateComponent(self.targetOutline, profile.TargetOutline)

    self:UpdateComponent(self.flashTexture.frame, profile.Flash)
    self.flashTexture.texture:SetAllPoints(self.flashTexture.frame)

    rootContainer:SetHeight(self:GetHeight())
    overlayContainer:SetHeight(self:GetHeight())
    container:SetHeight(self:GetHeight())
end

function PTUnitFrame:AdjustHealthPosition()
    local profile = self:GetProfile()

    local healthTexts = profile.HealthTexts
    local healthTextProps = (self:ShouldShowMissingHealth() and not profile.MissingHealthInline) and 
        healthTexts.WithMissing or healthTexts.Normal
    local missingHealthTextProps = healthTexts.Missing

    local xOffset, yOffset
    if self.pressed then
        xOffset, yOffset = 1, -1
    end
    self:UpdateComponent(self.healthText, healthTextProps, xOffset, yOffset)
    self:UpdateComponent(self.missingHealthText, missingHealthTextProps, xOffset, yOffset)
end

local alignmentAnchorMap = {
    ["LEFT"] = {
        ["TOP"] = "TOPLEFT",
        ["CENTER"] = "LEFT",
        ["BOTTOM"] = "BOTTOMLEFT",
    },
    ["CENTER"] = {
        ["TOP"] = "TOP",
        ["CENTER"] = "CENTER",
        ["BOTTOM"] = "BOTTOM",
    },
    ["RIGHT"] = {
        ["TOP"] = "TOPRIGHT",
        ["CENTER"] = "RIGHT",
        ["BOTTOM"] = "BOTTOMRIGHT",
    }
}
function PTUnitFrame:UpdateComponent(component, props, xOffset, yOffset)
    xOffset = xOffset or 0
    yOffset = yOffset or 0

    local anchor = props:GetAnchorComponent(self)

    component:ClearAllPoints()
    if component.SetFont then -- Must be a FontString
        component:SetWidth(math.min(props.MaxWidth, anchor:GetWidth()))
        component:SetHeight(props.FontSize * 1.25)
        component:SetFont("Fonts\\FRIZQT__.TTF", props.FontSize, props.Outline and "OUTLINE" or nil)
        if props.Outline then
            component:SetShadowOffset(0, 0)
        end
        component:SetJustifyH(props.AlignmentH)
        component:SetJustifyV(props.AlignmentV)
    else
        component:SetWidth(props:GetWidth(self))
        component:SetHeight(props:GetHeight(self))
    end
    local alignment = alignmentAnchorMap[props.AlignmentH][props.AlignmentV]
    component:SetPoint(alignment, anchor, alignment, props:GetOffsetX() + xOffset, props:GetOffsetY() + yOffset)
end

function PTUnitFrame:GetCache()
    return PTUnit.Get(self.unit) or PTUnit
end

function PTUnitFrame:GetAfflictedDebuffTypes()
    return self:GetCache().AfflictedDebuffTypes
end

function PTUnitFrame:GetWidth()
    return self:GetProfile().Width
end

function PTUnitFrame:GetHeight()
    return self:GetProfile():GetHeight()
end

function PTUnitFrame:GetName()
    if self:IsFake() then
        return self.fakeStats.name
    end
    return UnitName(self.unit)
end

function PTUnitFrame:GetClass()
    if self:IsFake() then
        return self.fakeStats.class
    end
    return util.GetClass(self.unit)
end

function PTUnitFrame:IsPlayer()
    return UnitIsPlayer(self.unit)
end

function PTUnitFrame:IsEnemy()
    return UnitCanAttack("player", self.unit)
end

function PTUnitFrame:IsFake()
    return Puppeteer.TestUI and not UnitExists(self.unit)
end

function PTUnitFrame:GetRole()
    return Puppeteer.GetUnitAssignedRole(self:GetUnit())
end

function PTUnitFrame:HasAggro()
    local unit = self:GetUnit()
    if self.isCustomUnit then
        if not self.guidUnit then
            return false
        end
        unit = PTUnitProxy.ResolveCustomUnit(self.guidUnit)
        if not unit then
            return false
        end
    end
    return Puppeteer.Banzai:GetUnitAggroByUnitId(unit)
end

local roleTexturesPath = PTUtil.GetAssetsPath().."textures\\roles\\"
local roleTextures = {
    ["Tank"] = roleTexturesPath.."Tank",
    ["Healer"] = roleTexturesPath.."Healer",
    ["Damage"] = roleTexturesPath.."Damage"
}
function PTUnitFrame:UpdateRole()
    local role = self:GetRole()
    self.roleIcon.icon:SetTexture(roleTextures[role])
    if role then
        self.roleIcon.frame:Show()
    else
        self.roleIcon.frame:Hide()
    end
end

function PTUnitFrame:GetProfile()
    return self.owningGroup:GetProfile()
end