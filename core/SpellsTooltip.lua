PTUtil.SetEnvironment(Puppeteer)
local _G = getfenv(0)
local compost = AceLibrary("Compost-2.0")
local util = PTUtil
local colorize = util.Colorize
local GetKeyModifier = util.GetKeyModifier
local GetClass = util.GetClass
local GetItemCount = util.GetItemCount
local IsValidMacro = util.IsValidMacro
local GetResourceCost = util.GetResourceCost
local T = PTLocale.T

local lowToHighColors = {
    {1, 0, 0}, 
    {1, 0.9, 0}, 
    {0.35, 1, 0.35}
}
local tooltipPowerColors = {
    ["mana"] = {0.5, 0.7, 1}, -- Not the accurate color, but more readable
    ["rage"] = {1, 0, 0},
    ["energy"] = {1, 1, 0}
}
local tooltipAnchorMap = {["Top Left"] = "ANCHOR_LEFT", ["Top Right"] = "ANCHOR_RIGHT", 
    ["Bottom Left"] = "ANCHOR_BOTTOMLEFT", ["Bottom Right"] = "ANCHOR_BOTTOMRIGHT"}

local tooltipCastsColors = {
    ["Normal"] = {0.6, 1, 0.6},
    ["Critical"] = {1, 1, 0},
    ["Zero"] = {1, 0.5, 0.5}
}
local normalFontColor = {NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b}
local unboundText = colorize("Unbound", 0.6, 0.6, 0.6)

local targetTypes = {"Friendly", "Hostile"}
ResurrectDisplayCache = {}
ButtonDisplayCache = nil
BindingDisplayCache = nil
DirtyDisplayModifiers = {}

SpecialSpellBindings = {}
for class, spell in pairs(util.ResurrectionSpells) do
    local binding = {
        ["Type"] = "SPELL",
        ["Data"] = spell
    }
    SpecialSpellBindings[spell] = binding
end
SpecialSpellBindings[T("Revive Champion")] = {
    ["Type"] = "SPELL",
    ["Data"] = T("Revive Champion")
}

BindTypeTooltipColors = {
    ["SPELL"] = normalFontColor,
    ["ACTION"] = normalFontColor,
    ["MACRO"] = {1, 0.6, 1},
    ["ITEM"] = {1, 1, 1},
    ["SCRIPT"] = {1, 0.5, 0.3},
    ["MULTI"] = normalFontColor
}


SpellsTooltip = CreateFrame("GameTooltip", "PTSpellsTooltip", UIParent, "GameTooltipTemplate")
SpellsTooltipOwner = nil
SpellsTooltipUnit = nil
SpellsTooltipAttach = nil
SpellsTooltipPowerBar = nil
do
    local manaBar = CreateFrame("StatusBar", "PTSpellsTooltipManaBar", SpellsTooltip)
    SpellsTooltipPowerBar = manaBar
    manaBar:SetStatusBarTexture(BarStyles["Puppeteer"])
    manaBar:SetMinMaxValues(0, 1)
    manaBar:SetWidth(100)
    manaBar:SetHeight(12)
    manaBar:SetPoint("TOPRIGHT", SpellsTooltip, "TOPRIGHT", -10, -12)

    local bg = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBar.background = bg
    bg:SetAllPoints(true)
    bg:SetTexture(0.3, 0.3, 0.3, 0.8)

    local text = manaBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    manaBar.text = text
    text:SetWidth(manaBar:GetWidth())
    text:SetHeight(manaBar:GetHeight())
    text:SetPoint("CENTER", manaBar, "CENTER")
    text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    text:SetShadowOffset(0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("CENTER")
end


local currentPower
local currentMaxPower
local currentPowerType


function InitBindingDisplayCache()
    ButtonDisplayCache = {}
    for _, button in ipairs(PTOptions.Buttons) do
        ButtonDisplayCache[button] = {}
        ButtonDisplayCache[button]["Normal"] = PTOptions.ButtonInfo[button].Name or button
        ButtonDisplayCache[button]["Unfocused"] = colorize(PTOptions.ButtonInfo[button].Name or button, 0.3, 0.3, 0.3)
    end

    BindingDisplayCache = {}
    for _, targetType in ipairs(targetTypes) do
        local levelTargetType = {}
        BindingDisplayCache[targetType] = levelTargetType
        for _, modifier in ipairs(util.GetKeyModifiers()) do
            local levelModifier = {}
            levelTargetType[modifier] = levelModifier
            for _, button in ipairs(PTOptions.Buttons) do
                local entry = {}
                levelModifier[button] = entry
            end
        end
    end
end

function MarkDisplayCacheDirty()

end

function UpdateBindingDisplays(targetType, modifier, forceUpdate)
    currentPower = UnitMana("player")
    currentMaxPower = UnitManaMax("player")
    currentPowerType = util.GetPowerType("player")
    local entries = BindingDisplayCache[targetType][modifier]
    for button, entry in pairs(entries) do
        UpdateBindingDisplay(GetBinding(targetType, modifier, button), entry, forceUpdate)
    end
    return entries
end

function UpdateBindingDisplay(binding, entry, fullUpdate)
    if fullUpdate then
        entry.Normal = nil
    end
    local prevNormal = entry.Normal
    _UpdateBindingDisplay(binding, entry)
    if prevNormal ~= entry.Normal then
        entry.Unfocused = colorize(util.StripColors(entry.Normal), 0.3, 0.3, 0.3)
    end
    return entry
end

function _UpdateBindingDisplay(binding, entry)
    if binding == nil or binding.Type == nil or binding.Data == nil then
        entry.Normal = unboundText
        return
    end
    local options = PTOptions.SpellsTooltip
    local currentPower = currentPower or UnitMana("player")
    local maxPower = currentMaxPower or UnitManaMax("player")
    local powerType = currentPowerType or util.GetPowerType("player")
    local needsUpdate = not entry.Normal
    local textColor = binding.Tooltip and binding.Tooltip.TextColor or BindTypeTooltipColors[binding.Type]
    local text = binding.Tooltip and binding.Tooltip.Data
    if binding.Type == "SPELL" then
        local spell = binding.Data
        if spell == "" then
            if needsUpdate then
                entry.Normal = unboundText
                entry.Casts = -1
            end
            return
        end
        local cost, resource = GetResourceCost(spell)
        if cost == "unknown" then
            if needsUpdate then
                entry.Normal = colorize(spell.." (Unknown)", 1, 0.4, 0.4)
                entry.Casts = -1
            end
            return
        elseif cost == 0 then
            entry.Normal = text or spell
            entry.Casts = -1
            return
        end

        local casts = math.floor(currentPower / cost)
        local resourceColor = tooltipPowerColors[resource]
        if resource ~= powerType then -- A druid can't cast a spell that requires a different power type
            casts = 0
        end
        if entry.Casts == casts and not needsUpdate then
            return
        end
        local spellText = colorize(text or spell, textColor)
        local costText
        if powerType == "mana" and resource == powerType then
            if options.ShowManaCost then
                costText = cost
            end
            if options.ShowManaPercentCost then
                costText = (costText and (costText.." ") or "")..util.RoundNumber((cost / maxPower) * 100, 1).."%"
            end
        else
            costText = cost
        end
        if casts == 0 then
            spellText = colorize(util.StripColors(spellText), 0.5, 0.5, 0.5)
        end
        if costText then
            spellText = spellText.." "..colorize(costText, resourceColor)
        end
        if casts <= options.HideCastsAbove then
            local castsColor
            if casts == 0 then
                castsColor = tooltipCastsColors["Zero"]
            elseif casts <= options.CriticalCastsLevel then
                castsColor = tooltipCastsColors["Critical"]
            else
                castsColor = tooltipCastsColors["Normal"]
            end
            spellText = spellText..colorize(" ("..casts..")", castsColor)
        end
        entry.Normal = spellText
        entry.Casts = casts
    elseif binding.Type == "ACTION" then
        entry.Normal = colorize(text or binding.Data, textColor)
    elseif binding.Type == "ITEM" then
        local item = binding.Data

        text = colorize(text or item, textColor)

        if PTOptions.SpellsTooltip.ShowItemCount then
            if not entry.NextUpdate or GetTime() > entry.NextUpdate then
                entry.Casts = GetItemCount(item) -- This is giga expensive
                entry.NextUpdate = GetTime() + 2
            end
            local casts = entry.Casts
            if casts <= options.HideCastsAbove then
                local castsColor
                if casts == 0 then
                    castsColor = tooltipCastsColors["Zero"]
                elseif casts <= options.CriticalCastsLevel then
                    castsColor = tooltipCastsColors["Critical"]
                else
                    castsColor = tooltipCastsColors["Normal"]
                end
                text = text..colorize(" ("..casts..")", castsColor)
            end
        end
        entry.Normal = text
    elseif binding.Type == "MACRO" then
        text = text or binding.Data
        if IsValidMacro(binding.Data) then
            text = colorize(text, textColor)
        else
            text = colorize(text.." (Invalid Macro)", 1, 0.4, 0.4)
        end
        entry.Normal = text
    elseif binding.Type == "SCRIPT" then
        entry.Normal =  colorize(text or "Script", textColor)
    elseif binding.Type == "MULTI" then
        entry.Normal = colorize(text or (binding.Data.Title ~= "" and binding.Data.Title) or "Multi", textColor)
    else
        entry.Normal = "Unhandled"
    end
end

function ApplySpellsTooltip(attachTo, unit, owner)
    if not PTOptions.SpellsTooltip.Enabled then
        return
    end
    --StartTiming("SpellsTooltip")
    SetTooltipKeyListenerEnabled(true)
    SpellsTooltipOwner = owner
    SpellsTooltipAttach = attachTo
    SpellsTooltipUnit = unit
    SpellsTooltip:SetOwner(attachTo, tooltipAnchorMap[PTOptions.SpellsTooltip.Anchor], 
        PTOptions.SpellsTooltip.OffsetX, PTOptions.SpellsTooltip.OffsetY)
    local options = PTOptions.SpellsTooltip
    local currentPower = UnitMana("player")
    local maxPower = UnitManaMax("player")
    local powerType = util.GetPowerType("player")
    local powerColor = tooltipPowerColors[powerType]
    local powerText = ""
    local showPowerBar = options.ShowPowerBar
    if options.ShowPowerAs == "Power" then
        powerText = tostring(currentPower)
    elseif options.ShowPowerAs == "Power/Max Power" then
        powerText = currentPower.."/"..maxPower
    elseif options.ShowPowerAs == "Power %" then
        powerText = util.RoundNumber((currentPower / maxPower) * 100).."%"
    end

    if showPowerBar then
        local r, g, b = util.InterpolateColorsNoTable(lowToHighColors, (currentPower / maxPower))
        powerText = colorize(powerText, r, g, b)
        SpellsTooltipPowerBar:SetStatusBarColor(powerColor[1], powerColor[2], powerColor[3])
        SpellsTooltipPowerBar:SetValue(currentPower / maxPower)
        SpellsTooltipPowerBar.text:SetText(powerText)
    else
        powerText = colorize(powerText, powerColor)
    end

    local modifier = GetKeyModifier()
    local displayModifier = modifier ~= "None" and 
        util.GetKeyModifierTypeByID(1 + (options.AbbreviatedKeys and 2 or 0) + (options.ColoredKeys and 1 or 0)) or " "
    SpellsTooltip:AddDoubleLine(displayModifier, showPowerBar and "                 " or powerText, 1, 1, 1)

    local friendly = not UnitCanAttack("player", unit)
    
    local deadFriend = util.IsDeadFriend(unit)
    local selfClass = GetClass("player")
    local canResurrect = PTOptions.AutoResurrect and deadFriend and util.ResurrectionSpells[selfClass]
    local canReviveChampion = canResurrect and util.GetSpellID(T("Revive Champion")) and 
        PTUnit.Get(unit):HasBuffIDOrName(45568, T("Holy Champion")) and UnitAffectingCombat("player")
    local resEntry
    if canReviveChampion then
        resEntry = UpdateBindingDisplay(SpecialSpellBindings[T("Revive Champion")], compost:GetTable())
    elseif canResurrect then
        resEntry = UpdateBindingDisplay(SpecialSpellBindings[util.ResurrectionSpells[selfClass]], compost:GetTable())
    end
    
    --StartTiming("BindingDisplays")
    local entries = UpdateBindingDisplays(friendly and "Friendly" or "Hostile", modifier)
    --EndTiming("BindingDisplays")
    for _, button in ipairs(PTOptions.Buttons) do
        local focused = not CurrentlyHeldButton or button == CurrentlyHeldButton
        local displayCache = entries[button]

        local leftText = focused and ButtonDisplayCache[button].Normal or ButtonDisplayCache[button].Unfocused

        local rightText
        local usingRes
        if resEntry then
            local binding = GetBindingFor(unit, modifier, button)
            if not binding or binding.Type == "SPELL" then
                rightText = focused and resEntry.Normal or resEntry.Unfocused
                usingRes = true
            end
        end
        rightText = rightText or (focused and displayCache.Normal or displayCache.Unfocused)

        if displayCache.Normal ~= unboundText or usingRes or PTOptions.ButtonInfo[button].ShowUnbound then
            SpellsTooltip:AddDoubleLine(leftText, rightText)
        end
    end
    if resEntry then
        compost:Reclaim(resEntry)
    end
    SpellsTooltip:Show()
    --EndTiming("SpellsTooltip")
end

function HideSpellsTooltip()
    SpellsTooltip:Hide()
    SpellsTooltipOwner = nil
    SpellsTooltipAttach = nil
    SpellsTooltipUnit = nil
    SetTooltipKeyListenerEnabled(false)
end

function ReapplySpellsTooltip()
    if SpellsTooltipOwner ~= nil then
        SpellsTooltip:Hide()
        ApplySpellsTooltip(SpellsTooltipAttach, SpellsTooltipUnit, SpellsTooltipAttach)
    end
end